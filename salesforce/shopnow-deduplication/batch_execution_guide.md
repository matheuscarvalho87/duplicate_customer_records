    # DuplicateMatchingBatch Execution Guide

## How to Execute Batch Jobs in Salesforce Developer Console

### 1. Access Developer Console
1. Open your Salesforce org: `sf org open -o ShopNowDev`
2. Go to **Developer Console** (Setup → Developer Console)
3. Click **Debug** → **Open Execute Anonymous Apex**

---

## 2. Batch Execution Commands

### 🚀 **Basic Execution - All Active Customers**
```apex
// Execute batch for all active, non-deleted customers
DuplicateMatchingBatch batch = new DuplicateMatchingBatch();
Id jobId = Database.executeBatch(batch, 200);
System.debug('Batch Job ID: ' + jobId);
System.debug('Batch started successfully!');
```

### 🧪 **Test Execution - Small Batch Size**
```apex
// For testing - process only 5 records per batch
DuplicateMatchingBatch batch = new DuplicateMatchingBatch();
Id jobId = Database.executeBatch(batch, 5);
System.debug('Test Batch Job ID: ' + jobId);
System.debug('Test batch started with small batch size');
```

### 🔄 **Retry Execution - Specific Customers**
```apex
// Execute batch for specific customer IDs (retry scenario)
List<Id> specificIds = new List<Id>{
    'a015j00000ABCDEf',  // Replace with actual Customer IDs
    'a015j00000XYZABc'
};
DuplicateMatchingBatch retryBatch = new DuplicateMatchingBatch(specificIds, true);
Id jobId = Database.executeBatch(retryBatch, 50);
System.debug('Retry Batch Job ID: ' + jobId);
```

---

## 3. Monitoring Commands

### 📊 **Check Job Status**
```apex
// Replace 'YOUR_JOB_ID_HERE' with actual Job ID from execution
Id jobId = 'YOUR_JOB_ID_HERE';
AsyncApexJob job = [
    SELECT Id, Status, NumberOfErrors, JobItemsProcessed, 
           TotalJobItems, ExtendedStatus, CreatedDate, CompletedDate
    FROM AsyncApexJob 
    WHERE Id = :jobId
];

System.debug('=== JOB STATUS ===');
System.debug('Status: ' + job.Status);
System.debug('Progress: ' + job.JobItemsProcessed + '/' + job.TotalJobItems);
System.debug('Errors: ' + job.NumberOfErrors);
System.debug('Started: ' + job.CreatedDate);
System.debug('Completed: ' + job.CompletedDate);
System.debug('Extended Status: ' + job.ExtendedStatus);
```

### 📋 **View All Recent Batch Jobs**
```apex
// View last 10 DuplicateMatchingBatch executions
List<AsyncApexJob> jobs = [
    SELECT Id, Status, ApexClass.Name, CreatedDate, CompletedDate,
           JobItemsProcessed, TotalJobItems, NumberOfErrors
    FROM AsyncApexJob 
    WHERE ApexClass.Name = 'DuplicateMatchingBatch'
    ORDER BY CreatedDate DESC
    LIMIT 10
];

System.debug('=== RECENT BATCH JOBS ===');
for(AsyncApexJob job : jobs) {
    String status = job.Status;
    String progress = job.JobItemsProcessed + '/' + job.TotalJobItems;
    String errors = String.valueOf(job.NumberOfErrors);
    
    System.debug(job.Id + ' | ' + status + ' | Progress: ' + progress + 
                 ' | Errors: ' + errors + ' | Started: ' + job.CreatedDate);
}
```

### 🛑 **Abort Running Job**
```apex
// Abort a running batch job (use with caution)
Id jobId = 'YOUR_JOB_ID_HERE';
System.abortJob(jobId);
System.debug('Job ' + jobId + ' has been aborted');
```

---

## 4. Data Verification Commands

### 🔍 **Check Duplicate Matches Created**
```apex
// View recent duplicate matches created by batch
List<Duplicate_Match__c> recentMatches = [
    SELECT Id, Status__c, Match_Score__c, Match_Type__c, CreatedDate,
           Customer_A__r.FirstName__c, Customer_A__r.LastName__c, Customer_A__r.Email__c,
           Customer_B__r.FirstName__c, Customer_B__r.LastName__c, Customer_B__r.Email__c
    FROM Duplicate_Match__c
    WHERE CreatedDate = TODAY
    ORDER BY CreatedDate DESC
    LIMIT 10
];

System.debug('=== RECENT DUPLICATE MATCHES ===');
for(Duplicate_Match__c match : recentMatches) {
    System.debug('Score: ' + match.Match_Score__c + ' | Type: ' + match.Match_Type__c);
    System.debug('Customer A: ' + match.Customer_A__r.FirstName__c + ' ' + 
                 match.Customer_A__r.LastName__c + ' (' + match.Customer_A__r.Email__c + ')');
    System.debug('Customer B: ' + match.Customer_B__r.FirstName__c + ' ' + 
                 match.Customer_B__r.LastName__c + ' (' + match.Customer_B__r.Email__c + ')');
    System.debug('---');
}
```

### 📈 **Count Statistics**
```apex
// Get statistics about customers and matches
Integer totalCustomers = [SELECT COUNT() FROM Customer__c WHERE IsActive__c = true];
Integer activeCustomers = [SELECT COUNT() FROM Customer__c 
                          WHERE IsActive__c = true 
                          AND (IsDeleted__c = false OR IsDeleted__c = null)];
Integer pendingMatches = [SELECT COUNT() FROM Duplicate_Match__c 
                         WHERE Status__c = 'Pending Review'];
Integer totalMatches = [SELECT COUNT() FROM Duplicate_Match__c];

System.debug('=== STATISTICS ===');
System.debug('Total Customers: ' + totalCustomers);
System.debug('Active Customers (not soft deleted): ' + activeCustomers);
System.debug('Pending Duplicate Matches: ' + pendingMatches);
System.debug('Total Duplicate Matches: ' + totalMatches);
```

---

## 5. Troubleshooting Commands

### ⚠️ **Check for Errors in Logs**
```apex
// Check recent debug logs for batch errors
List<ApexLog> logs = [
    SELECT Id, Application, DurationMilliseconds, Location, 
           LogLength, LogUser.Name, Operation, Request, StartTime, Status
    FROM ApexLog
    WHERE Operation LIKE '%Batch%'
    ORDER BY StartTime DESC
    LIMIT 5
];

System.debug('=== RECENT BATCH LOGS ===');
for(ApexLog log : logs) {
    System.debug('Log ID: ' + log.Id + ' | Status: ' + log.Status + 
                 ' | Duration: ' + log.DurationMilliseconds + 'ms');
}
```

### 🧹 **Clean Up Test Data** (Use with caution!)
```apex
// Delete all duplicate matches created today (for testing only)
List<Duplicate_Match__c> todayMatches = [
    SELECT Id FROM Duplicate_Match__c 
    WHERE CreatedDate = TODAY
];

if (!todayMatches.isEmpty()) {
    delete todayMatches;
    System.debug('Deleted ' + todayMatches.size() + ' duplicate matches created today');
} else {
    System.debug('No duplicate matches found for today');
}
```

---

## 6. Scheduler Management Commands

### ⏰ **Activate Hourly Scheduler (Recommended)**
```apex
// Use the built-in method to schedule hourly execution
DuplicateMatchingScheduler.scheduleHourly();
System.debug('DuplicateMatchingScheduler activated - will run every hour');
```

### 🕐 **Schedule at Specific Times**
```apex
// Schedule to run daily at 2:00 AM
String cronExpression = '0 0 2 * * ?'; // Every day at 2:00 AM
String jobName = 'DuplicateMatching-Daily-2AM';
DuplicateMatchingScheduler scheduler = new DuplicateMatchingScheduler();
Id scheduledJobId = System.schedule(jobName, cronExpression, scheduler);
System.debug('Scheduled Job ID: ' + scheduledJobId);

// Schedule to run every 30 minutes
String cronEvery30Min = '0 */30 * * * ?'; // Every 30 minutes
String job30MinName = 'DuplicateMatching-Every30Min';
Id jobId30Min = System.schedule(job30MinName, cronEvery30Min, scheduler);
System.debug('30-minute schedule Job ID: ' + jobId30Min);

// Schedule to run on weekdays only at 9:00 AM
String cronWeekdays = '0 0 9 ? * MON-FRI'; // Monday to Friday at 9:00 AM
String weekdaysJobName = 'DuplicateMatching-Weekdays-9AM';
Id weekdaysJobId = System.schedule(weekdaysJobName, cronWeekdays, scheduler);
System.debug('Weekdays schedule Job ID: ' + weekdaysJobId);
```

### 📅 **View Active Scheduled Jobs**
```apex
// View all active DuplicateMatchingScheduler jobs
List<CronTrigger> scheduledJobs = [
    SELECT Id, CronJobDetail.Name, CronExpression, State, 
           StartTime, EndTime, NextFireTime, PreviousFireTime
    FROM CronTrigger
    WHERE CronJobDetail.Name LIKE '%DuplicateMatching%'
    ORDER BY CronJobDetail.Name
];

System.debug('=== ACTIVE SCHEDULED JOBS ===');
if (scheduledJobs.isEmpty()) {
    System.debug('No DuplicateMatching scheduler jobs found');
} else {
    for (CronTrigger job : scheduledJobs) {
        System.debug('Job: ' + job.CronJobDetail.Name);
        System.debug('  ID: ' + job.Id);
        System.debug('  State: ' + job.State);
        System.debug('  Cron: ' + job.CronExpression);
        System.debug('  Next Run: ' + job.NextFireTime);
        System.debug('  Last Run: ' + job.PreviousFireTime);
        System.debug('---');
    }
}
```

### 🛑 **Deactivate/Abort Scheduled Jobs**
```apex
// Abort all DuplicateMatching scheduled jobs
List<CronTrigger> jobsToAbort = [
    SELECT Id, CronJobDetail.Name
    FROM CronTrigger
    WHERE CronJobDetail.Name LIKE '%DuplicateMatching%'
    AND State = 'WAITING'
];

System.debug('=== ABORTING SCHEDULED JOBS ===');
for (CronTrigger job : jobsToAbort) {
    try {
        System.abortJob(job.Id);
        System.debug('Aborted: ' + job.CronJobDetail.Name + ' (ID: ' + job.Id + ')');
    } catch (Exception e) {
        System.debug('Failed to abort ' + job.CronJobDetail.Name + ': ' + e.getMessage());
    }
}

if (jobsToAbort.isEmpty()) {
    System.debug('No active DuplicateMatching scheduler jobs found to abort');
}
```

### 🛑 **Abort Specific Scheduled Job**
```apex
// Abort a specific scheduled job by ID
Id jobIdToAbort = 'YOUR_SCHEDULED_JOB_ID_HERE';
try {
    System.abortJob(jobIdToAbort);
    System.debug('Successfully aborted scheduled job: ' + jobIdToAbort);
} catch (Exception e) {
    System.debug('Failed to abort job ' + jobIdToAbort + ': ' + e.getMessage());
}
```

### 🔧 **Manual Scheduler Execution (Testing)**
```apex
// Manually execute the scheduler logic (for testing)
DuplicateMatchingScheduler scheduler = new DuplicateMatchingScheduler();
scheduler.execute(null); // Execute immediately
System.debug('Scheduler executed manually - check batch jobs for results');
```

### 📊 **Check Scheduler Execution History**
```apex
// View recent scheduler executions and their results
List<AsyncApexJob> schedulerJobs = [
    SELECT Id, Status, ApexClass.Name, CreatedDate, CompletedDate,
           JobItemsProcessed, TotalJobItems, NumberOfErrors,
           MethodName, ExtendedStatus
    FROM AsyncApexJob 
    WHERE ApexClass.Name = 'DuplicateMatchingBatch'
    AND CreatedBy.Email = :UserInfo.getUserEmail()
    ORDER BY CreatedDate DESC
    LIMIT 20
];

System.debug('=== SCHEDULER EXECUTION HISTORY ===');
for(AsyncApexJob job : schedulerJobs) {
    String duration = '';
    if (job.CompletedDate != null) {
        Long durationMs = job.CompletedDate.getTime() - job.CreatedDate.getTime();
        duration = ' | Duration: ' + (durationMs/1000) + 's';
    }
    
    System.debug(job.CreatedDate.format() + ' | ' + job.Status + 
                 ' | Progress: ' + job.JobItemsProcessed + '/' + job.TotalJobItems +
                 ' | Errors: ' + job.NumberOfErrors + duration);
}
```

### ⚡ **Quick Scheduler Commands**
```apex
// QUICK START - Activate hourly scheduler
DuplicateMatchingScheduler.scheduleHourly();

// QUICK STOP - Deactivate all schedulers  
List<CronTrigger> jobs = [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name LIKE '%DuplicateMatching%'];
for (CronTrigger job : jobs) { System.abortJob(job.Id); }

// QUICK STATUS - Check if scheduler is active
Integer activeJobs = [SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.Name LIKE '%DuplicateMatching%' AND State = 'WAITING'];
System.debug('Active DuplicateMatching schedulers: ' + activeJobs);
```

---

## 📝 **Usage Notes:**

1. **Always test with small batch sizes first** (5-10 records)
2. **Monitor job progress** using the status commands
3. **Check your email** for batch completion summaries
4. **Review duplicate matches** before processing them
5. **Use abort commands only in emergencies**
6. **Scheduler runs automatically** - use `DuplicateMatchingScheduler.scheduleHourly()` to activate
7. **Monitor scheduled executions** regularly to ensure they're working properly

## 🚨 **Important:**
- Replace `'YOUR_JOB_ID_HERE'` with actual Job IDs
- Replace `'YOUR_SCHEDULED_JOB_ID_HERE'` with actual Scheduled Job IDs
- Replace Customer IDs in retry scenarios with real IDs
- Always test in a sandbox environment first
- Monitor system resources during large batch executions
- **Only one hourly scheduler should be active** - check before creating new ones

## ⚙️ **Cron Expression Reference:**
- `'0 0 * * * ?'` - Every hour
- `'0 0 2 * * ?'` - Daily at 2:00 AM
- `'0 */30 * * * ?'` - Every 30 minutes  
- `'0 0 9 ? * MON-FRI'` - Weekdays at 9:00 AM
- `'0 0 0 ? * SUN'` - Every Sunday at midnight