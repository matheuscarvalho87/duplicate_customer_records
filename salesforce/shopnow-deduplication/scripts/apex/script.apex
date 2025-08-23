List<Customer__c> customers = new List<Customer__c>();

customers.add(new Customer__c(
    FirstName__c = 'John',
    LastName__c = 'Smith',
    Email__c = 'john.smith@example.com',
    Phone__c = '555-1234'
));

customers.add(new Customer__c(
    FirstName__c = 'Jon',
    LastName__c = 'Smith',
    Email__c = 'jon.smith@example.com',
    Phone__c = '555-1234'
));

customers.add(new Customer__c(
    FirstName__c = 'Jane',
    LastName__c = 'Doe',
    Email__c = 'jane.doe@example.com',
    Phone__c = '555-5678'
));

customers.add(new Customer__c(
    FirstName__c = 'Jane',
    LastName__c = 'D',
    Email__c = 'j.doe@example.com',
    Phone__c = '555-5678'
));

insert customers;

System.debug('Customers created: ' + customers);

List<Duplicate_Match__c> matches = new List<Duplicate_Match__c>();

matches.add(new Duplicate_Match__c(
    Customer_A__c = customers[0].Id,
    Customer_B__c = customers[1].Id,
    Match_Score__c = 70,
    Match_Type__c = 'Fuzzy Name + Same Phone',
    Status__c = 'Pending Review'
));

matches.add(new Duplicate_Match__c(
    Customer_A__c = customers[2].Id,
    Customer_B__c = customers[3].Id,
    Match_Score__c = 50,
    Match_Type__c = 'Same Last Name + Same Phone',
    Status__c = 'Pending Review'
));

insert matches;

System.debug('Matches created: ' + matches);