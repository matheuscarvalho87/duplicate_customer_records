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

    public static Set<String> tokenize(String input) {
        String norm = normalizeString(input);
        Set<String> tokens = new Set<String>();
        if (String.isBlank(norm)) return tokens;
        for (String t : norm.split(' ')) if (!String.isBlank(t)) tokens.add(t);
        return tokens;
    }

    public static Decimal calculateSimilarity(String s1, String s2) {
        String a = normalizeString(s1), b = normalizeString(s2);
        if (a.length() == 0 && b.length() == 0) return 0;
        if (a == b) return 1;
        Integer maxLen = Math.max(a.length(), b.length());
        if (maxLen == 0) return 0;
        Integer dist = DuplicateMatchingService.levenshteinDistance(a, b);
        Decimal sim = 1 - (Decimal.valueOf(dist) / Decimal.valueOf(maxLen));
        return sim.setScale(3);
    }

    public static Boolean phoneNumberMatch(String p1, String p2) {
        if (String.isBlank(p1) || String.isBlank(p2)) return false;
        String a = p1.replaceAll('[^0-9]+', '');
        String b = p2.replaceAll('[^0-9]+', '');
        if (a.length() < 6 || b.length() < 6) return false;
        return a == b;
    }
}
