public with sharing class DuplicateMatchingBatch
    implements Database.Batchable<SObject>, Database.Stateful
{
    private Integer processedCustomers = 0;
    private Integer createdMatches = 0;
    private Integer skippedExisting = 0;
    private Integer errorCount = 0;
    private List<Id> failedCustomerIds = new List<Id>();

    private List<Id> specificCustomerIds;
    private Boolean isRetry;

    private String summaryEmailTo;

    public DuplicateMatchingBatch() {
        this(null, false);
    }
    public DuplicateMatchingBatch(List<Id> specificCustomerIds, Boolean isRetry) {
        this.specificCustomerIds = specificCustomerIds;
        this.isRetry = isRetry == true;
        this.summaryEmailTo = UserInfo.getUserEmail();
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        if (specificCustomerIds != null && !specificCustomerIds.isEmpty()) {
            return Database.getQueryLocator([
                SELECT Id, FirstName__c, LastName__c, Email__c, Phone__c, IsActive__c
                FROM Customer__c
                WHERE Id IN :specificCustomerIds AND IsActive__c = true
                ORDER BY Id
            ]);
        }
        return Database.getQueryLocator([
            SELECT Id, FirstName__c, LastName__c, Email__c, Phone__c, IsActive__c
            FROM Customer__c
            WHERE IsActive__c = true
            ORDER BY Id
        ]);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        try {
            List<Customer__c> customers = new List<Customer__c>();
            for (SObject so : scope) customers.add((Customer__c)so);
            processedCustomers += customers.size();

            List<Duplicate_Match__c> candidates = DuplicateMatchingService.findDuplicates(customers);
            if (candidates.isEmpty()) return;

            Set<Id> involved = new Set<Id>();
            for (Duplicate_Match__c d : candidates) {
                if (d.Customer_A__c != null) involved.add(d.Customer_A__c);
                if (d.Customer_B__c != null) involved.add(d.Customer_B__c);
            }

            Set<String> existingPairs = new Set<String>();
            for (Duplicate_Match__c ex : [
                SELECT Id, Customer_A__c, Customer_B__c
                FROM Duplicate_Match__c
                WHERE Customer_A__c IN :involved OR Customer_B__c IN :involved
            ]) {
                existingPairs.add(pairKey(ex.Customer_A__c, ex.Customer_B__c));
            }

            List<Duplicate_Match__c> toInsert = new List<Duplicate_Match__c>();
            for (Duplicate_Match__c d : candidates) {
                String k = pairKey(d.Customer_A__c, d.Customer_B__c);
                if (!existingPairs.contains(k)) {
                    toInsert.add(d);
                } else {
                    skippedExisting++;
                }
            }

            if (!toInsert.isEmpty()) {
                insert toInsert;
                createdMatches += toInsert.size();
            }
        } catch (Exception e) {
            errorCount++;
            // Marck failed IDs for retry
            for (SObject so : scope) failedCustomerIds.add(((Customer__c)so).Id);
            System.debug(LoggingLevel.ERROR, 'Batch execute error: ' + e.getMessage());
        }
    }

    public void finish(Database.BatchableContext bc) {
        List<Id> firstFailed = new List<Id>();
        Integer lim = Math.min(50, failedCustomerIds.size());
        for (Integer i = 0; i < lim; i++) {
            firstFailed.add(failedCustomerIds[i]);
        }

        try {
            Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
            msg.setToAddresses(new String[] { summaryEmailTo });
            msg.setSubject('[ShopNow] DuplicateMatchingBatch - Resumo ' + (isRetry ? '(Retry)' : ''));
            String body =
                'Batch Id: ' + bc.getJobId() + '\n' +
                'Processed customers: ' + processedCustomers + '\n' +
                'Created matches: ' + createdMatches + '\n' +
                'Skipped existing: ' + skippedExisting + '\n' +
                'Errors: ' + errorCount + '\n' +
                (firstFailed.isEmpty() ? '' : 'Failed IDs (first 50): ' + firstFailed.toString() + '\n') +
                'Finished at: ' + String.valueOf(Datetime.now());
            msg.setPlainTextBody(body);
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { msg });
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Failed to send summary email: ' + e.getMessage());
        }

        if (!failedCustomerIds.isEmpty() && !isRetry) {
            Set<Id> uniqueFailed = new Set<Id>(failedCustomerIds);
            Database.executeBatch(new DuplicateMatchingBatch(new List<Id>(uniqueFailed), true), 200);
        }
    }

    private static String pairKey(Id a, Id b) {
        if (a == null || b == null) return null;
        String sa = String.valueOf(a), sb = String.valueOf(b);
        return (sa < sb) ? (sa + '|' + sb) : (sb + '|' + sa);
    }
}
