@IsTest
private class DuplicateMatchingSchedulerTest {

    @IsTest
    static void testScheduleHourlyAndRun() {
        Test.startTest();
        
        DuplicateMatchingScheduler.scheduleHourly();
        Test.stopTest();

        AsyncApexJob[] jobs = [
            SELECT Id, JobType, Status, NumberOfErrors, TotalJobItems, CompletedDate
            FROM AsyncApexJob
            WHERE JobType IN ('ScheduledApex','BatchApex')
            ORDER BY CreatedDate DESC
            LIMIT 10
        ];
        System.assert(!jobs.isEmpty(), 'Expected at least one scheduled/batch job');
    }

    @IsTest
    static void testSchedulerEnqueuesBatch() {
        Test.startTest();

        Integer nextMinute = Math.mod(Datetime.now().minute()+1, 60);
        String cron = '0 ' + String.valueOf(nextMinute) + ' * * * ?';
        System.schedule('DuplicateMatchingScheduler-Now', cron, new DuplicateMatchingScheduler());

        Test.stopTest();

        Integer count = [SELECT COUNT() FROM AsyncApexJob WHERE JobType IN ('ScheduledApex','BatchApex')];
        System.assert(count > 0, 'Should have at least one job created by scheduler');
    }
}
