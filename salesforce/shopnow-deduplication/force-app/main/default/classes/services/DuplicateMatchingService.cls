public with sharing class DuplicateMatchingService extends BaseService {
    
    protected override String getClassName() { 
        return 'DuplicateMatchingService'; 
    }
    
    public List<Duplicate_Match__c> findDuplicates(List<Customer__c> customers) {
        logInfo('findDuplicates', 'Starting duplicate detection for ' + (customers != null ? customers.size() : 0) + ' customers');
        
        Long startTime = System.currentTimeMillis();
        
        try {
            if (customers == null || customers.isEmpty()) {
                logWarning('findDuplicates', 'Empty customer list provided');
                return new List<Duplicate_Match__c>();
            }

            if (customers.size() > DuplicateMatchConstants.MAX_DUPLICATE_PAIRS) {
                String message = 'Customer list size (' + customers.size() + ') exceeds maximum allowed (' + 
                               DuplicateMatchConstants.MAX_DUPLICATE_PAIRS + ')';
                logError('findDuplicates', message, null);
                throw new IllegalArgumentException(message);
            }
            List<Duplicate_Match__c> duplicateMatches = processCustomersForDuplicates(customers);
            
            Long executionTime = System.currentTimeMillis() - startTime;
            setMetric('findDuplicates_executionTime', executionTime);
            setMetric('findDuplicates_inputCount', customers.size());
            setMetric('findDuplicates_outputCount', duplicateMatches.size());
            
            logInfo('findDuplicates', 'Found ' + duplicateMatches.size() + ' potential duplicates in ' + executionTime + 'ms');
            return duplicateMatches;
            
        } catch (Exception e) {
            Long executionTime = System.currentTimeMillis() - startTime;
            logError('findDuplicates', 'Duplicate detection failed after ' + executionTime + 'ms', e);
            throw e;
        }
    }

    private List<Duplicate_Match__c> processCustomersForDuplicates(List<Customer__c> customers) {
        List<Duplicate_Match__c> duplicateMatches = new List<Duplicate_Match__c>();
        Set<String> processedPairs = new Set<String>();
        Integer comparisons = 0;
        Integer matches = 0;
        
        for (Integer i = 0; i < customers.size(); i++) {
            for (Integer j = i + 1; j < customers.size(); j++) {
                comparisons++;
                
                Customer__c customerA = customers[i];
                Customer__c customerB = customers[j];
                
                if (!isValidCustomerForProcessing(customerA) || !isValidCustomerForProcessing(customerB)) {
                    continue;
                }
                
                String pairKey = createPairKey(customerA.Id, customerB.Id);
                if (processedPairs.contains(pairKey)) {
                    continue;
                }
                processedPairs.add(pairKey);
                
                Integer matchScore = calculateMatchScore(customerA, customerB);
                String matchType = getMatchType(matchScore);
                
                if (matchScore > DuplicateMatchConstants.NO_MATCH_SCORE) {
                    matches++;
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
        
        setMetric('processCustomers_comparisons', comparisons);
        setMetric('processCustomers_matches', matches);
        setMetric('processCustomers_matchRate', comparisons > 0 ? (Decimal.valueOf(matches) / comparisons * 100).setScale(2) : 0);
        
        logDebug('processCustomersForDuplicates', 'Processed ' + comparisons + ' comparisons, found ' + matches + ' matches');
        
        return duplicateMatches;
    }
    
    @TestVisible
    private Integer calculateMatchScore(Customer__c customerA, Customer__c customerB) {
        try {
            if (hasExactEmailMatch(customerA, customerB)) {
                logDebug('calculateMatchScore', 'Exact email match found between customers');
                return DuplicateMatchConstants.EXACT_EMAIL_MATCH_SCORE; // 100
            }
            
            if (hasFuzzyNameMatch(customerA, customerB) && hasSamePhone(customerA, customerB)) {
                logDebug('calculateMatchScore', 'Fuzzy name + phone match found between customers');
                return DuplicateMatchConstants.FUZZY_NAME_PHONE_MATCH_SCORE; // 70
            }
            
            if (hasSameLastName(customerA, customerB) && hasSamePhone(customerA, customerB)) {
                logDebug('calculateMatchScore', 'Same last name + phone match found between customers');
                return DuplicateMatchConstants.SAME_LASTNAME_PHONE_MATCH_SCORE; // 50
            }
            
            return DuplicateMatchConstants.NO_MATCH_SCORE;
            
        } catch (Exception e) {
            logError('calculateMatchScore', 'Error calculating match score between customers', e);
            return DuplicateMatchConstants.NO_MATCH_SCORE;
        }
    }

    @TestVisible
    private Boolean hasExactEmailMatch(Customer__c customerA, Customer__c customerB) {
        if (String.isBlank(customerA.Email__c) || String.isBlank(customerB.Email__c)) {
            return false;
        }
        
        String emailA = customerA.Email__c.trim().toLowerCase();
        String emailB = customerB.Email__c.trim().toLowerCase();
        
        return emailA.equals(emailB);
    }

    @TestVisible
    private Boolean hasFuzzyNameMatch(Customer__c customerA, Customer__c customerB) {
        if (String.isBlank(customerA.FirstName__c) || String.isBlank(customerB.FirstName__c)) {
            return false;
        }
        
        try {
            Decimal similarity = FuzzyMatchingUtil.calculateSimilarity(
                customerA.FirstName__c, 
                customerB.FirstName__c
            );
            
            return similarity >= DuplicateMatchConstants.FUZZY_MATCH_THRESHOLD; // 0.8 (80%)
        } catch (Exception e) {
            logWarning('hasFuzzyNameMatch', 'Error calculating fuzzy match: ' + e.getMessage());
            return false;
        }
    }

    @TestVisible
    private Boolean hasSameLastName(Customer__c customerA, Customer__c customerB) {
        if (String.isBlank(customerA.LastName__c) || String.isBlank(customerB.LastName__c)) {
            return false;
        }
        
        String lastNameA = customerA.LastName__c.trim().toLowerCase();
        String lastNameB = customerB.LastName__c.trim().toLowerCase();
        
        return lastNameA.equals(lastNameB);
    }

    @TestVisible
    private Boolean hasSamePhone(Customer__c customerA, Customer__c customerB) {
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
    private String normalizePhone(String phone) {
        if (String.isBlank(phone)) {
            return '';
        }
        
        String normalized = phone.replaceAll('[^0-9]', '');
        return normalized != null ? normalized : '';
    }

    @TestVisible
    private String getMatchType(Integer score) {
        if (score == DuplicateMatchConstants.EXACT_EMAIL_MATCH_SCORE) {
            return DuplicateMatchConstants.MATCH_TYPE_EMAIL;
        } else if (score == DuplicateMatchConstants.FUZZY_NAME_PHONE_MATCH_SCORE) {
            return DuplicateMatchConstants.MATCH_TYPE_FUZZY_NAME_PHONE;
        } else if (score == DuplicateMatchConstants.SAME_LASTNAME_PHONE_MATCH_SCORE) {
            return DuplicateMatchConstants.MATCH_TYPE_LASTNAME_PHONE;
        }
        return 'No Match';
    }

    @TestVisible
    private String createPairKey(Id customerA, Id customerB) {
        if (customerA == null || customerB == null) {
            return null;
        }
        
        String idA = String.valueOf(customerA);
        String idB = String.valueOf(customerB);
        
        return idA < idB ? idA + '|' + idB : idB + '|' + idA;
    }

    private Boolean isValidCustomerForProcessing(Customer__c customer) {
        if (customer == null) {
            return false;
        }
        
        if (customer.IsActive__c != true || customer.IsDeleted__c == true) {
            return false;
        }
        
        if (String.isBlank(customer.FirstName__c) && 
            String.isBlank(customer.LastName__c) && 
            String.isBlank(customer.Email__c) && 
            String.isBlank(customer.Phone__c)) {
            return false;
        }
        
        return true;
    }

    /**
     * Levenshtein distance calculation for fuzzy matching
     * Public static utility method for potential reuse
     */
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