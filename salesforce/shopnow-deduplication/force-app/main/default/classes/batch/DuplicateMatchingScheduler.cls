global with sharing class DuplicateMatchingScheduler implements Schedulable {

    global void execute(SchedulableContext sc) {
        try {
            Id jobId = Database.executeBatch(new DuplicateMatchingBatch(), 200);
            System.debug(LoggingLevel.INFO, 'DuplicateMatchingBatch enqueued. AsyncApexJob Id: ' + jobId);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Scheduler failed to start batch: ' + e.getMessage());
            try {
                String cron = cronAfterMinutes(15);
                String name = 'DuplicateMatchingScheduler-Retry-' + Datetime.now().getTime();
                System.schedule(name, cron, new DuplicateMatchingScheduler());
                sendErrorEmail('Scheduler failed: ' + e.getMessage());
            } catch (Exception se) {
                System.debug(LoggingLevel.ERROR, 'Failed to reschedule after scheduler error: ' + se.getMessage());
            }
        }
    }

    public static void scheduleHourly() {
        String cron = '0 0 * * * ?';
        System.schedule('DuplicateMatchingScheduler-Hourly', cron, new DuplicateMatchingScheduler());
    }

    private static String cronAfterMinutes(Integer minutes) {
        Datetime dt = Datetime.now().addMinutes(minutes);
        return String.format('{0} {1} {2} {3} {4} ? {5}',
            new List<String>{
                String.valueOf(dt.second()),
                String.valueOf(dt.minute()),
                String.valueOf(dt.hour()),
                String.valueOf(dt.day()),
                String.valueOf(dt.month()),
                String.valueOf(dt.year())
            }
        );
    }

    private static void sendErrorEmail(String message) {
        try {
            Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
            msg.setToAddresses(new String[] { UserInfo.getUserEmail() });
            msg.setSubject('[ShopNow] DuplicateMatchingScheduler - Error');
            msg.setPlainTextBody(message);
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { msg });
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error sending scheduler email: ' + e.getMessage());
        }
    }
}
