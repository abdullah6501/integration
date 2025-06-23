@RestResource(urlMapping='/instagram/webhook')
global with sharing class InstagramWebhook {

    @HttpGet
    global static void verifyWebhook() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        String mode = req.params.get('hub.mode');
        String token = req.params.get('hub.verify_token');
        String challenge = req.params.get('hub.challenge');

        if (mode == 'subscribe' && token == 'abdullah_verify_insta') {
            res.statusCode = 200;
            res.responseBody = Blob.valueOf(challenge);
        } else {
            res.statusCode = 403;
        }
    }
    
    @HttpPost
    global static void handleWebhook() {
        try {
            String body = RestContext.request.requestBody.toString();
            System.debug('Received Instagram Webhook: ' + body);

            try {
                insert new Webhook_Payload__c(Payload__c = body);
            } catch (Exception e) {
                System.debug('Error storing webhook payload: ' + e.getMessage());
            }

            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(body);

            List<Instagram_Message__c> messageList = new List<Instagram_Message__c>();

            List<Object> entries = (List<Object>) payload.get('entry');
            for (Object entry : entries) {
                Map<String, Object> entryMap = (Map<String, Object>) entry;
                List<Object> messagingEvents = (List<Object>) entryMap.get('messaging');

                if (messagingEvents != null) {
                    for (Object event : messagingEvents) {
                        Map<String, Object> eventMap = (Map<String, Object>) event;

                        Map<String, Object> sender = (Map<String, Object>) eventMap.get('sender');
                        Map<String, Object> message = (Map<String, Object>) eventMap.get('message');

                        if (message != null && sender != null) {
                            Instagram_Message__c msg = new Instagram_Message__c();
                            msg.Sender_Id__c = String.valueOf(sender.get('id'));
                            msg.Message__c = String.valueOf(message.get('text'));
                            msg.IG_User_ID__c = String.valueOf(entryMap.get('id'));
                            msg.Timestamp__c = String.valueOf(Datetime.now());

                            messageList.add(msg);
                        }
                    }
                }
            }

            if (!messageList.isEmpty()) {
                insert messageList;
            }

        } catch (Exception e) {
            System.debug('Error handling Instagram webhook: ' + e.getMessage());
            throw new AuraHandledException('Webhook error: ' + e.getMessage());
        }
    }

    // @HttpPost
    // global static void handleWebhook() {
    //     RestRequest req = RestContext.request;
    //     RestResponse res = RestContext.response;

    //     try {
    //         String body = req.requestBody.toString();
    //         System.debug('Received Instagram Webhook: ' + body);

    //         // insert new Webhook_Payload__c(Payload__c = body);
            // try {
            //     insert new Webhook_Payload__c(
            //         Payload__c = body
            //     );
            // } catch (Exception e) {
            //     System.debug('Error storing webhook payload: ' + e.getMessage());
            // }

    //     } catch (Exception e) {
    //         System.debug('Error processing Instagram Webhook: ' + e.getMessage());
    //     }

    //     res.statusCode = 200;
    // }
}