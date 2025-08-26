@IsTest
private class DuplicateMatchingServiceTest {

    @IsTest
    static void testExactEmailMatch() {
        Customer__c a = new Customer__c(
            FirstName__c='John', LastName__c='Smith',
            Email__c='john@example.com', Phone__c='5551111111', IsActive__c=true
        );
        Customer__c b = new Customer__c(
            FirstName__c='Jon', LastName__c='Smith',
            Email__c='john@example.com', Phone__c='5552222222', IsActive__c=true
        );

        List<Duplicate_Match__c> rs = DuplicateMatchingService.findDuplicates(new List<Customer__c>{ a, b });
        System.assertEquals(1, rs.size(), 'One duplicate expected by exact email');
        System.assertEquals(DuplicateMatchConstants.EXACT_EMAIL_MATCH_SCORE, rs[0].Match_Score__c);
        System.assertEquals(DuplicateMatchConstants.MATCH_TYPE_EMAIL, rs[0].Match_Type__c);
    }

    @IsTest
    static void testFuzzyNameWithSamePhone() {
        Customer__c a = new Customer__c(
            FirstName__c='John', LastName__c='Doe',
            Email__c='a@ex.com', Phone__c='(555) 567-8901', IsActive__c=true
        );
        Customer__c b = new Customer__c(
            FirstName__c='Jon', LastName__c='Roe',
            Email__c='b@ex.com', Phone__c='5555678901', IsActive__c=true
        );

        List<Duplicate_Match__c> rs = DuplicateMatchingService.findDuplicates(new List<Customer__c>{ a, b });
        System.assertEquals(1, rs.size(), 'One duplicate expected by fuzzy first name + same phone');
        System.assertEquals(DuplicateMatchConstants.FUZZY_NAME_PHONE_MATCH_SCORE, rs[0].Match_Score__c);
        System.assertEquals(DuplicateMatchConstants.MATCH_TYPE_FUZZY_NAME_PHONE, rs[0].Match_Type__c);
    }

    @IsTest
    static void testLastNameWithSamePhone() {
        Customer__c a = new Customer__c(
            FirstName__c='Jane', LastName__c='Doe',
            Email__c='a@ex.com', Phone__c='5555678901', IsActive__c=true
        );
        Customer__c b = new Customer__c(
            FirstName__c='Other', LastName__c='Doe',
            Email__c='b@ex.com', Phone__c='(555) 567-8901', IsActive__c=true
        );

        List<Duplicate_Match__c> rs = DuplicateMatchingService.findDuplicates(new List<Customer__c>{ a, b });
        System.assertEquals(1, rs.size(), 'One duplicate expected by same last name + same phone');
        System.assertEquals(DuplicateMatchConstants.SAME_LASTNAME_PHONE_MATCH_SCORE, rs[0].Match_Score__c);
        System.assertEquals(DuplicateMatchConstants.MATCH_TYPE_LASTNAME_PHONE, rs[0].Match_Type__c);
    }

    @IsTest
    static void testNoDuplicates() {
        Customer__c a = new Customer__c(
            FirstName__c='Alice', LastName__c='Blue',
            Email__c='alice@acme.com', Phone__c='1111111111', IsActive__c=true
        );
        Customer__c b = new Customer__c(
            FirstName__c='Bob', LastName__c='Green',
            Email__c='bob@acme.com', Phone__c='2222222222', IsActive__c=true
        );

        List<Duplicate_Match__c> rs = DuplicateMatchingService.findDuplicates(new List<Customer__c>{ a, b });
        System.assertEquals(0, rs.size(), 'No duplicates expected');
    }

    @IsTest
    static void testPerformanceAndGovernorLimits() {
        Customer__c a = new Customer__c(
            FirstName__c='John', LastName__c='Smith',
            Email__c='john@example.com', Phone__c='5551111111', IsActive__c=true
        );
        Customer__c b = new Customer__c(
            FirstName__c='John', LastName__c='Smith',
            Email__c='john@example.com', Phone__c='5551111111', IsActive__c=true
        );

        Test.startTest();
        Integer soqlBefore = Limits.getQueries();
        Integer cpuBefore  = Limits.getCpuTime();

        List<Duplicate_Match__c> rs = DuplicateMatchingService.findDuplicates(new List<Customer__c>{ a, b });

        Integer soqlAfter = Limits.getQueries();
        Integer cpuAfter  = Limits.getCpuTime();
        Test.stopTest();

        System.assertEquals(1, rs.size(), 'One pair expected');
        System.assertEquals(0, soqlAfter - soqlBefore, 'Service should not execute SOQL');
        System.assert(cpuAfter - cpuBefore < Limits.getLimitCpuTime(), 'CPU well under limit');
    }
}
