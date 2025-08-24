public with sharing class AppLogger {
    public enum Level { ERROR, WARN, INFO, DEBUG }

    @TestVisible public static Level MIN_LEVEL = Level.WARN;

    @TestVisible public static Boolean PERSIST_TO_SOBJECT = true;

    public class LogContext {
        public String location;
        public String requestUri;
        public String userId;
        public Map<String, Object> extra;
    }

    public static void error(String msg, Exception e, Map<String,Object> ctx) { log(Level.ERROR, msg, e, ctx); }
    public static void warn (String msg, Map<String,Object> ctx)              { log(Level.WARN,  msg, null, ctx); }
    public static void info (String msg, Map<String,Object> ctx)              { log(Level.INFO,  msg, null, ctx); }
    public static void debug(String msg, Map<String,Object> ctx)              { log(Level.DEBUG, msg, null, ctx); }

    public static void log(Level lvl, String message, Exception e, Map<String,Object> ctx) {
        if (!isEnabled(lvl)) return;

        String stack = (e == null) ? null : e.getStackTraceString();
        System.debug(toApex(lvl),
            '['+String.valueOf(lvl)+'] ' + message +
            ' ctx=' + JSON.serialize(ctx) +
            (stack != null ? ' stack=' + stack : '')
        );

        if (!PERSIST_TO_SOBJECT || (lvl != Level.ERROR && lvl != Level.WARN)) return;

        try {
            if (!Schema.getGlobalDescribe().containsKey('Duplicate_Log__c')) return;

            Schema.SObjectType t = Schema.getGlobalDescribe().get('Duplicate_Log__c');
            Schema.DescribeSObjectResult d = t.getDescribe();
            Map<String, Schema.SObjectField> f = d.fields.getMap();

            SObject sob = t.newSObject();
            putIfExists(sob, f, 'Level__c',   String.valueOf(lvl));
            putIfExists(sob, f, 'Message__c', message);
            putIfExists(sob, f, 'StackTrace__c', stack);
            putIfExists(sob, f, 'Context__c', JSON.serialize(ctx));
            insert sob;
        } catch (Exception ignore) {
            // Never fail the main process due to logging issues
        }
    }

    private static Boolean isEnabled(Level lvl) {
        return severity(lvl) <= severity(MIN_LEVEL);
    }
    private static Integer severity(Level lvl) {
        if (lvl == Level.ERROR) return 0;
        if (lvl == Level.WARN)  return 1;
        if (lvl == Level.INFO)  return 2;
        return 3;
    }
    private static LoggingLevel toApex(Level lvl) {
        if (lvl == Level.ERROR) return LoggingLevel.ERROR;
        if (lvl == Level.WARN)  return LoggingLevel.WARN;
        if (lvl == Level.INFO)  return LoggingLevel.INFO;
        return LoggingLevel.DEBUG;
    }
    private static void putIfExists(SObject sob, Map<String, Schema.SObjectField> fmap, String fieldApi, Object val) {
        if (fmap.containsKey(fieldApi)) sob.put(fieldApi, val);
    }
}
