public with sharing class DuplicateMatchSelector {

    private static final String BASE_FIELDS =
        'Id, Match_Score__c, Status__c, CreatedDate, ' +
        'Customer_A__c, Customer_A__r.FirstName__c, Customer_A__r.LastName__c, ' +
        'Customer_A__r.Email__c, Customer_A__r.Phone__c, Customer_A__r.IsDeleted__c, ' +
        'Customer_B__c, Customer_B__r.FirstName__c, Customer_B__r.LastName__c, ' +
        'Customer_B__r.Email__c, Customer_B__r.Phone__c, Customer_B__r.IsDeleted__c';

    private static final String RESOLVE_FIELDS =
        'Id, Status__c, Match_Score__c, Customer_A__c, Customer_B__c';

    public static List<Duplicate_Match__c> selectPending(
        Integer limitValue,
        Integer offsetValue,
        Integer minScoreValue,
        String sortField,
        String sortOrder
    ) {
        String soql = 'SELECT ' + BASE_FIELDS +
                      ' FROM Duplicate_Match__c ' +
                      'WHERE Status__c = \'Pending Review\'' +
                      ' AND Customer_A__r.IsActive__c = true' +
                      ' AND Customer_B__r.IsActive__c = true' +
                      ' AND (Customer_A__r.IsDeleted__c = false OR Customer_A__r.IsDeleted__c = null)' +
                      ' AND (Customer_B__r.IsDeleted__c = false OR Customer_B__r.IsDeleted__c = null)';

        if (minScoreValue != null) {
            soql += ' AND Match_Score__c >= ' + String.valueOf(minScoreValue);
        }

        if (!String.isBlank(sortField) && !String.isBlank(sortOrder)) {
            soql += ' ORDER BY ' + sortField + ' ' + sortOrder;
        } else {
            soql += ' ORDER BY Match_Score__c DESC';
        }

        if (limitValue != null)  soql += ' LIMIT ' + String.valueOf(limitValue);
        if (offsetValue != null) soql += ' OFFSET ' + String.valueOf(offsetValue);

        return Database.query(soql);
    }

    public static Duplicate_Match__c selectById(Id matchId) {
        if (matchId == null) return null;

        List<Duplicate_Match__c> records = Database.query(
            'SELECT ' + RESOLVE_FIELDS +
            ' FROM Duplicate_Match__c ' +
            'WHERE Id = :matchId ' +
            'LIMIT 1'
        );
        return records.isEmpty() ? null : records[0];
    }

    public static Integer countPending(Integer minScoreValue) {
        String countSoql = 'SELECT COUNT() FROM Duplicate_Match__c ' +
                          'WHERE Status__c = \'Pending Review\'' +
                          ' AND Customer_A__r.IsActive__c = true' +
                          ' AND Customer_B__r.IsActive__c = true' +
                          ' AND (Customer_A__r.IsDeleted__c = false OR Customer_A__r.IsDeleted__c = null)' +
                          ' AND (Customer_B__r.IsDeleted__c = false OR Customer_B__r.IsDeleted__c = null)';

        if (minScoreValue != null) {
            countSoql += ' AND Match_Score__c >= ' + String.valueOf(minScoreValue);
        }

        return Database.countQuery(countSoql);
    }
}