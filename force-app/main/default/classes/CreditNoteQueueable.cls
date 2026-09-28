public class CreditNoteQueueable implements Queueable {
    private Id requestId;
    private Integer quantity;
    private String mobileNumber;
    private String messageBody;

    public CreditNoteQueueable(Id requestId, Integer quantity, String mobileNumber, String messageBody) {
        this.requestId = requestId;
        this.quantity = quantity;
        this.mobileNumber = mobileNumber;
        this.messageBody = messageBody;
    }

    public void execute(QueueableContext context) {
        if (String.isBlank(mobileNumber) || String.isBlank(messageBody)) {
            System.debug('MobilePhone or messageBody not found for Credit Note Id: ' + requestId);
            CreditNoteService.createCreditNoteFromRequest(requestId, quantity);
        } else if (String.isNotBlank(mobileNumber) && String.isNotBlank(messageBody)) {
            WhatsAppOutMessage.sendMessageForAgentYes(mobileNumber, messageBody, requestId, 'test');
        }
    }
}