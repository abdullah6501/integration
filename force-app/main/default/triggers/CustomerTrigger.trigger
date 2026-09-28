trigger CustomerTrigger on Customer (after insert) {
    for (Customer cust : Trigger.new) {
        System.enqueueJob(new CustomerNotificationQueue(cust.Id));
    }
}