public with sharing class DataFactory {
    // Tag to identify test data created by this class
    public static final String TEST_TAG_PREFIX = 'DF_';

    public class Result {
        public Integer customersInserted;
        public Integer matchesInserted;
        public List<Id> customerIds;
        public List<Id> matchIds;
    }

    public static List<Customer__c> createCustomers(Integer count) {
        if (count == null || count <= 0) count = 10;

        SecurityUtil.checkCRUD(Customer__c.SObjectType, 'create');
        SecurityUtil.checkFLS(
            Customer__c.SObjectType,
            new Set<String>{'FirstName__c','LastName__c','Email__c','Phone__c'},
            'create'
        );

        List<Customer__c> upserts = new List<Customer__c>();

        String tsStr = String.valueOf(DateTime.now().getTime());
        String tsSuffix = (tsStr.length() > 5) ? tsStr.substring(tsStr.length() - 5) : tsStr;

        for (Integer i = 1; i <= count; i++) {
            Boolean makeDupGroup = (Math.mod(i, 5) == 0 || Math.mod(i, 5) == 1);

            String baseFirst = makeDupGroup ? 'John' : 'Jane';
            String baseLast  = TEST_TAG_PREFIX + 'ShopNow_' + tsSuffix + '_' + String.valueOf(Math.mod(i, 9999));
            String email     = (makeDupGroup ? 'john' : 'jane') + '.' + tsStr + '.' + String.valueOf(i) + '@example.com';
            String phone     = makeDupGroup ? '555-100' + String.valueOf(Math.mod(i, 10)) : '555-200' + String.valueOf(Math.mod(i, 10));

            if (makeDupGroup && Math.mod(i, 2) == 0) baseFirst = 'Jon';

            upserts.add(new Customer__c(
                FirstName__c = baseFirst,
                LastName__c  = baseLast,
                Email__c     = email,
                Phone__c     = phone
            ));
        }

        insert upserts;
        return upserts;
    }


    public static List<Duplicate_Match__c> createDuplicateScenarios() {
        SecurityUtil.checkCRUD(Duplicate_Match__c.SObjectType, 'create');
        SecurityUtil.checkFLS(
            Duplicate_Match__c.SObjectType,
            new Set<String>{'Customer_A__c','Customer_B__c','Match_Score__c','Status__c'},
            'create'
        );
        SecurityUtil.checkCRUD(Customer__c.SObjectType, 'read');
        SecurityUtil.checkFLS(
            Customer__c.SObjectType,
            new Set<String>{'FirstName__c','LastName__c','Email__c','Phone__c'},
            'read'
        );

        List<Customer__c> dfCustomers = [
            SELECT Id, FirstName__c, LastName__c, Email__c, Phone__c
            FROM Customer__c
            WHERE LastName__c LIKE :TEST_TAG_PREFIX + '%'
            ORDER BY CreatedDate DESC
            LIMIT 500
        ];

        if (dfCustomers.size() < 2) return new List<Duplicate_Match__c>();

        List<Duplicate_Match__c> matches = new List<Duplicate_Match__c>();
        for (Integer i = 0; i+1 < dfCustomers.size(); i += 2) {
            Integer slot = Math.mod(i, 6);
            Decimal score;
            if (slot == 0) score = 90;         
            else if (slot == 2) score = 60;  
            else score = 30;                

            matches.add(new Duplicate_Match__c(
                Customer_A__c = dfCustomers[i].Id,
                Customer_B__c = dfCustomers[i+1].Id,
                Match_Score__c = score,
                Status__c = 'Pending Review'
            ));
        }

        if (!matches.isEmpty()) {
            insert matches;
        }
        return matches;
    }

    public static Result createTestData(Integer customerCount) {
        Result r = new Result();
        List<Customer__c> cs = createCustomers(customerCount == null ? 40 : customerCount);
        List<Duplicate_Match__c> ms = createDuplicateScenarios();

        r.customersInserted = cs.size();
        r.matchesInserted = ms.size();
        r.customerIds = new List<Id>();
        r.matchIds = new List<Id>();
        for (Customer__c c : cs) r.customerIds.add(c.Id);
        for (Duplicate_Match__c m : ms) r.matchIds.add(m.Id);
        return r;
    }

    public static void cleanupTestData() {
        List<Duplicate_Match__c> matches = [
            SELECT Id
            FROM Duplicate_Match__c
            WHERE (Customer_A__r.LastName__c LIKE :TEST_TAG_PREFIX + '%'
                   OR Customer_B__r.LastName__c LIKE :TEST_TAG_PREFIX + '%')
        ];
        if (!matches.isEmpty()) delete matches;

        List<Customer__c> customers = [
            SELECT Id
            FROM Customer__c
            WHERE LastName__c LIKE :TEST_TAG_PREFIX + '%'
            LIMIT 10000
        ];
        if (!customers.isEmpty()) delete customers;
    }
}
