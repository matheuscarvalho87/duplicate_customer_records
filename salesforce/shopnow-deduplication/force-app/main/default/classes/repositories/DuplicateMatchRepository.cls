public with sharing class DuplicateMatchRepository extends BaseService {
    protected override String getClassName() { return 'DuplicateMatchRepository'; }

    private static final String RESOLVE_FIELDS =
        'Id, Status__c, Match_Score__c, Customer_A__c, Customer_B__c';

    public Duplicate_Match__c getByIdForResolve(Id matchId) {
        if (matchId == null) throw new CalloutException('matchId is required');
        validateAccess(Duplicate_Match__c.SObjectType, 'READ');

        String soql =
            'SELECT ' + RESOLVE_FIELDS + ' ' +
            'FROM Duplicate_Match__c ' +
            'WHERE Id = :matchId ' +
            'LIMIT 1';

        List<Duplicate_Match__c> rows = (List<Duplicate_Match__c>) executeQuery(soql);
        if (rows.isEmpty()) {
            throw new QueryException('Duplicate_Match__c not found: ' + String.valueOf(matchId));
        }
        return rows[0];
    }

     public List<Duplicate_Match__c> getByIdsForBulkResolve(List<Id> matchIds, DuplicateResolutionService.BulkResolutionResult result) {
        if (matchIds == null || matchIds.isEmpty()) {
          throw new CalloutException('matchIds list cannot be null or empty');
        }

        validateAccess(Duplicate_Match__c.SObjectType, 'READ');
        validateFieldAccess(
            Duplicate_Match__c.SObjectType,
            new Set<String>{ 'Status__c', 'Match_Score__c', 'Customer_A__c', 'Customer_B__c' },
            'READ'
        );

        // Use DuplicateMatchSelector for optimized bulk queries
        List<Duplicate_Match__c> allMatches = DuplicateMatchSelector.selectByIdsForResolve(matchIds);
        Map<Id, Duplicate_Match__c> matchMap = new Map<Id, Duplicate_Match__c>(allMatches);

        List<Duplicate_Match__c> validMatches = new List<Duplicate_Match__c>();

        // Validate each requested ID and track errors
        for (Id requestedId : matchIds) {
            Duplicate_Match__c match = matchMap.get(requestedId);
            
            if (match == null) {
                DuplicateResolutionService.ErrorDetail error = new DuplicateResolutionService.ErrorDetail();
                error.id = String.valueOf(requestedId);
                error.message = 'Duplicate match not found';
                error.statusCode = 'NOT_FOUND';
                result.errors.add(error);
                result.failureCount++;
                continue;
            }

            if (match.Status__c != DuplicateMatchConstants.STATUS_PENDING) {
                DuplicateResolutionService.ErrorDetail error = new DuplicateResolutionService.ErrorDetail();
                error.id = String.valueOf(requestedId);
                error.message = 'Only pending duplicates can be resolved. Current status: ' + match.Status__c;
                error.statusCode = 'INVALID_STATUS';
                result.errors.add(error);
                result.failureCount++;
                continue;
            }

            validMatches.add(match);
        }

        return validMatches;
    }


    public void updateMatches(List<Duplicate_Match__c> matches) {
        if (matches == null || matches.isEmpty()) return;

        validateAccess(Duplicate_Match__c.SObjectType, 'UPDATE');
        validateFieldAccess(
            Duplicate_Match__c.SObjectType,
            new Set<String>{ 'Status__c' }, 'WRITE'
        );

        List<SObject> sobjs = new List<SObject>();
        for (Duplicate_Match__c m : matches) sobjs.add(m);

        updateRecords(sobjs, true);
    }

    public Database.SaveResult[] updateMatchesWithResults(List<Duplicate_Match__c> matches, Boolean allOrNone) {
        if (matches == null || matches.isEmpty()) {
            return new Database.SaveResult[]{};
        }

        validateAccess(Duplicate_Match__c.SObjectType, 'UPDATE');
        validateFieldAccess(
            Duplicate_Match__c.SObjectType,
            new Set<String>{ 'Status__c' }, 'WRITE'
        );

        List<SObject> sobjs = new List<SObject>();
        for (Duplicate_Match__c m : matches) sobjs.add(m);

        return updateRecords(sobjs, allOrNone);
    }

    public void deleteCustomers(List<Customer__c> customers) {
        if (customers == null || customers.isEmpty()) return;

        validateAccess(Customer__c.SObjectType, 'DELETE');

        List<SObject> sobjs = new List<SObject>();
        for (Customer__c c : customers) sobjs.add(c);

        deleteRecords(sobjs, true);
    }

    public Database.DeleteResult[] deleteCustomersWithResults(List<Customer__c> customers, Boolean allOrNone) {
        if (customers == null || customers.isEmpty()) {
            return new Database.DeleteResult[]{};
        }

        validateAccess(Customer__c.SObjectType, 'DELETE');

        List<SObject> sobjs = new List<SObject>();
        for (Customer__c c : customers) sobjs.add(c);

        return deleteRecords(sobjs, allOrNone);
    }
}
