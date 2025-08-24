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

    global class PaginationDTO {
        public Integer pageSize;
        public Integer pageOffset;
        public Integer total;
    }
    global class DuplicateResponseDTO {
        public List<DuplicateItemDTO> items;
        public PaginationDTO page;
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
            List<String> parts = String.isBlank(req.requestURI) ? new List<String>() : req.requestURI.split('/');
            Boolean isPending = (parts.size() > 0 && parts[parts.size()-1].toLowerCase() == 'pending');
            if (!isPending) {
                sendError(res, 404, 'Not Found', 'Endpoint não encontrado. Use /duplicates/pending.');
                return;
            }


            Integer pageLimit  = toInt(getParam(req, 'limit'), 50);
            Integer pageOffset = toInt(getParam(req, 'offset'), 0);
            Decimal minScore   = toDecimal(getParam(req, 'minScore'), 0);
            String  sortParam  = getParam(req, 'sort');
            String  orderParam = getParam(req, 'order');

            if (pageLimit == null || pageLimit <= 0 || pageLimit > 200) pageLimit = 50;
            if (pageOffset == null || pageOffset < 0) pageOffset = 0;

            String sortField = 'CreatedDate';
            if (sortParam != null) {
                String s = sortParam.toLowerCase();
                if (s == 'score') sortField = 'Match_Score__c';
                else if (s == 'createddate') sortField = 'CreatedDate';
            }
            String sortOrder = (orderParam != null && orderParam.toLowerCase() == 'asc') ? 'ASC' : 'DESC';

            String baseWhere = 'Status__c = \'Pending Review\' AND Match_Score__c >= :minScore';
            Integer total = (Integer)Database.countQuery(
                'SELECT COUNT() FROM Duplicate_Match__c WHERE ' + baseWhere
            );

            String soql =
                'SELECT Id, Match_Score__c, Status__c, CreatedDate, ' +
                'Customer_A__c, Customer_A__r.FirstName__c, Customer_A__r.LastName__c, ' +
                'Customer_A__r.Email__c, Customer_A__r.Phone__c, ' +
                'Customer_B__c, Customer_B__r.FirstName__c, Customer_B__r.LastName__c, ' +
                'Customer_B__r.Email__c, Customer_B__r.Phone__c ' +
                'FROM Duplicate_Match__c ' +
                'WHERE ' + baseWhere + ' ' +
                'ORDER BY ' + sortField + ' ' + sortOrder + ' ' +
                'LIMIT :pageLimit OFFSET :pageOffset';

            List<Duplicate_Match__c> rows = Database.query(soql);

            List<DuplicateItemDTO> items = new List<DuplicateItemDTO>();
            for (Duplicate_Match__c r : rows) {
                DuplicateItemDTO item = new DuplicateItemDTO();
                item.id = r.Id;
                item.score = r.Match_Score__c;
                item.status = r.Status__c;
                item.createdAt = r.CreatedDate;

                CustomerDTO ca = new CustomerDTO();
                ca.id = r.Customer_A__c;
                ca.firstName = (r.Customer_A__r != null) ? r.Customer_A__r.FirstName__c : null;
                ca.lastName  = (r.Customer_A__r != null) ? r.Customer_A__r.LastName__c  : null;
                ca.email     = (r.Customer_A__r != null) ? r.Customer_A__r.Email__c     : null;
                ca.phone     = (r.Customer_A__r != null) ? r.Customer_A__r.Phone__c     : null;
                item.customerA = ca;

                CustomerDTO cb = new CustomerDTO();
                cb.id = r.Customer_B__c;
                cb.firstName = (r.Customer_B__r != null) ? r.Customer_B__r.FirstName__c : null;
                cb.lastName  = (r.Customer_B__r != null) ? r.Customer_B__r.LastName__c  : null;
                cb.email     = (r.Customer_B__r != null) ? r.Customer_B__r.Email__c     : null;
                cb.phone     = (r.Customer_B__r != null) ? r.Customer_B__r.Phone__c     : null;
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

        } catch (QueryException qe) {
            sendError(res, 403, 'Forbidden', qe.getMessage());
        } catch (Exception e) {
            sendError(res, 500, 'Internal Server Error', e.getMessage());
        }
    }

    @HttpPost
    global static void resolve() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            Id matchId = extractMatchId(req.requestURI);
            if (matchId == null) {
                sendError(res, 400, 'Bad Request', 'Path inválido. Use /duplicates/{id}/resolve');
                return;
            }

            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());
            String action = (body != null && body.containsKey('action')) ? String.valueOf(body.get('action')) : null;

            if (String.isBlank(action)) {
                sendError(res, 400, 'Bad Request', 'Campo "action" é obrigatório (merge|ignore).');
                return;
            }
            action = action.toLowerCase();
            if (action != 'merge' && action != 'ignore') {
                sendError(res, 400, 'Bad Request', 'Ação inválida. Use "merge" ou "ignore".');
                return;
            }

            Duplicate_Match__c m = [
                SELECT Id, Status__c, Match_Score__c,
                       Customer_A__c, Customer_B__c
                FROM Duplicate_Match__c
                WHERE Id = :matchId
                LIMIT 1
            ];

            if (m.Status__c != 'Pending Review') {
                sendError(res, 400, 'Bad Request', 'Somente matches em "Pending Review" podem ser resolvidos.');
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

                res.statusCode = 200;
                Map<String, Object> ok = new Map<String, Object>{
                    'status'  => 'ok',
                    'action'  => action,
                    'matchId' => m.Id
                };
                res.responseBody = Blob.valueOf(JSON.serialize(ok));

            } catch (DmlException dml) {
                Database.rollback(sp);
                sendError(res, 400, 'Bad Request', dml.getMessage());
            } catch (Exception ex) {
                Database.rollback(sp);
                sendError(res, 500, 'Internal Server Error', ex.getMessage());
            }

        } catch (QueryException qe) {
            sendError(res, 404, 'Not Found', 'Duplicate_Match__c não encontrado para o id informado.');
        } catch (Exception e) {
            sendError(res, 500, 'Internal Server Error', e.getMessage());
        }
    }

    // =========================
    // Helpers
    // =========================
    private static String getParam(RestRequest req, String name) {
        return (req.params != null && req.params.containsKey(name)) ? req.params.get(name) : null;
    }
    private static Integer toInt(String s, Integer defVal) {
        try { return (s == null) ? defVal : Integer.valueOf(s); } catch (Exception e) { return defVal; }
    }
    private static Decimal toDecimal(String s, Decimal defVal) {
        try { return (s == null) ? defVal : Decimal.valueOf(s); } catch (Exception e) { return defVal; }
    }
    private static Id extractMatchId(String uri) {
        if (String.isBlank(uri)) return null;
        List<String> parts = uri.split('/');
        if (parts.size() < 2) return null;
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
    private static void sendError(RestResponse res, Integer code, String message, String details) {
        res.statusCode = code;
        ErrorResponseDTO err = new ErrorResponseDTO();
        err.message = message;
        err.details = details;
        res.responseBody = Blob.valueOf(JSON.serialize(err));
    }
}
