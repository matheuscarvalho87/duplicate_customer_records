public with sharing class DuplicateMatchingBatch implements Database.Batchable<SObject>, Database.Stateful {
    
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
        System.debug('DuplicateMatchingBatch: Starting batch processing');
        
        if (specificCustomerIds != null && !specificCustomerIds.isEmpty()) {

            System.debug('DuplicateMatchingBatch: Processing ' + specificCustomerIds.size() + ' specific customers');
            return Database.getQueryLocator([
                SELECT Id, FirstName__c, LastName__c, Email__c, Phone__c, 
                       IsActive__c, IsDeleted__c
                FROM Customer__c
                WHERE Id IN :specificCustomerIds 
                AND IsActive__c = true
                AND (IsDeleted__c = false OR IsDeleted__c = null)
                ORDER BY Id
            ]);
        }
        
        System.debug('DuplicateMatchingBatch: Processing all active customers');
        return Database.getQueryLocator([
            SELECT Id, FirstName__c, LastName__c, Email__c, Phone__c, 
                   IsActive__c, IsDeleted__c
            FROM Customer__c
            WHERE IsActive__c = true
            AND (IsDeleted__c = false OR IsDeleted__c = null)
            ORDER BY CreatedDate DESC
        ]);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        try {
            List<Customer__c> customers = new List<Customer__c>();
            for (SObject so : scope) {
                customers.add((Customer__c)so);
            }
            processedCustomers += customers.size();

            System.debug('DuplicateMatchingBatch: Processing batch of ' + customers.size() + ' customers');
            List<Duplicate_Match__c> potentialDuplicates = DuplicateMatchingService.findDuplicates(customers);
            
            if (potentialDuplicates.isEmpty()) {
                System.debug('DuplicateMatchingBatch: No duplicates found in this batch');
                return;
            }

            System.debug('DuplicateMatchingBatch: Found ' + potentialDuplicates.size() + ' potential duplicate pairs');

            Set<Id> involvedCustomerIds = new Set<Id>();
            for (Duplicate_Match__c duplicate : potentialDuplicates) {
                if (duplicate.Customer_A__c != null) {
                    involvedCustomerIds.add(duplicate.Customer_A__c);
                }
                if (duplicate.Customer_B__c != null) {
                    involvedCustomerIds.add(duplicate.Customer_B__c);
                }
            }


            Set<String> existingPairs = new Set<String>();
            List<Duplicate_Match__c> existingMatches = [
                SELECT Id, Customer_A__c, Customer_B__c
                FROM Duplicate_Match__c
                WHERE Customer_A__c IN :involvedCustomerIds 
                OR Customer_B__c IN :involvedCustomerIds
            ];

            for (Duplicate_Match__c existingMatch : existingMatches) {
                String pairKey = createPairKey(existingMatch.Customer_A__c, existingMatch.Customer_B__c);
                if (pairKey != null) {
                    existingPairs.add(pairKey);
                }
            }

            List<Duplicate_Match__c> newDuplicates = new List<Duplicate_Match__c>();
            for (Duplicate_Match__c duplicate : potentialDuplicates) {
                String pairKey = createPairKey(duplicate.Customer_A__c, duplicate.Customer_B__c);
                
                if (pairKey != null && !existingPairs.contains(pairKey)) {
                    newDuplicates.add(duplicate);
                } else {
                    skippedExisting++;
                }
            }

            if (!newDuplicates.isEmpty()) {
                insert newDuplicates;
                createdMatches += newDuplicates.size();
                System.debug('DuplicateMatchingBatch: Created ' + newDuplicates.size() + ' new duplicate match records');
            }

            if (skippedExisting > 0) {
                System.debug('DuplicateMatchingBatch: Skipped ' + skippedExisting + ' existing duplicate pairs');
            }

        } catch (DmlException dmlEx) {
            errorCount++;
            String errorMsg = 'DML error in batch execute: ' + dmlEx.getMessage();
            System.debug(LoggingLevel.ERROR, errorMsg);
            
            for (SObject so : scope) {
                failedCustomerIds.add(((Customer__c)so).Id);
            }
            
        } catch (Exception ex) {
            errorCount++;
            String errorMsg = 'Unexpected error in batch execute: ' + ex.getMessage();
            System.debug(LoggingLevel.ERROR, errorMsg);
            

            for (SObject so : scope) {
                failedCustomerIds.add(((Customer__c)so).Id);
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('DuplicateMatchingBatch: Finishing batch job');
        System.debug('DuplicateMatchingBatch: Final stats - Processed: ' + processedCustomers + 
                    ', Created: ' + createdMatches + ', Skipped: ' + skippedExisting + 
                    ', Errors: ' + errorCount);

        // Prepare failed IDs for email (limit to first 50 for readability)
        List<Id> firstFailed = new List<Id>();
        Integer limitValue = Math.min(50, failedCustomerIds.size());
        for (Integer i = 0; i < limitValue; i++) {
            firstFailed.add(failedCustomerIds[i]);
        }

        try {
            sendSummaryEmail(bc.getJobId(), firstFailed);
        } catch (Exception emailEx) {
            System.debug(LoggingLevel.ERROR, 'Failed to send summary email: ' + emailEx.getMessage());
        }

        // Schedule retry batch if there were failures and this isn't already a retry
        if (!failedCustomerIds.isEmpty() && !isRetry) {
            try {
                Set<Id> uniqueFailedIds = new Set<Id>(failedCustomerIds);
                List<Id> retryIds = new List<Id>(uniqueFailedIds);
                
                System.debug('DuplicateMatchingBatch: Scheduling retry batch for ' + retryIds.size() + ' failed customers');
                Database.executeBatch(new DuplicateMatchingBatch(retryIds, true), 200);
                
            } catch (Exception retryEx) {
                System.debug(LoggingLevel.ERROR, 'Failed to schedule retry batch: ' + retryEx.getMessage());
            }
        }
    }

    private void sendSummaryEmail(Id jobId, List<Id> firstFailed) {
        if (String.isBlank(summaryEmailTo)) {
            System.debug('DuplicateMatchingBatch: No email address configured for summary');
            return;
        }

        Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
        msg.setToAddresses(new String[] { summaryEmailTo });
        msg.setSubject('[ShopNow] Duplicate Matching Batch - Summary ' + (isRetry ? '(Retry)' : ''));
        
        String emailBody = 
            'Duplicate Matching Batch Execution Summary\n' +
            '==========================================\n\n' +
            'Batch Job ID: ' + jobId + '\n' +
            'Execution Type: ' + (isRetry ? 'Retry' : 'Regular') + '\n' +
            'Finished at: ' + String.valueOf(Datetime.now()) + '\n\n' +
            'RESULTS:\n' +
            '--------\n' +
            'Customers processed: ' + processedCustomers + '\n' +
            'New duplicate matches created: ' + createdMatches + '\n' +
            'Existing pairs skipped: ' + skippedExisting + '\n' +
            'Batches with errors: ' + errorCount + '\n\n';

        if (!firstFailed.isEmpty()) {
            emailBody += 'FAILED CUSTOMER IDs (first 50):\n';
            emailBody += '--------------------------------\n';
            emailBody += String.join(firstFailed, ', ') + '\n\n';
            
            if (failedCustomerIds.size() > 50) {
                emailBody += 'Additional ' + (failedCustomerIds.size() - 50) + ' failed customers not shown.\n\n';
            }
        }

        if (!isRetry && !failedCustomerIds.isEmpty()) {
            emailBody += 'A retry batch has been automatically scheduled for failed customers.\n';
        }

        msg.setPlainTextBody(emailBody);
        
        try {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { msg });
            System.debug('DuplicateMatchingBatch: Summary email sent successfully');
        } catch (Exception emailEx) {
            System.debug(LoggingLevel.ERROR, 'DuplicateMatchingBatch: Failed to send email: ' + emailEx.getMessage());
        }
    }

    private static String createPairKey(Id customerA, Id customerB) {
        if (customerA == null || customerB == null) {
            return null;
        }
        
        String idA = String.valueOf(customerA);
        String idB = String.valueOf(customerB);
        
        return idA < idB ? idA + '|' + idB : idB + '|' + idA;
    }
}