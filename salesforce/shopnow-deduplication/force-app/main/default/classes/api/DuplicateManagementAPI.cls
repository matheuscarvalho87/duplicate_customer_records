@RestResource(urlMapping='/duplicates/*')
global with sharing class DuplicateManagementAPI extends BaseAPI {

    global class CustomerDTO {
        public Id id;
        public String firstName;
        public String lastName;
        public String email;
        public String phone;
    }
    global class DuplicateItemDTO {
        public Id id;
        public Decimal score;
        public String status;
        public Datetime createdAt;
        public CustomerDTO customerA;
        public CustomerDTO customerB;
    }
    global class ErrorResponseDTO {
        public String message;
        public String details;
    }

    @HttpGet
    global static void get() {
        DuplicateManagementAPI api = new DuplicateManagementAPI();
        try {
            SecurityUtil.validateAccess('ShopNow_Deduplication_Access');

            String path = (RestContext.request != null && RestContext.request.requestURI != null)
                ? RestContext.request.requestURI.toLowerCase() : '';
            if (path.endsWith('/pending')) {
                api.handleGetPending();
            } else {
                sendError(RestContext.response, 404, 'Not Found', 'Use /duplicates/pending.');
            }
        } catch (SecurityException se) {
            AppLogger.warn('Security violation in GET /duplicates/pending', buildCtx());
            sendError(RestContext.response, 403, 'Forbidden', se.getMessage());
        } catch (QueryException qe) {
            AppLogger.error('QueryException in GET /duplicates/pending', qe, buildCtx());
            sendError(RestContext.response, 403, 'Forbidden', qe.getMessage());
        } catch (Exception e) {
            AppLogger.error('Unexpected in GET /duplicates/pending', e, buildCtx());
            sendError(RestContext.response, 500, 'Internal Server Error', e.getMessage());
        }
    }

    @TestVisible
    private void handleGetPending() {
        Long t0 = System.currentTimeMillis();

        Integer pageLimit   = validateQueryInteger('limit',     50, 1, 200);
        Integer pageOffset  = validateQueryInteger('offset',     0, 0, 5000);
        Decimal minScore    = validateQueryDecimal('minScore',   0, 0, 1000);
        Integer sinceDays   = validateQueryInteger('sinceDays', 365, 1, 1825);

        String sortParam  = sanitizeInput(q('sort',  null), 32, false);
        String orderParam = sanitizeInput(q('order', null),  4, false);

        String allowedSort = SecurityUtil.sanitizeSort(sortParam, new Set<String>{ 'score', 'createddate' }, 'createddate');
        String sortField   = (allowedSort == 'score') ? 'Match_Score__c' : 'CreatedDate';
        String sortOrder   = (orderParam != null && orderParam.toLowerCase() == 'asc') ? 'ASC' : 'DESC';

        Datetime startDate = System.now().addDays(-sinceDays);
        String statusPending = 'Pending Review';

        Integer total = DuplicateMatchSelector.countPending(minScore, startDate, statusPending);

        DuplicateMatchSelector.PendingFilter f = new DuplicateMatchSelector.PendingFilter();
        f.minScore   = minScore;
        f.startDate  = startDate;
        f.sortField  = sortField;
        f.sortOrder  = sortOrder.toUpperCase();
        f.limitSize  = pageLimit;
        f.offsetSize = pageOffset;
        f.statusValue= statusPending;

        List<Duplicate_Match__c> rows = DuplicateMatchSelector.selectPending(f);

        List<DuplicateItemDTO> items = new List<DuplicateItemDTO>();
        for (Duplicate_Match__c r : rows) {
            DuplicateItemDTO item = new DuplicateItemDTO();
            item.id        = r.Id;
            item.score     = r.Match_Score__c;
            item.status    = r.Status__c;
            item.createdAt = r.CreatedDate;

            CustomerDTO ca = new CustomerDTO();
            ca.id = r.Customer_A__c;
            if (r.Customer_A__r != null) {
                ca.firstName = r.Customer_A__r.FirstName__c;
                ca.lastName  = r.Customer_A__r.LastName__c;
                ca.email     = r.Customer_A__r.Email__c;
                ca.phone     = r.Customer_A__r.Phone__c;
            }
            item.customerA = ca;

            CustomerDTO cb = new CustomerDTO();
            cb.id = r.Customer_B__c;
            if (r.Customer_B__r != null) {
                cb.firstName = r.Customer_B__r.FirstName__c;
                cb.lastName  = r.Customer_B__r.LastName__c;
                cb.email     = r.Customer_B__r.Email__c;
                cb.phone     = r.Customer_B__r.Phone__c;
            }
            item.customerB = cb;

            items.add(item);
        }

        Map<String, Object> payload = new Map<String, Object>{
            'items' => items,
            'page'  => new Map<String, Object>{
                'limit'  => pageLimit,
                'offset' => pageOffset,
                'total'  => total
            }
        };

        performanceMetrics.put('api.pending.limit', pageLimit);
        performanceMetrics.put('api.pending.offset', pageOffset);
        performanceMetrics.put('api.pending.minScore', minScore);
        performanceMetrics.put('api.pending.sinceDays', sinceDays);
        performanceMetrics.put('api.pending.rows', rows.size());
        performanceMetrics.put('api.pending.total', total);
        performanceMetrics.put('api.pending.timeMs', System.currentTimeMillis() - t0);

        AppLogger.debug('GET /duplicates/pending OK (selector)', buildCtx());
        ok(payload);
    }


    @HttpPost
    global static void resolve() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            SecurityUtil.validateAccess('ShopNow_Deduplication_Access');

            Id matchId = extractMatchId(req.requestURI);
            if (matchId == null) { sendError(res, 400, 'Bad Request', 'Use /duplicates/{id}/resolve'); return; }

            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());
            String action = (body != null && body.containsKey('action')) ? String.valueOf(body.get('action')) : null;

            if (String.isBlank(action)) { sendError(res, 400, 'Bad Request', 'action é obrigatório (merge|ignore).'); return; }

            DuplicateResolutionService svc = new DuplicateResolutionService();
            svc.resolve(matchId, action);

            Map<String, Object> ok = new Map<String, Object>{
                'status' => 'ok', 'action' => action.toLowerCase(), 'matchId' => matchId
            };
            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(ok));

            AppLogger.info('Duplicate resolved', new Map<String,Object>{
                'matchId' => matchId, 'action' => action
            });

        } catch (SecurityException se) {
            AppLogger.warn('Security violation in POST /resolve', buildCtx());
            sendError(res, 403, 'Forbidden', se.getMessage());
        } catch (QueryException qe) {
            AppLogger.error('Not Found in POST /resolve', qe, buildCtx());
            sendError(res, 404, 'Not Found', 'Duplicate_Match__c não encontrado.');
        } catch (AuraHandledException ahe) {
            AppLogger.warn('Business guard in POST /resolve', new Map<String,Object>{ 'msg' => ahe.getMessage() });
            sendError(res, 400, 'Bad Request', ahe.getMessage());
        } catch (DmlException dml) {
            AppLogger.error('DML error in POST /resolve', dml, buildCtx());
            sendError(res, 400, 'Bad Request', dml.getMessage());
        } catch (Exception e) {
            AppLogger.error('Unexpected in POST /resolve (outer)', e, buildCtx());
            sendError(res, 500, 'Internal Server Error', e.getMessage());
        }
    }

    private static Map<String,Object> buildCtx() {
        return new Map<String,Object>{
            'uri' => (RestContext.request != null ? RestContext.request.requestURI : null),
            'userId' => UserInfo.getUserId()
        };
    }

    private static Id extractMatchId(String uri) {
        List<String> parts = pathParts(uri);
        if (parts.isEmpty()) return null;
        for (Integer i = 0; i < parts.size(); i++) {
            if (parts[i].toLowerCase() == 'duplicates' && i+2 < parts.size()) {
                String candidate = parts[i+1];
                String tail = parts[i+2].toLowerCase();
                if (tail == 'resolve') {
                    try { return Id.valueOf(candidate); } catch (Exception e) { return null; }
                }
            }
        }
        return null;
    }
    private static List<String> pathParts(String uri) {
        if (String.isBlank(uri)) return new List<String>();
        String pathOnly = uri.split('\\?')[0];
        return pathOnly.split('/');
    }

    private static void sendError(RestResponse res, Integer code, String message, String details) {
        BaseAPI.setCorsHeaders();
        if (res == null) res = new RestResponse();
        res.statusCode = code;
        ErrorResponseDTO err = new ErrorResponseDTO();
        err.message = message;
        err.details = details;
        res.responseBody = Blob.valueOf(JSON.serialize(err));
    }
}
