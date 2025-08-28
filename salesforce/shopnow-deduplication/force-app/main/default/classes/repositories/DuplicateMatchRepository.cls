public with sharing class DuplicateMatchRepository extends BaseService {
    protected override String getClassName() { 
        return 'DuplicateMatchRepository'; 
    }

    private static final Set<String> DUPLICATE_MATCH_READ_FIELDS = new Set<String>{
        'Id', 'Match_Score__c', 'Status__c', 'CreatedDate', 'Match_Type__c',
        'Customer_A__c', 'Customer_B__c', 'Review_Date__c', 'Reviewed_By__c'
    };

    private static final Set<String> CUSTOMER_READ_FIELDS = new Set<String>{
        'FirstName__c', 'LastName__c', 'Email__c', 'Phone__c', 'IsDeleted__c'
    };

    private static final Set<String> DUPLICATE_MATCH_UPDATE_FIELDS = new Set<String>{
        'Status__c', 'Review_Date__c', 'Reviewed_By__c'
    };

    private static final Set<String> CUSTOMER_UPDATE_FIELDS = new Set<String>{
        'IsDeleted__c', 'MergedInto__c', 'DeletedDate__c', 'DeletedBy__c', 'IsActive__c'
    };

    public List<Duplicate_Match__c> getPending(
        Integer limitValue,
        Integer offsetValue,
        Integer minScoreValue,
        String sortField,
        String sortOrder
    ) {
        logDebug('getPending', 'Retrieving pending duplicates with limit=' + limitValue + ', offset=' + offsetValue + ', minScore=' + minScoreValue);
        
        try {
            validateAccess(Duplicate_Match__c.SObjectType, 'READ');
            validateFieldAccess(Duplicate_Match__c.SObjectType, DUPLICATE_MATCH_READ_FIELDS, 'READ');
            validateAccess(Customer__c.SObjectType, 'READ');
            validateFieldAccess(Customer__c.SObjectType, CUSTOMER_READ_FIELDS, 'READ');

            List<Duplicate_Match__c> results = DuplicateMatchSelector.selectPending(
                limitValue, offsetValue, minScoreValue, sortField, sortOrder
            );
            
            setMetric('getPending_resultCount', results.size());
            logDebug('getPending', 'Retrieved ' + results.size() + ' pending duplicate matches');
            
            return results;
            
        } catch (SecurityException se) {
            logError('getPending', 'Security validation failed', se);
            throw se;
        } catch (Exception e) {
            logError('getPending', 'Failed to retrieve pending duplicates', e);
            throw e;
        }
    }

    public Duplicate_Match__c getById(Id matchId) {
        logDebug('getById', 'Retrieving duplicate match by ID: ' + matchId);
        
        try {
            validateAccess(Duplicate_Match__c.SObjectType, 'READ');
            validateFieldAccess(Duplicate_Match__c.SObjectType, DUPLICATE_MATCH_READ_FIELDS, 'READ');
            validateAccess(Customer__c.SObjectType, 'READ');
            validateFieldAccess(Customer__c.SObjectType, CUSTOMER_READ_FIELDS, 'READ');
            
            if (matchId == null) {
                logWarning('getById', 'Match ID is null');
                return null;
            }

            Duplicate_Match__c result = DuplicateMatchSelector.selectById(matchId);
            
            if (result != null) {
                logDebug('getById', 'Successfully retrieved duplicate match: ' + matchId);
            } else {
                logWarning('getById', 'Duplicate match not found: ' + matchId);
            }
            
            return result;
            
        } catch (SecurityException se) {
            logError('getById', 'Security validation failed for matchId: ' + matchId, se);
            throw se;
        } catch (Exception e) {
            logError('getById', 'Failed to retrieve duplicate match: ' + matchId, e);
            throw e;
        }
    }

     public void updateMatch(Duplicate_Match__c matchRecord) {
        
        
        try {
            if (matchRecord == null) {
                logWarning('updateMatch', 'Match record is null, skipping update');
                return;
            }

            if (matchRecord.Id == null) {
                String errorMsg = 'Cannot update record without ID';
                logError('updateMatch', errorMsg, null);
                throw new IllegalArgumentException(errorMsg);
            }
            logDebug('updateMatch', 'Updating duplicate match: ' + matchRecord.Id );
            // Security validation
            validateAccess(Duplicate_Match__c.SObjectType, 'UPDATE');
            validateFieldAccess(Duplicate_Match__c.SObjectType, DUPLICATE_MATCH_UPDATE_FIELDS, 'UPDATE');

            List<SObject> recordsToUpdate = new List<SObject>{matchRecord};
            updateRecords(recordsToUpdate, true);
            
            logInfo('updateMatch', 'Successfully updated duplicate match: ' + matchRecord.Id);
            
        } catch (SecurityException se) {
            logError('updateMatch', 'Security validation failed for match update', se);
            throw se;
        } catch (Exception e) {
            logError('updateMatch', 'Failed to update duplicate match', e);
            throw e;
        }
    }

    public Integer countPending(Integer minScoreValue) {
        logDebug('countPending', 'Counting pending duplicates with minScore: ' + minScoreValue);
        
        try {
            validateAccess(Duplicate_Match__c.SObjectType, 'READ');
            
            Integer count = DuplicateMatchSelector.countPending(minScoreValue);
            
            setMetric('countPending_result', count);
            logDebug('countPending', 'Found ' + count + ' pending duplicates');
            
            return count;
            
        } catch (SecurityException se) {
            logError('countPending', 'Security validation failed', se);
            throw se;
        } catch (Exception e) {
            logError('countPending', 'Failed to count pending duplicates', e);
            throw e;
        }
    }

    public void softDeleteCustomer(Id customerToDelete, Id customerToKeep) {
        logInfo('softDeleteCustomer', 'Performing soft delete: customerToDelete=' + customerToDelete + ', customerToKeep=' + customerToKeep);
        
        try {
            if (customerToDelete == null || customerToKeep == null) {
                String errorMsg = 'Both customer IDs are required for merge operation';
                logError('softDeleteCustomer', errorMsg, null);
                throw new IllegalArgumentException(errorMsg);
            }

            if (customerToDelete == customerToKeep) {
                String errorMsg = 'Cannot merge customer with itself';
                logError('softDeleteCustomer', errorMsg, null);
                throw new IllegalArgumentException(errorMsg);
            }

            validateAccess(Customer__c.SObjectType, 'UPDATE');
            validateFieldAccess(Customer__c.SObjectType, CUSTOMER_UPDATE_FIELDS, 'UPDATE');

            Customer__c customerRecord = new Customer__c();
            customerRecord.Id = customerToDelete;
            customerRecord.IsDeleted__c = true;
            customerRecord.MergedInto__c = customerToKeep;
            customerRecord.DeletedDate__c = System.now();
            customerRecord.DeletedBy__c = UserInfo.getUserId();
            customerRecord.IsActive__c = false;

            List<SObject> recordsToUpdate = new List<SObject>{customerRecord};
            updateRecords(recordsToUpdate, true);
            
            logInfo('softDeleteCustomer', 'Successfully performed soft delete and merge operation');
            
        } catch (SecurityException se) {
            logError('softDeleteCustomer', 'Security validation failed for soft delete operation', se);
            throw se;
        } catch (Exception e) {
            logError('softDeleteCustomer', 'Failed to perform soft delete operation', e);
            throw e;
        }
    }
}