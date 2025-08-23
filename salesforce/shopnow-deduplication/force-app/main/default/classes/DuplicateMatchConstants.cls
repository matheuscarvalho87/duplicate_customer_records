public with sharing class DuplicateMatchConstants {
     // Match Score Thresholds
    public static final Integer EXACT_EMAIL_MATCH_SCORE = 100;
    public static final Integer FUZZY_NAME_PHONE_MATCH_SCORE = 70;
    public static final Integer SAME_LASTNAME_PHONE_MATCH_SCORE = 50;
    public static final Integer NO_MATCH_SCORE = 0;
    
    // Match Types
    public static final String MATCH_TYPE_EMAIL = 'Exact Email Match';
    public static final String MATCH_TYPE_FUZZY_NAME_PHONE = 'Fuzzy Name + Same Phone';
    public static final String MATCH_TYPE_LASTNAME_PHONE = 'Same Last Name + Same Phone';
    
    // Status Values
    public static final String STATUS_PENDING = 'Pending Review';
    public static final String STATUS_MERGED = 'Merged';
    public static final String STATUS_IGNORED = 'Ignored';
    
    // Fuzzy Matching Parameters
    public static final Decimal FUZZY_MATCH_THRESHOLD = 0.8; // 80% similarity
    public static final Integer LEVENSHTEIN_MAX_DISTANCE = 2;
    
    // Batch Processing
    public static final Integer BATCH_SIZE = 200;
    public static final Integer MAX_DUPLICATE_PAIRS = 10000;
    
    // Error Messages
    public static final String ERROR_INVALID_CUSTOMERS = 'Invalid or empty customer list provided';
    public static final String ERROR_DML_EXCEPTION = 'Error creating duplicate match records: ';
    public static final String ERROR_QUERY_EXCEPTION = 'Error querying existing matches: ';
}