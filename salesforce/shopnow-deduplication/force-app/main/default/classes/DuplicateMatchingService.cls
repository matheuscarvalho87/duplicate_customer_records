public with sharing class DuplicateMatchingService {
     public static List<Duplicate_Match__c> findDuplicates(List<Customer__c> customers) {
        List<Duplicate_Match__c> out = new List<Duplicate_Match__c>();
        if (customers == null || customers.isEmpty()) return out;

        Map<String, List<Customer__c>> byEmail = new Map<String, List<Customer__c>>();
        Map<String, List<Customer__c>> byPhone = new Map<String, List<Customer__c>>();

        for (Customer__c c : customers) {
            if (c == null) continue;

            if (!String.isBlank(c.Email__c)) {
                String e = c.Email__c.trim().toLowerCase();
                if (!byEmail.containsKey(e)) byEmail.put(e, new List<Customer__c>());
                byEmail.get(e).add(c);
            }
            if (!String.isBlank(c.Phone__c)) {
                String pDigits = c.Phone__c.replaceAll('[^0-9]+', '');
                if (!byPhone.containsKey(pDigits)) byPhone.put(pDigits, new List<Customer__c>());
                byPhone.get(pDigits).add(c);
            }
        }

        Set<String> seenPairs = new Set<String>();

        // Exact email match
        for (String e : byEmail.keySet()) {
            List<Customer__c> grp = byEmail.get(e);
            for (Integer i=0; i<grp.size(); i++) {
                for (Integer j=i+1; j<grp.size(); j++) {
                    Customer__c a = grp[i], b = grp[j];
                    Integer score = 100;
                    String key = pairKey(a.Id, b.Id);
                    if (!seenPairs.contains(key)) {
                        out.add(createDuplicateRecord(a, b, score));
                        seenPairs.add(key);
                    }
                }
            }
        }

        // Same phone + (fuzzy first name OR same last name)
        for (String pKey : byPhone.keySet()) {
            List<Customer__c> grp = byPhone.get(pKey);
            if (grp.size() < 2) continue;

            for (Integer i=0; i<grp.size(); i++) {
                for (Integer j=i+1; j<grp.size(); j++) {
                    Customer__c a = grp[i], b = grp[j];
                    if (!FuzzyMatchingUtil.phoneNumberMatch(a.Phone__c, b.Phone__c)) continue;

                    Integer score = calculateMatchScore(a, b);
                    if (score > 0) {
                        String key = pairKey(a.Id, b.Id);
                        if (!seenPairs.contains(key)) {
                            out.add(createDuplicateRecord(a, b, score));
                            seenPairs.add(key);
                        }
                    }
                }
            }
        }

        return out;
    }


    public static Integer calculateMatchScore(Customer__c a, Customer__c b) {
        if (a == null || b == null) return 0;

        if (!String.isBlank(a.Email__c) && !String.isBlank(b.Email__c) &&
            a.Email__c.trim().toLowerCase() == b.Email__c.trim().toLowerCase()) {
            return 100;
        }

        if (!FuzzyMatchingUtil.phoneNumberMatch(a.Phone__c, b.Phone__c)) {
            return 0;
        }

        if (fuzzyMatch(a.FirstName__c, b.FirstName__c)) {
            return 70;
        }

        if (!String.isBlank(a.LastName__c) && !String.isBlank(b.LastName__c)) {
            String la = FuzzyMatchingUtil.normalizeString(a.LastName__c);
            String lb = FuzzyMatchingUtil.normalizeString(b.LastName__c);
            if (la == lb) {
                return 50;
            }
        }

        return 0;
    }

    public static Boolean fuzzyMatch(String s1, String s2) {
        if (String.isBlank(s1) || String.isBlank(s2)) return false;
        String a = FuzzyMatchingUtil.normalizeString(s1);
        String b = FuzzyMatchingUtil.normalizeString(s2);
        if (a == b) return true;
        
        Decimal sim = FuzzyMatchingUtil.calculateSimilarity(a, b);
        if (sim >= 0.750) return true;

        Integer dist = levenshteinDistance(a, b);
        if (dist <= 1) return true;

        if (a.length() > 0 && b.length() > 0 && a.substring(0,1) == b.substring(0,1)) {
            Integer diff = Math.abs(a.length() - b.length());
            if (diff <= 1 && (a.startsWith(b) || b.startsWith(a))) return true;
        }
        return false;
    }

    // Big O(n*m) inMemory O(min(n,m))
    public static Integer levenshteinDistance(String s1, String s2) {
        if (s1 == null) s1 = '';
        if (s2 == null) s2 = '';
        Integer n = s1.length();
        Integer m = s2.length();
        if (n == 0) return m;
        if (m == 0) return n;

        List<Integer> prev = new List<Integer>();
        List<Integer> curr = new List<Integer>();
        for (Integer j=0; j<=m; j++) prev.add(j);

        for (Integer i=1; i<=n; i++) {
            curr.clear();
            curr.add(i);
            for (Integer j=1; j<=m; j++) {
                Integer cost = (s1.substring(i-1, i) == s2.substring(j-1, j)) ? 0 : 1;
                Integer ins = curr.get(j-1) + 1;
                Integer del = prev.get(j) + 1;        
                Integer sub = prev.get(j-1) + cost;    
                curr.add(Math.min(ins, Math.min(del, sub)));
            }
            prev = new List<Integer>(curr);
        }
        return prev.get(m);
    }

    public static Duplicate_Match__c createDuplicateRecord(Customer__c a, Customer__c b, Integer score) {
        String typeLabel;
        if (score == 100) typeLabel = 'Exact Email';
        else if (score == 70) typeLabel = 'Fuzzy Name + Same Phone';
        else if (score == 50) typeLabel = 'Same Last Name + Same Phone';
        else typeLabel = 'No Rule';

        return new Duplicate_Match__c(
            Customer_A__c = a != null ? a.Id : null,
            Customer_B__c = b != null ? b.Id : null,
            Match_Score__c = score,
            Match_Type__c = typeLabel,
            Status__c = 'Pending Review'
        );
    }

    private static String pairKey(Id a, Id b) {
        if (a == null || b == null) return null;
        String sa = String.valueOf(a), sb = String.valueOf(b);
        return (sa < sb) ? (sa + '|' + sb) : (sb + '|' + sa);
    }
}
