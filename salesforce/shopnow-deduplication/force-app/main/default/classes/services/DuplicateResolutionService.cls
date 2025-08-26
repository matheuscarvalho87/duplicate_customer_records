public with sharing class DuplicateResolutionService extends BaseService {
    protected override String getClassName() { return 'DuplicateResolutionService'; }

    public void resolve(Id matchId, String actionRaw) {
        if (matchId == null) throw new AuraHandledException('matchId is required');
        if (String.isBlank(actionRaw)) throw new AuraHandledException('action is required');

        String action = actionRaw.toLowerCase();
        if (action != 'ignore' && action != 'merge') {
            throw new AuraHandledException('Invalid action. Use "merge" or "ignore".');
        }

        Long t0 = System.currentTimeMillis();
        DuplicateMatchRepository repo = new DuplicateMatchRepository();

        Duplicate_Match__c m = repo.getByIdForResolve(matchId);

        if (m.Status__c != DuplicateMatchConstants.STATUS_PENDING) {
            throw new AuraHandledException('Only "' + DuplicateMatchConstants.STATUS_PENDING + '" can be resolved.');
        }

        Savepoint sp = Database.setSavepoint();
        try {
            if (action == 'ignore') {
                m.Status__c = DuplicateMatchConstants.STATUS_IGNORED;
                repo.updateMatches(new List<Duplicate_Match__c>{ m });
            } else {
                if (m.Customer_B__c != null) {
                    repo.deleteCustomers(new List<Customer__c>{ new Customer__c(Id = m.Customer_B__c) });
                }
                m.Status__c = DuplicateMatchConstants.STATUS_MERGED;
                repo.updateMatches(new List<Duplicate_Match__c>{ m });
            }

            setMetric('resolve.action', action);
            setMetric('resolve.timeMs', System.currentTimeMillis() - t0);
            logInfo('resolve', 'Resolved duplicate ' + String.valueOf(matchId) + ' with action=' + action);

        } catch (Exception ex) {
            Database.rollback(sp);
            logError('resolve', 'Failed to resolve ' + String.valueOf(matchId) + ' action=' + action + ' :: ' + ex.getMessage(), ex);
            throw ex;
        }
    }
}
