public with sharing class DuplicateMatchRepository extends BaseService {
    protected override String getClassName() { return 'DuplicateMatchRepository'; }

    public List<Duplicate_Match__c> getPending(
        Integer limitVal,
        Integer offsetVal,
        Integer minScoreVal,
        String sortField,
        String sortOrder
    ) {
        return DuplicateMatchSelector.selectPending(limitVal, offsetVal, minScoreVal, sortField, sortOrder);
    }

    public Duplicate_Match__c getById(Id matchId) {
        return DuplicateMatchSelector.selectById(matchId);
    }

    public void updateMatch(Duplicate_Match__c matchRec) {
        if (matchRec == null) return;
        update matchRec;
    }
}
