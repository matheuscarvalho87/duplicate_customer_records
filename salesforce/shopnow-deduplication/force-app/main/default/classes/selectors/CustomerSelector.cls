public with sharing class CustomerSelector {
    
    private static final String MATCHING_FIELDS = 
        'Id, FirstName__c, LastName__c, Email__c, Phone__c, IsActive__c, IsDeleted__c';
    
    public static List<Customer__c> selectActiveForMatching() {
        return Database.query(
            'SELECT ' + MATCHING_FIELDS + 
            ' FROM Customer__c ' +
            ' WHERE IsActive__c = true ' +
            ' AND (IsDeleted__c = false OR IsDeleted__c = null)' +
            ' ORDER BY CreatedDate DESC'
        );
    }
    
    public static List<Customer__c> selectByIdsForMatching(Set<Id> customerIds) {
        if (customerIds == null || customerIds.isEmpty()) {
            return new List<Customer__c>();
        }
        
        return Database.query(
            'SELECT ' + MATCHING_FIELDS + 
            ' FROM Customer__c ' +
            ' WHERE Id IN :customerIds ' +
            ' AND IsActive__c = true ' +
            ' AND (IsDeleted__c = false OR IsDeleted__c = null)'
        );
    }
    
    public static List<Customer__c> selectRecentForMatching(DateTime sinceDate) {
        if (sinceDate == null) {
            return selectActiveForMatching();
        }
        
        return Database.query(
            'SELECT ' + MATCHING_FIELDS + 
            ' FROM Customer__c ' +
            ' WHERE IsActive__c = true ' +
            ' AND (IsDeleted__c = false OR IsDeleted__c = null)' +
            ' AND (CreatedDate >= :sinceDate OR LastModifiedDate >= :sinceDate)' +
            ' ORDER BY LastModifiedDate DESC'
        );
    }

    public static Integer countActiveCustomers() {
        return Database.countQuery(
            'SELECT COUNT() FROM Customer__c ' +
            ' WHERE IsActive__c = true ' +
            ' AND (IsDeleted__c = false OR IsDeleted__c = null)'
        );
    }
}