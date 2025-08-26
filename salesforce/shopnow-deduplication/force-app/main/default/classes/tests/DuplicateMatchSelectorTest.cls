@IsTest
private class DuplicateMatchSelectorTest {

    @IsTest
    static void testCountAndSelectPendingWithSortingAndPaging() {
        Customer__c a1 = new Customer__c(FirstName__c='John',  LastName__c='Alpha', Email__c='a1@ex.com', Phone__c='1111111111');
        Customer__c b1 = new Customer__c(FirstName__c='Joan',  LastName__c='Beta',  Email__c='b1@ex.com', Phone__c='2222222222');
        Customer__c a2 = new Customer__c(FirstName__c='Alice', LastName__c='Gamma', Email__c='a2@ex.com', Phone__c='3333333333');
        Customer__c b2 = new Customer__c(FirstName__c='Bob',   LastName__c='Delta', Email__c='b2@ex.com', Phone__c='4444444444');
        insert new List<Customer__c>{ a1, b1, a2, b2 };

        Duplicate_Match__c m1 = new Duplicate_Match__c(
            Customer_A__c = a1.Id, Customer_B__c = b1.Id,
            Match_Score__c = 95, Status__c = 'Pending Review'
        );
        Duplicate_Match__c m2 = new Duplicate_Match__c(
            Customer_A__c = a2.Id, Customer_B__c = b2.Id,
            Match_Score__c = 70, Status__c = 'Pending Review'
        );

        Duplicate_Match__c m3 = new Duplicate_Match__c(
            Customer_A__c = a1.Id, Customer_B__c = b2.Id,
            Match_Score__c = 10, Status__c = 'Resolved'
        );
        insert new List<Duplicate_Match__c>{ m1, m2, m3 };

        Duplicate_Match__c oldM = new Duplicate_Match__c(
            Customer_A__c = a1.Id, Customer_B__c = b1.Id,
            Match_Score__c = 99, Status__c = 'Pending Review'
        );
        insert oldM;
        Test.setCreatedDate(oldM.Id, System.now().addDays(-400));

        Decimal minScore  = 50;
        Datetime startDt  = System.now().addDays(-365);
        String statusVal  = 'Pending Review';

        Integer total = DuplicateMatchSelector.countPending(minScore, startDt, statusVal);
        System.assertEquals(2, total, 'Count should include only recent PENDING with score >= 50');

        DuplicateMatchSelector.PendingFilter f = new DuplicateMatchSelector.PendingFilter();
        f.minScore    = minScore;
        f.startDate   = startDt;
        f.sortField   = 'Match_Score__c';
        f.sortOrder   = 'DESC';
        f.limitSize   = 1;
        f.offsetSize  = 0;
        f.statusValue = statusVal;

        List<Duplicate_Match__c> page1 = DuplicateMatchSelector.selectPending(f);
        System.assertEquals(1, page1.size(), 'page1 size');
        System.assertEquals(95, page1[0].Match_Score__c, 'first page highest score');

        f.offsetSize = 1;
        List<Duplicate_Match__c> page2 = DuplicateMatchSelector.selectPending(f);
        System.assertEquals(1, page2.size(), 'page2 size');
        System.assertEquals(70, page2[0].Match_Score__c, 'second page next score');

        f.sortOrder  = 'ASC';
        f.limitSize  = 2;
        f.offsetSize = 0;
        List<Duplicate_Match__c> ascRows = DuplicateMatchSelector.selectPending(f);
        System.assertEquals(2, ascRows.size(), 'asc page size');
        System.assert(ascRows[0].Match_Score__c <= ascRows[1].Match_Score__c, 'ascending sort respected');
        System.assertEquals(70, ascRows[0].Match_Score__c);
        System.assertEquals(95, ascRows[1].Match_Score__c);
    }
}
