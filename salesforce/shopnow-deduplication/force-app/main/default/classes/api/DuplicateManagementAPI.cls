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
        setCorsHeaders();
        DuplicateManagementAPI api = new DuplicateManagementAPI();

        String path = subPath();
        String lowerPath = path != null ? path.toLowerCase() : '';
        if (String.isBlank(lowerPath) || (lowerPath != '/pending' && lowerPath != 'pending')) {
            api.notFound('Route not found. Expected GET /duplicates/pending');
            return;
        }

        try {
            Integer limitValue = api.validateQueryInteger('limit', 50, 1, 200);
            Integer offsetValue = api.validateQueryInteger('offset', 0, 0, null);
            Integer minScoreValue = api.validateQueryInteger('minScore', 0, 0, 100);

            String sortParam = api.qAllowed('sort', 'score', new Set<String>{ 'score', 'createddate', 'status' });
            String orderParam = api.qAllowed('order', 'desc', new Set<String>{ 'asc', 'desc' });

            List<DuplicateResolutionService.DuplicateItemDTO> dtoItems =
                service.getPendingDtos(limitValue, offsetValue, minScoreValue, sortParam, orderParam);

            // Get total count for pagination
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

            api.ok(response);
        } catch (Exception e) {
            api.error(500, 'server_error', 'Failed to fetch pending duplicates: ' + e.getMessage(), null);
        }
    }

    @HttpPost
    global static void resolve() {
        setCorsHeaders();
        DuplicateManagementAPI api = new DuplicateManagementAPI();

        String path = subPath();
        String lowerPath = path != null ? path.toLowerCase() : '';
        if (String.isBlank(lowerPath) || !lowerPath.endsWith('/resolve') || path.length() <= '/resolve'.length() + 1) {
            api.notFound('Route not found. Expected POST /duplicates/{id}/resolve');
            return;
        }

        String matchId = path.substringBetween('/', '/resolve');
        if (String.isBlank(matchId)) {
            api.badRequest('Missing duplicate match Id', null);
            return;
        }

        ResolveRequest requestBody;
        try {
            String requestBodyString = RestContext.request.requestBody.toString();
            requestBody = (ResolveRequest) JSON.deserialize(requestBodyString, ResolveRequest.class);
        } catch (Exception e) {
            api.badRequest('Invalid request body: ' + e.getMessage(), null);
            return;
        }

        if (requestBody == null || String.isBlank(requestBody.action)) {
            api.badRequest('Missing action parameter', null);
            return;
        }

        try {
            Duplicate_Match__c matchRecord = [
                SELECT Id, Customer_A__c, Customer_B__c, Status__c 
                FROM Duplicate_Match__c 
                WHERE Id = :matchId 
                LIMIT 1
            ];

            service.resolveSingle(matchId, requestBody.action);

            ResolveResponse response = new ResolveResponse();
            response.id = matchId;
            response.action = requestBody.action.toLowerCase();
            response.status = 'success';

            if (response.action == 'merge') {
                response.message = 'Customer successfully merged via soft delete';
                response.survivingCustomer = matchRecord.Customer_A__c;
                response.mergedCustomer = matchRecord.Customer_B__c;
            } else if (response.action == 'ignore') {
                response.message = 'Duplicate match ignored successfully';
            }

            api.ok(response);

        } catch (CalloutException ce) {
            api.badRequest(ce.getMessage(), null);
        } catch (QueryException qe) {
            api.notFound('Duplicate match not found: ' + matchId);
        } catch (Exception e) {
            api.error(500, 'server_error', 'Failed to resolve duplicate: ' + e.getMessage(), null);
        }
    }
}