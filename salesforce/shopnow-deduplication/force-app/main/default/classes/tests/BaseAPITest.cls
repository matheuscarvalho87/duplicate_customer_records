@IsTest
private class BaseAPITest {
    private class TestAPI extends BaseAPI {
        public void callOk(Object body) { ok(body); }
        public void callOk(Object body, Integer status) { ok(body, status); }
        public void callCreated(Object body) { created(body); }
        public void callNoContent() { noContent(); }
        public void callBadRequest(String message) { badRequest(message, null); }
        public void callNotFound(String message) { notFound(message); }
        public void callUnauthorized(String message) { unauthorized(message); }
        public void callError(Integer status, String code, String message, Map<String, Object> details) {
            error(status, code, message, details);
        }
        public String callValidateQuery(String name, String dft) { return validateQuery(name, dft); }
        public Integer callValidateQueryInteger(String name, Integer dft, Integer minVal, Integer maxVal) {
            return validateQueryInteger(name, dft, minVal, maxVal);
        }
        public String callQAllowed(String name, String dft, Set<String> allowed) {
            return qAllowed(name, dft, allowed);
        }
    }

    private static void setupRest(String method, String uri, String body) {
        RestRequest req = new RestRequest();
        req.httpMethod = method;
        req.requestURI = uri;
        if (body != null) req.requestBody = Blob.valueOf(body);
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;
    }

    private static Map<String, Object> parseJson(String s) {
        return (Map<String, Object>) System.JSON.deserializeUntyped(s);
    }

    @IsTest
    static void testValidateQuery_readsFromUri() {
        setupRest('GET', '/services/apexrest/x?limit=10&offset=3', null);
        TestAPI api = new TestAPI();

        Integer limitValue = api.callValidateQueryInteger('limit', 50, 1, 200);
        Integer offset = api.callValidateQueryInteger('offset', 0, 0, null);

        System.assertEquals(10, limitValue);
        System.assertEquals(3, offset);
    }

    @IsTest
    static void testValidateQueryInteger_appliesMinAndMax() {
        setupRest('GET', '/services/apexrest/x?limit=-5', null);
        TestAPI api = new TestAPI();
        System.assertEquals(1, api.callValidateQueryInteger('limit', 50, 1, 200));

        setupRest('GET', '/services/apexrest/x?limit=9999', null);
        System.assertEquals(200, api.callValidateQueryInteger('limit', 50, 1, 200));
    }

    @IsTest
    static void testValidateQueryInteger_invalidTriggers400() {
        setupRest('GET', '/services/apexrest/x?limit=notANumber', null);
        TestAPI api = new TestAPI();

        Boolean thrown = false;
        try {
            api.callValidateQueryInteger('limit', 50, 1, 200);
        } catch (Exception e) {
            thrown = true;
        }
        System.assertEquals(true, thrown, 'Should throw on invalid integer');
        System.assertEquals(400, RestContext.response.statusCode, 'Should set 400 Bad Request');
        Map<String, Object> err = parseJson(RestContext.response.responseBody.toString());
        System.assertEquals('bad_request', (String)((Map<String, Object>)err.get('error')).get('code'));
    }

    @IsTest
    static void testQAllowed_valid() {
        setupRest('GET', '/services/apexrest/x?sort=score', null);
        TestAPI api = new TestAPI();
        String out = api.callQAllowed('sort', 'score', new Set<String>{ 'score', 'createddate', 'status' });
        System.assertEquals('score', out);
    }

    @IsTest
    static void testQAllowed_invalidTriggers400() {
        setupRest('GET', '/services/apexrest/x?sort=unknown', null);
        TestAPI api = new TestAPI();

        Boolean thrown = false;
        try {
            api.callQAllowed('sort', 'score', new Set<String>{ 'score', 'createddate', 'status' });
        } catch (CalloutException e) {
            thrown = true;
        }
        System.assertEquals(true, thrown, 'Should throw CalloutException for invalid value');
        System.assertEquals(400, RestContext.response.statusCode);
        Map<String, Object> err = parseJson(RestContext.response.responseBody.toString());
        System.assertEquals('bad_request', (String)((Map<String, Object>)err.get('error')).get('code'));
    }

    @IsTest
    static void testOkAndCreatedSetHeadersAndBody() {
        setupRest('GET', '/services/apexrest/x', null);
        TestAPI api = new TestAPI();

        api.callOk(new Map<String, Object>{ 'foo' => 'bar' });
        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> body = parseJson(RestContext.response.responseBody.toString());
        System.assertEquals('bar', (String)body.get('foo'));

        setupRest('GET', '/services/apexrest/x', null);
        api.callCreated(new Map<String, Object>{ 'id' => '123' });
        System.assertEquals(201, RestContext.response.statusCode);
        Map<String, Object> createdBody = parseJson(RestContext.response.responseBody.toString());
        System.assertEquals('123', (String)createdBody.get('id'));
    }

    @IsTest
    static void testNoContentSets204() {
        setupRest('GET', '/services/apexrest/x', null);
        TestAPI api = new TestAPI();
        api.callNoContent();
        System.assertEquals(204, RestContext.response.statusCode);
    }

    @IsTest
    static void testErrorEnvelope() {
        setupRest('GET', '/services/apexrest/x', null);
        TestAPI api = new TestAPI();
        api.callError(500, 'server_error', 'Boom', new Map<String, Object>{ 'detail' => 'x' });

        System.assertEquals(500, RestContext.response.statusCode);
        Map<String, Object> err = parseJson(RestContext.response.responseBody.toString());
        Map<String, Object> e = (Map<String, Object>) err.get('error');
        System.assertEquals('server_error', (String) e.get('code'));
        System.assertEquals('Boom', (String) e.get('message'));
        System.assertEquals('x', (String) ((Map<String, Object>) e.get('details')).get('detail'));
    }
}
