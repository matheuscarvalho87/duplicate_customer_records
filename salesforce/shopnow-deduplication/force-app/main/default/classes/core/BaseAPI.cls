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
        RestContext.response.statusCode = 204;
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

   protected String validateQuery(String paramName, String defaultValue) {
    RestRequest currentRequest = RestContext.request;

    String value = (currentRequest != null && currentRequest.params != null)
        ? currentRequest.params.get(paramName)
        : null;

    if (String.isBlank(value) && currentRequest != null) {
        String requestUri = currentRequest.requestURI;
        if (requestUri != null) {
            Integer questionMarkIndex = requestUri.indexOf('?');
            if (questionMarkIndex != -1 && questionMarkIndex < requestUri.length() - 1) {
                String queryString = requestUri.substring(questionMarkIndex + 1);
                for (String entry : queryString.split('&')) {
                    List<String> keyValue = entry.split('=', 2);
                    if (!keyValue.isEmpty()) {
                        String queryKey = EncodingUtil.urlDecode(keyValue[0], 'UTF-8');
                        if (queryKey == paramName) {
                            String queryValue = (keyValue.size() > 1)
                                ? EncodingUtil.urlDecode(keyValue[1], 'UTF-8')
                                : '';
                            value = queryValue;
                            break;
                        }
                    }
                }
            }
        }
    }
    return String.isBlank(value) ? defaultValue : value;
}

protected Integer validateQueryInteger(String paramName, Integer defaultValue, Integer minValue, Integer maxValue) {
    try {
        String rawValue = validateQuery(paramName, null);
        if (rawValue == null) return defaultValue;

        Integer parsedValue = Integer.valueOf(rawValue);
        if (minValue != null && parsedValue < minValue) parsedValue = minValue;
        if (maxValue != null && parsedValue > maxValue) parsedValue = maxValue;
        return parsedValue;
    } catch (Exception ex) {
        badRequest('Invalid integer for "' + paramName + '"', new Map<String, Object>{ 'param' => paramName });
        throw ex;
    }
}

protected String qAllowed(String paramName, String defaultValue, Set<String> allowedValues) {
    String candidate = validateQuery(paramName, defaultValue);
    if (candidate == null) return defaultValue;

    String normalizedCandidate = candidate.toLowerCase();
    if (!allowedValues.contains(normalizedCandidate)) {
        badRequest(
            'Invalid value for "' + paramName + '"',
            new Map<String, Object>{ 'param' => paramName, 'allowed' => allowedValues }
        );
        throw new CalloutException('Invalid parameter: ' + paramName);
    }
    return normalizedCandidate;
}
}
