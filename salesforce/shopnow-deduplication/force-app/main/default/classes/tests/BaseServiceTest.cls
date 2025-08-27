@IsTest
private class BaseServiceTest {
    private class TestService extends BaseService {
        protected override String getClassName() { return 'TestService'; }

        public Database.SaveResult[] doInsert(List<SObject> records, Boolean allOrNone) {
            return insertRecords(records, allOrNone);
        }
        public Database.SaveResult[] doUpdate(List<SObject> records, Boolean allOrNone) {
            return updateRecords(records, allOrNone);
        }
        public Database.UpsertResult[] doUpsert(List<SObject> records, Schema.SObjectField extIdField, Boolean allOrNone) {
            return upsertRecords(records, extIdField, allOrNone);
        }
        public Database.DeleteResult[] doDelete(List<SObject> records, Boolean allOrNone) {
            return deleteRecords(records, allOrNone);
        }
        public List<SObject> doQuery(String soql) { return executeQuery(soql); }
        public Integer doCountQuery(String soqlCount) { return executeCountQuery(soqlCount); }
        public void doValidateAccess(Schema.SObjectType t, String op) { validateAccess(t, op); }
        public void doValidateFieldAccess(Schema.SObjectType t, Set<String> fields, String op) { validateFieldAccess(t, fields, op); }
        public Boolean doHasPermission(String perm) { return hasPermission(perm); }
        public void doRequirePermission(String perm) { requirePermission(perm); }
        public String doSanitize(String input) { return sanitizeInput(input); }
        public String doSanitizeWithRules(String input, Integer maxLen, Boolean allowSpaces) { return sanitizeInput(input, maxLen, allowSpaces); }
        public void setPerf(String k, Object v) { setMetric(k, v); }
        public Map<String, Object> perf() { return getPerformanceMetrics(); }
    }

    @testSetup
    static void seed() {
        List<Customer__c> cs = new List<Customer__c>{
            new Customer__c(FirstName__c='John', LastName__c='Smith', Email__c='john@example.com', Phone__c='555-0001', IsActive__c=true),
            new Customer__c(FirstName__c='Jane', LastName__c='Doe',   Email__c='jane@example.com', Phone__c='555-0002', IsActive__c=true)
        };
        insert cs;
    }

    private static Duplicate_Match__c makeValidMatch() {
        List<Customer__c> cs = [SELECT Id FROM Customer__c ORDER BY CreatedDate ASC LIMIT 2];
        return new Duplicate_Match__c(
            Customer_A__c = cs[0].Id,
            Customer_B__c = cs[1].Id,
            Match_Score__c = 80,
            Status__c = 'Pending Review'
        );
    }

    @IsTest
    static void testInsert_success_and_partialErrors() {
        TestService svc = new TestService();

        Duplicate_Match__c ok1 = makeValidMatch();
        Duplicate_Match__c bad1 = new Duplicate_Match__c(Status__c='Pending Review'); // missing required fields

        Test.startTest();
        Database.SaveResult[] res = svc.doInsert(new List<SObject>{ ok1, bad1 }, false);
        Test.stopTest();

        System.assertEquals(2, res.size());
        System.assert(res[0].isSuccess(), 'First insert should succeed');
        System.assert(!res[1].isSuccess(), 'Second insert should fail');

        Map<String, Object> metrics = svc.perf();
        System.assert(metrics.containsKey('lastInsertTime'));
        System.assertEquals(2, (Integer)metrics.get('lastInsertCount'));
    }

    @IsTest
    static void testUpdate_success_and_error() {
        TestService svc = new TestService();

        Duplicate_Match__c ok = makeValidMatch();
        Duplicate_Match__c willFail = makeValidMatch();
        insert new List<Duplicate_Match__c>{ ok, willFail };

        ok.Status__c = 'Merged';
        willFail.Status__c = 'INVALID_STATUS';

        Test.startTest();
        Database.SaveResult[] res = svc.doUpdate(new List<SObject>{ ok, willFail }, false);
        Test.stopTest();

        System.assertEquals(2, res.size());
        System.assert(res[0].isSuccess());
        System.assert(!res[1].isSuccess());

        Map<String, Object> metrics = svc.perf();
        System.assert(metrics.containsKey('lastUpdateTime'));
        System.assertEquals(2, (Integer)metrics.get('lastUpdateCount'));
    }

    @IsTest
    static void testUpsert_create_update_and_error() {
        TestService svc = new TestService();

        Duplicate_Match__c toCreate = makeValidMatch();
        insert new List<SObject>{}; // noop for clarity

        insert makeValidMatch();
        Duplicate_Match__c existing = [SELECT Id, Status__c FROM Duplicate_Match__c ORDER BY CreatedDate DESC LIMIT 1];
        existing.Status__c = 'Ignored';

        Duplicate_Match__c bad = new Duplicate_Match__c(Status__c = 'Pending Review');

        Test.startTest();
        Database.UpsertResult[] res = svc.doUpsert(new List<SObject>{ toCreate, existing, bad }, null, false);
        Test.stopTest();

        System.assertEquals(3, res.size());
        System.assert(res[0].isSuccess() && res[0].isCreated(), 'First should be created');
        System.assert(res[1].isSuccess() && !res[1].isCreated(), 'Second should be updated');
        System.assert(!res[2].isSuccess(), 'Third should fail');

        Map<String, Object> metrics = svc.perf();
        System.assert(metrics.containsKey('lastUpsertTime'));
        System.assertEquals(3, (Integer)metrics.get('lastUpsertCount'));
    }

    @IsTest
    static void testDelete_success_and_error() {
        TestService svc = new TestService();

        Duplicate_Match__c ok = makeValidMatch();
        Duplicate_Match__c alreadyDeleted = makeValidMatch();
        insert new List<Duplicate_Match__c>{ ok, alreadyDeleted };

        Database.delete(alreadyDeleted);

        Test.startTest();
        Database.DeleteResult[] res = svc.doDelete(new List<SObject>{ ok, alreadyDeleted }, false);
        Test.stopTest();

        System.assertEquals(2, res.size());
        System.assert(res[0].isSuccess());
        System.assert(!res[1].isSuccess());

        Map<String, Object> metrics = svc.perf();
        System.assert(metrics.containsKey('lastDeleteTime'));
        System.assertEquals(2, (Integer)metrics.get('lastDeleteCount'));
    }

    @IsTest
    static void testExecuteQuery_safe_and_block_unsafe() {
        TestService svc = new TestService();

        List<SObject> ok = svc.doQuery('SELECT Id FROM Customer__c LIMIT 5');
        System.assert(ok != null, 'Safe query should run');

        Boolean threw = false;
        try {
            svc.doQuery('DELETE FROM Customer__c WHERE Id != null');
        } catch (SecurityException e) {
            threw = true;
        }
        System.assertEquals(true, threw, 'Unsafe query should be blocked');
    }

    @IsTest
    static void testExecuteCountQuery_safe_and_block_unsafe() {
        TestService svc = new TestService();

        Integer cnt = svc.doCountQuery('SELECT COUNT() FROM Customer__c');
        System.assert(cnt >= 0);

        Boolean threw = false;
        try {
            svc.doCountQuery('TRUNCATE TABLE Customer__c');
        } catch (SecurityException e) {
            threw = true;
        }
        System.assertEquals(true, threw, 'Unsafe count query should be blocked');
    }

    @IsTest
    static void testValidateAccess_and_FieldAccess() {
        TestService svc = new TestService();
        svc.doValidateAccess(Customer__c.SObjectType, 'CREATE');
        svc.doValidateFieldAccess(
            Customer__c.SObjectType,
            new Set<String>{ 'FirstName__c', 'LastName__c', 'Email__c' },
            'READ'
        );
        System.assert(true, 'Access validation executed');
    }

    @IsTest
    static void testPermissions_and_requirePermission() {
        TestService svc = new TestService();
        Boolean has = svc.doHasPermission('NonExistent_Permission_Flag');
        System.assert(has == true || has == false, 'Should return a boolean');

        Boolean threw = false;
        try {
            svc.doRequirePermission('NonExistent_Permission_Flag');
        } catch (SecurityException e) {
            threw = true;
        }
        System.assertEquals(true, threw, 'requirePermission should throw when permission is missing');
    }

    @IsTest
    static void testSanitizeInput_and_metrics() {
        TestService svc = new TestService();

        String s1 = svc.doSanitize('  Hello <script>alert(1)</script>  ');
        String s2 = svc.doSanitizeWithRules('ABC 123', 4, true);
        System.assertNotEquals(null, s1);
        System.assertNotEquals(null, s2);

        svc.setPerf('customKey', 'customValue');
        Map<String, Object> metrics = svc.perf();
        System.assert(metrics.containsKey('totalExecutionTime'));
        System.assert(metrics.containsKey('heapUsed'));
        System.assertEquals('customValue', (String)metrics.get('customKey'));
    }
}
