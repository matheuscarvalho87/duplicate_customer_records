@IsTest
private class DuplicateManagementAPITest {
    private static List<Customer__c> seedCustomers(Integer qty, String prefix) {
        List<Customer__c> customers = new List<Customer__c>();
        for (Integer i = 0; i < qty; i++) {
            customers.add(new Customer__c(
                FirstName__c = prefix + i,
                LastName__c  = 'Tester',
                Email__c     = prefix + i + '@ex.com',
                Phone__c     = '555000' + String.valueOf(100 + i)
            ));
        }
        insert customers;
        return customers;
    }

    private static List<Duplicate_Match__c> seedPendingMatches(
        List<Customer__c> aList,
        List<Customer__c> bList,
        List<Integer> scores
    ) {
        List<Duplicate_Match__c> matches = new List<Duplicate_Match__c>();
        for (Integer i = 0; i < scores.size(); i++) {
            Duplicate_Match__c dm = new Duplicate_Match__c();
            dm.Customer_A__c  = aList[Math.mod(i, aList.size())].Id;
            dm.Customer_B__c  = bList[Math.mod(i, bList.size())].Id;
            dm.Match_Score__c = scores[i];
            dm.Status__c      = 'Pending Review';
            matches.add(dm);
        }
        insert matches;
        return matches;
    }

    private static RestRequest makeGetReq(Integer limitSize, Integer offsetSize, String sortKey, String sortOrder) {
        RestRequest req = new RestRequest();
        req.requestUri  = '/services/apexrest/duplicates/pending';
        req.httpMethod  = 'GET';

        req.addParameter('limit',     String.valueOf(limitSize));
        req.addParameter('offset',    String.valueOf(offsetSize));
        req.addParameter('minScore',  '0');
        req.addParameter('sinceDays', '365');
        req.addParameter('sort',      (sortKey   == null ? 'score' : sortKey));
        req.addParameter('order',     (sortOrder == null ? 'desc'  : sortOrder));

        return req;
    }


    private static Integer toInt(Object v) { return Integer.valueOf(String.valueOf(v)); }

    @IsTest
    static void getPending_handler_payload_stable() {
        List<Customer__c> aList = seedCustomers(3, 'A');
        List<Customer__c> bList = seedCustomers(3, 'B');
        seedPendingMatches(aList, bList, new List<Integer>{ 10, 50, 90 });

        RestContext.request  = makeGetReq(3, 0, 'score', 'desc');
        RestContext.response = new RestResponse();

        DuplicateManagementAPI api = new DuplicateManagementAPI();

        Test.startTest();
        api.handleGetPending();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode, 'HTTP 200 expected');

        String body = RestContext.response.responseBody == null ? '' : RestContext.response.responseBody.toString();
        Map<String, Object> json  = (Map<String, Object>) JSON.deserializeUntyped(body);
        System.assert(json.containsKey('items') && json.containsKey('page'), 'Envelope must contain items and page');

        List<Object> items        = (List<Object>) json.get('items');
        Map<String, Object> page  = (Map<String, Object>) json.get('page');

        System.assertEquals(3, items.size(), 'limit=3 should return 3 items');
        System.assertEquals(3, toInt(page.get('limit')));
        System.assertEquals(0, toInt(page.get('offset')));
        System.assertEquals(3, toInt(page.get('total')));

        Map<String, Object> first = (Map<String, Object>) items[0];
        System.assert(first.containsKey('id'));
        System.assert(first.containsKey('score'));
        System.assert(first.containsKey('status'));
        System.assert(first.containsKey('createdAt'));
        System.assert(first.containsKey('customerA'));
        System.assert(first.containsKey('customerB'));

        Map<String, Object> ca = (Map<String, Object>) first.get('customerA');
        Map<String, Object> cb = (Map<String, Object>) first.get('customerB');
        System.assert(ca.containsKey('id'), 'customerA.id present');
        System.assert(cb.containsKey('id'), 'customerB.id present');
    }

    @IsTest
    static void getPending_handler_sort_by_score_desc() {
        List<Customer__c> aList = seedCustomers(3, 'A2');
        List<Customer__c> bList = seedCustomers(3, 'B2');
        seedPendingMatches(aList, bList, new List<Integer>{ 20, 60, 40, 95, 70 });

        RestContext.request  = makeGetReq(5, 0, 'score', 'desc');
        RestContext.response = new RestResponse();

        DuplicateManagementAPI api = new DuplicateManagementAPI();

        Test.startTest();
        api.handleGetPending();
        Test.stopTest();

        String body = RestContext.response.responseBody == null ? '' : RestContext.response.responseBody.toString();
        Map<String, Object> json  = (Map<String, Object>) JSON.deserializeUntyped(body);
        List<Object> items        = (List<Object>) json.get('items');

        List<Decimal> scores = new List<Decimal>();
        for (Object o : items) {
            Map<String, Object> row = (Map<String, Object>) o;
            scores.add((Decimal) row.get('score'));
        }
        for (Integer i = 1; i < scores.size(); i++) {
            System.assert(scores[i-1] >= scores[i], 'Scores must be sorted DESC');
        }
    }

    @IsTest
    static void get_router_403_forbidden_error_shape() {
        RestContext.request  = makeGetReq(1, 0, 'score', 'desc');
        RestContext.response = new RestResponse();

        Test.startTest();
        DuplicateManagementAPI.get();
        Test.stopTest();

        System.assertEquals(403, RestContext.response.statusCode, 'Expected 403 Forbidden');
        String body = RestContext.response.responseBody == null ? '' : RestContext.response.responseBody.toString();
        Map<String, Object> err = (Map<String, Object>) JSON.deserializeUntyped(body);
        System.assertEquals('Forbidden', String.valueOf(err.get('message')));
        System.assert(err.containsKey('details'), 'Error payload must include "details"');
    }
}
