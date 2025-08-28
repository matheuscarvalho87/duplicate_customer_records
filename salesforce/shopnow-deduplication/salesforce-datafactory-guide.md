# Salesforce DataFactory - Setup and Execution Guide

## Overview

This guide explains how to execute the `DataFactory` class in your Salesforce Developer Console. This class is part of the ShopNow Duplicate Management system and is designed to create test data for customer deduplication scenarios.

## Understanding the DataFactory Class

The `DataFactory` class serves as a **test data generator** for our duplicate management system. It creates:

1. **Customer records** with intentionally similar data to simulate duplicates
2. **Duplicate match records** that represent potential duplicates found by the system
3. **Cleanup utilities** to remove test data when needed

### Key Features:
- **Security-first approach**: Uses `SecurityUtil` to check CRUD/FLS permissions before operations
- **Realistic test scenarios**: Creates customers with similar names, emails, and phones to simulate real duplicates
- **Batch operations**: Efficiently handles multiple records at once
- **Cleanup functionality**: Easy removal of test data

## Prerequisites

Before executing this code, ensure you have:

1. ✅ **Salesforce Developer Org** access
2. ✅ **System Administrator** or equivalent permissions
3. ✅ **Custom objects deployed**:
   - `Customer__c`
   - `Duplicate_Match__c`
4. ✅ **Apex classes deployed**:
   - `SecurityUtil.cls`
   - `DataFactory.cls`

## How to Execute in Developer Console

### Step 1: Open Developer Console

1. Log into your Salesforce org: `https://orgfarm-d26e890132-dev-ed.develop.lightning.force.com/`
2. Click the **gear icon** (⚙️) in the top right
3. Select **Developer Console**

### Step 2: Open Execute Anonymous Window

1. In Developer Console, go to **Debug** menu
2. Select **Open Execute Anonymous Window**
3. Or use keyboard shortcut: `Ctrl + E` (Windows/Linux) or `Cmd + E` (Mac)

### Step 3: Execute Code Examples

#### Example 1: Create Test Customers Only
```apex
// Create 20 test customers with potential duplicates
List<Customer__c> customers = DataFactory.createCustomers(20);
System.debug('Created ' + customers.size() + ' customers');

// Display some sample data
for (Integer i = 0; i < Math.min(5, customers.size()); i++) {
    Customer__c c = customers[i];
    System.debug('Customer ' + (i+1) + ': ' + c.FirstName__c + ' ' + c.LastName__c + ' - ' + c.Email__c);
}
```

#### Example 2: Create Complete Test Dataset
```apex
// Create comprehensive test data (customers + duplicate matches)
DataFactory.Result result = DataFactory.createTestData(30);

System.debug('=== TEST DATA CREATION RESULTS ===');
System.debug('Customers created: ' + result.customersInserted);
System.debug('Duplicate matches created: ' + result.matchesInserted);
System.debug('Customer IDs: ' + result.customerIds.size() + ' records');
System.debug('Match IDs: ' + result.matchIds.size() + ' records');
```

#### Example 3: Create Duplicate Scenarios Only
```apex
// First ensure you have customers, then create duplicate scenarios
List<Duplicate_Match__c> matches = DataFactory.createDuplicateScenarios();
System.debug('Created ' + matches.size() + ' duplicate match scenarios');

// Display match details
for (Duplicate_Match__c match : matches) {
    System.debug('Match: Score=' + match.Match_Score__c + ', Status=' + match.Status__c);
}
```

#### Example 4: Cleanup Test Data
```apex
// Clean up all test data created by DataFactory
System.debug('Cleaning up test data...');
DataFactory.cleanupTestData();
System.debug('Cleanup completed');
```

#### Example 5: Full Cycle (Create, Inspect, Cleanup)
```apex
try {
    // Step 1: Create test data
    System.debug('=== CREATING TEST DATA ===');
    DataFactory.Result result = DataFactory.createTestData(15);
    System.debug('Created ' + result.customersInserted + ' customers and ' + result.matchesInserted + ' matches');
    
    // Step 2: Query and inspect the data
    System.debug('=== INSPECTING CREATED DATA ===');
    List<Customer__c> testCustomers = [
        SELECT Id, FirstName__c, LastName__c, Email__c, Phone__c 
        FROM Customer__c 
        WHERE LastName__c LIKE 'DF_%' 
        LIMIT 5
    ];
    
    for (Customer__c customer : testCustomers) {
        System.debug('Customer: ' + customer.FirstName__c + ' ' + customer.LastName__c + 
                    ' (' + customer.Email__c + ')');
    }
    
    // Step 3: Check duplicate matches
    List<Duplicate_Match__c> matches = [
        SELECT Id, Match_Score__c, Status__c, 
               Customer_A__r.FirstName__c, Customer_A__r.LastName__c,
               Customer_B__r.FirstName__c, Customer_B__r.LastName__c
        FROM Duplicate_Match__c 
        WHERE Status__c = 'Pending Review'
        LIMIT 3
    ];
    
    System.debug('=== DUPLICATE MATCHES ===');
    for (Duplicate_Match__c match : matches) {
        System.debug('Match (Score: ' + match.Match_Score__c + '): ' +
                    match.Customer_A__r.FirstName__c + ' ' + match.Customer_A__r.LastName__c + 
                    ' vs ' +
                    match.Customer_B__r.FirstName__c + ' ' + match.Customer_B__r.LastName__c);
    }
    
    // Optional: Uncomment to clean up immediately
    // System.debug('=== CLEANING UP ===');
    // DataFactory.cleanupTestData();
    // System.debug('Cleanup completed');
    
} catch (Exception e) {
    System.debug('Error: ' + e.getMessage());
    System.debug('Stack trace: ' + e.getStackTraceString());
}
```

### Step 4: Execute and Monitor

1. **Paste your chosen code** into the Execute Anonymous window
2. **Check "Open Log"** checkbox (important for seeing debug output)
3. **Click "Execute"** button
4. **Monitor the logs** in the bottom panel for results and any errors

## Understanding the Output

### Debug Log Messages
- `Created X customers` - Number of customer records inserted
- `Created X duplicate match scenarios` - Number of potential duplicates created
- Customer details with names, emails showing the duplicate patterns
- Match details showing scores and relationships between customers

### Data Patterns Created

The DataFactory creates realistic duplicate scenarios:

**Similar Names:**
- John ShopNow_12345_1 vs Jon ShopNow_12345_2 (fuzzy name match)
- Same last names with slight first name variations

**Phone Patterns:**
- Customers with same phone numbers (555-100X pattern)
- Different phone patterns for non-duplicates (555-200X)

**Email Patterns:**
- john.timestamp.1@example.com vs john.timestamp.2@example.com
- Systematic email generation to avoid conflicts