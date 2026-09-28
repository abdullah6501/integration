public class WhatsAppOutMessage {
    @AuraEnabled
    public static void sendMessage(String phoneNumber, String message) {
        String phoneId = System.Label.Phone_Id; 
        String accessToken = System.Label.Access_Token;
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

                Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());

                String messageId;
                if (responseBody.containsKey('messages')) {
                    List<Object> messages = (List<Object>) responseBody.get('messages');
                    if (!messages.isEmpty()) {
                        Map<String, Object> messageMap = (Map<String, Object>) messages[0];
                        messageId = (String) messageMap.get('id');
                    }
                }

                Message__c sentMessage = new Message__c(
                    Sender__c = 'Me',
                    Receiver__c = phoneNumber,
                    Message_Body__c = message,
                    Status__c = 'Sent',
                    Type__c = 'text',
                    Message_Id_Text__c = messageId
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
                SELECT Id, Sender__c, Receiver__c, File_Show__c, 
                Message_Body__c, 
                Type__c, Status__c, CreatedDate
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

    @AuraEnabled(cacheable=true)
    public static String getContactsWithLastMessages() {
        List<Contact> contacts = [
            SELECT Id, Name, MobilePhone
            FROM Contact
            WHERE MobilePhone != null
            ORDER BY LastModifiedDate DESC
            LIMIT 50
        ];

        Set<String> phoneNumbers = new Set<String>();
        for (Contact c : contacts) {
            phoneNumbers.add(c.MobilePhone);
        }

        Map<String, Message__c> lastMessages = new Map<String, Message__c>();
        for (AggregateResult ar : [
            SELECT Sender__c, Receiver__c, MAX(CreatedDate) lastDate
            FROM Message__c
            WHERE (Sender__c = 'Me' OR Receiver__c = 'Me' OR Sender__c IN :phoneNumbers OR Receiver__c IN :phoneNumbers)
            GROUP BY Sender__c, Receiver__c
        ]) {
            String sender = (String)ar.get('Sender__c');
            String receiver = (String)ar.get('Receiver__c');
            DateTime lastDate = (DateTime)ar.get('lastDate');

            Message__c lastMsg = [
                SELECT Id, Message_Body__c, CreatedDate, Type__c, Sender__c, Receiver__c
                FROM Message__c
                WHERE (Sender__c = :sender AND Receiver__c = :receiver)
                AND CreatedDate = :lastDate
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];

            String contactPhone = (sender == 'Me') ? receiver : sender;
            lastMessages.put(contactPhone, lastMsg);
        }

        // Prepare response
        List<Map<String, Object>> response = new List<Map<String, Object>>();
        for (Contact c : contacts) {
            Map<String, Object> contactData = new Map<String, Object>{
                'Id' => c.Id,
                'Name' => c.Name,
                'MobilePhone' => c.MobilePhone,
                'preview' => '',
                'time' => null,
                'isFromMe' => false
            };

            if (lastMessages.containsKey(c.MobilePhone)) {
                Message__c msg = lastMessages.get(c.MobilePhone);
                contactData.put('preview', 
                    msg.Type__c == 'text' ? msg.Message_Body__c : 
                    msg.Type__c == 'image' ? 'Image' :
                    msg.Type__c == 'video' ? 'Video' : 'Document');
                contactData.put('time', msg.CreatedDate);
                contactData.put('isFromMe', msg.Sender__c == 'Me');
            }

            response.add(contactData);
        }

        response.sort(new MessageTimeComparator());
        return JSON.serialize(response);
    }

    // Comparator class to sort by message time
    public class MessageTimeComparator implements System.Comparator<Map<String, Object>> {
        public Integer compare(Map<String, Object> a, Map<String, Object> b) {
            DateTime aTime = (DateTime)a.get('time');
            DateTime bTime = (DateTime)b.get('time');
            
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            
            if (aTime > bTime) return -1;
            if (aTime < bTime) return 1;
            return 0;
        }
    }

    // For sending response to agentforce
    @future(callout=true)
    public static void sendMessageForAgent(String phoneNumber, String message) {
        String phoneId = System.Label.Phone_Id; 
        String accessToken = System.Label.Access_Token;
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

                Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());

                String messageId;
                if (responseBody.containsKey('messages')) {
                    List<Object> messages = (List<Object>) responseBody.get('messages');
                    if (!messages.isEmpty()) {
                        Map<String, Object> messageMap = (Map<String, Object>) messages[0];
                        messageId = (String) messageMap.get('id');
                    }
                }

                Message__c sentMessage = new Message__c(
                    Sender__c = 'Me',
                    Receiver__c = phoneNumber,
                    Message_Body__c = message,
                    Status__c = 'Sent',
                    Type__c = 'text',
                    Message_Id_Text__c = messageId
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

    // @future(callout=true)
    public static void sendMessageForAgentYes(String phoneNumber, String message, Id requestId) {
        String phoneId = System.Label.Phone_Id; 
        String accessToken = System.Label.Access_Token;
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

                Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());

                String messageId;
                if (responseBody.containsKey('messages')) {
                    List<Object> messages = (List<Object>) responseBody.get('messages');
                    if (!messages.isEmpty()) {
                        Map<String, Object> messageMap = (Map<String, Object>) messages[0];
                        messageId = (String) messageMap.get('id');
                    }
                }

                Message__c sentMessage = new Message__c(
                    Sender__c = 'Me',
                    Receiver__c = phoneNumber,
                    Message_Body__c = message,
                    Status__c = 'Sent',
                    Type__c = 'text',
                    Message_Id_Text__c = messageId,
                    Request__c = requestId
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

    @future(callout=true)
    public static void sendMessageForAgentYes(String phoneNumber, String message, Id requestId, String name) {
        String phoneId = System.Label.Phone_Id; 
        String accessToken = System.Label.Access_Token;
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

                Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());

                String messageId;
                if (responseBody.containsKey('messages')) {
                    List<Object> messages = (List<Object>) responseBody.get('messages');
                    if (!messages.isEmpty()) {
                        Map<String, Object> messageMap = (Map<String, Object>) messages[0];
                        messageId = (String) messageMap.get('id');
                    }
                }

                Message__c sentMessage = new Message__c(
                    Sender__c = 'Me',
                    Receiver__c = phoneNumber,
                    Message_Body__c = message,
                    Status__c = 'Sent',
                    Type__c = 'text',
                    Message_Id_Text__c = messageId,
                    Request__c = requestId
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
}