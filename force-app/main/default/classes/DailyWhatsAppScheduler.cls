public class DailyWhatsAppScheduler implements Schedulable {
    public void execute(SchedulableContext context) {
        System.enqueueJob(new WhatsAppSchedulerQueue());
    }
}