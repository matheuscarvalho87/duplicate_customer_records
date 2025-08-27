public with sharing class DuplicateMatchConstants {
     // Match Score Thresholds
    public static final Integer EXACT_EMAIL_MATCH_SCORE = 100;
    public static final Integer FUZZY_NAME_PHONE_MATCH_SCORE = 70;
    public static final Integer SAME_LASTNAME_PHONE_MATCH_SCORE = 50;
    
    // Match Types
    public static final String MATCH_TYPE_EMAIL = 'Exact Email Match';
    public static final String MATCH_TYPE_FUZZY_NAME_PHONE = 'Fuzzy Name + Same Phone';
    public static final String MATCH_TYPE_LASTNAME_PHONE = 'Same Last Name + Same Phone';
    
    // Status Values
    public static final String STATUS_PENDING = 'Pending Review';
    public static final String STATUS_MERGED = 'Merged';
    public static final String STATUS_IGNORED = 'Ignored';
    
    
    // Batch Processing
    public static final Integer BATCH_SIZE = 200;
    public static final Integer MAX_DUPLICATE_PAIRS = 10000;
    public static final Integer MAX_BULK_IDS = 200;
}