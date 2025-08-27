public with sharing class DuplicateResolutionService extends BaseService {
    protected override String getClassName() { return 'DuplicateResolutionService'; }

    public class BulkResolutionResult {
        public Integer successCount = 0;
        public Integer failureCount = 0;
        public List<ErrorDetail> errors = new List<ErrorDetail>();

        public Boolean hasErrors() {
            return failureCount > 0;
        }
    }
    public class ErrorDetail {
        public String id;
        public String message;
        public String statusCode;
    }

    public BulkResolutionResult bulkResolve(List<String> matchIds, String action) {
    
        String normalizedAction = action.toLowerCase();
        if (normalizedAction != 'merge' && normalizedAction != 'ignore') {
           throw new CalloutException('Invalid action. Use "merge" or "ignore"');
        }

        Long startTime = System.currentTimeMillis();
        BulkResolutionResult result = new BulkResolutionResult();

        logInfo('bulkResolve', 
            String.format('Starting bulk {0} for {1} duplicates', 
                new List<String>{normalizedAction, String.valueOf(matchIds.size())}));

        try {
            List<Id> validIds = validateAndConvertIds(matchIds, result);
            if (validIds.isEmpty()) {
                logWarning('bulkResolve', 'No valid IDs to process');
                return result;
            }

            DuplicateMatchRepository repo = new DuplicateMatchRepository();

            List<Duplicate_Match__c> validMatches = repo.getByIdsForBulkResolve(validIds, result);
            if (validMatches.isEmpty()) {
                logWarning('bulkResolve', 'No valid records to process after validation');
                return result;
            }

            Savepoint sp = Database.setSavepoint();
            try {
                if (normalizedAction == 'ignore') {
                    processBulkIgnore(validMatches, result, repo);
                } else {
                    processBulkMerge(validMatches, result, repo);
                }

                setMetric('bulkResolve.executionTime', System.currentTimeMillis() - startTime);
                setMetric('bulkResolve.successCount', result.successCount);
                setMetric('bulkResolve.failureCount', result.failureCount);

                logInfo('bulkResolve', 
                    String.format('Completed bulk {0}: {1} successful, {2} failed', 
                        new List<String>{
                            normalizedAction, 
                            String.valueOf(result.successCount), 
                            String.valueOf(result.failureCount)
                        }));

            } catch (Exception e) {
                Database.rollback(sp);
                logError('bulkResolve', 'Transaction failed during bulk operation: ' + e.getMessage(), e);
                throw e;
            }

            return result;

        } catch (Exception e) {
            logError('bulkResolve', 'Bulk resolve failed: ' + e.getMessage(), e);
            throw new CalloutException('Bulk resolution failed: ' + e.getMessage());
        }
    }

    private List<Id> validateAndConvertIds(List<String> matchIds, BulkResolutionResult result) {
        List<Id> validIds = new List<Id>();
        
        for (String idStr : matchIds) {
            try {
                Id validId = Id.valueOf(idStr);
                validIds.add(validId);
            } catch (Exception e) {
                ErrorDetail error = new ErrorDetail();
                error.id = idStr;
                error.message = 'Invalid ID format';
                error.statusCode = 'INVALID_ID_FORMAT';
                result.errors.add(error);
                result.failureCount++;
            }
        }
        
        return validIds;
    }

    private void processBulkIgnore(List<Duplicate_Match__c> matches, BulkResolutionResult result, DuplicateMatchRepository repo) {
        try {
            for (Duplicate_Match__c match : matches) {
                match.Status__c = DuplicateMatchConstants.STATUS_IGNORED;
            }

            Database.SaveResult[] saveResults = repo.updateMatchesWithResults(matches, false);

            processUpdateResults(saveResults, matches, result, 'ignore');

        } catch (Exception e) {
            logError('processBulkIgnore', 'Failed to process bulk ignore: ' + e.getMessage(), e);
            throw e;
        }
    }

    private void processBulkMerge(List<Duplicate_Match__c> matches, BulkResolutionResult result, DuplicateMatchRepository repo) {
        try {
            List<Duplicate_Match__c> matchesWithCustomers = new List<Duplicate_Match__c>();
            List<Duplicate_Match__c> matchesWithoutCustomers = new List<Duplicate_Match__c>();
            List<Customer__c> customersToDelete = new List<Customer__c>();
            Map<Id, Duplicate_Match__c> customerToMatchMap = new Map<Id, Duplicate_Match__c>();

            for (Duplicate_Match__c match : matches) {
                if (match.Customer_B__c != null) {
                    matchesWithCustomers.add(match);
                    Customer__c customerToDelete = new Customer__c(Id = match.Customer_B__c);
                    customersToDelete.add(customerToDelete);
                    customerToMatchMap.put(match.Customer_B__c, match);
                } else {
                    matchesWithoutCustomers.add(match);
                }
            }

            if (!matchesWithoutCustomers.isEmpty()) {
                processMatchesWithoutCustomerDeletion(matchesWithoutCustomers, result, repo);
            }

            if (!matchesWithCustomers.isEmpty()) {
                processMatchesWithCustomerDeletion(matchesWithCustomers, customersToDelete, customerToMatchMap, result, repo);
            }

        } catch (Exception e) {
            logError('processBulkMerge', 'Failed to process bulk merge: ' + e.getMessage(), e);
            throw e;
        }
    }

    private void processMatchesWithoutCustomerDeletion(List<Duplicate_Match__c> matches, BulkResolutionResult result, DuplicateMatchRepository repo) {
        for (Duplicate_Match__c match : matches) {
            match.Status__c = DuplicateMatchConstants.STATUS_MERGED;
        }

        Database.SaveResult[] saveResults = repo.updateMatchesWithResults(matches, false);
        processUpdateResults(saveResults, matches, result, 'merge');
    }

    private void processMatchesWithCustomerDeletion(
        List<Duplicate_Match__c> matches, 
        List<Customer__c> customersToDelete,
        Map<Id, Duplicate_Match__c> customerToMatchMap,
        BulkResolutionResult result, 
        DuplicateMatchRepository repo
    ) {

        Database.DeleteResult[] deleteResults = repo.deleteCustomersWithResults(customersToDelete, false);
        
        Set<Id> failedCustomerIds = new Set<Id>();
        
        for (Integer i = 0; i < deleteResults.size(); i++) {
            Database.DeleteResult deleteResult = deleteResults[i];
            Customer__c customer = customersToDelete[i];
            
            if (!deleteResult.isSuccess()) {
                failedCustomerIds.add(customer.Id);
                Duplicate_Match__c relatedMatch = customerToMatchMap.get(customer.Id);
                
                ErrorDetail error = new ErrorDetail();
                error.id = String.valueOf(relatedMatch.Id);
                error.message = 'Failed to delete customer: ' + getFirstError(deleteResult.getErrors());
                error.statusCode = 'CUSTOMER_DELETE_FAILED';
                result.errors.add(error);
                result.failureCount++;
            }
        }

        List<Duplicate_Match__c> matchesToUpdate = new List<Duplicate_Match__c>();
        for (Duplicate_Match__c match : matches) {
            if (!failedCustomerIds.contains(match.Customer_B__c)) {
                match.Status__c = DuplicateMatchConstants.STATUS_MERGED;
                matchesToUpdate.add(match);
            }
        }

        if (!matchesToUpdate.isEmpty()) {
            Database.SaveResult[] updateResults = repo.updateMatchesWithResults(matchesToUpdate, false);
            processUpdateResults(updateResults, matchesToUpdate, result, 'merge');
        }
    }

    private void processUpdateResults(
        Database.SaveResult[] saveResults, 
        List<Duplicate_Match__c> matches, 
        BulkResolutionResult result, 
        String action
    ) {
        for (Integer i = 0; i < saveResults.size(); i++) {
            Database.SaveResult saveResult = saveResults[i];
            Duplicate_Match__c match = matches[i];
            
            if (saveResult.isSuccess()) {
                result.successCount++;
            } else {
                result.failureCount++;
                
                ErrorDetail error = new ErrorDetail();
                error.id = String.valueOf(match.Id);
                error.message = String.format('Failed to {0}: {1}', 
                    new List<String>{action, getFirstError(saveResult.getErrors())});
                error.statusCode = 'UPDATE_FAILED';
                result.errors.add(error);
            }
        }
    }

    private String getFirstError(List<Database.Error> errors) {
        return errors.isEmpty() ? 'Unknown error' : errors[0].getMessage();
    }
}