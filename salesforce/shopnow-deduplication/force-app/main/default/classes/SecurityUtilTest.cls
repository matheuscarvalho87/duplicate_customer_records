@IsTest
private class SecurityUtilTest {

    @IsTest
    static void testValidateAccess_softMode_noException() {
        Boolean original = SecurityUtil.ENFORCE_CUSTOM_PERMISSION;
        try {
            SecurityUtil.ENFORCE_CUSTOM_PERMISSION = false;
            SecurityUtil.validateAccess('ShopNow_Deduplication_Access');
            System.assert(true, 'Sem exceção em soft-mode');
        } finally {
            SecurityUtil.ENFORCE_CUSTOM_PERMISSION = original;
        }
    }

    @IsTest
    static void testValidateAccess_enforced_throws() {
        Boolean original = SecurityUtil.ENFORCE_CUSTOM_PERMISSION;
        try {
            SecurityUtil.ENFORCE_CUSTOM_PERMISSION = true;
            Boolean thrown = false;
            try {
                SecurityUtil.validateAccess('ShopNow_Deduplication_Access');
                System.assert(false, 'Deveria lançar exceção quando permissão não está atribuída/definida');
            } catch (Exception e) {
                thrown = true;
                System.assert(e.getMessage().contains('Custom Permission'),
                    'Mensagem deveria indicar ausência de Custom Permission');
            }
            System.assertEquals(true, thrown);
        } finally {
            SecurityUtil.ENFORCE_CUSTOM_PERMISSION = original;
        }
    }

    @IsTest
    static void testCheckCRUD_read_ok() {
        SecurityUtil.checkCRUD(Account.SObjectType, 'read');
        System.assert(true);
    }

    @IsTest
    static void testCheckFLS_read_ok() {
        SecurityUtil.checkFLS(Account.SObjectType, new Set<String>{ 'Name' }, 'read');
        System.assert(true);
    }

    @IsTest
    static void testCheckFLS_invalidField_throws() {
        Boolean thrown = false;
        try {
            SecurityUtil.checkFLS(Account.SObjectType, new Set<String>{ 'I_Do_Not_Exist__c' }, 'read');
            System.assert(false, 'Campo inexistente deveria lançar exceção');
        } catch (Exception e) {
            thrown = true;
            System.assert(e.getMessage().contains('Campo inexistente'),
                'Mensagem deveria indicar campo inexistente');
        }
        System.assertEquals(true, thrown);
    }

    @IsTest
    static void testSanitizeInput_and_Sort() {
        String dirty = 'scorE; DROP TABLE --';
        String clean = SecurityUtil.sanitizeInput(dirty, 10, false);
        System.assertNotEquals(dirty, clean, 'Deveria sanitizar caracteres proibidos');
        System.assert(clean.length() <= 10, 'Deveria respeitar truncamento');

        String allowed = SecurityUtil.sanitizeSort('score', new Set<String>{ 'score', 'createddate' }, 'createddate');
        System.assertEquals('score', allowed);

        String fallback = SecurityUtil.sanitizeSort('bad', new Set<String>{ 'score', 'createddate' }, 'createddate');
        System.assertEquals('createddate', fallback);
    }
}
