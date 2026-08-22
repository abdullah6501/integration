public class RequestNotificationQueue implements Queueable {
    private Id requestId;

    public RequestNotificationQueue(Id requestId) {
        this.requestId = requestId;
    }

    public void execute(QueueableContext context) {
        RFAB__Request__c req = [
            SELECT Id, Name, RFAB__Request_Date__c, RFAB__Status__c, RFAB__Contact__c, 
            RFAB__Contact__r.MobilePhone, RFAB__Contact__r.Name
            FROM RFAB__Request__c WHERE Id = :requestId LIMIT 1
        ];
        // RequestHelper.processRequest(req);
        if (req.RFAB__Status__c == 'Delivered') {
            RequestHelper.handleDeliveredRequest(req); 
        } else {
            RequestHelper.processRequest(req);
        }
    }
}
