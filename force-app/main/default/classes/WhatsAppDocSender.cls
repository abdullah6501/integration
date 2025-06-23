public with sharing class WhatsAppDocSender {
    @AuraEnabled
    public static String sendDocToWhatsApp(String phoneNumber, String docId) {
        String phoneId = '386100344590283'; // Ranger
        // String phoneId = '551350278069887'; 
        String accessToken = 'EAAXlnOd7Gv0BO2UK1GLm3ALR9FqXpXtKfULirhohhDEzcc7zPFJa7y4nx0aZB9XZBhvWyS5uZApqzKtu6GS5R6K6Nj9uGcwXvNbpFZB5rJy7iAO147FxfGZCCVSwajSFB98LkcmhE9XSsVM8bpeolIsc0RHB7zzQ43ZC0NZBo64X6Gm34HAAnNRAblMro72ZC5LDZCQZDZD'; //Ranger
        // String accessToken = 'EAAV3QI4oOUYBOZCJSMD1aYKAa6TmPTcRVKAA4QENJ0wlV5zzzcoPwQm2gRa8x5BmaDqoYrjC1R3dsRvRzoWiTPibx0nFoXsv5YsSg5CwLKZAmY0oXZCpV3jBxnqnOSGZCBu3q9in6eUOLLPnMxtmdLCxa0DZCcLJASyC49oZCcRedo46xLBpR0A4TjZAYSh8GZBZA3QZDZD';
        String apiUrl = 'https://graph.facebook.com/v17.0/' + phoneId + '/media';
 
        try {
            // ContentDocument file = [SELECT Id, Title FROM ContentDocument WHERE Id = :docId];
            ContentVersion version = [SELECT Id, Title, ContentDocumentId, FileExtension FROM ContentVersion WHERE ContentDocumentId = :docId LIMIT 1];
    
            ContentDistribution distribution = new ContentDistribution(Name = version.Title,
                                                                       ContentVersionId = version.Id,
                                                                       PreferencesAllowViewInBrowser = true);

            insert distribution;
            ContentDistribution shareFile = [SELECT Id, ContentDownloadUrl, DistributionPublicUrl FROM ContentDistribution WHERE Id = :distribution.Id];
            String publicUrl = shareFile.ContentDownloadUrl;

            String ShowUrl = shareFile.DistributionPublicUrl;
            // String ShowUrl = '/sfc/servlet.shepherd/version/download/' + version.Id ;
            String mediaType;
            if (version.FileExtension == 'pdf' || version.FileExtension == 'doc' || version.FileExtension == 'docx' || version.FileExtension == 'ppt' || version.FileExtension == 'pptx' || version.FileExtension == 'xls' || version.FileExtension == 'xlsx' || version.FileExtension == 'txt' || version.FileExtension == 'csv') {
                mediaType = 'document';
            } else {
                throw new AuraHandledException('Unsupported file type: ' + version.FileExtension);
            }

            return System.enqueueJob(new WhatsAppDocSenderQueueable(phoneNumber, publicUrl, version.Title, ShowUrl,  mediaType));
            // return response.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static String docPreview (String docId) {
        System.debug('docId: ' + docId);
        
        try {
            ContentVersion version = [SELECT Id, Title, ContentDocumentId, FileExtension FROM ContentVersion WHERE ContentDocumentId = :docId LIMIT 1];
            // String PreviewUrl = '/sfc/servlet.shepherd/version/download/' + version.Id ;
            String PreviewTitle = version.Title;
            String DocExtension = version.FileExtension;

            String PreviewUrl = PreviewTitle + '.' + DocExtension;
            System.debug('Preview URL: title :  ' + PreviewUrl);
            return PreviewUrl;
        } catch (Exception e) {
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }
    
    public class WhatsAppDocSenderQueueable implements Queueable, Database.AllowsCallouts {
        private String phoneNumber;
        private String publicUrl;
        private String fileName;
        private String ShowUrl;
        private String mediaType;

        public WhatsAppDocSenderQueueable(String phoneNumber, String publicUrl, String fileName, String ShowUrl, String mediaType) {
            this.phoneNumber = phoneNumber;
            this.publicUrl = publicUrl;
            this.fileName = fileName;
            this.ShowUrl = ShowUrl;
            this.mediaType = mediaType;
        }

        public void execute(QueueableContext context) {
            try {
                String phoneId = '386100344590283'; //Ranger
                // String phoneId = '551350278069887';
                String accessToken = 'EAAXlnOd7Gv0BO2UK1GLm3ALR9FqXpXtKfULirhohhDEzcc7zPFJa7y4nx0aZB9XZBhvWyS5uZApqzKtu6GS5R6K6Nj9uGcwXvNbpFZB5rJy7iAO147FxfGZCCVSwajSFB98LkcmhE9XSsVM8bpeolIsc0RHB7zzQ43ZC0NZBo64X6Gm34HAAnNRAblMro72ZC5LDZCQZDZD'; //Ranger
                // String accessToken = 'EAAV3QI4oOUYBOZCJSMD1aYKAa6TmPTcRVKAA4QENJ0wlV5zzzcoPwQm2gRa8x5BmaDqoYrjC1R3dsRvRzoWiTPibx0nFoXsv5YsSg5CwLKZAmY0oXZCpV3jBxnqnOSGZCBu3q9in6eUOLLPnMxtmdLCxa0DZCcLJASyC49oZCcRedo46xLBpR0A4TjZAYSh8GZBZA3QZDZD';
                String messageApiUrl = 'https://graph.facebook.com/v17.0/' + phoneId + '/messages';
                HttpRequest messageRequest = new HttpRequest();
                messageRequest.setEndpoint(messageApiUrl);
                messageRequest.setMethod('POST');
                messageRequest.setHeader('Authorization', 'Bearer ' + accessToken);
                messageRequest.setHeader('Content-Type', 'application/json');

                Map<String, Object> messagePayload = new Map<String, Object>{
                    'messaging_product' => 'whatsapp',
                    'recipient_type'=> 'individual',
                    'to' => phoneNumber,
                    'type' => mediaType,
                    mediaType => new Map<String, String>{ 'link' => publicUrl }
                };
                System.debug('messagePayload:'+messagePayload);

                messageRequest.setBody(JSON.serialize(messagePayload));

                Http http = new Http();
                HttpResponse messageResponse = http.send(messageRequest);
                System.debug('Message Response: ' + messageResponse.getBody());

                if (messageResponse.getStatusCode() == 200) {
                    System.debug('Entered');

                    Message__c message = new Message__c(
                        Sender__c = 'Me',
                        Receiver__c = phoneNumber,
                        Status__c = 'Sent',
                        Message_Body__c = 'Document: ' + fileName,
                        File_Show__c = ShowUrl,
                        Type__c = mediaType
                    );
                    insert message;
                    System.debug('Document sent successfully!');
                } else {
                    throw new AuraHandledException('Failed to send document message: ' + messageResponse.getBody());
                }
            } catch (Exception e) {
                throw new AuraHandledException('Error sending message: ' + e.getMessage());
            }
        }       
    }
}