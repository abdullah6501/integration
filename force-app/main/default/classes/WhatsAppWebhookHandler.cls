@RestResource(urlMapping='/whatsappwebhook')
global class WhatsAppWebhookHandler {
    @HttpGet
    global static void validateWebhook() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        String mode = req.params.get('hub.mode');
        String token = req.params.get('hub.verify_token');
        String challenge = req.params.get('hub.challenge');

        String verifyToken = 'abdullah_verify';  //Ranger
        // String verifyToken = 'horizon_verify'; 
        if (mode == 'subscribe' && token == verifyToken) {
            res.statusCode = 200;
            res.responseBody = Blob.valueOf(challenge);
        } else {
            res.statusCode = 403;
        }
    }

    @HttpPost
    global static void handleWebhook() {
        RestRequest req = RestContext.request;
        String payload = req.requestBody.toString();
        System.debug('Incoming Webhook Payload: ' + payload);

        try {
            insert new Webhook_Payload__c(
                Payload__c = payload
            );
        } catch (Exception e) {
            System.debug('Error storing webhook payload: ' + e.getMessage());
        }

        try {
            Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(payload);
            if (data.containsKey('entry')) {
                List<Object> entries = (List<Object>) data.get('entry');
                for (Object entryObj : entries) {
                    Map<String, Object> entry = (Map<String, Object>) entryObj;
                    if (entry.containsKey('changes')) {
                        List<Object> changes = (List<Object>) entry.get('changes');
                        for (Object changeObj : changes) {
                            Map<String, Object> change = (Map<String, Object>) changeObj;
                            if (change.containsKey('value')) {
                                Map<String, Object> value = (Map<String, Object>) change.get('value');
                                if (value.containsKey('messages')) {
                                    List<Object> messages = (List<Object>) value.get('messages');
                                    for (Object messageObj : messages) {
                                        Map<String, Object> message = (Map<String, Object>) messageObj;
                                        String sender = (String) message.get('from');
                                        
                                        if (message.containsKey('text')) {
                                            String messageBody = (String) ((Map<String, Object>) message.get('text')).get('body');
                                            insert new Message__c(
                                                Sender__c = sender,
                                                Receiver__c = 'Me',
                                                Message_Body__c = messageBody,
                                                Status__c = 'Received',
                                                Type__c = 'text'
                                            );
                                        }

                                        if (message.containsKey('button')) {
                                            Map<String, Object> button = (Map<String, Object>) message.get('button');
                                            String buttonPayload = (String) button.get('payload');
                                            String buttonText = (String) button.get('text');

                                            insert new Message__c(
                                                Sender__c = sender,
                                                Receiver__c = 'Me',
                                                Message_Body__c = buttonText,
                                                Status__c = 'Received',
                                                Type__c = 'text'
                                                // Button_ID__c = buttonPayload
                                            );
                                        }                                     
                                        
                                        if (message.containsKey('image')) {
                                            Map<String, Object> image = (Map<String, Object>) message.get('image');
                                            String mediaId = (String) image.get('id'); 
                                            String mimeType = (String) image.get('mime_type');

                                            fetchAndSaveMedia(mediaId, sender, mimeType, 'image');
                                        }

                                        if (message.containsKey('video')) {
                                            Map<String, Object> image = (Map<String, Object>) message.get('video');
                                            String mediaId = (String) image.get('id'); 
                                            String mimeType = (String) image.get('mime_type');

                                            fetchAndSaveMedia(mediaId, sender, mimeType, 'video');
                                        }

                                        if (message.containsKey('document')) {
                                            Map<String, Object> image = (Map<String, Object>) message.get('document');
                                            String mediaId = (String) image.get('id'); 
                                            String mimeType = (String) image.get('mime_type');

                                            fetchAndSaveMedia(mediaId, sender, mimeType, 'document');
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } catch (Exception e) {
            System.debug('Error processing webhook: ' + e.getMessage());
        }
    }

    public static void fetchAndSaveMedia(String mediaId, String sender, String mimeType, String mediaType) {
        String accessToken = 'EAAXlnOd7Gv0BO2UK1GLm3ALR9FqXpXtKfULirhohhDEzcc7zPFJa7y4nx0aZB9XZBhvWyS5uZApqzKtu6GS5R6K6Nj9uGcwXvNbpFZB5rJy7iAO147FxfGZCCVSwajSFB98LkcmhE9XSsVM8bpeolIsc0RHB7zzQ43ZC0NZBo64X6Gm34HAAnNRAblMro72ZC5LDZCQZDZD'; //ranger
        // String accessToken = 'EAAV3QI4oOUYBOZCJSMD1aYKAa6TmPTcRVKAA4QENJ0wlV5zzzcoPwQm2gRa8x5BmaDqoYrjC1R3dsRvRzoWiTPibx0nFoXsv5YsSg5CwLKZAmY0oXZCpV3jBxnqnOSGZCBu3q9in6eUOLLPnMxtmdLCxa0DZCcLJASyC49oZCcRedo46xLBpR0A4TjZAYSh8GZBZA3QZDZD'; // horizon
        String mediaUrlEndpoint = 'https://graph.facebook.com/v17.0/' + mediaId;
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(mediaUrlEndpoint);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + accessToken);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            Map<String, Object> responseJson = (Map<String, Object>) System.JSON.deserializeUntyped(res.getBody());
            String mediaDownloadUrl = (String) responseJson.get('url');

            HttpRequest mediaReq = new HttpRequest();
            mediaReq.setEndpoint(mediaDownloadUrl);
            mediaReq.setMethod('GET');
            mediaReq.setHeader('Authorization', 'Bearer ' + accessToken);

            HttpResponse mediaRes = http.send(mediaReq);
            if (mediaRes.getStatusCode() == 200) {
                Blob mediaBlob = mediaRes.getBodyAsBlob();

                String fileExtension = getFileExtensionFromMimeType(mimeType);
                String fileName = 'whatsapp_' + mediaType + fileExtension;
                String fileTitle = 'WhatsApp ' + mediaType.capitalize() + ' from ' + sender;

                ContentVersion content = new ContentVersion(
                    Title = fileTitle,
                    PathOnClient = fileName,
                    VersionData = mediaBlob,
                    Description = 'Received from WhatsApp'
                );
                insert content;

                Message__c imageMessage = new Message__c(
                    Sender__c = sender,
                    Receiver__c = 'Me',
                    Message_Body__c = mediaType.capitalize() + ' Received from ' + sender,
                    Status__c = 'Received',
                    Type__c = mediaType,
                    File_Show__c = '/sfc/servlet.shepherd/version/download/' + content.Id
                    );
                insert imageMessage;

                System.debug('Image saved successfully in Salesforce');
            } else {
                System.debug('Error downloading media: ' + mediaRes.getStatusCode());
            }
        } else {
            System.debug('Error fetching media URL: ' + res.getStatusCode());
        }
    }

    public static String getFileExtensionFromMimeType(String mimeType) {
        Map<String, String> mimeTypeMap = new Map<String, String>{
            'image/jpeg' => '.jpg',
            'image/jpg' => '.jpg',
            'image/png' => '.png',
            'image/gif' => '.gif',
            'video/mp4' => '.mp4',
            'video/x-msvideo' => '.avi',
            'video/3gpp' => '.3gp',
            'video/quicktime' => '.mov',
            'video/x-matroska' => '.mkv',
            'video/x-flv' => '.flv',
            'video/x-ms-wmv' => '.wmv',
            'application/pdf' => '.pdf',
            'application/msword' => '.doc',
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document' => '.docx',
            'application/vnd.ms-powerpoint' => '.ppt',
            'application/vnd.openxmlformats-officedocument.presentationml.presentation' => '.pptx',
            'application/vnd.ms-excel' => '.xls',
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' => '.xlsx',
            'text/plain' => '.txt',
            'text/csv' => '.csv'
        };
    
        return mimeTypeMap.containsKey(mimeType) ? mimeTypeMap.get(mimeType) : '.bin';
    }
}

// @RestResource(urlMapping='/whatsappwebhook')
// global class WhatsAppWebhookHandler {
//     @HttpGet
//     global static void validateWebhook() {
//         RestRequest req = RestContext.request;
//         RestResponse res = RestContext.response;

//         String mode = req.params.get('hub.mode');
//         String token = req.params.get('hub.verify_token');
//         String challenge = req.params.get('hub.challenge');

//         String verifyToken = 'abdullah_verify';  //Ranger
//         // String verifyToken = 'horizon_verify'; 
//         if (mode == 'subscribe' && token == verifyToken) {
//             res.statusCode = 200;
//             res.responseBody = Blob.valueOf(challenge);
//         } else {
//             res.statusCode = 403;
//         }
//     }

//     @HttpPost
//     global static void handleWebhook() {
//         RestRequest req = RestContext.request;
//         String payload = req.requestBody.toString();
//         System.debug('Incoming Webhook Payload: ' + payload);

//         // try {
//         //     insert new Webhook_Payload__c(
//         //         Payload__c = payload
//         //     );
//         // } catch (Exception e) {
//         //     System.debug('Error storing webhook payload: ' + e.getMessage());
//         // }

//         List<Contact> contactsToInsert = new List<Contact>();
//         List<Message__c> messagesToInsert = new List<Message__c>();

//         try {
//             Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(payload);
//             if (data.containsKey('entry')) {
//                 List<Object> entries = (List<Object>) data.get('entry');
//                 for (Object entryObj : entries) {
//                     Map<String, Object> entry = (Map<String, Object>) entryObj;
//                     if (entry.containsKey('changes')) {
//                         List<Object> changes = (List<Object>) entry.get('changes');
//                         for (Object changeObj : changes) {
//                             Map<String, Object> change = (Map<String, Object>) changeObj;
//                             if (change.containsKey('value')) {
//                                 Map<String, Object> value = (Map<String, Object>) change.get('value');

//                                 Map<String, String> senderNameMap = new Map<String, String>();
//                                 if (value.containsKey('contacts')) {
//                                     List<Object> contacts = (List<Object>) value.get('contacts');
//                                     for (Object contactObj : contacts) {
//                                         Map<String, Object> contact = (Map<String, Object>) contactObj;
//                                         String waId = (String) contact.get('wa_id');
//                                         Map<String, Object> profile = (Map<String, Object>) contact.get('profile');
//                                         String name = (String) profile.get('name');
//                                         senderNameMap.put(waId, name);
//                                     }
//                                 }

//                                 if (value.containsKey('messages')) {
//                                     List<Object> messages = (List<Object>) value.get('messages');
//                                     for (Object messageObj : messages) {
//                                         Map<String, Object> message = (Map<String, Object>) messageObj;
//                                         String sender = (String) message.get('from');

//                                         String contactName = senderNameMap.containsKey(sender) ? senderNameMap.get(sender) : sender;

//                                         List<Contact> existingContacts = [SELECT Id FROM Contact WHERE MobilePhone = :sender LIMIT 1];
                                        
//                                         if (existingContacts.isEmpty()) {
//                                             Contact newContact = new Contact(
//                                                 LastName = contactName,
//                                                 MobilePhone = sender,
//                                                 RFAB__Gender__c = 'Male'
//                                             );
//                                             contactsToInsert.add(newContact);
//                                         }

//                                         // try {
//                                         //     insert new Webhook_Payload__c(
//                                         //         Payload__c = JSON.serialize(contactsToInsert)
//                                         //     );
//                                         // } catch (Exception e) {
//                                         //     System.debug('Error storing webhook payload: ' + e.getMessage());
//                                         // }
                                        
//                                         if (message.containsKey('text')) {
//                                             String messageBody = (String) ((Map<String, Object>) message.get('text')).get('body');
//                                             Message__c msg = new Message__c(
//                                                 Sender__c = sender,
//                                                 Receiver__c = 'Me',
//                                                 Message_Body__c = messageBody,
//                                                 Status__c = 'Received',
//                                                 Type__c = 'text'
//                                             );
//                                             messagesToInsert.add(msg);
//                                         }
                                        
//                                         // if (message.containsKey('text')) {
//                                         //     String messageBody = (String) ((Map<String, Object>) message.get('text')).get('body');
                                            
//                                         //     insert new Message__c(
//                                         //         Sender__c = sender,
//                                         //         Receiver__c = 'Me',
//                                         //         Message_Body__c = messageBody,
//                                         //         Status__c = 'Received',
//                                         //         Type__c = 'text'
//                                         //     );
//                                         // }

//                                         if (message.containsKey('button')) {
//                                             Map<String, Object> button = (Map<String, Object>) message.get('button');
//                                             String buttonPayload = (String) button.get('payload');
//                                             String buttonText = (String) button.get('text');

//                                             insert new Message__c(
//                                                 Sender__c = sender,
//                                                 Receiver__c = 'Me',
//                                                 Message_Body__c = buttonText,
//                                                 Status__c = 'Received',
//                                                 Type__c = 'text',
//                                                 Button_ID__c = buttonPayload
//                                             );
//                                         }                                     
                                        
//                                         if (message.containsKey('image')) {
//                                             Map<String, Object> image = (Map<String, Object>) message.get('image');
//                                             String mediaId = (String) image.get('id'); 
//                                             String mimeType = (String) image.get('mime_type');

//                                             fetchAndSaveMedia(mediaId, sender, mimeType, 'image');
//                                         }

//                                         if (message.containsKey('video')) {
//                                             Map<String, Object> image = (Map<String, Object>) message.get('video');
//                                             String mediaId = (String) image.get('id'); 
//                                             String mimeType = (String) image.get('mime_type');

//                                             fetchAndSaveMedia(mediaId, sender, mimeType, 'video');
//                                         }

//                                         if (message.containsKey('document')) {
//                                             Map<String, Object> image = (Map<String, Object>) message.get('document');
//                                             String mediaId = (String) image.get('id'); 
//                                             String mimeType = (String) image.get('mime_type');

//                                             fetchAndSaveMedia(mediaId, sender, mimeType, 'document');
//                                         }
//                                     }
//                                 }
//                             }
//                         }
//                     }
//                 }
//             }
//         } catch (Exception e) {
//             System.debug('Error processing webhook: ' + e.getMessage());
//         }
//         if (!contactsToInsert.isEmpty()) {
//             insert contactsToInsert;
//         }
//         if (!messagesToInsert.isEmpty()) {
//             insert messagesToInsert;
//         }
//     }

//     public static void fetchAndSaveMedia(String mediaId, String sender, String mimeType, String mediaType) {
//         String accessToken = 'EAAXlnOd7Gv0BO2UK1GLm3ALR9FqXpXtKfULirhohhDEzcc7zPFJa7y4nx0aZB9XZBhvWyS5uZApqzKtu6GS5R6K6Nj9uGcwXvNbpFZB5rJy7iAO147FxfGZCCVSwajSFB98LkcmhE9XSsVM8bpeolIsc0RHB7zzQ43ZC0NZBo64X6Gm34HAAnNRAblMro72ZC5LDZCQZDZD'; //ranger
//         // String accessToken = 'EAAV3QI4oOUYBOZCJSMD1aYKAa6TmPTcRVKAA4QENJ0wlV5zzzcoPwQm2gRa8x5BmaDqoYrjC1R3dsRvRzoWiTPibx0nFoXsv5YsSg5CwLKZAmY0oXZCpV3jBxnqnOSGZCBu3q9in6eUOLLPnMxtmdLCxa0DZCcLJASyC49oZCcRedo46xLBpR0A4TjZAYSh8GZBZA3QZDZD'; // horizon
//         String mediaUrlEndpoint = 'https://graph.facebook.com/v17.0/' + mediaId;
        
//         HttpRequest req = new HttpRequest();
//         req.setEndpoint(mediaUrlEndpoint);
//         req.setMethod('GET');
//         req.setHeader('Authorization', 'Bearer ' + accessToken);

//         Http http = new Http();
//         HttpResponse res = http.send(req);

//         if (res.getStatusCode() == 200) {
//             Map<String, Object> responseJson = (Map<String, Object>) System.JSON.deserializeUntyped(res.getBody());
//             String mediaDownloadUrl = (String) responseJson.get('url');

//             HttpRequest mediaReq = new HttpRequest();
//             mediaReq.setEndpoint(mediaDownloadUrl);
//             mediaReq.setMethod('GET');
//             mediaReq.setHeader('Authorization', 'Bearer ' + accessToken);

//             HttpResponse mediaRes = http.send(mediaReq);
//             if (mediaRes.getStatusCode() == 200) {
//                 Blob mediaBlob = mediaRes.getBodyAsBlob();

//                 String fileExtension = getFileExtensionFromMimeType(mimeType);
//                 String fileName = 'whatsapp_' + mediaType + fileExtension;
//                 String fileTitle = 'WhatsApp ' + mediaType.capitalize() + ' from ' + sender;

//                 ContentVersion content = new ContentVersion(
//                     Title = fileTitle,
//                     PathOnClient = fileName,
//                     VersionData = mediaBlob,
//                     Description = 'Received from WhatsApp'
//                 );
//                 insert content;

//                 Message__c imageMessage = new Message__c(
//                     Sender__c = sender,
//                     Receiver__c = 'Me',
//                     Message_Body__c = mediaType.capitalize() + ' Received from ' + sender,
//                     Status__c = 'Received',
//                     Type__c = mediaType,
//                     File_Show__c = '/sfc/servlet.shepherd/version/download/' + content.Id
//                     );
//                 insert imageMessage;

//                 System.debug('Image saved successfully in Salesforce');
//             } else {
//                 System.debug('Error downloading media: ' + mediaRes.getStatusCode());
//             }
//         } else {
//             System.debug('Error fetching media URL: ' + res.getStatusCode());
//         }
//     }

//     public static String getFileExtensionFromMimeType(String mimeType) {
//         Map<String, String> mimeTypeMap = new Map<String, String>{
//             'image/jpeg' => '.jpg',
//             'image/jpg' => '.jpg',
//             'image/png' => '.png',
//             'image/gif' => '.gif',
//             'video/mp4' => '.mp4',
//             'video/x-msvideo' => '.avi',
//             'video/3gpp' => '.3gp',
//             'video/quicktime' => '.mov',
//             'video/x-matroska' => '.mkv',
//             'video/x-flv' => '.flv',
//             'video/x-ms-wmv' => '.wmv',
//             'application/pdf' => '.pdf',
//             'application/msword' => '.doc',
//             'application/vnd.openxmlformats-officedocument.wordprocessingml.document' => '.docx',
//             'application/vnd.ms-powerpoint' => '.ppt',
//             'application/vnd.openxmlformats-officedocument.presentationml.presentation' => '.pptx',
//             'application/vnd.ms-excel' => '.xls',
//             'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' => '.xlsx',
//             'text/plain' => '.txt',
//             'text/csv' => '.csv'
//         };
    
//         return mimeTypeMap.containsKey(mimeType) ? mimeTypeMap.get(mimeType) : '.bin';
//     }
// }