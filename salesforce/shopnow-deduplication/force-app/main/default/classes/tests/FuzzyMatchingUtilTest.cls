@IsTest
private class FuzzyMatchingUtilTest {

    @IsTest
    static void testNormalizeString() {
        System.assertEquals('john smith', FuzzyMatchingUtil.normalizeString(' John.Smith!! '));
        System.assertEquals('carlos junior', FuzzyMatchingUtil.normalizeString('  CARLOS   JÚNIOR '));
        System.assertEquals('', FuzzyMatchingUtil.normalizeString(null));
        System.assertEquals('', FuzzyMatchingUtil.normalizeString('   '));
    }

    @IsTest
    static void testTokenize() {
        Set<String> tokens = FuzzyMatchingUtil.tokenize('Hello World 123');
        System.assert(tokens.contains('hello'));
        System.assert(tokens.contains('world'));
        System.assert(tokens.contains('123'));
        System.assertEquals(3, tokens.size());

        System.assertEquals(new Set<String>(), FuzzyMatchingUtil.tokenize('   '));
    }

    @IsTest
    static void testCalculateSimilarityExact() {
        Decimal sim = FuzzyMatchingUtil.calculateSimilarity('John', 'John');
        System.assertEquals(1, sim);
    }

    @IsTest
    static void testCalculateSimilarityClose() {
        Decimal sim = FuzzyMatchingUtil.calculateSimilarity('John', 'Jon');
        System.assert(sim >= 0.7 && sim < 1, 'Expected partial similarity between John and Jon');
    }

    @IsTest
    static void testCalculateSimilarityEmpty() {
        Decimal sim = FuzzyMatchingUtil.calculateSimilarity('', '');
        System.assertEquals(0, sim);
    }

    @IsTest
    static void testPhoneNumberMatch() {
        System.assertEquals(true, FuzzyMatchingUtil.phoneNumberMatch('(555) 123-4567', '5551234567'));
        System.assertEquals(true, FuzzyMatchingUtil.phoneNumberMatch('5551234', '5551234'));
         System.assertEquals(false, FuzzyMatchingUtil.phoneNumberMatch('55512', '55512')); // less than 6 digits
        System.assertEquals(false, FuzzyMatchingUtil.phoneNumberMatch(null, '5551234567'));
    }
}
