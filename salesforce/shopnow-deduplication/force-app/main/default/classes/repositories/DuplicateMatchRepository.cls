public with sharing class DuplicateMatchRepository extends BaseService {
    protected override String getClassName() { return 'DuplicateMatchRepository'; }

    private static final String RESOLVE_FIELDS =
        'Id, Status__c, Match_Score__c, Customer_A__c, Customer_B__c';

    public Duplicate_Match__c getByIdForResolve(Id matchId) {
        if (matchId == null) throw new AuraHandledException('matchId is required');
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

    public void deleteCustomers(List<Customer__c> customers) {
        if (customers == null || customers.isEmpty()) return;

        validateAccess(Customer__c.SObjectType, 'DELETE');

        List<SObject> sobjs = new List<SObject>();
        for (Customer__c c : customers) sobjs.add(c);

        deleteRecords(sobjs, true);
    }
}
