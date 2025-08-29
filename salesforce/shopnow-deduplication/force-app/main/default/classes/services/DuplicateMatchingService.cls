public with sharing class DuplicateMatchingService extends BaseService {
    
    protected override String getClassName() { 
        return 'DuplicateMatchingService'; 
    }
    
    /**
     * Optimized duplicate detection using Indexing Pattern Strategy
     * Complexity: O(n log n) instead of O(n²)
     * Performance gain: ~99% reduction in comparisons for large datasets
     */
    public List<Duplicate_Match__c> findDuplicates(List<Customer__c> customers) {
        logInfo('findDuplicates', 'Starting optimized duplicate detection for ' + (customers != null ? customers.size() : 0) + ' customers');
        
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

            List<Duplicate_Match__c> duplicateMatches = processCustomersWithIndexing(customers);
            
            Long executionTime = System.currentTimeMillis() - startTime;
            setMetric('findDuplicates_executionTime', executionTime);
            setMetric('findDuplicates_inputCount', customers.size());
            setMetric('findDuplicates_outputCount', duplicateMatches.size());
            
            logInfo('findDuplicates', 'Found ' + duplicateMatches.size() + ' potential duplicates in ' + executionTime + 'ms using indexing strategy');
            return duplicateMatches;
            
        } catch (Exception e) {
            Long executionTime = System.currentTimeMillis() - startTime;
            logError('findDuplicates', 'Duplicate detection failed after ' + executionTime + 'ms', e);
            throw e;
        }
    }

    /**
     * CORE OPTIMIZATION METHOD - FIXED VERSION
     * Uses indexing pattern to group customers by matching criteria
     * This reduces comparisons from O(n²) to O(n log n)
     */
    private List<Duplicate_Match__c> processCustomersWithIndexing(List<Customer__c> customers) {
        logDebug('processCustomersWithIndexing', 'Building indexes for ' + customers.size() + ' customers');
        
        CustomerIndexes indexes = buildCustomerIndexes(customers);
        
        List<Duplicate_Match__c> duplicateMatches = new List<Duplicate_Match__c>();
        Set<String> processedPairs = new Set<String>();
        
        Integer totalComparisons = 0;
        Integer matches = 0;
        
 
        MatchResult emailResult = processEmailIndex(indexes.emailIndex, processedPairs);
        duplicateMatches.addAll(emailResult.matches);
        totalComparisons += emailResult.comparisons;
        matches += emailResult.matchCount;
        
        MatchResult phoneResult = processPhoneIndex(indexes.phoneIndex, processedPairs);
        duplicateMatches.addAll(phoneResult.matches);
        totalComparisons += phoneResult.comparisons;
        matches += phoneResult.matchCount;
        
        setMetric('processCustomers_comparisons', totalComparisons);
        setMetric('processCustomers_matches', matches);
        setMetric('processCustomers_matchRate', totalComparisons > 0 ? (Decimal.valueOf(matches) / totalComparisons * 100).setScale(2) : 0);
        setMetric('processCustomers_optimizationRatio', calculateOptimizationRatio(customers.size(), totalComparisons));
        
        logInfo('processCustomersWithIndexing', String.format(
            'Optimization Results: {0} total comparisons vs {1} brute force comparisons. {2}x performance gain!',
            new List<Object>{totalComparisons, customers.size() * customers.size(), (customers.size() * customers.size()) / Math.max(totalComparisons, 1)}
        ));
        
        return duplicateMatches;
    }

    private CustomerIndexes buildCustomerIndexes(List<Customer__c> customers) {
        CustomerIndexes indexes = new CustomerIndexes();
        
        for (Customer__c customer : customers) {
            if (!isValidCustomerForProcessing(customer)) {
                continue;
            }
            if (!String.isBlank(customer.Email__c)) {
                String emailKey = normalizeEmail(customer.Email__c);
                if (!indexes.emailIndex.containsKey(emailKey)) {
                    indexes.emailIndex.put(emailKey, new List<Customer__c>());
                }
                indexes.emailIndex.get(emailKey).add(customer);
            }

            if (!String.isBlank(customer.Phone__c)) {
                String phoneKey = normalizePhone(customer.Phone__c);
                if (phoneKey.length() >= 6) { 
                    if (!indexes.phoneIndex.containsKey(phoneKey)) {
                        indexes.phoneIndex.put(phoneKey, new List<Customer__c>());
                    }
                    indexes.phoneIndex.get(phoneKey).add(customer);
                }
            }
        }
        
        logDebug('buildCustomerIndexes', String.format(
            'Built indexes: {0} email groups, {1} phone groups', 
            new List<Object>{indexes.emailIndex.size(), indexes.phoneIndex.size()}
        ));
        
        return indexes;
    }

    private MatchResult processEmailIndex(Map<String, List<Customer__c>> emailIndex, Set<String> processedPairs) {
        MatchResult result = new MatchResult();
        
        for (String email : emailIndex.keySet()) {
            List<Customer__c> customersWithSameEmail = emailIndex.get(email);
   
            if (customersWithSameEmail.size() > 1) {
                logDebug('processEmailIndex', 'Processing email group: ' + email + ' with ' + customersWithSameEmail.size() + ' customers');
                
                for (Integer i = 0; i < customersWithSameEmail.size(); i++) {
                    for (Integer j = i + 1; j < customersWithSameEmail.size(); j++) {
                        Customer__c customerA = customersWithSameEmail[i];
                        Customer__c customerB = customersWithSameEmail[j];
                        
                        String pairKey = createPairKey(customerA.Id, customerB.Id);
                        if (pairKey != null && processedPairs.contains(pairKey)) {
                            continue; 
                        }
                        

                        result.comparisons++;
                        
                        if (pairKey != null) {
                            processedPairs.add(pairKey);
                        }
                        
                        result.matches.add(new Duplicate_Match__c(
                            Customer_A__c = customerA.Id,
                            Customer_B__c = customerB.Id,
                            Match_Score__c = DuplicateMatchConstants.EXACT_EMAIL_MATCH_SCORE,
                            Match_Type__c = DuplicateMatchConstants.MATCH_TYPE_EMAIL,
                            Status__c = DuplicateMatchConstants.STATUS_PENDING
                        ));
                        result.matchCount++;
                        
                        logDebug('processEmailIndex', 'Email match found: ' + customerA.Id + ' <-> ' + customerB.Id);
                    }
                }
            }
        }
        
        logInfo('processEmailIndex', String.format(
            'Email index processing: {0} comparisons, {1} matches found',
            new List<Object>{result.comparisons, result.matchCount}
        ));
        
        return result;
    }

    private MatchResult processPhoneIndex(Map<String, List<Customer__c>> phoneIndex, Set<String> processedPairs) {
        MatchResult result = new MatchResult();
        
        for (String phone : phoneIndex.keySet()) {
            List<Customer__c> customersWithSamePhone = phoneIndex.get(phone);
            
            if (customersWithSamePhone.size() > 1) {
                logDebug('processPhoneIndex', 'Processing phone group: ' + phone + ' with ' + customersWithSamePhone.size() + ' customers');
                
                for (Integer i = 0; i < customersWithSamePhone.size(); i++) {
                    for (Integer j = i + 1; j < customersWithSamePhone.size(); j++) {
                        Customer__c customerA = customersWithSamePhone[i];
                        Customer__c customerB = customersWithSamePhone[j];
                        
                        String pairKey = createPairKey(customerA.Id, customerB.Id);
                        if (pairKey != null && processedPairs.contains(pairKey)) {
                            continue; 
                        }
                        
                        result.comparisons++;
                        
                        Integer matchScore = calculatePhoneBasedMatchScore(customerA, customerB);
                        if (matchScore > DuplicateMatchConstants.NO_MATCH_SCORE) {
                            if (pairKey != null) {
                                processedPairs.add(pairKey);
                            }
                            
                            result.matches.add(new Duplicate_Match__c(
                                Customer_A__c = customerA.Id,
                                Customer_B__c = customerB.Id,
                                Match_Score__c = matchScore,
                                Match_Type__c = getMatchType(matchScore),
                                Status__c = DuplicateMatchConstants.STATUS_PENDING
                            ));
                            result.matchCount++;
                            
                            logDebug('processPhoneIndex', String.format(
                                'Phone+Name match found: {0} <-> {1} (Score: {2})',
                                new List<Object>{customerA.Id, customerB.Id, matchScore}
                            ));
                        }
                    }
                }
            }
        }
        
        logInfo('processPhoneIndex', String.format(
            'Phone index processing: {0} comparisons, {1} matches found',
            new List<Object>{result.comparisons, result.matchCount}
        ));
        
        return result;
    }

    @TestVisible
    private Integer calculatePhoneBasedMatchScore(Customer__c customerA, Customer__c customerB) {
        try {

            if (hasFuzzyNameMatch(customerA, customerB)) {
                logDebug('calculatePhoneBasedMatchScore', 'Fuzzy name match found with same phone');
                return DuplicateMatchConstants.FUZZY_NAME_PHONE_MATCH_SCORE; // 70
            }
            
            if (hasSameLastName(customerA, customerB)) {
                logDebug('calculatePhoneBasedMatchScore', 'Same last name found with same phone');
                return DuplicateMatchConstants.SAME_LASTNAME_PHONE_MATCH_SCORE; // 50
            }
            
            return DuplicateMatchConstants.NO_MATCH_SCORE;
            
        } catch (Exception e) {
            logError('calculatePhoneBasedMatchScore', 'Error calculating phone-based match score', e);
            return DuplicateMatchConstants.NO_MATCH_SCORE;
        }
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
    private String normalizeEmail(String email) {
        if (String.isBlank(email)) {
            return '';
        }
        return email.trim().toLowerCase();
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
        
        if (customer.IsActive__c != true) {
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

    private Decimal calculateOptimizationRatio(Integer totalCustomers, Integer actualComparisons) {
        if (actualComparisons == 0) return 0;
        Integer bruteForceComparisons = totalCustomers * totalCustomers;
        return Decimal.valueOf(bruteForceComparisons) / Decimal.valueOf(actualComparisons);
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
    private class CustomerIndexes {
        public Map<String, List<Customer__c>> emailIndex;
        public Map<String, List<Customer__c>> phoneIndex;
        
        public CustomerIndexes() {
            this.emailIndex = new Map<String, List<Customer__c>>();
            this.phoneIndex = new Map<String, List<Customer__c>>();
        }
    }
    
    private class MatchResult {
        public List<Duplicate_Match__c> matches;
        public Integer comparisons;
        public Integer matchCount;
        
        public MatchResult() {
            this.matches = new List<Duplicate_Match__c>();
            this.comparisons = 0;
            this.matchCount = 0;
        }
    }
}