@IsTest
private class DuplicateManagementAPITest {
    private static User makeBasicUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias = 'stdusr',
            Email = 'stdusr@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Std',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/Sao_Paulo',
            Username = 'stdusr' + System.currentTimeMillis() + '@example.com',
            ProfileId = p.Id
        );
        return u;
    }

    private static Map<String, Object> seedData() {
        List<Customer__c> cs = new List<Customer__c>{
            new Customer__c(FirstName__c='John', LastName__c='Smith', Email__c='john.smith@example.com', Phone__c='555-1234'),
            new Customer__c(FirstName__c='Jon',  LastName__c='Smith', Email__c='jon.smith@example.com',  Phone__c='555-1234'),
            new Customer__c(FirstName__c='Jane', LastName__c='Doe',   Email__c='jane.doe@example.com',  Phone__c='555-5678'),
            new Customer__c(FirstName__c='Jane', LastName__c='D.',    Email__c='j.doe@example.com',     Phone__c='555-5678')
        };
        insert cs;

        List<Duplicate_Match__c> matches = new List<Duplicate_Match__c>{
            new Duplicate_Match__c(Customer_A__c = cs[0].Id, Customer_B__c = cs[1].Id, Match_Score__c = 70, Status__c='Pending Review'),
            new Duplicate_Match__c(Customer_A__c = cs[2].Id, Customer_B__c = cs[3].Id, Match_Score__c = 50, Status__c='Pending Review')
        };
        insert matches;

        return new Map<String, Object>{
            'customers' => cs,
            'matches'   => matches
        };
    }

    @IsTest
    static void testGetPendingDuplicates() {
        Map<String, Object> data = seedData();

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/duplicates/pending?limit=10&offset=0&minScore=40&sort=score&order=desc';
        req.httpMethod = 'GET';
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DuplicateManagementAPI.getPending();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        List<Object> items = (List<Object>) parsed.get('items');
        Map<String, Object> page = (Map<String, Object>) parsed.get('page');
        System.assert(items.size() >= 2, 'Deveria retornar ao menos 2 itens');
        System.assertEquals(10, (Integer)page.get('limit'));
        System.assertEquals(0, (Integer)page.get('offset'));
        System.assertNotEquals(null, page.get('total'));
    }

    @IsTest
    static void testPagination() {
        Map<String, Object> data = seedData();

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/duplicates/pending?limit=1&offset=1&minScore=0&sort=createdDate&order=asc';
        req.httpMethod = 'GET';
        RestResponse res = new RestResponse();
        RestContext.request = req; RestContext.response = res;

        Test.startTest();
        DuplicateManagementAPI.getPending();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        List<Object> items = (List<Object>) parsed.get('items');
        Map<String, Object> page = (Map<String, Object>) parsed.get('page');
        System.assertEquals(1, items.size());
        System.assertEquals(1, (Integer)page.get('offset'));
        System.assertEquals(1, (Integer)page.get('limit'));
    }

    @IsTest
    static void testMergeAction() {
        Map<String, Object> data = seedData();
        List<Duplicate_Match__c> ms = (List<Duplicate_Match__c>)data.get('matches');
        Id matchId = ms[0].Id;
        Id loserId = ((List<Customer__c>)data.get('customers'))[1].Id; // Customer_B do primeiro match

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/duplicates/' + matchId + '/resolve';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"action":"merge"}');
        RestResponse res = new RestResponse();
        RestContext.request = req; RestContext.response = res;

        Test.startTest();
        DuplicateManagementAPI.resolve();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);

        Duplicate_Match__c refreshed = [SELECT Status__c FROM Duplicate_Match__c WHERE Id = :matchId];
        System.assertEquals('Merged', refreshed.Status__c);

        Boolean loserExists = true;
        try {
            Customer__c c = [SELECT Id FROM Customer__c WHERE Id = :loserId];
        } catch (Exception e) {
            loserExists = false;
        }
        System.assertEquals(false, loserExists, 'Customer_B deveria ter sido deletado');
    }

    @IsTest
    static void testIgnoreAction() {
        Map<String, Object> data = seedData();
        List<Duplicate_Match__c> ms = (List<Duplicate_Match__c>)data.get('matches');
        Id matchId = ms[1].Id;

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/duplicates/' + matchId + '/resolve';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"action":"ignore"}');
        RestResponse res = new RestResponse();
        RestContext.request = req; RestContext.response = res;

        Test.startTest();
        DuplicateManagementAPI.resolve();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        Duplicate_Match__c refreshed = [SELECT Status__c FROM Duplicate_Match__c WHERE Id = :matchId];
        System.assertEquals('Ignored', refreshed.Status__c);
    }

    @IsTest
    static void testInvalidId() {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/duplicates/001000000000000/resolve';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"action":"merge"}');
        RestResponse res = new RestResponse();
        RestContext.request = req; RestContext.response = res;

        Test.startTest();
        DuplicateManagementAPI.resolve();
        Test.stopTest();

        System.assertEquals(404, res.statusCode);
    }

    @IsTest
    static void testUnauthorized() {
        Map<String, Object> data = seedData();

        User u = makeBasicUser();
        insert u;
        System.runAs(u) {
            RestRequest req = new RestRequest();
            req.requestUri = '/services/apexrest/duplicates/pending';
            req.httpMethod = 'GET';
            RestResponse res = new RestResponse();
            RestContext.request = req; RestContext.response = res;

            Test.startTest();
            DuplicateManagementAPI.getPending();
            Test.stopTest();

            System.assertEquals(403, res.statusCode);
        }
    }
}
