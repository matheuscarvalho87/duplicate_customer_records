public abstract with sharing class BaseService {
    protected String className;
    private Long startTime;
    protected Map<String, Object> performanceMetrics;

    protected BaseService() {
        this.className = getClassName();
        this.performanceMetrics = new Map<String, Object>();
        this.startTime = System.currentTimeMillis();
    }
    
    protected void validateAccess(Schema.SObjectType sObjType, String operation) {
        try {
            SecurityUtil.checkCRUD(sObjType, operation);
            logDebug('validateAccess', 'Access validated for ' + operation + ' on ' + sObjType);
        } catch (Exception e) {
            logError('validateAccess', 'Access denied: ' + e.getMessage(), e);
            throw new SecurityException('Access denied for ' + operation + ' on ' + sObjType.getDescribe().getName());
        }
    }
    
    protected void validateFieldAccess(Schema.SObjectType sObjType, Set<String> fields, String operation) {
        try {
            SecurityUtil.checkFLS(sObjType, fields, operation);
            logDebug('validateFieldAccess', 'Field access validated for ' + fields.size() + ' fields');
        } catch (Exception e) {
            logError('validateFieldAccess', 'Field access denied: ' + e.getMessage(), e);
            throw new SecurityException('Field access denied: ' + e.getMessage());
        }
    }
    
    protected Boolean hasPermission(String permissionName) {
        Boolean hasAccess = FeatureManagement.checkPermission(permissionName);
        logDebug('hasPermission', 'Permission check for ' + permissionName + ': ' + hasAccess);
        return hasAccess;
    }
    
    protected void requirePermission(String permissionName) {
        if (!hasPermission(permissionName)) {
            String errorMsg = 'Required permission missing: ' + permissionName;
            logError('requirePermission', errorMsg, null);
            throw new SecurityException(errorMsg);
        }
    }
    

    protected Database.SaveResult[] insertRecords(List<SObject> records, Boolean allOrNone) {
        if (records == null || records.isEmpty()) {
            logWarning('insertRecords', 'No records to insert');
            return new Database.SaveResult[]{};
        }
        
        Long operationStart = System.currentTimeMillis();
        
        try {
            if (!records.isEmpty()) {
                validateAccess(records[0].getSObjectType(), 'CREATE');
            }
            
            Database.SaveResult[] results = Database.insert(records, allOrNone);
            
            processResults(results, 'INSERT', records);
            
            Long operationTime = System.currentTimeMillis() - operationStart;
            performanceMetrics.put('lastInsertTime', operationTime);
            performanceMetrics.put('lastInsertCount', records.size());
            
            return results;
            
        } catch (Exception e) {
            logError('insertRecords', 'Insert operation failed: ' + e.getMessage(), e);
            throw e;
        }
    }
    
    protected Database.SaveResult[] updateRecords(List<SObject> records, Boolean allOrNone) {
        if (records == null || records.isEmpty()) {
            logWarning('updateRecords', 'No records to update');
            return new Database.SaveResult[]{};
        }
        
        Long operationStart = System.currentTimeMillis();
        
        try {
            if (!records.isEmpty()) {
                validateAccess(records[0].getSObjectType(), 'UPDATE');
            }
            
            Database.SaveResult[] results = Database.update(records, allOrNone);
            
            processResults(results, 'UPDATE', records);
            
            Long operationTime = System.currentTimeMillis() - operationStart;
            performanceMetrics.put('lastUpdateTime', operationTime);
            performanceMetrics.put('lastUpdateCount', records.size());
            
            return results;
            
        } catch (Exception e) {
            logError('updateRecords', 'Update operation failed: ' + e.getMessage(), e);
            throw e;
        }
    }
   
    protected Database.UpsertResult[] upsertRecords(List<SObject> records, 
                                                    Schema.SObjectField externalIdField, 
                                                    Boolean allOrNone) {
        if (records == null || records.isEmpty()) {
            logWarning('upsertRecords', 'No records to upsert');
            return new Database.UpsertResult[]{};
        }
        
        Long operationStart = System.currentTimeMillis();
        
        try {
            if (!records.isEmpty()) {
                validateAccess(records[0].getSObjectType(), 'CREATE');
                validateAccess(records[0].getSObjectType(), 'UPDATE');
            }
            
            Database.UpsertResult[] results;
            if (externalIdField != null) {
                results = Database.upsert(records, externalIdField, allOrNone);
            } else {
                results = Database.upsert(records, allOrNone);
            }
            
            processUpsertResults(results, records);
            
            Long operationTime = System.currentTimeMillis() - operationStart;
            performanceMetrics.put('lastUpsertTime', operationTime);
            performanceMetrics.put('lastUpsertCount', records.size());
            
            return results;
            
        } catch (Exception e) {
            logError('upsertRecords', 'Upsert operation failed: ' + e.getMessage(), e);
            throw e;
        }
    }
    
    protected Database.DeleteResult[] deleteRecords(List<SObject> records, Boolean allOrNone) {
        if (records == null || records.isEmpty()) {
            logWarning('deleteRecords', 'No records to delete');
            return new Database.DeleteResult[]{};
        }
        
        Long operationStart = System.currentTimeMillis();
        
        try {
            if (!records.isEmpty()) {
                validateAccess(records[0].getSObjectType(), 'DELETE');
            }
            
            Database.DeleteResult[] results = Database.delete(records, allOrNone);
            
            processDeleteResults(results, records);
            
            Long operationTime = System.currentTimeMillis() - operationStart;
            performanceMetrics.put('lastDeleteTime', operationTime);
            performanceMetrics.put('lastDeleteCount', records.size());
            
            return results;
            
        } catch (Exception e) {
            logError('deleteRecords', 'Delete operation failed: ' + e.getMessage(), e);
            throw e;
        }
    }
    
    protected List<SObject> executeQuery(String query) {
        Long queryStart = System.currentTimeMillis();
        
        try {
            if (!isQuerySafe(query)) {
                throw new SecurityException('Unsafe query detected');
            }
            
            List<SObject> results = Database.query(query);
            
            Long queryTime = System.currentTimeMillis() - queryStart;
            logDebug('executeQuery', 'Query executed in ' + queryTime + 'ms, returned ' + results.size() + ' records');
            
            return results;
            
        } catch (Exception e) {
            logError('executeQuery', 'Query failed: ' + e.getMessage(), e);
            throw e;
        }
    }
    
    protected Integer executeCountQuery(String query) {
        Long queryStart = System.currentTimeMillis();
        
        try {
            if (!isQuerySafe(query)) {
                throw new SecurityException('Unsafe query detected');
            }

            Integer count = Database.countQuery(query);

            Long queryTime = System.currentTimeMillis() - queryStart;
            logDebug('executeCountQuery', 'Count query executed in ' + queryTime + 'ms, count: ' + count);
            
            return count;
            
        } catch (Exception e) {
            logError('executeCountQuery', 'Count query failed: ' + e.getMessage(), e);
            throw e;
        }
    }
    
    private Boolean isQuerySafe(String query) {
        if (String.isBlank(query)) return false;
        
        String lowerQuery = query.toLowerCase();
        if (lowerQuery.contains('delete ') || 
            lowerQuery.contains('drop ') || 
            lowerQuery.contains('truncate ') ||
            lowerQuery.contains('alter ')) {
            return false;
        }
        return true;
    }
    
    private void processResults(Database.SaveResult[] results, String operation, List<SObject> records) {
        Integer successCount = 0;
        Integer errorCount = 0;
        List<String> errorMessages = new List<String>();
        
        for (Integer i = 0; i < results.size(); i++) {
            Database.SaveResult result = results[i];
            
            if (result.isSuccess()) {
                successCount++;
            } else {
                errorCount++;
                SObject record = records[i];
                
                for (Database.Error error : result.getErrors()) {
                    String errorMsg = String.format(
                        'Record {0} - Fields: {1}, Status: {2}, Message: {3}',
                        new List<String>{
                            String.valueOf(i),
                            String.join(error.getFields(), ','),
                            error.getStatusCode().name(),
                            error.getMessage()
                        }
                    );
                    errorMessages.add(errorMsg);
                }
            }
        }
        
        logBulkOperation(operation, results.size(), successCount, errorCount);
        
        if (!errorMessages.isEmpty()) {
            logError('processResults', String.join(errorMessages, '; '), null);
        }
    }

    private void processUpsertResults(Database.UpsertResult[] results, List<SObject> records) {
        Integer createdCount = 0;
        Integer updatedCount = 0;
        Integer errorCount = 0;
        List<String> errorMessages = new List<String>();
        
        for (Integer i = 0; i < results.size(); i++) {
            Database.UpsertResult result = results[i];
            
            if (result.isSuccess()) {
                if (result.isCreated()) {
                    createdCount++;
                } else {
                    updatedCount++;
                }
            } else {
                errorCount++;
                
                for (Database.Error error : result.getErrors()) {
                    errorMessages.add(error.getMessage());
                }
            }
        }
        
        String summary = String.format('Created: {0}, Updated: {1}, Errors: {2}',
            new List<String>{
                String.valueOf(createdCount),
                String.valueOf(updatedCount),
                String.valueOf(errorCount)
            }
        );
        logInfo('processUpsertResults', summary);
        
        if (!errorMessages.isEmpty()) {
            logError('processUpsertResults', String.join(errorMessages, '; '), null);
        }
    }
    
    private void processDeleteResults(Database.DeleteResult[] results, List<SObject> records) {
        Integer successCount = 0;
        Integer errorCount = 0;
        List<String> errorMessages = new List<String>();
        
        for (Database.DeleteResult result : results) {
            if (result.isSuccess()) {
                successCount++;
            } else {
                errorCount++;
                for (Database.Error error : result.getErrors()) {
                    errorMessages.add(error.getMessage());
                }
            }
        }
        
        logBulkOperation('DELETE', results.size(), successCount, errorCount);
        
        if (!errorMessages.isEmpty()) {
            logError('processDeleteResults', String.join(errorMessages, '; '), null);
        }
    }
    
    protected void logDebug(String methodName, String message) {
        Map<String, Object> context = new Map<String, Object>{
            'class' => className,
            'method' => methodName
        };
        AppLogger.debug(message, context);
    }
    
    protected void logInfo(String methodName, String message) {
        Map<String, Object> context = new Map<String, Object>{
            'class' => className,
            'method' => methodName
        };
        AppLogger.info(message, context);
    }
    
    protected void logWarning(String methodName, String message) {
        Map<String, Object> context = new Map<String, Object>{
            'class' => className,
            'method' => methodName
        };
        AppLogger.warn(message, context);
    }
    
    protected void logError(String methodName, String message, Exception e) {
        Map<String, Object> context = new Map<String, Object>{
            'class' => className,
            'method' => methodName
        };
        AppLogger.error(message, e, context);
    }
    
    protected void logBulkOperation(String operation, Integer total, Integer success, Integer errors) {
        Map<String, Object> context = new Map<String, Object>{
            'class' => className,
            'operation' => operation,
            'total' => total,
            'success' => success,
            'errors' => errors
        };
        String message = String.format('Bulk {0}: Total={1}, Success={2}, Errors={3}',
            new List<String>{operation, String.valueOf(total), String.valueOf(success), String.valueOf(errors)});
        
        if (errors > 0) {
            AppLogger.warn(message, context);
        } else {
            AppLogger.info(message, context);
        }
    }
    
    protected String sanitizeInput(String input) {
        return SecurityUtil.sanitizeInput(input, null, true);
    }
    
    protected String sanitizeInput(String input, Integer maxLength, Boolean allowSpaces) {
        return SecurityUtil.sanitizeInput(input, maxLength, allowSpaces);
    }

    protected void setMetric(String key, Object value) {
        if (String.isBlank(key)) return;
        performanceMetrics.put(key, value);
    }
    
    public Map<String, Object> getPerformanceMetrics() {
        Long totalTime = System.currentTimeMillis() - startTime;
        performanceMetrics.put('totalExecutionTime', totalTime);
        performanceMetrics.put('heapUsed', Limits.getHeapSize());
        performanceMetrics.put('queriesUsed', Limits.getQueries());
        performanceMetrics.put('dmlUsed', Limits.getDmlStatements());
        performanceMetrics.put('cpuUsed', Limits.getCpuTime());
        return performanceMetrics;
    }
    
    protected abstract String getClassName();
    
}