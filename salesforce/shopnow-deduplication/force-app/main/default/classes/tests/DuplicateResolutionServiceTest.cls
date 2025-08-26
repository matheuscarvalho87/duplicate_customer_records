@IsTest
private class DuplicateResolutionServiceTest {

    private static Map<String, Id> seed() {
        Customer__c ca = new Customer__c(FirstName__c='Alice', LastName__c='A', Email__c='a@ex.com', Phone__c='1111111111');
        Customer__c cb = new Customer__c(FirstName__c='Bob',   LastName__c='B', Email__c='b@ex.com', Phone__c='2222222222');
        insert new List<Customer__c>{ ca, cb };

        Duplicate_Match__c m = new Duplicate_Match__c(
            Customer_A__c = ca.Id,
            Customer_B__c = cb.Id,
            Match_Score__c = 80,
            Status__c = 'Pending Review'
        );
        insert m;

        return new Map<String, Id>{ 'A' => ca.Id, 'B' => cb.Id, 'M' => m.Id };
    }

    @IsTest
    static void testIgnoreFlow() {
        Map<String, Id> ids = seed();
        Id matchId = ids.get('M');

        DuplicateResolutionService svc = new DuplicateResolutionService();
        svc.resolve(matchId, 'ignore');

        Duplicate_Match__c after = [
            SELECT Id, Status__c FROM Duplicate_Match__c WHERE Id = :matchId
        ];
        System.assertEquals('Ignored', after.Status__c, 'Status must change to Ignored');
    }

    @IsTest
    static void testMergeFlowDeletesCustomerB() {
        Map<String, Id> ids = seed();
        Id matchId = ids.get('M');
        Id customerB = ids.get('B');

        DuplicateResolutionService svc = new DuplicateResolutionService();
        svc.resolve(matchId, 'merge');

        Duplicate_Match__c after = [
            SELECT Id, Status__c FROM Duplicate_Match__c WHERE Id = :matchId
        ];
        System.assertEquals('Merged', after.Status__c, 'Status must change to Merged');

        Boolean existsB = false;
        try {
            Customer__c b = [SELECT Id FROM Customer__c WHERE Id = :customerB LIMIT 1];
            existsB = (b != null);
        } catch (QueryException qe) {
            existsB = false;
        }
        System.assertEquals(false, existsB, 'Customer_B__c must be deleted on merge');
    }

    @IsTest
    static void testGuardStatusNotPending() {
        Customer__c ca = new Customer__c(FirstName__c='X', LastName__c='Y', Email__c='x@ex.com', Phone__c='9999999999');
        Customer__c cb = new Customer__c(FirstName__c='Z', LastName__c='W', Email__c='z@ex.com', Phone__c='8888888888');
        insert new List<Customer__c>{ ca, cb };

        Duplicate_Match__c m = new Duplicate_Match__c(
            Customer_A__c = ca.Id,
            Customer_B__c = cb.Id,
            Match_Score__c = 50,
            Status__c = 'Resolved'
        );
        insert m;

        Boolean thrown = false;
        try {
            new DuplicateResolutionService().resolve(m.Id, 'ignore');
        } catch (AuraHandledException ahe) {
            thrown = true;
            System.assert(ahe.getMessage().contains('Only "Pending Review"'), 'Guard message expected');
        }
        System.assertEquals(true, thrown, 'Expected guard exception when status != Pending Review');
    }
}
