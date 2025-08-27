public with sharing class DuplicateMatchingService {
    
    public static List<Duplicate_Match__c> findDuplicates(List<Customer__c> customers) {
        if (customers == null || customers.isEmpty()) {
            System.debug('DuplicateMatchingService: Empty customer list provided');
            return new List<Duplicate_Match__c>();
        }
        
        List<Duplicate_Match__c> duplicateMatches = new List<Duplicate_Match__c>();
        Set<String> processedPairs = new Set<String>();
        for (Integer i = 0; i < customers.size(); i++) {
            for (Integer j = i + 1; j < customers.size(); j++) {
                Customer__c customerA = customers[i];
                Customer__c customerB = customers[j];
                
                if (customerA == null || customerB == null || 
                    customerA.IsActive__c != true || customerB.IsActive__c != true ||
                    customerA.IsDeleted__c == true || customerB.IsDeleted__c == true) {
                    continue;
                }
                
                String pairKey = createPairKey(customerA.Id, customerB.Id);
                if (processedPairs.contains(pairKey)) {
                    continue;
                }
                processedPairs.add(pairKey);
                
                Integer matchScore = calculateMatchScore(customerA, customerB);
                String matchType = getMatchType(matchScore);
                
                if (matchScore > 0) {
                    duplicateMatches.add(new Duplicate_Match__c(
                        Customer_A__c = customerA.Id,
                        Customer_B__c = customerB.Id,
                        Match_Score__c = matchScore,
                        Match_Type__c = matchType,
                        Status__c = DuplicateMatchConstants.STATUS_PENDING
                    ));
                }
            }
        }
        
        System.debug('DuplicateMatchingService: Found ' + duplicateMatches.size() + ' potential duplicates');
        return duplicateMatches;
    }
    
    @TestVisible
    private static Integer calculateMatchScore(Customer__c customerA, Customer__c customerB) {
        
        if (hasExactEmailMatch(customerA, customerB)) {
            return DuplicateMatchConstants.EXACT_EMAIL_MATCH_SCORE; // 100
        }
        
        if (hasFuzzyNameMatch(customerA, customerB) && hasSamePhone(customerA, customerB)) {
            return DuplicateMatchConstants.FUZZY_NAME_PHONE_MATCH_SCORE; // 70
        }
 
        if (hasSameLastName(customerA, customerB) && hasSamePhone(customerA, customerB)) {
            return DuplicateMatchConstants.SAME_LASTNAME_PHONE_MATCH_SCORE; // 50
        }
        
        return DuplicateMatchConstants.NO_MATCH_SCORE;
    }
    

    @TestVisible
    private static Boolean hasExactEmailMatch(Customer__c customerA, Customer__c customerB) {
        if (String.isBlank(customerA.Email__c) || String.isBlank(customerB.Email__c)) {
            return false;
        }
        
        String emailA = customerA.Email__c.trim().toLowerCase();
        String emailB = customerB.Email__c.trim().toLowerCase();
        
        return emailA.equals(emailB);
    }
    
 
    @TestVisible
    private static Boolean hasFuzzyNameMatch(Customer__c customerA, Customer__c customerB) {
        if (String.isBlank(customerA.FirstName__c) || String.isBlank(customerB.FirstName__c)) {
            return false;
        }
        
        Decimal similarity = FuzzyMatchingUtil.calculateSimilarity(
            customerA.FirstName__c, 
            customerB.FirstName__c
        );
        
        return similarity >= DuplicateMatchConstants.FUZZY_MATCH_THRESHOLD; // 0.8 (80%)
    }
    
    @TestVisible
    private static Boolean hasSameLastName(Customer__c customerA, Customer__c customerB) {
        if (String.isBlank(customerA.LastName__c) || String.isBlank(customerB.LastName__c)) {
            return false;
        }
        
        String lastNameA = customerA.LastName__c.trim().toLowerCase();
        String lastNameB = customerB.LastName__c.trim().toLowerCase();
        
        return lastNameA.equals(lastNameB);
    }
    
    @TestVisible
    private static Boolean hasSamePhone(Customer__c customerA, Customer__c customerB) {
        if (String.isBlank(customerA.Phone__c) || String.isBlank(customerB.Phone__c)) {
            return false;
        }
        
        String phoneA = normalizePhone(customerA.Phone__c);
        String phoneB = normalizePhone(customerB.Phone__c);
        
        if (phoneA.length() < 6 || phoneB.length() < 6) {
            return false;
        }
        
        return phoneA.equals(phoneB);
    }

    @TestVisible
    private static String normalizePhone(String phone) {
        if (String.isBlank(phone)) {
            return '';
        }
        
        String normalized = phone.replaceAll('[^0-9]', '');
        return normalized != null ? normalized : '';
    }
    

    @TestVisible
    private static String getMatchType(Integer score) {
        if (score == 100) {
            return DuplicateMatchConstants.MATCH_TYPE_EMAIL;
        } else if (score == 70) {
            return DuplicateMatchConstants.MATCH_TYPE_FUZZY_NAME_PHONE;
        } else if (score == 50) {
            return DuplicateMatchConstants.MATCH_TYPE_LASTNAME_PHONE;
        }
        return 'No Match';
    }
    
    @TestVisible
    private static String createPairKey(Id customerA, Id customerB) {
        if (customerA == null || customerB == null) {
            return null;
        }
        
        String idA = String.valueOf(customerA);
        String idB = String.valueOf(customerB);
        
        return idA < idB ? idA + '|' + idB : idB + '|' + idA;
    }
    
    public static Integer levenshteinDistance(String stringA, String stringB) {
        if (String.isBlank(stringA)) return String.isBlank(stringB) ? 0 : stringB.length();
        if (String.isBlank(stringB)) return stringA.length();
        
        Integer lenA = stringA.length();
        Integer lenB = stringB.length();
        
        List<List<Integer>> matrix = new List<List<Integer>>();

        for (Integer i = 0; i <= lenA; i++) {
            matrix.add(new List<Integer>());
            for (Integer j = 0; j <= lenB; j++) {
                if (i == 0) {
                    matrix[i].add(j);
                } else if (j == 0) {
                    matrix[i].add(i);
                } else {
                    matrix[i].add(0);
                }
            }
        }
    
        for (Integer i = 1; i <= lenA; i++) {
            for (Integer j = 1; j <= lenB; j++) {
                Integer cost = stringA.charAt(i-1) == stringB.charAt(j-1) ? 0 : 1;
                
                Integer deletion = matrix[i-1][j] + 1;
                Integer insertion = matrix[i][j-1] + 1;
                Integer substitution = matrix[i-1][j-1] + cost;
                
                matrix[i][j] = Math.min(deletion, Math.min(insertion, substitution));
            }
        }
        
        return matrix[lenA][lenB];
    }
}