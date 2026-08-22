trigger ContactTrigger on Customer (after insert, after update) {
    for (Customer cust : Trigger.new) {
        System.enqueueJob(new CustomerNotificationQueue(cust.Id));
    }
}