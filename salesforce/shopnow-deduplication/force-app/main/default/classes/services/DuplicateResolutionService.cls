public with sharing class DuplicateResolutionService extends BaseService {
    protected override String getClassName() { return 'DuplicateResolutionService'; }
    public class CustomerDTO {
        public Id id;
        public String firstName;
        public String lastName;
        public String email;
        public String phone;
    }
    public class DuplicateItemDTO {
        public Id id;
        public Decimal score;
        public String status;
        public Datetime createdAt;
        public CustomerDTO customerA;
        public CustomerDTO customerB;
    }
    public class ErrorResponseDTO {
        public String message;
        public String details;
    }

    private final DuplicateMatchRepository repo = new DuplicateMatchRepository();

    public List<DuplicateItemDTO> getPendingDtos(
        Integer limitVal,
        Integer offsetVal,
        Integer minScoreVal,
        String sortParam,
        String orderParam
    ) {
        String sortField =
            (sortParam == 'score') ? 'Match_Score__c' :
            (sortParam == 'createddate') ? 'CreatedDate' :
            'Status__c';

        List<Duplicate_Match__c> records = repo.getPending(
            limitVal,
            offsetVal,
            minScoreVal,
            sortField,
            orderParam
        );

        List<DuplicateItemDTO> dtos = new List<DuplicateItemDTO>();
        for (Duplicate_Match__c m : records) {
            dtos.add(toDuplicateItemDTO(m));
        }
        return dtos;
    }

    public void resolveSingle(String matchId, String action) {
        Duplicate_Match__c matchRec = repo.getById(matchId);

        if (matchRec == null) {
            throw new CalloutException('Duplicate match not found: ' + matchId);
        }

        String normalized = action != null ? action.toLowerCase() : '';
        if (normalized == 'ignore') {
            matchRec.Status__c = DuplicateMatchConstants.STATUS_IGNORED;
            repo.updateMatch(matchRec);
            return;
        }

        if (normalized == 'merge') {
            if (matchRec.Customer_B__c != null) {
                delete new Customer__c(Id = matchRec.Customer_B__c);
            }
            matchRec.Status__c = DuplicateMatchConstants.STATUS_MERGED;
            repo.updateMatch(matchRec);
            return;
        }

        throw new CalloutException('Invalid action. Use "merge" or "ignore".');
    }

    // -----------------------------
    // Mapping helpers
    // -----------------------------
    private DuplicateItemDTO toDuplicateItemDTO(Duplicate_Match__c m) {
        DuplicateItemDTO dto = new DuplicateItemDTO();
        dto.id        = m.Id;
        dto.score     = m.Match_Score__c;
        dto.status    = m.Status__c;
        dto.createdAt = m.CreatedDate;

        dto.customerA = toCustomerDTO(m.Customer_A__c, m.Customer_A__r);
        dto.customerB = toCustomerDTO(m.Customer_B__c, m.Customer_B__r);
        return dto;
    }

    private CustomerDTO toCustomerDTO(Id id, SObject rel) {
        CustomerDTO c = new CustomerDTO();
        c.id = id;
        if (rel != null) {
            Customer__c cust = (Customer__c) rel;
            c.firstName = (String) cust.get('FirstName__c');
            c.lastName  = (String) cust.get('LastName__c');
            c.email     = (String) cust.get('Email__c');
            c.phone     = (String) cust.get('Phone__c');
        }
        return c;
    }
}
