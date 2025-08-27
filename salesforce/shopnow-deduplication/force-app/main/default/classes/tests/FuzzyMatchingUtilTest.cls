@IsTest
private class FuzzyMatchingUtilTest {

    @IsTest
    static void testNormalizeString() {
        System.assertEquals('john smith', FuzzyMatchingUtil.normalizeString(' John.Smith!! '));
        System.assertEquals('carlos junior', FuzzyMatchingUtil.normalizeString('  CARLOS   JÚNIOR '));
        System.assertEquals('', FuzzyMatchingUtil.normalizeString(null));
        System.assertEquals('', FuzzyMatchingUtil.normalizeString('   '));

        String norm = FuzzyMatchingUtil.normalizeString(' Áção,   manhã!!  PEÑÓN  ');
        System.assertEquals('acao manha penon', norm);

        System.assertEquals('new york', FuzzyMatchingUtil.normalizeString('New-York!!'));
    }

    @IsTest
    static void testCalculateSimilarity_identical_and_diacritics() {
        Decimal s1 = FuzzyMatchingUtil.calculateSimilarity('José', 'Jose');
        System.assertEquals(Decimal.valueOf('1.000'), s1);

        Decimal s2 = FuzzyMatchingUtil.calculateSimilarity('New-York!!', 'new york');
        System.assertEquals(Decimal.valueOf('1.000'), s2);
    }

    @IsTest
    static void testCalculateSimilarity_blankInputCases() {
        System.assertEquals(Decimal.valueOf('1.000'), FuzzyMatchingUtil.calculateSimilarity('', ''));
        System.assertEquals(Decimal.valueOf('0.000'), FuzzyMatchingUtil.calculateSimilarity('', 'abc'));
        System.assertEquals(Decimal.valueOf('0.000'), FuzzyMatchingUtil.calculateSimilarity(null, 'abc'));
        System.assertEquals(Decimal.valueOf('0.000'), FuzzyMatchingUtil.calculateSimilarity('abc', null));
    }

    @IsTest
    static void testCalculateSimilarity_editDistanceExamples() {
        Decimal jJon = FuzzyMatchingUtil.calculateSimilarity('John', 'Jon');
        System.assertEquals(Decimal.valueOf('0.750'), jJon);

        Decimal janeJanet = FuzzyMatchingUtil.calculateSimilarity('Jane', 'Janet');
        System.assertEquals(Decimal.valueOf('0.800'), janeJanet);

        Decimal diff = FuzzyMatchingUtil.calculateSimilarity('abc', 'xyz');
        System.assertEquals(Decimal.valueOf('0.000'), diff);
    }
}
