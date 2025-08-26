public with sharing class DuplicateMatchingService extends BaseService {
    public static List<Duplicate_Match__c> findDuplicates(List<Customer__c> customers) {
        return new DuplicateMatchingService().findDuplicatesInternal(customers);
    }

    protected override String getClassName() {
        return 'DuplicateMatchingService';
    }

    @TestVisible
    private List<Duplicate_Match__c> findDuplicatesInternal(List<Customer__c> customers) {
        if (customers == null || customers.isEmpty()) {
            logWarning('findDuplicatesInternal', 'Empty customer list received');
            return new List<Duplicate_Match__c>();
        }

        Long t0 = System.currentTimeMillis();

        List<Customer__c> active = new List<Customer__c>();
        for (Customer__c c : customers) {
            if (c != null && (c.IsActive__c == null || c.IsActive__c == true)) {
                active.add(c);
            }
        }
        if (active.isEmpty()) {
            logInfo('findDuplicatesInternal', 'No active customers to process');
            return new List<Duplicate_Match__c>();
        }

        Map<String, List<Customer__c>> byEmail = new Map<String, List<Customer__c>>();
        Map<String, List<Customer__c>> byPhone = new Map<String, List<Customer__c>>();

        for (Customer__c c : active) {
            if (!String.isBlank(c.Email__c)) {
                String em = normalizeEmail(c.Email__c);
                if (!String.isBlank(em)) {
                    if (!byEmail.containsKey(em)) byEmail.put(em, new List<Customer__c>());
                    byEmail.get(em).add(c);
                }
            }
            if (!String.isBlank(c.Phone__c)) {
                String ph = normalizePhone(c.Phone__c);
                if (!String.isBlank(ph)) {
                    if (!byPhone.containsKey(ph)) byPhone.put(ph, new List<Customer__c>());
                    byPhone.get(ph).add(c);
                }
            }
        }

        Set<String> seenPairs = new Set<String>();
        List<Duplicate_Match__c> out = new List<Duplicate_Match__c>();

        addEmailPairs(byEmail, seenPairs, out);
        addPhonePairs(byPhone, seenPairs, out);

        Long dt = System.currentTimeMillis() - t0;
        performanceMetrics.put('findDuplicates.countIn', customers.size());
        performanceMetrics.put('findDuplicates.countActive', active.size());
        performanceMetrics.put('findDuplicates.pairsOut', out.size());
        performanceMetrics.put('findDuplicates.timeMs', dt);
        logInfo('findDuplicatesInternal', 'Pairs=' + out.size() + ' in ' + dt + 'ms');

        return out;
    }

    @TestVisible
    private void addEmailPairs(
        Map<String, List<Customer__c>> byEmail,
        Set<String> seenPairs,
        List<Duplicate_Match__c> out
    ) {
        if (byEmail == null || byEmail.isEmpty()) return;
        for (String em : byEmail.keySet()) {
            List<Customer__c> bucket = byEmail.get(em);
            if (bucket == null || bucket.size() < 2) continue;

            for (Integer i = 0; i < bucket.size(); i++) {
                for (Integer j = i + 1; j < bucket.size(); j++) {
                    Customer__c a = bucket[i], b = bucket[j];
                    String key = pairKey(a != null ? a.Id : null, b != null ? b.Id : null);
                    if (key == null || seenPairs.contains(key)) continue;
                    seenPairs.add(key);

                    out.add(createDuplicateRecord(
                        a, b,
                        DuplicateMatchConstants.EXACT_EMAIL_MATCH_SCORE,
                        DuplicateMatchConstants.MATCH_TYPE_EMAIL
                    ));
                }
            }
        }
    }

    @TestVisible
    private void addPhonePairs(
        Map<String, List<Customer__c>> byPhone,
        Set<String> seenPairs,
        List<Duplicate_Match__c> out
    ) {
        if (byPhone == null || byPhone.isEmpty()) return;

        final Double NAME_SIMILARITY_THRESHOLD = 0.78; // 78%

        for (String ph : byPhone.keySet()) {
            List<Customer__c> bucket = byPhone.get(ph);
            if (bucket == null || bucket.size() < 2) continue;

            for (Integer i = 0; i < bucket.size(); i++) {
                for (Integer j = i + 1; j < bucket.size(); j++) {
                    Customer__c a = bucket[i], b = bucket[j];
                    String key = pairKey(a != null ? a.Id : null, b != null ? b.Id : null);
                    if (key == null || seenPairs.contains(key)) continue;

                    Boolean sameLast = !String.isBlank(a.LastName__c)
                        && !String.isBlank(b.LastName__c)
                        && a.LastName__c.trim().toLowerCase() == b.LastName__c.trim().toLowerCase();

                    if (sameLast) {
                        seenPairs.add(key);
                        out.add(createDuplicateRecord(
                            a, b,
                            DuplicateMatchConstants.SAME_LASTNAME_PHONE_MATCH_SCORE,
                            DuplicateMatchConstants.MATCH_TYPE_LASTNAME_PHONE
                        ));
                        continue;
                    }

                    Double sim = nameSimilarity(a.FirstName__c, b.FirstName__c);
                    if (sim >= NAME_SIMILARITY_THRESHOLD) {
                        seenPairs.add(key);
                        out.add(createDuplicateRecord(
                            a, b,
                            DuplicateMatchConstants.FUZZY_NAME_PHONE_MATCH_SCORE,
                            DuplicateMatchConstants.MATCH_TYPE_FUZZY_NAME_PHONE
                        ));
                    }
                }
            }
        }
    }


    @TestVisible
    private String normalizeEmail(String raw) {
        if (String.isBlank(raw)) return null;
        String s = sanitizeInput(raw).trim().toLowerCase();
        return s;
    }

    @TestVisible
    private String normalizePhone(String raw) {
        if (String.isBlank(raw)) return null;
        String onlyDigits = '';
        for (Integer i = 0; i < raw.length(); i++) {
            String ch = String.valueOf(raw.charAt(i));
            if (ch >= '0' && ch <= '9') onlyDigits += ch;
        }

        return String.isBlank(onlyDigits) ? null : onlyDigits;
    }

    @TestVisible
    private Double nameSimilarity(String a, String b) {
        if (String.isBlank(a) || String.isBlank(b)) return 0.0;
        String s1 = a.trim().toLowerCase();
        String s2 = b.trim().toLowerCase();
        if (s1 == s2) return 1.0;

        Integer dist = levenshteinDistance(s1, s2);
        Integer maxLen = Math.max(s1.length(), s2.length());
        if (maxLen == 0) return 1.0;

        return 1.0 - ((Double) dist) / maxLen;
    }

    @TestVisible
    public Integer levenshteinDistance(String a, String b) {
        Integer n = a == null ? 0 : a.length();
        Integer m = b == null ? 0 : b.length();
        if (n == 0) return m;
        if (m == 0) return n;

        List<Integer> prev = new List<Integer>();
        for (Integer j = 0; j <= m; j++) prev.add(j);

        for (Integer i = 1; i <= n; i++) {
            List<Integer> curr = new List<Integer>();
            curr.add(i);
            for (Integer j = 1; j <= m; j++) {
                Integer cost = (a.charAt(i - 1) == b.charAt(j - 1)) ? 0 : 1;
                Integer ins = curr.get(j - 1) + 1;
                Integer del = prev.get(j) + 1;
                Integer sub = prev.get(j - 1) + cost;
                curr.add(Math.min(ins, Math.min(del, sub)));
            }
            prev = new List<Integer>(curr);
        }
        return prev.get(m);
    }

    @TestVisible
    private Duplicate_Match__c createDuplicateRecord(Customer__c a, Customer__c b, Integer score, String typeLabel) {
        return new Duplicate_Match__c(
            Customer_A__c = a != null ? a.Id : null,
            Customer_B__c = b != null ? b.Id : null,
            Match_Score__c = score,
            Match_Type__c = typeLabel,
            Status__c = DuplicateMatchConstants.STATUS_PENDING
        );
    }

    @TestVisible
    private static String pairKey(Id a, Id b) {
        if (a == null || b == null) return null;
        String sa = String.valueOf(a), sb = String.valueOf(b);
        return (sa < sb) ? (sa + '|' + sb) : (sb + '|' + sa);
    }
}
