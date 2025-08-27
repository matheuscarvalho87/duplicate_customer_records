public with sharing class SecurityUtil {

    public static Boolean ENFORCE_CUSTOM_PERMISSION = false;

    public static void validateAccess(String customPermissionApiName) {
        if (String.isBlank(customPermissionApiName)) return;
        if (!ENFORCE_CUSTOM_PERMISSION) return;
        Boolean ok = FeatureManagement.checkPermission(customPermissionApiName);
        if (!ok) {
            throw new SecurityException('Custom Permission ausente: ' + customPermissionApiName);
        }
    }

    public static void checkCRUD(Schema.SObjectType sType, String operation) {
        Schema.DescribeSObjectResult d = sType.getDescribe();
        Boolean allowed = false;
        String op = operation != null ? operation.toLowerCase() : 'read';
        if (op == 'read')   allowed = d.isAccessible();
        if (op == 'create') allowed = d.isCreateable();
        if (op == 'update') allowed = d.isUpdateable();
        if (op == 'delete') allowed = d.isDeletable();
        if (!allowed) {
            throw new SecurityException('Permissão de objeto insuficiente: ' + op + ' em ' + d.getName());
        }
    }

    public static void checkFLS(Schema.SObjectType sType, Set<String> fieldApiNames, String operation) {
        if (fieldApiNames == null || fieldApiNames.isEmpty()) return;
        Map<String, Schema.SObjectField> fmap = sType.getDescribe().fields.getMap();
        String sObjName = sType.getDescribe().getName();
        for (String f : fieldApiNames) {
            if (!fmap.containsKey(f)) {
                throw new SecurityException('Campo inexistente em ' + sObjName + ': ' + f);
            }
            Schema.DescribeFieldResult fd = fmap.get(f).getDescribe();
            Boolean allowed = false;
            String op = operation != null ? operation.toLowerCase() : 'read';
            if (op == 'read')   allowed = fd.isAccessible();
            if (op == 'create') allowed = fd.isCreateable();
            if (op == 'update') allowed = fd.isUpdateable();
            if (!allowed) {
                throw new SecurityException('FLS insuficiente: ' + op + ' em ' + sObjName + '.' + f);
            }
        }
    }

    public static String sanitizeInput(String s, Integer maxLen, Boolean allowSpaces) {
        if (s == null) return null;
        String pattern = allowSpaces ? '[^A-Za-z0-9_\\-\\.\\s]' : '[^A-Za-z0-9_\\-\\.]';
        String cleaned = s.replaceAll(pattern, '');
        if (maxLen != null && maxLen > 0 && cleaned.length() > maxLen) {
            cleaned = cleaned.substring(0, maxLen);
        }
        return cleaned;
    }

    public static String sanitizeSort(String requested, Set<String> allowed, String defaultValue) {
        if (String.isBlank(requested)) return defaultValue;
        String r = requested.toLowerCase();
        return (allowed != null && allowed.contains(r)) ? r : defaultValue;
    }
}
