@IsTest
private class DuplicateMatchingServiceTest {

    @IsTest
    static void testExactEmailMatch() {
        Customer__c a = new Customer__c(FirstName__c='John', LastName__c='Smith', Email__c='john@example.com', Phone__c='5551111111', IsActive__c=true);
        Customer__c b = new Customer__c(FirstName__c='Jon',  LastName__c='Smith', Email__c='john@example.com', Phone__c='5552222222', IsActive__c=true);

        DuplicateMatchingService service = new DuplicateMatchingService();
        List<Duplicate_Match__c> rs = service.findDuplicates(new List<Customer__c>{ a, b });
        System.assertEquals(1, rs.size(), 'One duplicate expected by exact email');
        System.assertEquals(DuplicateMatchConstants.EXACT_EMAIL_MATCH_SCORE, rs[0].Match_Score__c);
        System.assertEquals(DuplicateMatchConstants.MATCH_TYPE_EMAIL, rs[0].Match_Type__c);
    }

    @IsTest
    static void testFuzzyNameWithSamePhone() {
        Customer__c a = new Customer__c(FirstName__c='Jane', LastName__c='Doe',  Email__c='a@ex.com', Phone__c='(555) 567-8901', IsActive__c=true);
        Customer__c b = new Customer__c(FirstName__c='Janet', LastName__c='Roe', Email__c='b@ex.com', Phone__c='5555678901',    IsActive__c=true);

        DuplicateMatchingService service = new DuplicateMatchingService();
        List<Duplicate_Match__c> rs = service.findDuplicates(new List<Customer__c>{ a, b });
        System.assertEquals(1, rs.size(), 'One duplicate expected by fuzzy first name + same phone');
        System.assertEquals(DuplicateMatchConstants.FUZZY_NAME_PHONE_MATCH_SCORE, rs[0].Match_Score__c);
        System.assertEquals(DuplicateMatchConstants.MATCH_TYPE_FUZZY_NAME_PHONE, rs[0].Match_Type__c);
    }

    @IsTest
    static void testFuzzyBelowThreshold_noMatch() {
        Customer__c a = new Customer__c(FirstName__c='John', LastName__c='Doe', Email__c='a@ex.com', Phone__c='5555678901', IsActive__c=true);
        Customer__c b = new Customer__c(FirstName__c='Jon',  LastName__c='Roe', Email__c='b@ex.com', Phone__c='(555) 567-8901', IsActive__c=true);
        
        DuplicateMatchingService service = new DuplicateMatchingService();
        List<Duplicate_Match__c> rs = service.findDuplicates(new List<Customer__c>{ a, b });
        System.assertEquals(0, rs.size(), 'Should not match when fuzzy similarity is below threshold even with same phone');
    }

    @IsTest
    static void testLastNameWithSamePhone() {
        Customer__c a = new Customer__c(FirstName__c='Jane',  LastName__c='Doe', Email__c='a@ex.com', Phone__c='5555678901',     IsActive__c=true);
        Customer__c b = new Customer__c(FirstName__c='Other', LastName__c='Doe', Email__c='b@ex.com', Phone__c='(555) 567-8901', IsActive__c=true);

        DuplicateMatchingService service = new DuplicateMatchingService();
        List<Duplicate_Match__c> rs = service.findDuplicates(new List<Customer__c>{ a, b });
        System.assertEquals(1, rs.size(), 'One duplicate expected by same last name + same phone');
        System.assertEquals(DuplicateMatchConstants.SAME_LASTNAME_PHONE_MATCH_SCORE, rs[0].Match_Score__c);
        System.assertEquals(DuplicateMatchConstants.MATCH_TYPE_LASTNAME_PHONE, rs[0].Match_Type__c);
    }

    @IsTest
    static void testNoDuplicates() {
        Customer__c a = new Customer__c(FirstName__c='Alice', LastName__c='Blue',  Email__c='alice@acme.com', Phone__c='1111111111', IsActive__c=true);
        Customer__c b = new Customer__c(FirstName__c='Bob',   LastName__c='Green', Email__c='bob@acme.com',   Phone__c='2222222222', IsActive__c=true);
        DuplicateMatchingService service = new DuplicateMatchingService();
        List<Duplicate_Match__c> rs = service.findDuplicates(new List<Customer__c>{ a, b });
        System.assertEquals(0, rs.size(), 'No duplicates expected');
    }

    @IsTest
    static void testPerformanceAndGovernorLimits() {
        Customer__c a = new Customer__c(FirstName__c='John', LastName__c='Smith', Email__c='john@example.com', Phone__c='5551111111', IsActive__c=true);
        Customer__c b = new Customer__c(FirstName__c='John', LastName__c='Smith', Email__c='john@example.com', Phone__c='5551111111', IsActive__c=true);

        Test.startTest();
        Integer soqlBefore = Limits.getQueries();
        Integer cpuBefore  = Limits.getCpuTime();
        DuplicateMatchingService service = new DuplicateMatchingService();
        List<Duplicate_Match__c> rs = service.findDuplicates(new List<Customer__c>{ a, b });
        Integer soqlAfter = Limits.getQueries();
        Integer cpuAfter  = Limits.getCpuTime();
        Test.stopTest();

        System.assertEquals(1, rs.size(), 'One pair expected');
        System.assertEquals(0, soqlAfter - soqlBefore, 'Service should not execute SOQL');
        System.assert(cpuAfter - cpuBefore < Limits.getLimitCpuTime(), 'CPU well under limit');
    }

    @IsTest
    static void testNormalizePhone_and_samePhoneMinLength() {
        DuplicateMatchingService service = new DuplicateMatchingService();
        String n1 = service.normalizePhone('(555) 567-8901');
        String n2 = service.normalizePhone('5555678901');
        System.assertEquals('5555678901', n1);
        System.assertEquals('5555678901', n2);

        Customer__c a = new Customer__c(FirstName__c='A', LastName__c='X', Email__c='a@x.com', Phone__c='12345', IsActive__c=true);
        Customer__c b = new Customer__c(FirstName__c='B', LastName__c='Y', Email__c='b@y.com', Phone__c='12345', IsActive__c=true);
        Boolean sameShort = service.hasSamePhone(a, b);
        System.assertEquals(false, sameShort, 'Phones shorter than 6 digits must not match');
    }

    @IsTest
    static void testGetMatchType_noMatch() {
        DuplicateMatchingService service = new DuplicateMatchingService();
        String t0 = service.getMatchType(0);
        String t30 = service.getMatchType(30);
        System.assertEquals('No Match', t0);
        System.assertEquals('No Match', t30);
    }

    @IsTest
    static void testCreatePairKey_nulls_and_ordering() {
        DuplicateMatchingService service = new DuplicateMatchingService();
        String kNull = service.createPairKey(null, null);
        System.assertEquals(null, kNull);

        Customer__c ca = new Customer__c(FirstName__c='A', LastName__c='Z', Email__c='a'+System.currentTimeMillis()+'@x.com', Phone__c='1111111111', IsActive__c=true);
        Customer__c cb = new Customer__c(FirstName__c='B', LastName__c='Z', Email__c='b'+System.currentTimeMillis()+'@x.com', Phone__c='2222222222', IsActive__c=true);
        insert new List<Customer__c>{ ca, cb };

        String key = service.createPairKey(ca.Id, cb.Id);
        String minId = String.valueOf(ca.Id) < String.valueOf(cb.Id) ? String.valueOf(ca.Id) : String.valueOf(cb.Id);
        String maxId = String.valueOf(ca.Id) < String.valueOf(cb.Id) ? String.valueOf(cb.Id) : String.valueOf(ca.Id);
        System.assertEquals(minId + '|' + maxId, key);
    }

    @IsTest
    static void testLevenshteinDistance_paths() {
        System.assertEquals(0, DuplicateMatchingService.levenshteinDistance('', ''));
        System.assertEquals(3, DuplicateMatchingService.levenshteinDistance('', 'abc'));
        System.assertEquals(3, DuplicateMatchingService.levenshteinDistance('kitten', 'sitting')); // canonical example => 3
    }
}
