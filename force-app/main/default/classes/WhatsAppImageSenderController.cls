public with sharing class WhatsAppImageSenderController {
    @AuraEnabled
    public static String sendImageToWhatsApp(String phoneNumber, String fileId) {
        String phoneId = '386100344590283';  //Ranger
        // String phoneId = '551350278069887'; 
        String accessToken = 'EAAXlnOd7Gv0BO2UK1GLm3ALR9FqXpXtKfULirhohhDEzcc7zPFJa7y4nx0aZB9XZBhvWyS5uZApqzKtu6GS5R6K6Nj9uGcwXvNbpFZB5rJy7iAO147FxfGZCCVSwajSFB98LkcmhE9XSsVM8bpeolIsc0RHB7zzQ43ZC0NZBo64X6Gm34HAAnNRAblMro72ZC5LDZCQZDZD'; //Ranger
        // String accessToken = 'EAAV3QI4oOUYBOZCJSMD1aYKAa6TmPTcRVKAA4QENJ0wlV5zzzcoPwQm2gRa8x5BmaDqoYrjC1R3dsRvRzoWiTPibx0nFoXsv5YsSg5CwLKZAmY0oXZCpV3jBxnqnOSGZCBu3q9in6eUOLLPnMxtmdLCxa0DZCcLJASyC49oZCcRedo46xLBpR0A4TjZAYSh8GZBZA3QZDZD';
        String apiUrl = 'https://graph.facebook.com/v17.0/' + phoneId + '/media';
 
        try {
            // ContentDocument file = [SELECT Id, Title FROM ContentDocument WHERE Id = :fileId];
            ContentVersion version = [SELECT Id, Title, ContentDocumentId, FileExtension FROM ContentVersion WHERE ContentDocumentId = :fileId LIMIT 1];
    
            ContentDistribution distribution = new ContentDistribution(Name = version.Title,
                                                                       ContentVersionId = version.Id,
                                                                       PreferencesAllowViewInBrowser = true);

            insert distribution;
            ContentDistribution shareFile = [SELECT Id, ContentDownloadUrl, DistributionPublicUrl FROM ContentDistribution WHERE Id = :distribution.Id];
            String publicUrl = shareFile.ContentDownloadUrl;

            String ShowUrlDoc = shareFile.DistributionPublicUrl; // For Documents
            String ShowUrlIV = '/sfc/servlet.shepherd/version/download/' + version.Id ; // For Images and Videos

            String mediaType;
            if (version.FileExtension == 'jpg' || version.FileExtension == 'jpeg' || version.FileExtension == 'png') {
                mediaType = 'image';
            } else if (version.FileExtension == 'mp4' || version.FileExtension == 'avi' || version.FileExtension == 'mov') {
                mediaType = 'video';
            } else if (version.FileExtension == 'pdf' || version.FileExtension == 'doc' || version.FileExtension == 'docx' || version.FileExtension == 'ppt' || version.FileExtension == 'pptx' || version.FileExtension == 'xls' || version.FileExtension == 'xlsx' || version.FileExtension == 'txt' || version.FileExtension == 'csv') {
                mediaType = 'document';
            } else {
                throw new AuraHandledException('Unsupported file type: ' + version.FileExtension);
            }
            
            return System.enqueueJob(new WhatsAppImageSenderQueueable(phoneNumber, publicUrl, ShowUrlDoc, ShowUrlIV, version.Title, mediaType));
            // return 'Sent Successfully';
            // return response.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static String imagePreview (String previewId) {
        System.debug('previewId: ' + previewId);
        
        try {
            ContentVersion version = [SELECT Id, Title, ContentDocumentId FROM ContentVersion WHERE ContentDocumentId = :previewId LIMIT 1];
            String PreviewUrl = '/sfc/servlet.shepherd/version/download/' + version.Id ;
            System.debug('Preview URL: ' + PreviewUrl);
            return PreviewUrl;
        } catch (Exception e) {
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String videoPreview(String previewId) {
        System.debug('previewId: ' + previewId);

        try {
            ContentVersion version = [SELECT Id, Title, ContentDocumentId FROM ContentVersion WHERE ContentDocumentId = :previewId LIMIT 1];
            String PreviewUrl = '/sfc/servlet.shepherd/version/download/' + version.Id;
            System.debug('Preview URL: ' + PreviewUrl);
            return PreviewUrl;
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

    public class WhatsAppImageSenderQueueable implements Queueable, Database.AllowsCallouts {
        private String phoneNumber;
        private String publicUrl;
        private String ShowUrlDoc;
        private String ShowUrlIV;
        private String fileName;
        private String mediaType;

        public WhatsAppImageSenderQueueable(String phoneNumber, String publicUrl, String ShowUrlDoc, String ShowUrlIV, String fileName, String mediaType) {
            this.phoneNumber = phoneNumber;
            this.publicUrl = publicUrl;
            this.ShowUrlDoc = ShowUrlDoc;
            this.ShowUrlIV = ShowUrlIV;
            this.fileName = fileName;
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
                    Message__c message = new Message__c(
                        Sender__c = 'Me',
                        Receiver__c = phoneNumber,
                        Status__c = 'Sent',
                        Message_Body__c = mediaType.capitalize() + ': ' + fileName,
                        File_Show__c = (mediaType == 'document') ? ShowUrlDoc : ShowUrlIV,
                        Type__c = mediaType
                    );
                    insert message;
                    System.debug('Media sent successfully!');
                } else {
                    throw new AuraHandledException('Failed to send media message: ' + messageResponse.getBody());
                }
            } catch (Exception e) {
                throw new AuraHandledException('Error sending message: ' + e.getMessage());
            }
        }      
    }
}