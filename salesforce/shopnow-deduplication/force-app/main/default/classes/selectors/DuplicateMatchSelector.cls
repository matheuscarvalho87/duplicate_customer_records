public with sharing class DuplicateMatchSelector {

    private static final String BASE_FIELDS =
        'Id, Match_Score__c, Status__c, CreatedDate, ' +
        'Customer_A__c, Customer_A__r.FirstName__c, Customer_A__r.LastName__c, ' +
        'Customer_A__r.Email__c, Customer_A__r.Phone__c, ' +
        'Customer_B__c, Customer_B__r.FirstName__c, Customer_B__r.LastName__c, ' +
        'Customer_B__r.Email__c, Customer_B__r.Phone__c';

    private static final String RESOLVE_FIELDS =
        'Id, Status__c, Match_Score__c, Customer_A__c, Customer_B__c';

    public static List<Duplicate_Match__c> selectPending(
        Integer limitVal,
        Integer offsetVal,
        Integer minScoreVal,
        String sortField,
        String sortOrder
    ) {
        String soql = 'SELECT ' + BASE_FIELDS +
                      ' FROM Duplicate_Match__c ' +
                      'WHERE Status__c = \'Pending Review\'';

        if (minScoreVal != null) {
            soql += ' AND Match_Score__c >= ' + String.valueOf(minScoreVal);
        }

        if (!String.isBlank(sortField) && !String.isBlank(sortOrder)) {
            soql += ' ORDER BY ' + sortField + ' ' + sortOrder;
        } else {
            soql += ' ORDER BY Match_Score__c DESC';
        }

        if (limitVal != null)  soql += ' LIMIT ' + String.valueOf(limitVal);
        if (offsetVal != null) soql += ' OFFSET ' + String.valueOf(offsetVal);

        return Database.query(soql);
    }

    public static Duplicate_Match__c selectById(Id matchId) {
        if (matchId == null) return null;

        List<Duplicate_Match__c> recs = Database.query(
            'SELECT ' + RESOLVE_FIELDS +
            ' FROM Duplicate_Match__c ' +
            'WHERE Id = :matchId ' +
            'LIMIT 1'
        );
        return recs.isEmpty() ? null : recs[0];
    }
}
