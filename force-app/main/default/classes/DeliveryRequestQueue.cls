public class DeliveryRequestQueue implements Queueable {
    private Id requestId;

    public DeliveryRequestQueue(Id requestId) {
        this.requestId = requestId;
    }

    public void execute(QueueableContext context) {
        RequestHelper.handleDeliveryRequest(requestId);
    }
}