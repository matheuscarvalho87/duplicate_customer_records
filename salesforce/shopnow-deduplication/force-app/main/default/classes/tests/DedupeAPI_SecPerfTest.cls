@IsTest
private class DedupeAPI_SecPerfTest {

    private class Seed {
        List<Customer__c> customers;
        List<Duplicate_Match__c> matches;
    }

    private static Seed seedBasicMatches() {
        List<Customer__c> cs = new List<Customer__c>{
            new Customer__c(FirstName__c='John', LastName__c='Smith', Email__c='john.smith@example.com', Phone__c='555-1000'),
            new Customer__c(FirstName__c='Jon',  LastName__c='Smith', Email__c='jon.smith@example.com',  Phone__c='555-1001'),
            new Customer__c(FirstName__c='Jane', LastName__c='Doe',   Email__c='jane.doe@example.com',  Phone__c='555-1002'),
            new Customer__c(FirstName__c='J.',   LastName__c='Doe',   Email__c='j.doe@example.com',     Phone__c='555-1003'),
            new Customer__c(FirstName__c='Beth', LastName__c='Lee',   Email__c='beth.lee@example.com',  Phone__c='555-1004'),
            new Customer__c(FirstName__c='B.',   LastName__c='Lee',   Email__c='b.lee@example.com',     Phone__c='555-1005')
        };
        insert cs;

        List<Duplicate_Match__c> ms = new List<Duplicate_Match__c>{
            new Duplicate_Match__c(Customer_A__c = cs[0].Id, Customer_B__c = cs[1].Id, Match_Score__c = 90, Status__c='Pending Review'),
            new Duplicate_Match__c(Customer_A__c = cs[2].Id, Customer_B__c = cs[3].Id, Match_Score__c = 60, Status__c='Pending Review'),
            new Duplicate_Match__c(Customer_A__c = cs[4].Id, Customer_B__c = cs[5].Id, Match_Score__c = 30, Status__c='Pending Review')
        };
        insert ms;

        Test.setCreatedDate(ms[0].Id, System.now().addDays(-1));
        Test.setCreatedDate(ms[1].Id, System.now().addDays(-10));
        Test.setCreatedDate(ms[2].Id, System.now().addDays(-400));

        Seed s = new Seed(); s.customers = cs; s.matches = ms; return s;
    }

    private static RestRequest mkGet(String baseUri, Map<String,String> q) {
        RestRequest req = new RestRequest();
        req.httpMethod = 'GET';
        if (q == null || q.isEmpty()) { req.requestUri = baseUri; return req; }
        List<String> pairs = new List<String>();
        for (String k : q.keySet()) {
            pairs.add(k + '=' + EncodingUtil.urlEncode(q.get(k), 'UTF-8'));
        }
        req.requestUri = baseUri + '?' + String.join(pairs, '&');
        return req;
    }

    private static RestResponse mkRes() { return new RestResponse(); }
    private static Map<String, Object> parseJson(Blob b) {
        return (Map<String, Object>) JSON.deserializeUntyped(b.toString());
    }
    private static User mkStdUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        return new User(
            Alias='stdusr', Email='stdusr@example.com', EmailEncodingKey='UTF-8',
            LastName='Std', LanguageLocaleKey='en_US', LocaleSidKey='en_US',
            TimeZoneSidKey='America/Sao_Paulo',
            Username='stdusr' + System.currentTimeMillis() + '@example.com',
            ProfileId=p.Id
        );
    }

    @IsTest
    static void test403_validateAccess_whenEnforced() {
        Boolean original = SecurityUtil.ENFORCE_CUSTOM_PERMISSION;
        try {
            SecurityUtil.ENFORCE_CUSTOM_PERMISSION = true;

            RestRequest req = mkGet('/services/apexrest/duplicates/pending', null);
            RestResponse res = mkRes();
            RestContext.request = req; RestContext.response = res;

            Test.startTest(); DuplicateManagementAPI.getPending(); Test.stopTest();
            System.assertEquals(403, res.statusCode);
        } finally {
            SecurityUtil.ENFORCE_CUSTOM_PERMISSION = original;
        }
    }

    @IsTest
    static void testSinceDays_selectivity() {
        seedBasicMatches();

        RestRequest req = mkGet('/services/apexrest/duplicates/pending', new Map<String,String>{
            'sinceDays' => '30', 'minScore' => '0', 'limit' => '50', 'offset' => '0',
            'sort' => 'createdDate', 'order' => 'desc'
        });
        RestResponse res = mkRes();
        RestContext.request = req; RestContext.response = res;

        Test.startTest(); DuplicateManagementAPI.getPending(); Test.stopTest();

        System.assertEquals(200, res.statusCode);
        Map<String, Object> out = parseJson(res.responseBody);
        List<Object> items = (List<Object>) out.get('items');
        Map<String, Object> page = (Map<String, Object>) out.get('page');
        System.assertEquals(2, items.size(), 'Com sinceDays=30 deve retornar apenas 2 itens');
        System.assertEquals(2, (Integer) page.get('total'));
    }

   @IsTest
    static void testSortWhitelist_scoreDesc_and_invalidFallback() {
        seedBasicMatches();

        RestRequest req1 = mkGet('/services/apexrest/duplicates/pending', new Map<String,String>{
            'sinceDays' => '1000', 'minScore' => '0', 'limit' => '100', 'offset' => '0',
            'sort' => 'score', 'order' => 'desc'
        });
        RestResponse res1 = mkRes();

        RestRequest req2 = mkGet('/services/apexrest/duplicates/pending', new Map<String,String>{
            'sinceDays' => '1000', 'minScore' => '0', 'limit' => '100', 'offset' => '0',
            'sort' => 'badField', 'order' => 'desc'
        });
        RestResponse res2 = mkRes();

        Test.startTest();
        RestContext.request = req1; RestContext.response = res1;
        DuplicateManagementAPI.getPending();

        RestContext.request = req2; RestContext.response = res2;
        DuplicateManagementAPI.getPending();
        Test.stopTest();

        System.assertEquals(200, res1.statusCode);

        Map<String, Object> out1 = parseJson(res1.responseBody);
        List<Object> items1 = (List<Object>) out1.get('items');
        System.assert(items1.size() >= 2, 'Deve retornar ao menos 2 itens');

        Integer s0 = ((Decimal)((Map<String,Object>)items1[0]).get('score')).intValue();
        Integer s1 = ((Decimal)((Map<String,Object>)items1[1]).get('score')).intValue();
        System.assertEquals(90, s0);
        System.assertEquals(60, s1);
        if (items1.size() >= 3) {
            Integer s2 = ((Decimal)((Map<String,Object>)items1[2]).get('score')).intValue();
            System.assertEquals(30, s2);
        }

        System.assertEquals(200, res2.statusCode);
        Map<String, Object> out2 = parseJson(res2.responseBody);
        List<Object> items2 = (List<Object>) out2.get('items');
        Integer firstScore = ((Decimal)((Map<String,Object>)items2[0]).get('score')).intValue();
        System.assertEquals(90, firstScore, 'Fallback deve priorizar o mais recente (score 90)');
    }

    @IsTest
    static void testRunAsRestrictedUser_returns403() {
        Boolean original = SecurityUtil.ENFORCE_CUSTOM_PERMISSION;
        SecurityUtil.ENFORCE_CUSTOM_PERMISSION = false;
        try {
            seedBasicMatches();
            User u = mkStdUser(); insert u;

            System.runAs(u) {
                RestRequest req = mkGet('/services/apexrest/duplicates/pending', new Map<String,String>{
                    'sinceDays' => '1000', 'limit' => '10', 'offset' => '0'
                });
                RestResponse res = mkRes();
                RestContext.request = req; RestContext.response = res;

                Test.startTest(); DuplicateManagementAPI.getPending(); Test.stopTest();

                System.assertEquals(403, res.statusCode);
            }
        } finally {
            SecurityUtil.ENFORCE_CUSTOM_PERMISSION = original;
        }
    }
}
