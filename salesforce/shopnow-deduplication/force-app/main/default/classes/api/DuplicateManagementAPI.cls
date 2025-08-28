/**
 * REST API for duplicate management operations.
 * 
 * Helper methods are kept private within this class as they are:
 * - Specific to this API's request/response format
 * - Relatively simple (< 20 lines each)
 * - Not reused by other components
 * 
 * In a larger system with multiple APIs sharing similar patterns,
 * these would be extracted to shared utility classes.
 */
@RestResource(urlMapping='/duplicates/*')
global with sharing class DuplicateManagementAPI extends BaseAPI {

    global class ResolveRequest { 
        public String action; 
    }

    global class ResolveResponse {
        public String id;
        public String action;
        public String status;
        public String message;
        public Id survivingCustomer;
        public Id mergedCustomer;
    }

    @TestVisible
    private static DuplicateResolutionService service = new DuplicateResolutionService();

    @TestVisible
    private static String subPath() {
        RestRequest req = RestContext.request;
        if (req == null || String.isBlank(req.requestURI)) return '';
        String uri = req.requestURI;
       
        String afterDuplicates = uri.substringAfter('/duplicates');
        Integer questionMarkIndex = afterDuplicates.indexOf('?');
        if (questionMarkIndex != -1) afterDuplicates = afterDuplicates.substring(0, questionMarkIndex);   
        return afterDuplicates;
    }

    @HttpGet
    global static void getPending() {
        new DuplicateManagementAPI().handleGetPending();
    }

    @HttpPost
    global static void resolve() {
        new DuplicateManagementAPI().handleResolve();
    }

    private void handleGetPending() {
        logDebug('handleGetPending', 'Processing GET /duplicates/pending request');
        
        setCorsHeaders();
        
        Long startTime = System.currentTimeMillis();

        try {
            String path = subPath();
            String lowerPath = path != null ? path.toLowerCase() : '';
            if (String.isBlank(lowerPath) || (lowerPath != '/pending' && lowerPath != 'pending')) {
                notFound('Route not found. Expected GET /duplicates/pending');
                return;
            }

            Integer limitValue = validateQueryInteger('limit', 50, 1, 200);
            Integer offsetValue = validateQueryInteger('offset', 0, 0, null);
            Integer minScoreValue = validateQueryInteger('minScore', 0, 0, 100);

            String sortParam = qAllowed('sort', 'score', new Set<String>{ 'score', 'createddate', 'status' });
            String orderParam = qAllowed('order', 'desc', new Set<String>{ 'asc', 'desc' });

            List<DuplicateResolutionService.DuplicateItemDTO> dtoItems =
                service.getPendingDtos(limitValue, offsetValue, minScoreValue, sortParam, orderParam);

            Integer totalCount = service.getTotalCount(minScoreValue);

            List<Object> objectItems = new List<Object>();
            for (DuplicateResolutionService.DuplicateItemDTO dto : dtoItems) {
                objectItems.add(dto);
            }

            Map<String, Object> response = new Map<String, Object>{
                'items' => objectItems,
                'pagination' => new Map<String, Object>{
                    'limit' => limitValue,
                    'offset' => offsetValue,
                    'total' => totalCount,
                    'hasMore' => (offsetValue + dtoItems.size()) < totalCount
                }
            };

            Long executionTime = System.currentTimeMillis() - startTime;
            setMetric('api_getPending_executionTime', executionTime);
            setMetric('api_getPending_resultCount', dtoItems.size());

            logInfo('handleGetPending', 'Successfully processed GET request in ' + executionTime + 'ms, returned ' + dtoItems.size() + ' items');

            ok(response);

        } catch (Exception e) {
            Long executionTime = System.currentTimeMillis() - startTime;
            logError('handleGetPending', 'Failed to process GET request after ' + executionTime + 'ms', e);
            error(500, 'server_error', 'Failed to fetch pending duplicates: ' + e.getMessage(), null);
        }
    }

    private void handleResolve() {
        logDebug('handleResolve', 'Processing POST /duplicates/{id}/resolve request');
        
        setCorsHeaders();
        
        Long startTime = System.currentTimeMillis();

        try {
            String path = subPath();
            String lowerPath = path != null ? path.toLowerCase() : '';
            if (String.isBlank(lowerPath) || !lowerPath.endsWith('/resolve') || path.length() <= '/resolve'.length() + 1) {
                notFound('Route not found. Expected POST /duplicates/{id}/resolve');
                return;
            }

            String matchId = path.substringBetween('/', '/resolve');
            if (String.isBlank(matchId)) {
                badRequest('Missing duplicate match Id', null);
                return;
            }
               
            ResolveRequest requestBody = parseRequestBody();
            if (requestBody == null || String.isBlank(requestBody.action)) {
                badRequest('Missing action parameter', null);
                return;
            }

            Duplicate_Match__c matchRecord = validateAndGetMatch(matchId);
            if (matchRecord == null) {
                notFound('Duplicate match not found: ' + matchId);
                return;
            }

            service.resolveSingle(matchId, requestBody.action);

            ResolveResponse response = buildResolveResponse(matchId, requestBody.action, matchRecord);

            Long executionTime = System.currentTimeMillis() - startTime;
            setMetric('api_resolve_executionTime', executionTime);
            setMetric('api_resolve_action', requestBody.action.toLowerCase());

            logInfo('handleResolve', 'Successfully processed resolve request for match ' + matchId + ' in ' + executionTime + 'ms');

            ok(response);

        } catch (CalloutException ce) {
            Long executionTime = System.currentTimeMillis() - startTime;
            logWarning('handleResolve', 'Business logic exception after ' + executionTime + 'ms: ' + ce.getMessage());
            badRequest(ce.getMessage(), null);
        } catch (Exception e) {
            Long executionTime = System.currentTimeMillis() - startTime;
            logError('handleResolve', 'Failed to process resolve request after ' + executionTime + 'ms', e);
            error(500, 'server_error', 'Failed to resolve duplicate: ' + e.getMessage(), null);
        }
    }

    private ResolveRequest parseRequestBody() {
        try {
            if (RestContext.request == null || RestContext.request.requestBody == null) {
                return null;
            }
            
            String requestBodyString = RestContext.request.requestBody.toString();
            if (String.isBlank(requestBodyString)) {
                return null;
            }
            
            return (ResolveRequest) JSON.deserialize(requestBodyString, ResolveRequest.class);
        } catch (Exception e) {
            logWarning('parseRequestBody', 'Failed to parse request body: ' + e.getMessage());
            badRequest('Invalid request body: ' + e.getMessage(), null);
            return null;
        }
    }

    private Duplicate_Match__c validateAndGetMatch(String matchId) {
        try {
            matchId = sanitizeInput(matchId, 18, false);
            
            if (String.isBlank(matchId)) {
                return null;
            }

            List<Duplicate_Match__c> matches = [
                SELECT Id, Customer_A__c, Customer_B__c, Status__c 
                FROM Duplicate_Match__c 
                WHERE Id = :matchId 
                LIMIT 1
            ];

            return matches.isEmpty() ? null : matches[0];

        } catch (Exception e) {
            logError('validateAndGetMatch', 'Failed to validate/retrieve match: ' + matchId, e);
            return null;
        }
    }

    private ResolveResponse buildResolveResponse(String matchId, String action, Duplicate_Match__c matchRecord) {
        ResolveResponse response = new ResolveResponse();
        response.id = matchId;
        response.action = action.toLowerCase();
        response.status = 'success';

        if (response.action == 'merge') {
            response.message = 'Customer successfully merged via soft delete';
            response.survivingCustomer = matchRecord.Customer_A__c;
            response.mergedCustomer = matchRecord.Customer_B__c;
        } else if (response.action == 'ignore') {
            response.message = 'Duplicate match ignored successfully';
        }

        return response;
    }
}