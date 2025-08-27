@RestResource(urlMapping='/duplicates/*')
global with sharing class DuplicateManagementAPI extends BaseAPI {

    global class ResolveRequest { public String action; }

    private static String subPath() {
        RestRequest req = RestContext.request;
        if (req == null || String.isBlank(req.requestURI)) return '';
        String uri = req.requestURI;
       
        String after = uri.substringAfter('/duplicates');
        Integer q = after.indexOf('?');
        if (q != -1) after = after.substring(0, q);   
        return after;
    }


    @HttpGet
    global static void getPending() {
        setCorsHeaders();
        DuplicateManagementAPI api = new DuplicateManagementAPI();

        String path = subPath();
        String low  = path != null ? path.toLowerCase() : '';
        if (String.isBlank(low) || (low != '/pending' && low != 'pending')) {
            api.notFound('Route not found. Expected GET /duplicates/pending');
            return;
        }

        try {
            Integer limitVal    = api.validateQueryInteger('limit', 50, 1, 200);
            Integer offsetVal   = api.validateQueryInteger('offset', 0, 0, null);
            Integer minScoreVal = api.validateQueryInteger('minScore', 0, 0, 100);

            String sortParam = api.qAllowed('sort',  'score', new Set<String>{ 'score', 'createddate', 'status' });
            String orderParam= api.qAllowed('order', 'desc',  new Set<String>{ 'asc', 'desc' });

            DuplicateResolutionService service = new DuplicateResolutionService();
            List<DuplicateResolutionService.DuplicateItemDTO> dtoItems =
                service.getPendingDtos(limitVal, offsetVal, minScoreVal, sortParam, orderParam);

            List<Object> objItems = new List<Object>();
            for (DuplicateResolutionService.DuplicateItemDTO dto : dtoItems) objItems.add(dto);

            api.ok(api.pageEnvelope(dtoItems.size(), offsetVal, limitVal, objItems));
        } catch (Exception e) {
            api.error(500, 'server_error', 'Failed to fetch pending duplicates: ' + e.getMessage(), null);
        }
    }

    @HttpPost
    global static void resolve() {
        setCorsHeaders();
        DuplicateManagementAPI api = new DuplicateManagementAPI();

        String path = subPath();
        String low  = path != null ? path.toLowerCase() : '';
        if (String.isBlank(low) || !low.endsWith('/resolve') || path.length() <= '/resolve'.length() + 1) {
            api.notFound('Route not found. Expected POST /duplicates/{id}/resolve');
            return;
        }


        String matchId = path.substringBetween('/', '/resolve');
        if (String.isBlank(matchId)) {
            api.badRequest('Missing duplicate match Id', null);
            return;
        }

        ResolveRequest body;
        try {
            body = (ResolveRequest) JSON.deserialize(RestContext.request.requestBody.toString(), ResolveRequest.class);
        } catch (Exception e) {
            api.badRequest('Invalid request body', null);
            return;
        }

        if (body == null || String.isBlank(body.action)) {
            api.badRequest('Missing action parameter', null);
            return;
        }

        try {
            DuplicateResolutionService service = new DuplicateResolutionService();
            service.resolveSingle(matchId, body.action);

            api.ok(new Map<String, Object>{
                'id' => matchId,
                'action' => body.action,
                'status' => 'success'
            });
        } catch (Exception e) {
            api.error(500, 'server_error', 'Failed to resolve duplicate: ' + e.getMessage(), null);
        }
    }

}
