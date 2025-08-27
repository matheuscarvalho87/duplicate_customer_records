public with sharing class DuplicateMatchRepository extends BaseService {
    protected override String getClassName() { return 'DuplicateMatchRepository'; }

    public List<Duplicate_Match__c> getPending(
        Integer limitValue,
        Integer offsetValue,
        Integer minScoreValue,
        String sortField,
        String sortOrder
    ) {
        return DuplicateMatchSelector.selectPending(limitValue, offsetValue, minScoreValue, sortField, sortOrder);
    }

    public Duplicate_Match__c getById(Id matchId) {
        return DuplicateMatchSelector.selectById(matchId);
    }

    public void updateMatch(Duplicate_Match__c matchRecord) {
        if (matchRecord == null) return;
        update matchRecord;
    }

    public Integer countPending(Integer minScoreValue) {
        return DuplicateMatchSelector.countPending(minScoreValue);
    }

    public void softDeleteCustomer(Id customerToDelete, Id customerToKeep) {
        if (customerToDelete == null || customerToKeep == null) {
            throw new IllegalArgumentException('Both customer IDs are required for merge operation');
        }

        Customer__c customerRecord = new Customer__c();
        customerRecord.Id = customerToDelete;
        customerRecord.IsDeleted__c = true;
        customerRecord.MergedInto__c = customerToKeep;
        customerRecord.DeletedDate__c = System.now();
        customerRecord.DeletedBy__c = UserInfo.getUserId();
        customerRecord.IsActive__c = false;

        update customerRecord;
    }
}