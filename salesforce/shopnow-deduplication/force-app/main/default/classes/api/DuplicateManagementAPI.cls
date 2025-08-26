@RestResource(urlMapping='/duplicates/*')
global with sharing class DuplicateManagementAPI {
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
    global static void getPending() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            SecurityUtil.validateAccess('ShopNow_Deduplication_Access');

            List<String> parts = pathParts(req.requestURI);
            Boolean isPending = (parts.size() > 0 && parts[parts.size()-1].toLowerCase() == 'pending');
            if (!isPending) { sendError(res, 404, 'Not Found', 'Use /duplicates/pending.'); return; }

            Integer pageLimit   = toInt(req, 'limit', 50);
            Integer pageOffset  = toInt(req, 'offset', 0);
            Decimal minScore    = toDecimal(req, 'minScore', 0);
            Integer sinceDays   = toInt(req, 'sinceDays', 365);   // ajuda seletividade via CreatedDate indexado
            String  sortParam   = SecurityUtil.sanitizeInput(getParam(req, 'sort'), 32, false);
            String  orderParam  = SecurityUtil.sanitizeInput(getParam(req, 'order'), 4,  false);

            if (pageLimit == null || pageLimit <= 0 || pageLimit > 200) pageLimit = 50;
            if (pageOffset == null || pageOffset < 0) pageOffset = 0;
            if (sinceDays == null || sinceDays <= 0 || sinceDays > 1825) sinceDays = 365;

            String sortField = 'CreatedDate';
            String allowedSort = SecurityUtil.sanitizeSort(sortParam, new Set<String>{ 'score', 'createddate' }, 'createddate');
            if (allowedSort == 'score') sortField = 'Match_Score__c';
            String sortOrder = (orderParam != null && orderParam.toLowerCase() == 'asc') ? 'ASC' : 'DESC';

            SecurityUtil.checkCRUD(Duplicate_Match__c.SObjectType, 'read');
            SecurityUtil.checkFLS(
                Duplicate_Match__c.SObjectType,
                new Set<String>{ 'Match_Score__c', 'Status__c', 'Customer_A__c', 'Customer_B__c' },
                'read'
            );
            SecurityUtil.checkCRUD(Customer__c.SObjectType, 'read');
            SecurityUtil.checkFLS(
                Customer__c.SObjectType,
                new Set<String>{ 'FirstName__c', 'LastName__c', 'Email__c', 'Phone__c' },
                'read'
            );

            Datetime startDate = System.now().addDays(-sinceDays);

            Integer total = (Integer)Database.countQuery(
                'SELECT COUNT() FROM Duplicate_Match__c ' +
                'WHERE Status__c = \'Pending Review\' AND Match_Score__c >= :minScore AND CreatedDate >= :startDate'
            );

            String soql =
                'SELECT Id, Match_Score__c, Status__c, CreatedDate, ' +
                'Customer_A__c, Customer_A__r.FirstName__c, Customer_A__r.LastName__c, ' +
                'Customer_A__r.Email__c, Customer_A__r.Phone__c, ' +
                'Customer_B__c, Customer_B__r.FirstName__c, Customer_B__r.LastName__c, ' +
                'Customer_B__r.Email__c, Customer_B__r.Phone__c ' +
                'FROM Duplicate_Match__c ' +
                'WHERE Status__c = \'Pending Review\' AND Match_Score__c >= :minScore AND CreatedDate >= :startDate ' +
                'ORDER BY ' + sortField + ' ' + sortOrder + ' ' +
                'LIMIT :pageLimit OFFSET :pageOffset';

            List<Duplicate_Match__c> rows = Database.query(soql);

            SObjectAccessDecision dec = Security.stripInaccessible(AccessType.READABLE, rows);
            rows = (List<Duplicate_Match__c>) dec.getRecords();


            List<DuplicateItemDTO> items = new List<DuplicateItemDTO>();
            for (Duplicate_Match__c r : rows) {
                DuplicateItemDTO item = new DuplicateItemDTO();
                item.id       = r.Id;
                item.score    = r.Match_Score__c;
                item.status   = r.Status__c;
                item.createdAt= r.CreatedDate;

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

            Map<String, Object> page = new Map<String, Object>{
                'limit'  => pageLimit,
                'offset' => pageOffset,
                'total'  => total
            };
            Map<String, Object> payload = new Map<String, Object>{
                'items' => items,
                'page'  => page
            };

            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(payload));
            AppLogger.debug('GET /duplicates/pending OK', buildCtx());

        } catch (SecurityException se) {
            AppLogger.warn('Security violation in GET /duplicates/pending', buildCtx());
            sendError(res, 403, 'Forbidden', se.getMessage());
        } catch (QueryException qe) {
            AppLogger.error('QueryException in GET /duplicates/pending', qe, buildCtx());
            sendError(res, 403, 'Forbidden', qe.getMessage());
        } catch (Exception e) {
            AppLogger.error('Unexpected in GET /duplicates/pending', e, buildCtx());
            sendError(res, 500, 'Internal Server Error', e.getMessage());
        }
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
            action = action.toLowerCase();
            if (action != 'merge' && action != 'ignore') { sendError(res, 400, 'Bad Request', 'Use "merge" ou "ignore".'); return; }

            SecurityUtil.checkCRUD(Duplicate_Match__c.SObjectType, 'update');
            SecurityUtil.checkFLS(Duplicate_Match__c.SObjectType, new Set<String>{ 'Status__c' }, 'update');
            if (action == 'merge') {
                SecurityUtil.checkCRUD(Customer__c.SObjectType, 'delete');
            }

            Duplicate_Match__c m = [
                SELECT Id, Status__c, Match_Score__c, Customer_A__c, Customer_B__c
                FROM Duplicate_Match__c
                WHERE Id = :matchId
                LIMIT 1
            ];

            if (m.Status__c != 'Pending Review') {
                sendError(res, 400, 'Bad Request', 'Apenas "Pending Review" pode ser resolvido.');
                return;
            }

            Savepoint sp = Database.setSavepoint();
            try {
                if (action == 'ignore') {
                    m.Status__c = 'Ignored';
                    update m;
                } else {
                    if (m.Customer_B__c != null) {
                        delete new List<Customer__c>{ new Customer__c(Id = m.Customer_B__c) };
                    }
                    m.Status__c = 'Merged';
                    update m;
                }

                Map<String, Object> ok = new Map<String, Object>{
                    'status' => 'ok', 'action' => action, 'matchId' => m.Id
                };
                res.statusCode = 200;
                res.responseBody = Blob.valueOf(JSON.serialize(ok));

                AppLogger.info('Duplicate resolved', new Map<String,Object>{
                    'matchId' => m.Id, 'action' => action
                });

            } catch (DmlException dml) {
                Database.rollback(sp);
                AppLogger.error('DML error in POST /resolve', dml, buildCtx());
                sendError(res, 400, 'Bad Request', dml.getMessage());
            } catch (Exception ex) {
                Database.rollback(sp);
                AppLogger.error('Unexpected in POST /resolve (inner)', ex, buildCtx());
                sendError(res, 500, 'Internal Server Error', ex.getMessage());
            }

        } catch (SecurityException se) {
            AppLogger.warn('Security violation in POST /resolve', buildCtx());
            sendError(res, 403, 'Forbidden', se.getMessage());
        } catch (QueryException qe) {
            AppLogger.error('Not Found in POST /resolve', qe, buildCtx());
            sendError(res, 404, 'Not Found', 'Duplicate_Match__c não encontrado.');
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
    private static String getParam(RestRequest req, String name) {
        return (req.params != null && req.params.containsKey(name)) ? req.params.get(name) : null;
    }
    private static Integer toInt(RestRequest req, String name, Integer defVal) {
        try { String s = getParam(req, name); return (s == null) ? defVal : Integer.valueOf(s); }
        catch (Exception e) { return defVal; }
    }
    private static Decimal toDecimal(RestRequest req, String name, Decimal defVal) {
        try { String s = getParam(req, name); return (s == null) ? defVal : Decimal.valueOf(s); }
        catch (Exception e) { return defVal; }
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
        res.statusCode = code;
        ErrorResponseDTO err = new ErrorResponseDTO();
        err.message = message;
        err.details = details;
        res.responseBody = Blob.valueOf(JSON.serialize(err));
    }
}
 