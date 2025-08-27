@IsTest
private class DupManAPI_PerfLimitsTest {

    private static void seed(Integer pairs, Integer pendingCount, Integer resolvedCount) {
        List<Customer__c> custAList = new List<Customer__c>();
        List<Customer__c> custBList = new List<Customer__c>();
        for (Integer i = 0; i < pairs; i++) {
            custAList.add(new Customer__c(
                FirstName__c = 'A' + i,
                LastName__c  = 'Tester',
                Email__c     = 'a' + i + '@ex.com',
                Phone__c     = '111111111' + String.valueOf(Math.mod(i,10))
            ));
            custBList.add(new Customer__c(
                FirstName__c = 'B' + i,
                LastName__c  = 'Tester',
                Email__c     = 'b' + i + '@ex.com',
                Phone__c     = '222222222' + String.valueOf(Math.mod(i,10))
            ));
        }
        insert custAList;
        insert custBList;

        List<Duplicate_Match__c> pending = new List<Duplicate_Match__c>();
        for (Integer i = 0; i < pendingCount; i++) {
            Integer score = 10 + Math.mod(i, 91); // 10..100
            Duplicate_Match__c dm = new Duplicate_Match__c();
            dm.Customer_A__c   = custAList[Math.mod(i, custAList.size())].Id;
            dm.Customer_B__c   = custBList[Math.mod(i, custBList.size())].Id;
            dm.Match_Score__c  = score;
            dm.Status__c       = 'Pending Review';
            pending.add(dm);
        }
        insert pending;

        if (resolvedCount > 0) {
            List<Duplicate_Match__c> resolved = new List<Duplicate_Match__c>();
            for (Integer i = 0; i < resolvedCount; i++) {
                Duplicate_Match__c dm = new Duplicate_Match__c();
                dm.Customer_A__c   = custAList[Math.mod(i, custAList.size())].Id;
                dm.Customer_B__c   = custBList[Math.mod(i, custBList.size())].Id;
                dm.Match_Score__c  = 5;
                dm.Status__c       = 'Resolved';
                resolved.add(dm);
            }
            insert resolved;
        }
    }

    private static RestRequest mkReq(Integer limitSize, Integer offsetSize) {
        RestRequest req = new RestRequest();
        req.requestUri  = '/services/apexrest/duplicates/pending';
        req.httpMethod  = 'GET';

        req.addParameter('limit',     String.valueOf(limitSize));
        req.addParameter('offset',    String.valueOf(offsetSize));
        req.addParameter('minScore',  '0');
        req.addParameter('sinceDays', '365');
        req.addParameter('sort',      'score');
        req.addParameter('order',     'desc');
        return req;
    }

    private static Integer toInt(Object v) {
        return Integer.valueOf(String.valueOf(v));
    }

    // @IsTest
    // static void limits_50_items() {
    //     seed(160, 150, 10);

    //     RestContext.request  = mkReq(50, 0);
    //     RestContext.response = new RestResponse();

    //     DuplicateManagementAPI api = new DuplicateManagementAPI();

    //     Integer qBefore   = Limits.getQueries();
    //     Integer cpuBefore = Limits.getCpuTime();

    //     Test.startTest();
    //     api.handleGetPending();
    //     Test.stopTest();

    //     Integer qDelta   = Limits.getQueries() - qBefore;
    //     Integer cpuDelta = Limits.getCpuTime() - cpuBefore;

    //     System.assertEquals(2, qDelta, 'Must execute exactly 2 SOQL statements');

    //     System.assert(
    //         cpuDelta < (Limits.getLimitCpuTime() / 2),
    //         'CPU should be below half the per-tx limit. Actual=' + cpuDelta + ' of ' + Limits.getLimitCpuTime()
    //     );

    //     System.assertEquals(200, RestContext.response.statusCode, 'HTTP 200 expected');
    //     String body = (RestContext.response.responseBody == null) ? '' : RestContext.response.responseBody.toString();
    //     Map<String, Object> json  = (Map<String, Object>) JSON.deserializeUntyped(body);
    //     Map<String, Object> page  = (Map<String, Object>) json.get('page');
    //     List<Object> items        = (List<Object>) json.get('items');

    //     System.assertEquals(50, items.size(), 'Should return exactly the requested page size (limit=50)');
    //     System.assertEquals(150, toInt(page.get('total')), 'Total should reflect all recent PENDING matches');
    // }

    // @IsTest
    // static void limits_100_items() {
    //     seed(160, 150, 0);

    //     RestContext.request  = mkReq(100, 0);
    //     RestContext.response = new RestResponse();

    //     DuplicateManagementAPI api = new DuplicateManagementAPI();

    //     Integer qBefore   = Limits.getQueries();
    //     Integer cpuBefore = Limits.getCpuTime();

    //     Test.startTest();
    //     api.handleGetPending();
    //     Test.stopTest();

    //     Integer qDelta   = Limits.getQueries() - qBefore;
    //     Integer cpuDelta = Limits.getCpuTime() - cpuBefore;

    //     System.assertEquals(2, qDelta, 'Query count must remain 2 (COUNT + SELECT)');
    //     System.assert(
    //         cpuDelta < (Limits.getLimitCpuTime() / 2),
    //         'CPU should stay well below half the limit for 100 items. Actual=' + cpuDelta
    //     );

    //     System.assertEquals(200, RestContext.response.statusCode);
    //     String body = (RestContext.response.responseBody == null) ? '' : RestContext.response.responseBody.toString();
    //     Map<String, Object> json  = (Map<String, Object>) JSON.deserializeUntyped(body);
    //     List<Object> items        = (List<Object>) json.get('items');
    //     System.assertEquals(100, items.size(), 'Should return exactly 100 items when limit=100');
    // }
}
