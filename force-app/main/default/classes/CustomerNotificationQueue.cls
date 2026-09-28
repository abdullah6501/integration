public class CustomerNotificationQueue implements Queueable {
    private Id customerId;

    public CustomerNotificationQueue(Id customerId) {
        this.customerId = customerId;
    }

    public void execute(QueueableContext context) {
        Customer cust = [
            SELECT Id, Name, Contact__c, Contact__r.MobilePhone
            FROM Customer
            WHERE Id = :customerId LIMIT 1
        ];
        CustomerHelper.processContact(cust);
    }
}