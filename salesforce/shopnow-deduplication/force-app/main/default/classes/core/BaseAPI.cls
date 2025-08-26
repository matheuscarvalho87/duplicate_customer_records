public abstract with sharing class BaseAPI extends BaseService {
    protected override String getClassName() {
        return 'BaseAPI';
    }

    public static void setCorsHeaders() {
        if (RestContext.response == null) return;
        RestContext.response.addHeader('Access-Control-Allow-Origin', '*');
        RestContext.response.addHeader('Access-Control-Allow-Methods', 'GET, POST, PATCH, PUT, DELETE, OPTIONS');
        RestContext.response.addHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type, X-Requested-With');
        RestContext.response.addHeader('Access-Control-Max-Age', '86400');
        RestContext.response.addHeader('Content-Type', 'application/json; charset=UTF-8');
    }

    @TestVisible
    public static void handleOptions() {
        setCorsHeaders();
        RestContext.response.statusCode = 204; // No Content
    }

    protected void ok(Object body, Integer statusCode) {
        setCorsHeaders();
        RestContext.response.statusCode = (statusCode == null ? 200 : statusCode);
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(body));
    }
    protected void ok(Object body) { ok(body, 200); }
    protected void created(Object body) { ok(body, 201); }

    protected void noContent() {
        setCorsHeaders();
        RestContext.response.statusCode = 204;
    }

    protected void badRequest(String message, Map<String, Object> details) {
        error(400, 'bad_request', message, details);
    }
    protected void notFound(String message) {
        error(404, 'not_found', message, null);
    }
    protected void unauthorized(String message) {
        error(401, 'unauthorized', message, null);
    }

    protected void error(Integer status, String code, String message, Map<String, Object> details) {
        setCorsHeaders();
        RestContext.response.statusCode = status;
        Map<String, Object> err = new Map<String, Object>{
            'error' => new Map<String, Object>{
                'code' => code,
                'message' => message,
                'details' => details
            }
        };
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(err));
    }

    protected String q(String name, String dft) {
        String v = RestContext.request != null ? RestContext.request.params.get(name) : null;
        return (v == null || v.trim().length() == 0) ? dft : v;
    }

    protected Integer qi(String name, Integer dft, Integer minVal, Integer maxVal) {
        try {
            String raw = q(name, null);
            if (raw == null) return dft;
            Integer val = Integer.valueOf(raw);
            if (minVal != null && val < minVal) val = minVal;
            if (maxVal != null && val > maxVal) val = maxVal;
            return val;
        } catch (Exception e) {
            badRequest('Invalid integer for "' + name + '"', new Map<String,Object>{ 'param' => name });
            throw e;
        }
    }

    protected Decimal qd(String name, Decimal dft, Decimal minVal, Decimal maxVal) {
        try {
            String raw = q(name, null);
            if (raw == null) return dft;
            Decimal val = Decimal.valueOf(raw);
            if (minVal != null && val < minVal) val = minVal;
            if (maxVal != null && val > maxVal) val = maxVal;
            return val;
        } catch (Exception e) {
            badRequest('Invalid decimal for "' + name + '"', new Map<String,Object>{ 'param' => name });
            throw e;
        }
    }

    protected String qAllowed(String name, String dft, Set<String> allowed) {
        String v = q(name, dft);
        if (v == null) return dft;
        String low = v.toLowerCase();
        if (!allowed.contains(low)) {
            badRequest('Invalid value for "' + name + '"', new Map<String,Object>{ 'param' => name, 'allowed' => allowed });
            throw new AuraHandledException('Invalid parameter: ' + name);
        }
        return low;
    }

    protected Map<String, Object> pageEnvelope(Integer total, Integer pageOffset, Integer pageLimit, List<Object> items) {
        return new Map<String, Object>{
            'page' => new Map<String, Object>{
                'total'  => total,
                'offset' => pageOffset,
                'limit'  => pageLimit
            },
            'items' => items
        };
    }
}
