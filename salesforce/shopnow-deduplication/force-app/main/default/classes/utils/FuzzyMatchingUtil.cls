public with sharing class FuzzyMatchingUtil {

    private static String stripDiacritics(String s) {
        if (s == null) return '';
        String out = s;
        out = out.replaceAll('[áàâãä]', 'a');
        out = out.replaceAll('[éèêë]', 'e');
        out = out.replaceAll('[íìîï]', 'i');
        out = out.replaceAll('[óòôõö]', 'o');
        out = out.replaceAll('[úùûü]', 'u');
        out = out.replaceAll('[ç]', 'c');
        out = out.replaceAll('[ñ]', 'n');
        return out;
    }

    public static String normalizeString(String input) {
        if (String.isBlank(input)) return '';
        String s = stripDiacritics(input.trim().toLowerCase());
        // Remove non-alphanumeric characters, collapse spaces
        s = s.replaceAll('[^a-z0-9]+', ' ');
        s = s.replaceAll('\\s+', ' ').trim();
        return s;
    }

      public static Decimal calculateSimilarity(String stringA, String stringB) {
        if (String.isBlank(stringA) && String.isBlank(stringB)) {
            return 1.0; 
        }
        if (String.isBlank(stringA) || String.isBlank(stringB)) {
            return 0.0; 
        }
        
        String normalizedA = normalizeString(stringA);
        String normalizedB = normalizeString(stringB);
        
        if (normalizedA.equals(normalizedB)) {
            return 1.0;
        }
        
        Integer distance = DuplicateMatchingService.levenshteinDistance(normalizedA, normalizedB);
        Integer maxLength = Math.max(normalizedA.length(), normalizedB.length());
        
        if (maxLength == 0) {
            return 1.0;
        }
        
        Decimal similarity = 1.0 - (Decimal.valueOf(distance) / Decimal.valueOf(maxLength));
        return similarity.setScale(3);
    }
}
