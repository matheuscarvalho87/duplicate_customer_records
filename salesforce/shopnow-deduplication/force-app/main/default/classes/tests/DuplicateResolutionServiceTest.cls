@IsTest
private class DuplicateResolutionServiceTest {
    private static Duplicate_Match__c makePendingMatch(Decimal score) {
        Customer__c a = new Customer__c(
            FirstName__c='A'+System.currentTimeMillis(),
            LastName__c='Test',
            Email__c='a'+System.currentTimeMillis()+'@ex.com',
            Phone__c='5550001',
            IsActive__c=true
        );
        Customer__c b = new Customer__c(
            FirstName__c='B'+System.currentTimeMillis(),
            LastName__c='Test',
            Email__c='b'+System.currentTimeMillis()+'@ex.com',
            Phone__c='5550001',
            IsActive__c=true
        );
        insert new List<Customer__c>{ a, b };

        Duplicate_Match__c m = new Duplicate_Match__c(
            Customer_A__c = a.Id,
            Customer_B__c = b.Id,
            Match_Score__c = score,
            Status__c = DuplicateMatchConstants.STATUS_PENDING
        );
        insert m;
        return m;
    }

    private static Duplicate_Match__c makeNonPendingMatch(String statusValue) {
        Customer__c a = new Customer__c(
            FirstName__c='C'+System.currentTimeMillis(),
            LastName__c='Test',
            Email__c='c'+System.currentTimeMillis()+'@ex.com',
            Phone__c='5550002',
            IsActive__c=true
        );
        Customer__c b = new Customer__c(
            FirstName__c='D'+System.currentTimeMillis(),
            LastName__c='Test',
            Email__c='d'+System.currentTimeMillis()+'@ex.com',
            Phone__c='5550002',
            IsActive__c=true
        );
        insert new List<Customer__c>{ a, b };

        Duplicate_Match__c m = new Duplicate_Match__c(
            Customer_A__c = a.Id,
            Customer_B__c = b.Id,
            Match_Score__c = 60,
            Status__c = statusValue
        );
        insert m;
        return m;
    }

    @IsTest
    static void testGetPendingDtos_sortsAndMaps() {
        Duplicate_Match__c m1 = makePendingMatch(90);
        Duplicate_Match__c m2 = makePendingMatch(70);
        Duplicate_Match__c m3 = makePendingMatch(40);
        makeNonPendingMatch(DuplicateMatchConstants.STATUS_IGNORED);

        DuplicateResolutionService svc = new DuplicateResolutionService();

        Test.startTest();
        List<DuplicateResolutionService.DuplicateItemDTO> dtos =
            svc.getPendingDtos(2, 0, 50, 'score', 'desc');
        Test.stopTest();

        System.assertEquals(2, dtos.size(), 'Should page 2 items');
        System.assert(dtos[0].score >= dtos[1].score, 'Should be sorted by score desc');
        for (DuplicateResolutionService.DuplicateItemDTO d : dtos) {
            System.assertEquals(DuplicateMatchConstants.STATUS_PENDING, d.status);
            System.assertNotEquals(null, d.id);
            System.assertNotEquals(null, d.createdAt);
            System.assertNotEquals(null, d.customerA);
            System.assertNotEquals(null, d.customerB);
        }
    }

    @IsTest
    static void testResolve_ignore_success() {
        Duplicate_Match__c m = makePendingMatch(65);
        DuplicateResolutionService svc = new DuplicateResolutionService();

        Test.startTest();
        svc.resolveSingle(String.valueOf(m.Id), 'ignore');
        Test.stopTest();

        Duplicate_Match__c refreshed = [
            SELECT Status__c, Review_Date__c, Reviewed_By__c
            FROM Duplicate_Match__c
            WHERE Id = :m.Id
        ];
        System.assertEquals(DuplicateMatchConstants.STATUS_IGNORED, refreshed.Status__c);
        System.assertNotEquals(null, refreshed.Review_Date__c);
        System.assertEquals(UserInfo.getUserId(), refreshed.Reviewed_By__c);
    }

    @IsTest
    static void testResolve_merge_success_softDeleteB() {
        Customer__c a = new Customer__c(
            FirstName__c='Keep'+System.currentTimeMillis(),
            LastName__c='Cust',
            Email__c='keep'+System.currentTimeMillis()+'@ex.com',
            Phone__c='5550101',
            IsActive__c=true
        );
        Customer__c b = new Customer__c(
            FirstName__c='Merge'+System.currentTimeMillis(),
            LastName__c='Cust',
            Email__c='merge'+System.currentTimeMillis()+'@ex.com',
            Phone__c='5550101',
            IsActive__c=true
        );
        insert new List<Customer__c>{ a, b };

        Duplicate_Match__c m = new Duplicate_Match__c(
            Customer_A__c = a.Id,
            Customer_B__c = b.Id,
            Match_Score__c = 85,
            Status__c = DuplicateMatchConstants.STATUS_PENDING
        );
        insert m;

        DuplicateResolutionService svc = new DuplicateResolutionService();

        Test.startTest();
        svc.resolveSingle(String.valueOf(m.Id), 'merge');
        Test.stopTest();

        Duplicate_Match__c refreshed = [
            SELECT Status__c, Review_Date__c, Reviewed_By__c, Customer_A__c, Customer_B__c
            FROM Duplicate_Match__c
            WHERE Id = :m.Id
        ];
        System.assertEquals(DuplicateMatchConstants.STATUS_MERGED, refreshed.Status__c);
        System.assertNotEquals(null, refreshed.Review_Date__c);
        System.assertEquals(UserInfo.getUserId(), refreshed.Reviewed_By__c);

        Customer__c bRef = [
            SELECT IsDeleted__c, MergedInto__c, DeletedDate__c, DeletedBy__c, IsActive__c
            FROM Customer__c
            WHERE Id = :b.Id
        ];
        System.assertEquals(true, bRef.IsDeleted__c, 'Customer B should be soft-deleted');
        System.assertEquals(a.Id, bRef.MergedInto__c, 'Customer B should point to A');
        System.assertNotEquals(null, bRef.DeletedDate__c);
        System.assertEquals(UserInfo.getUserId(), bRef.DeletedBy__c);
        System.assertEquals(false, bRef.IsActive__c);
    }

    @IsTest
    static void testResolve_onlyPendingEnforced() {
        Duplicate_Match__c m = makeNonPendingMatch(DuplicateMatchConstants.STATUS_IGNORED);
        DuplicateResolutionService svc = new DuplicateResolutionService();

        Boolean threw = false;
        try {
            svc.resolveSingle(String.valueOf(m.Id), 'ignore');
        } catch (CalloutException e) {
            threw = true;
            System.assert(e.getMessage().contains('Only pending matches'), 'Should enforce pending status');
        }
        System.assertEquals(true, threw);
    }

    @IsTest
    static void testResolve_invalidAction() {
        Duplicate_Match__c m = makePendingMatch(60);
        DuplicateResolutionService svc = new DuplicateResolutionService();

        Boolean threw = false;
        try {
            svc.resolveSingle(String.valueOf(m.Id), 'skip');
        } catch (CalloutException e) {
            threw = true;
            System.assert(e.getMessage().contains('Invalid action'), 'Should require merge or ignore');
        }
        System.assertEquals(true, threw);
    }

    @IsTest
    static void testGetTotalCount() {
        makePendingMatch(90);
        makePendingMatch(55);
        makePendingMatch(40);

        DuplicateResolutionService svc = new DuplicateResolutionService();

        Test.startTest();
        Integer total = svc.getTotalCount(50);
        Test.stopTest();

        System.assert(total >= 2, 'Should count matches with score >= 50');
    }
}
