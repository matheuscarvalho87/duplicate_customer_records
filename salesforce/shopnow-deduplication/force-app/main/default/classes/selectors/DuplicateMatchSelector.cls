public with sharing class DuplicateMatchSelector {
    private static final String BASE_FIELDS =
        'Id, Match_Score__c, Status__c, CreatedDate, ' +
        'Customer_A__c, Customer_A__r.FirstName__c, Customer_A__r.LastName__c, ' +
        'Customer_A__r.Email__c, Customer_A__r.Phone__c, ' +
        'Customer_B__c, Customer_B__r.FirstName__c, Customer_B__r.LastName__c, ' +
        'Customer_B__r.Email__c, Customer_B__r.Phone__c';

    private static final String RESOLVE_FIELDS =
        'Id, Status__c, Match_Score__c, Customer_A__c, Customer_B__c';

    public class PendingFilter {
        public Decimal  minScore;
        public Datetime startDate;
        public String   sortField;  
        public String   sortOrder;  
        public Integer  limitSize;
        public Integer  offsetSize;
        public String   statusValue; 
    }

    public static Integer countPending(Decimal minScore, Datetime startDate, String statusValue) {
        SecurityUtil.checkCRUD(Duplicate_Match__c.SObjectType, 'read');

        String soql =
            'SELECT COUNT() FROM Duplicate_Match__c ' +
            'WHERE Status__c = :statusValue ' +
            'AND Match_Score__c >= :minScore ' +
            'AND CreatedDate >= :startDate';

        return (Integer) Database.countQuery(soql);
    }

    public static List<Duplicate_Match__c> selectPending(PendingFilter f) {
        if (f == null) throw new CalloutException('Filter required');

        String order = (f.sortOrder == 'ASC') ? 'ASC' : 'DESC';

        Set<String> allowedOrderBy = new Set<String>{ 'Match_Score__c', 'CreatedDate' };
        String orderBy = (String.isBlank(f.sortField) || !allowedOrderBy.contains(f.sortField))
            ? 'CreatedDate' : f.sortField;

        Decimal  minScore   = f.minScore;
        Datetime startDate  = f.startDate;
        Integer  lim        = f.limitSize;
        Integer  off        = f.offsetSize;
        String   statusVal  = f.statusValue;

        String soql =
            'SELECT ' + BASE_FIELDS + ' ' +
            'FROM Duplicate_Match__c ' +
            'WHERE Status__c = :statusVal ' +
            'AND Match_Score__c >= :minScore ' +
            'AND CreatedDate >= :startDate ' +
            'ORDER BY ' + orderBy + ' ' + order + ' ' +
            'LIMIT :lim OFFSET :off';

        List<Duplicate_Match__c> rows = Database.query(soql);

        SecurityUtil.checkFLS(
            Duplicate_Match__c.SObjectType,
            new Set<String>{ 'Match_Score__c', 'Status__c', 'Customer_A__c', 'Customer_B__c' },
            'read'
        );
        SecurityUtil.checkCRUD(Customer__c.SObjectType, 'read');
        SecurityUtil.checkFLS(
            Customer__c.SObjectType,
            new Set<String>{ 'FirstName__c', 'LastName__c', 'Email__c', 'Phone__c' },
            'read'
        );

        SObjectAccessDecision dec = Security.stripInaccessible(AccessType.READABLE, rows);
        return (List<Duplicate_Match__c>) dec.getRecords();
    }

    public static List<Duplicate_Match__c> selectByIdsForResolve(List<Id> matchIds) {
        if (matchIds == null || matchIds.isEmpty()) {
           throw new CalloutException('Match IDs list cannot be null or empty');
        }

        if (matchIds.size() > DuplicateMatchConstants.MAX_BULK_IDS) {
            throw new CalloutException(String.format('Too many IDs for bulk operation. Maximum allowed: {0}', 
                    new List<String>{String.valueOf(DuplicateMatchConstants.MAX_BULK_IDS)}));
        }

        SecurityUtil.checkCRUD(Duplicate_Match__c.SObjectType, 'read');
        SecurityUtil.checkFLS(
            Duplicate_Match__c.SObjectType,
            new Set<String>{ 'Status__c', 'Match_Score__c', 'Customer_A__c', 'Customer_B__c' },
            'read'
        );

        String soql =
            'SELECT ' + RESOLVE_FIELDS + ' ' +
            'FROM Duplicate_Match__c ' +
            'WHERE Id IN :matchIds ' +
            'FOR UPDATE';

        List<Duplicate_Match__c> rows = Database.query(soql);

        SObjectAccessDecision dec = Security.stripInaccessible(AccessType.READABLE, rows);
        return (List<Duplicate_Match__c>) dec.getRecords();
    }
}