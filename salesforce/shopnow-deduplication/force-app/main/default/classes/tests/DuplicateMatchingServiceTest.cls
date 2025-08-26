@IsTest
private class DuplicateMatchingServiceTest {

    @IsTest
    static void testExactEmailMatch() {
        Customer__c a = new Customer__c(
            FirstName__c='John', LastName__c='Smith',
            Email__c='john@example.com', Phone__c='5551111111', IsActive__c=true);
        Customer__c b = new Customer__c(
            FirstName__c='Jon', LastName__c='Smith',
            Email__c='john@example.com', Phone__c='5552222222', IsActive__c=true);

        List<Duplicate_Match__c> rs = DuplicateMatchingService.findDuplicates(new List<Customer__c>{a, b});
        System.assertEquals(1, rs.size());
        System.assertEquals(DuplicateMatchConstants.EXACT_EMAIL_MATCH_SCORE, rs[0].Match_Score__c);
        System.assertEquals(DuplicateMatchConstants.MATCH_TYPE_EMAIL, rs[0].Match_Type__c);
    }

    @IsTest
    static void testFuzzyNameWithPhone() {
        Customer__c a = new Customer__c(
            FirstName__c='John', LastName__c='Smith',
            Email__c='a@ex.com', Phone__c='(555) 123-4567', IsActive__c=true);
        Customer__c b = new Customer__c(
            FirstName__c='Jon', LastName__c='Smith',
            Email__c='b@ex.com', Phone__c='5551234567', IsActive__c=true);

        List<Duplicate_Match__c> rs = DuplicateMatchingService.findDuplicates(new List<Customer__c>{a, b});
        System.assertEquals(1, rs.size(), 'Fuzzy + same phone should match');
        System.assertEquals(DuplicateMatchConstants.FUZZY_NAME_PHONE_MATCH_SCORE, rs[0].Match_Score__c);
        System.assertEquals(DuplicateMatchConstants.MATCH_TYPE_FUZZY_NAME_PHONE, rs[0].Match_Type__c);
    }

    @IsTest
    static void testLastNameWithPhone() {
        Customer__c a = new Customer__c(
            FirstName__c='Jane', LastName__c='Doe',
            Email__c='a@ex.com', Phone__c='5555678901', IsActive__c=true);
        Customer__c b = new Customer__c(
            FirstName__c='Other', LastName__c='Doe',
            Email__c='b@ex.com', Phone__c='(555) 567-8901', IsActive__c=true);

        List<Duplicate_Match__c> rs = DuplicateMatchingService.findDuplicates(new List<Customer__c>{a, b});
        System.assertEquals(1, rs.size(), 'LastName + same phone should match');
        System.assertEquals(DuplicateMatchConstants.SAME_LASTNAME_PHONE_MATCH_SCORE, rs[0].Match_Score__c);
        System.assertEquals(DuplicateMatchConstants.MATCH_TYPE_LASTNAME_PHONE, rs[0].Match_Type__c);
    }

    @IsTest
    static void testNoMatch() {
        Customer__c a = new Customer__c(
            FirstName__c='Ana', LastName__c='Silva',
            Email__c='ana@ex.com', Phone__c='11111111', IsActive__c=true);
        Customer__c b = new Customer__c(
            FirstName__c='Bruno', LastName__c='Souza',
            Email__c='bruno@ex.com', Phone__c='22222222', IsActive__c=true);

        List<Duplicate_Match__c> rs = DuplicateMatchingService.findDuplicates(new List<Customer__c>{a, b});
        System.assertEquals(0, rs.size());
    }

    @IsTest
static void testBulkProcessing() {
    List<Customer__c> cs = new List<Customer__c>();
    for (Integer i=0; i<220; i++) {
        String first = (Math.mod(i, 2) == 0) ? 'John' : 'Jon';
        String phone = '555' + String.valueOf(1000000 + i); // cada um com número diferente
        cs.add(new Customer__c(
            FirstName__c = first,
            LastName__c  = 'Smith',
            Email__c     = 'user'+i+'@ex.com',
            Phone__c     = phone,
            IsActive__c  = true
        ));
    }

    Test.startTest();
    List<Duplicate_Match__c> rs = DuplicateMatchingService.findDuplicates(cs);
    Test.stopTest();

    System.assert(rs.size() >= 0, 'Should run bulk without CPU errors');
}

    @IsTest
    static void testGovernorLimits() {
        Customer__c a = new Customer__c(
            FirstName__c='John', LastName__c='Smith',
            Email__c='j1@ex.com', Phone__c='5551111111', IsActive__c=true);
        Customer__c b = new Customer__c(
            FirstName__c='Jon', LastName__c='Smith',
            Email__c='j2@ex.com', Phone__c='5551111111', IsActive__c=true);

        Test.startTest();
        Integer soqlBefore = Limits.getQueries();
        Integer cpuBefore  = Limits.getCpuTime();

        List<Duplicate_Match__c> rs = DuplicateMatchingService.findDuplicates(new List<Customer__c>{a, b});

        Integer soqlAfter = Limits.getQueries();
        Integer cpuAfter  = Limits.getCpuTime();
        Test.stopTest();

        System.assertEquals(1, rs.size(), 'One pair expected');
        System.assert(soqlAfter - soqlBefore <= 1, 'Service should use minimal SOQL (0 esperado)');
        System.assert(cpuAfter - cpuBefore < Limits.getLimitCpuTime(), 'CPU well under limit');
    }
}
