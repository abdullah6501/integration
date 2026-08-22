public class MessageHandler {

    public static void processMessages(List<Message__c> messages) {
        for (Message__c msg : messages) {
            if (!shouldTriggerAction(msg)) {
                continue;
            }

            if(msg.Button_Id__c != null && msg.Button_Id__c.equalsIgnoreCase('accept')){
                String repliedMessageId = msg.Message_Replied_Id_Text__c;
                Id requestId;

                if (repliedMessageId != null) {
                    List<Message__c> repliedMsgs = [SELECT Id, Message_Id_Text__c, Request__c FROM Message__c WHERE Message_Id_Text__c = :repliedMessageId];
                    requestId = repliedMsgs[0].Request__c;
                }
                RequestHelper.changeStateOfRequest(requestId, 'Dispatched');
            } else if(msg.Button_Id__c != null && msg.Button_Id__c.equalsIgnoreCase('delivered')){
                String repliedMessageId = msg.Message_Replied_Id_Text__c;
                Id requestId;

                if (repliedMessageId != null) {
                    List<Message__c> repliedMsgs = [SELECT Id, Message_Id_Text__c, Request__c FROM Message__c WHERE Message_Id_Text__c = :repliedMessageId];
                    requestId = repliedMsgs[0].Request__c;
                }
                RequestHelper.changeStateOfRequest(requestId, 'Delivered');
            } else if(msg.Button_Id__c != null && msg.Button_Id__c.equalsIgnoreCase('yes')){
                    
                String phoneNumber = msg.Sender__c;
                String messageBody = 'How many Quantities?';

                String repliedMessageId = msg.Message_Replied_Id_Text__c;
                Id requestId;
                
                if (repliedMessageId != null) {
                    List<Message__c> repliedMsgs = [
                        SELECT Id, Message_Id_Text__c, Request__c 
                        FROM Message__c 
                        WHERE Message_Id_Text__c = :repliedMessageId 
                        LIMIT 1
                    ];
                    
                    if (!repliedMsgs.isEmpty()) {
                        requestId = repliedMsgs[0].Request__c;

                        System.enqueueJob(new DiscrepancyHandlerQueue(phoneNumber, messageBody, requestId)); 
                    } else {
                        System.debug('No replied message found for ID: ' + repliedMessageId);
                    }
                } else {
                    System.debug('repliedMessageId is null');
                }
                // System.enqueueJob(new DiscrepancyHandlerQueue(phoneNumber, messageBody, requestId));    
                // WhatsAppOutMessage.sendMessageForAgent(phoneNumber, messageBody, requestId);
            } else if (msg.Receiver__c.equalsIgnoreCase('me') && isNumeric(msg.Message_Body__c)) {
               
                String repliedMessageId = msg.Message_Replied_Id_Text__c;
                Id requestId;
            
                if (String.isNotBlank(repliedMessageId)) {
                    List<Message__c> repliedMsgs = [
                        SELECT Id, Message_Id_Text__c, Request__c
                        FROM Message__c
                        WHERE Message_Id_Text__c = :repliedMessageId
                        LIMIT 1
                    ];
                    if (!repliedMsgs.isEmpty()) {
                        requestId = repliedMsgs[0].Request__c;
                    } else {
                        System.debug('No message found with replied ID: ' + repliedMessageId);
                        return;
                    }
                }

                Integer qty = Integer.valueOf(msg.Message_Body__c);
                if (requestId != null) {
                    List<RFAB__Request_Item__c> itemsWithZeroQty = [
                        SELECT Id, RFAB__Quantity__c
                        FROM RFAB__Request_Item__c
                        WHERE RFAB__Request__c = :requestId
                        AND RFAB__Quantity__c = 0
                        LIMIT 1
                    ];
                
                    if (!itemsWithZeroQty.isEmpty()) {
                        RFAB__Request_Item__c itemToUpdate = itemsWithZeroQty[0];
                        itemToUpdate.RFAB__Quantity__c = qty;
                        update itemToUpdate;
                
                        System.debug('Updated Request Item Quantity to: ' + qty);
                    } else {
                        System.enqueueJob(new CreditNoteQueueable(requestId, qty, null, null));
                    }
                } else {
                    System.debug('Request ID is null; cannot create Credit Note.');
                }
                // if (requestId != null) {
                //     System.enqueueJob(new CreditNoteQueueable(requestId, qty, null, null));
                //     // CreditNoteService.createCreditNoteFromRequest(requestId, qty);
                // } else {
                //     System.debug('Request ID is null; cannot create Credit Note.');
                // }
            } else if(msg.Receiver__c != null && msg.Button_Id__c != null) {
                try {
                    String phoneNumber = msg.Sender__c;
                    String messageBody = 'How many Quantities?';
                    RFAB__Product__c product = [
                        SELECT Id, Name
                        FROM RFAB__Product__c
                        WHERE Name = :msg.Button_Id__c
                        LIMIT 1
                    ];

                    Contact contactNumber = [
                        SELECT Id
                        FROM Contact
                        WHERE MobilePhone = :msg.Sender__c];
            
                    RFAB__Request__c req = new RFAB__Request__c(
                        Name = 'Request - ' + msg.Sender__c,
                        RFAB__Request_Date__c = Date.today(),
                        RFAB__Contact__c = contactNumber.Id,
                        RFAB__Project__c = 'a1HfI000000bqqrUAA'
                        );
                    insert req;
            
                    RFAB__Request_Item__c item = new RFAB__Request_Item__c(
                        Name = 'Req Item - ' + product.Name,
                        RFAB__Request__c = req.Id,
                        RFAB__Product__c = product.Id,
                        RFAB__Quantity__c = 0
                    );
                    insert item;

                    System.enqueueJob(new DiscrepancyHandlerQueue(phoneNumber, messageBody, req.id)); 
            
                } catch (Exception e) {
                    System.debug('Error creating request and item: ' + e.getMessage());
                }
            }
        }
    }

    private static Boolean shouldTriggerAction(Message__c msg) {
        return msg.Receiver__c != null && msg.Receiver__c.equalsIgnoreCase('me');
    }

    private static Boolean isNumeric(String str) {
        if (String.isBlank(str)) return false;
        try {
            Decimal d = Decimal.valueOf(str);
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    // private static Boolean isProduct(String str) {
    //     RFAB__Product__c product = [
    //         SELECT Id, Name FROM RFAB__Product__c
    //         WHERE Name = :str
    //         LIMIT 1];
    //     if (product != null) {
    //         return true;
    //     } else {
    //         return false;
    //     }
    // }
}