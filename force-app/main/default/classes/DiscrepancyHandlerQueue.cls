public class DiscrepancyHandlerQueue implements Queueable, Database.AllowsCallouts {
    private Id requestId;
    private String phoneNumber;
    private String message;

    public DiscrepancyHandlerQueue(String phoneNumber, String message, Id requestId) {
        this.requestId = requestId;
        this.phoneNumber = phoneNumber;
        this.message = message;
    }

    public void execute(QueueableContext context) {
        // try {
        //     insert new WhatsApp_Template__c(
        //         Header_Value__c = 'enter WhatsAppOutMessage'
        //     );
        // } catch (Exception e) {
        //     System.debug('Error storing webhook payload: ' + e.getMessage());
        // }
        WhatsAppOutMessage.sendMessageForAgentYes(phoneNumber, message, requestId);
    }
}