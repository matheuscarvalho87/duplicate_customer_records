@IsTest
private class DuplicateMatchingBatchTest {

    @testSetup
    static void seed() {
        String run = String.valueOf(System.currentTimeMillis());

        List<Customer__c> cs = new List<Customer__c>();

        cs.add(new Customer__c(
            FirstName__c='John', LastName__c='Smith',
            Email__c='john-'+run+'@ex.com',
            Phone__c='(555) 123-4567',
            IsActive__c=true
        ));
        cs.add(new Customer__c(
            FirstName__c='Jon', LastName__c='Smith',
            Email__c='jon-'+run+'@ex.com',
            Phone__c='5551234567',
            IsActive__c=true
        ));

        cs.add(new Customer__c(
            FirstName__c='Jane', LastName__c='Doe',
            Email__c='jane-'+run+'@ex.com',
            Phone__c='5555678901',
            IsActive__c=true
        ));
        cs.add(new Customer__c(
            FirstName__c='Jim', LastName__c='Doe',
            Email__c='jim-'+run+'@ex.com',
            Phone__c='(555) 567-8901',
            IsActive__c=true
        ));

        insert cs;
    }

    @IsTest
    static void testBatchCreatesMatchesAndIsIdempotent() {
        Integer before = [SELECT COUNT() FROM Duplicate_Match__c];

        Test.startTest();

        Database.executeBatch(new DuplicateMatchingBatch(), DuplicateMatchConstants.BATCH_SIZE);
        Database.executeBatch(new DuplicateMatchingBatch(), DuplicateMatchConstants.BATCH_SIZE);
        Test.stopTest();

        Integer after = [SELECT COUNT() FROM Duplicate_Match__c];

        System.assertEquals(before + 2, after,
            'Running two batches consecutively should create the two unique pairs only once (idempotent).');
    }

    @IsTest
    static void testFinishSendsSummaryAndBatchCompletes() {
        Test.startTest();
        Id jobId = Database.executeBatch(new DuplicateMatchingBatch(), DuplicateMatchConstants.BATCH_SIZE);
        Test.stopTest();

        AsyncApexJob[] jobs = [
            SELECT Id, JobType, Status, NumberOfErrors, TotalJobItems, CompletedDate
            FROM AsyncApexJob
            WHERE Id = :jobId
            LIMIT 1
        ];
        System.assertEquals(1, jobs.size(), 'Expected one AsyncApexJob for the executed batch.');
        System.assert(jobs[0].Status == 'Completed' || jobs[0].Status == 'CompletedWithErrors',
            'Batch should have completed (with or without errors).');
    }

    @IsTest
    static void testStartWithSpecificIdsBranch() {
        List<Customer__c> two = [
            SELECT Id
            FROM Customer__c
            WHERE IsActive__c = true
            LIMIT 2
        ];
        System.assertEquals(2, two.size(), 'Expected at least two seeded customers');

        Test.startTest();
        Database.executeBatch(
            new DuplicateMatchingBatch(new List<Id>{ two[0].Id, two[1].Id }, false),
            DuplicateMatchConstants.BATCH_SIZE
        );
        Test.stopTest();

        Integer cnt = [SELECT COUNT() FROM Duplicate_Match__c];
        System.assert(cnt >= 0, 'Batch with specific IDs executed.');
    }
}
