public with sharing class DuplicateResolutionService extends BaseService {
    protected override String getClassName() { return 'DuplicateResolutionService'; }
    
    public class CustomerDTO {
        public Id id;
        public String firstName;
        public String lastName;
        public String email;
        public String phone;
        public Boolean isDeleted;
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

    private final DuplicateMatchRepository repository = new DuplicateMatchRepository();

    public List<DuplicateItemDTO> getPendingDtos(
        Integer limitValue,
        Integer offsetValue,
        Integer minScoreValue,
        String sortParam,
        String orderParam
    ) {
        String sortField =
            (sortParam == 'score') ? 'Match_Score__c' :
            (sortParam == 'createddate') ? 'CreatedDate' :
            'Status__c';

        List<Duplicate_Match__c> records = repository.getPending(
            limitValue,
            offsetValue,
            minScoreValue,
            sortField,
            orderParam
        );

        List<DuplicateItemDTO> dtos = new List<DuplicateItemDTO>();
        for (Duplicate_Match__c matchRecord : records) {
            dtos.add(toDuplicateItemDTO(matchRecord));
        }
        return dtos;
    }

    public void resolveSingle(String matchId, String action) {
        Duplicate_Match__c matchRecord = repository.getById(matchId);

        if (matchRecord == null) {
            throw new CalloutException('Duplicate match not found: ' + matchId);
        }

        if (matchRecord.Status__c != DuplicateMatchConstants.STATUS_PENDING) {
            throw new CalloutException('Only pending matches can be resolved');
        }

        String normalizedAction = action != null ? action.toLowerCase() : '';
        
        if (normalizedAction == 'ignore') {
            matchRecord.Status__c = DuplicateMatchConstants.STATUS_IGNORED;
            matchRecord.Review_Date__c = System.now();
            matchRecord.Reviewed_By__c = UserInfo.getUserId();
            repository.updateMatch(matchRecord);
            return;
        }

        if (normalizedAction == 'merge') {
            if (matchRecord.Customer_B__c != null && matchRecord.Customer_A__c != null) {
                // Perform soft delete instead of hard delete
                repository.softDeleteCustomer(matchRecord.Customer_B__c, matchRecord.Customer_A__c);
            }
            
            matchRecord.Status__c = DuplicateMatchConstants.STATUS_MERGED;
            matchRecord.Review_Date__c = System.now();
            matchRecord.Reviewed_By__c = UserInfo.getUserId();
            repository.updateMatch(matchRecord);
            return;
        }

        throw new CalloutException('Invalid action. Use "merge" or "ignore".');
    }

    public Integer getTotalCount(Integer minScoreValue) {
        return repository.countPending(minScoreValue);
    }

    // -----------------------------
    // Mapping helpers
    // -----------------------------
    private DuplicateItemDTO toDuplicateItemDTO(Duplicate_Match__c matchRecord) {
        DuplicateItemDTO dto = new DuplicateItemDTO();
        dto.id = matchRecord.Id;
        dto.score = matchRecord.Match_Score__c;
        dto.status = matchRecord.Status__c;
        dto.createdAt = matchRecord.CreatedDate;

        dto.customerA = toCustomerDTO(matchRecord.Customer_A__c, matchRecord.Customer_A__r);
        dto.customerB = toCustomerDTO(matchRecord.Customer_B__c, matchRecord.Customer_B__r);
        return dto;
    }

    private CustomerDTO toCustomerDTO(Id customerId, SObject customerRelation) {
        CustomerDTO customerDto = new CustomerDTO();
        customerDto.id = customerId;
        
        if (customerRelation != null) {
            Customer__c customer = (Customer__c) customerRelation;
            customerDto.firstName = (String) customer.get('FirstName__c');
            customerDto.lastName = (String) customer.get('LastName__c');
            customerDto.email = (String) customer.get('Email__c');
            customerDto.phone = (String) customer.get('Phone__c');
            customerDto.isDeleted = (Boolean) customer.get('IsDeleted__c');
        }
        return customerDto;
    }
}