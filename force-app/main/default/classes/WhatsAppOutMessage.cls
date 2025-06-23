public with sharing class WhatsAppOutMessage {
    @AuraEnabled
    public static void sendMessage(String phoneNumber, String message) {
        String phoneId = '386100344590283';  //Ranger
        // String phoneId = '551350278069887'; 
        String accessToken = 'EAAXlnOd7Gv0BO2UK1GLm3ALR9FqXpXtKfULirhohhDEzcc7zPFJa7y4nx0aZB9XZBhvWyS5uZApqzKtu6GS5R6K6Nj9uGcwXvNbpFZB5rJy7iAO147FxfGZCCVSwajSFB98LkcmhE9XSsVM8bpeolIsc0RHB7zzQ43ZC0NZBo64X6Gm34HAAnNRAblMro72ZC5LDZCQZDZD'; //Ranger
        // String accessToken = 'EAAV3QI4oOUYBOZCJSMD1aYKAa6TmPTcRVKAA4QENJ0wlV5zzzcoPwQm2gRa8x5BmaDqoYrjC1R3dsRvRzoWiTPibx0nFoXsv5YsSg5CwLKZAmY0oXZCpV3jBxnqnOSGZCBu3q9in6eUOLLPnMxtmdLCxa0DZCcLJASyC49oZCcRedo46xLBpR0A4TjZAYSh8GZBZA3QZDZD';
        String apiUrl = 'https://graph.facebook.com/v17.0/' + phoneId + '/messages';

        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(apiUrl);
        request.setMethod('POST');
        request.setHeader('Authorization', 'Bearer ' + accessToken);
        request.setHeader('Content-Type', 'application/json');

        Map<String, Object> body = new Map<String, Object>{
            'messaging_product' => 'whatsapp',
            'to' => phoneNumber,
            'type' => 'text',
            'text' => new Map<String, String>{ 'body' => message }
        };
        request.setBody(JSON.serialize(body));

        try {
            HttpResponse response = http.send(request);
            System.debug('Response: ' + response.getBody());

            if (response.getStatusCode() == 200 || response.getStatusCode() == 201) {

                Message__c sentMessage = new Message__c(
                    Sender__c = 'Me',
                    Receiver__c = phoneNumber,
                    Message_Body__c = message,
                    Status__c = 'Sent',
                    Type__c = 'text'
                );
                insert sentMessage;
            } else {
                System.debug('Error Response: ' + response.getBody());
                throw new AuraHandledException('Failed to send message: ' + response.getBody());
            }
        } catch (Exception e) {
            System.debug('Error sending message: ' + e.getMessage());
            throw new AuraHandledException('Error sending message: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static String getPhoneNumberForRecord(String recordId) {
        try {
            Contact record = [
                SELECT MobilePhone 
                FROM Contact 
                WHERE Id = :recordId 
                LIMIT 1
            ];
            return record.MobilePhone;
        } catch (Exception e) {
            System.debug('Error fetching phone number: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving phone number.');
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Message__c> getMessagesForPhoneNumber(String phoneNumber) {
        try {
            return [
                SELECT Id, Sender__c, Receiver__c, File_Show__c, Message_Body__c, Type__c, Status__c, CreatedDate
                FROM Message__c
                WHERE (Sender__c = 'Me' AND Receiver__c = :phoneNumber) 
                   OR (Sender__c = :phoneNumber AND Receiver__c = 'Me')
                ORDER BY CreatedDate ASC
            ];
        } catch (Exception e) {
            System.debug('Error retrieving messages: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving messages.');
        }
    }
}