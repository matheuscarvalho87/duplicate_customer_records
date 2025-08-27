@IsTest
private class DuplicateMatchRepositoryTest {
    @testSetup
    static void seed() {
        String run = String.valueOf(System.currentTimeMillis());

        List<Customer__c> cs = new List<Customer__c>{
            new Customer__c(FirstName__c='John',  LastName__c='Smith', Email__c='john-'+run+'@ex.com',  Phone__c='5550001', IsActive__c=true),
            new Customer__c(FirstName__c='Jon',   LastName__c='Smith', Email__c='jon-'+run+'@ex.com',   Phone__c='5550002', IsActive__c=true),
            new Customer__c(FirstName__c='Jane',  LastName__c='Doe',   Email__c='jane-'+run+'@ex.com',  Phone__c='5550003', IsActive__c=true),
            new Customer__c(FirstName__c='Jana',  LastName__c='Doe',   Email__c='jana-'+run+'@ex.com',  Phone__c='5550004', IsActive__c=true),
            new Customer__c(FirstName__c='Jim',   LastName__c='Beam',  Email__c='jim-'+run+'@ex.com',   Phone__c='5550005', IsActive__c=true),
            new Customer__c(FirstName__c='Jimm',  LastName__c='Beam',  Email__c='jimm-'+run+'@ex.com',  Phone__c='5550006', IsActive__c=true),
            new Customer__c(FirstName__c='Ana',   LastName__c='Silva', Email__c='ana-'+run+'@ex.com',   Phone__c='5550007', IsActive__c=true),
            new Customer__c(FirstName__c='Anna',  LastName__c='Silva', Email__c='anna-'+run+'@ex.com',  Phone__c='5550008', IsActive__c=true)
        };
        insert cs;

        List<Duplicate_Match__c> matches = new List<Duplicate_Match__c>{
            new Duplicate_Match__c(Customer_A__c=cs[0].Id, Customer_B__c=cs[1].Id, Match_Score__c=90, Status__c='Pending Review'),
            new Duplicate_Match__c(Customer_A__c=cs[2].Id, Customer_B__c=cs[3].Id, Match_Score__c=70, Status__c='Pending Review'),
            new Duplicate_Match__c(Customer_A__c=cs[4].Id, Customer_B__c=cs[5].Id, Match_Score__c=40, Status__c='Pending Review'),
            new Duplicate_Match__c(Customer_A__c=cs[6].Id, Customer_B__c=cs[7].Id, Match_Score__c=85, Status__c='Ignored')
        };
        insert matches;
    }

    @IsTest
    static void testGetPending_and_count() {
        DuplicateMatchRepository repo = new DuplicateMatchRepository();

        Test.startTest();
        List<Duplicate_Match__c> page = repo.getPending(2, 0, 50, 'Match_Score__c', 'desc');
        Integer total = repo.countPending(50);
        Test.stopTest();

        System.assertEquals(2, page.size(), 'Should return page size of 2');
        System.assertEquals(2, total, 'Should count only pending matches with score >= 50');

        Decimal s1 = page[0].Match_Score__c;
        Decimal s2 = page[1].Match_Score__c;
        System.assert(s1 >= s2, 'Results should be sorted by score desc');

        for (Duplicate_Match__c m : page) {
            System.assertEquals('Pending Review', m.Status__c, 'Only pending should be returned');
            System.assert(m.Match_Score__c >= 50, 'Score filter should be applied');
        }
    }

    @IsTest
    static void testGetById() {
        Duplicate_Match__c anyPending = [
            SELECT Id FROM Duplicate_Match__c
            WHERE Status__c = 'Pending Review'
            ORDER BY Match_Score__c DESC
            LIMIT 1
        ];
        DuplicateMatchRepository repo = new DuplicateMatchRepository();

        Test.startTest();
        Duplicate_Match__c found = repo.getById(anyPending.Id);
        Test.stopTest();

        System.assertEquals(anyPending.Id, found.Id, 'Should retrieve the exact record by Id');
    }

    @IsTest
    static void testUpdateMatch() {
        Duplicate_Match__c m = [
            SELECT Id, Status__c
            FROM Duplicate_Match__c
            WHERE Status__c = 'Pending Review'
            ORDER BY Match_Score__c ASC
            LIMIT 1
        ];
        DuplicateMatchRepository repo = new DuplicateMatchRepository();

        m.Status__c = 'Ignored';

        Test.startTest();
        repo.updateMatch(m);
        repo.updateMatch(null);
        Test.stopTest();

        Duplicate_Match__c refreshed = [SELECT Status__c FROM Duplicate_Match__c WHERE Id = :m.Id];
        System.assertEquals('Ignored', refreshed.Status__c, 'Status should be updated');
    }

    @IsTest
    static void testSoftDeleteCustomer_success() {
        Customer__c keep = new Customer__c(FirstName__c='Keep', LastName__c='Customer', Email__c='keep-'+System.currentTimeMillis()+'@ex.com', Phone__c='5551000', IsActive__c=true);
        Customer__c del  = new Customer__c(FirstName__c='Del',  LastName__c='Customer', Email__c='del-'+System.currentTimeMillis()+'@ex.com',  Phone__c='5551001', IsActive__c=true);
        insert new List<Customer__c>{ keep, del };

        DuplicateMatchRepository repo = new DuplicateMatchRepository();

        Test.startTest();
        repo.softDeleteCustomer(del.Id, keep.Id);
        Test.stopTest();

        Customer__c refreshed = [
            SELECT IsDeleted__c, MergedInto__c, DeletedDate__c, DeletedBy__c, IsActive__c
            FROM Customer__c
            WHERE Id = :del.Id
        ];

        System.assertEquals(true, refreshed.IsDeleted__c, 'Should be soft-deleted');
        System.assertEquals(keep.Id, refreshed.MergedInto__c, 'Should reference the surviving customer');
        System.assertNotEquals(null, refreshed.DeletedDate__c, 'DeletedDate__c should be set');
        System.assertEquals(UserInfo.getUserId(), refreshed.DeletedBy__c, 'DeletedBy__c should be current user');
        System.assertEquals(false, refreshed.IsActive__c, 'Should be inactive after soft delete');
    }

    @IsTest
    static void testSoftDeleteCustomer_invalidArgs() {
        DuplicateMatchRepository repo = new DuplicateMatchRepository();

        Boolean threw1 = false;
        try { repo.softDeleteCustomer(null, null); } catch (IllegalArgumentException e) { threw1 = true; }
        System.assertEquals(true, threw1, 'Both IDs missing should throw');

        Customer__c keep = new Customer__c(FirstName__c='K', LastName__c='C', Email__c='k-'+System.currentTimeMillis()+'@ex.com', Phone__c='5552000', IsActive__c=true);
        insert keep;

        Boolean threw2 = false;
        try { repo.softDeleteCustomer(null, keep.Id); } catch (IllegalArgumentException e) { threw2 = true; }
        System.assertEquals(true, threw2, 'Missing delete Id should throw');

        Boolean threw3 = false;
        try { repo.softDeleteCustomer(keep.Id, null); } catch (IllegalArgumentException e) { threw3 = true; }
        System.assertEquals(true, threw3, 'Missing keep Id should throw');
    }
}
