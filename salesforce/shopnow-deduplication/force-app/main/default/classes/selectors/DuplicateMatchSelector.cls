public with sharing class DuplicateMatchSelector {
    private static final String BASE_FIELDS =
        'Id, Match_Score__c, Status__c, CreatedDate, ' +
        'Customer_A__c, Customer_A__r.FirstName__c, Customer_A__r.LastName__c, ' +
        'Customer_A__r.Email__c, Customer_A__r.Phone__c, ' +
        'Customer_B__c, Customer_B__r.FirstName__c, Customer_B__r.LastName__c, ' +
        'Customer_B__r.Email__c, Customer_B__r.Phone__c';


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
        if (f == null) throw new AuraHandledException('Filter required');

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
}
