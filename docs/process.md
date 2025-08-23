# Session for documentation process

## Understanding the problem
 * a program to get possible duplicate users, matching than and allow admin to merge them

## Challenges
* Undestanding the Salesforce data model
* Understanding the Salesforce CLI (sf)
* Understanding the Salesforce Apex language
* Understanding how modules work in Salesforce
* Understanding data relationships in Salesforce
* Understanding permissions in Salesforce
* understanding objects in Salesforce
* understanding tabs in Salesforce
* understanding how to create a custom object in Salesforce
* understanding APEX, class, triggers, anonymous scripts
* understanding tests in Salesforce
## Util commands for SF
  ### See all connected orgs
  sf org list

  ### Show details of the current org
  sf org display

  ### Open the current org in the browser
  sf org open

  ### Deploy code to the org
  sf project deploy start

  ### Retrieve code from the org
  sf project retrieve start

  ### Watch logs
  sf apex tail log --color

  ### Executar código Apex anônimo
  sf apex run --file myScript.apex -o <orgName>

  ### Create a new class
  sf apex class create -n DuplicateMatchConstants -d force-app/main/default/classes

  ## Queries to validate

  ### Get all customers
  SELECT Id, FirstName__c, LastName__c, Email__c, Phone__c
  FROM Customer__c
  ORDER BY CreatedDate DESC 

  ### Get all duplicate matches
  SELECT Id, Customer_A__c, Customer_B__c, Match_Score__c, Match_Type__c, Status__c
  FROM Duplicate_Match__c
  ORDER BY CreatedDate DESC
 
## Problems logs
* Salesforce account is not working

## Observations
* We can't run tests without deploying the code first, what makes it hard to test small pieces of code
and work with TDD, but we can crate a scratch org and do the development there, then deploy to the main org