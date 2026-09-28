// Thoufic-28JUL25 handle conversation for Ranger Bot
public with sharing class ChatService {
    private static final String BASE_URL = 'https://api.valarhr.com/dbops/crud/document';
    private static final String chatservice_endpoint = 'callout:chat_service_credential/dbops/crud/document';
    private static final String Org_token_for_chatservice = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJjb21wYW55SWQiOiJBT295WjZkelptOER2NWhXSWIiLCJ1c2VyTmFtZSI6ImFkbWluQGRlbW8udmFsYXJociIsInVfaWQiOiI2ODhkZjBjZmExZDI1Y2ZiMzkwNWJjYWEiLCJwZXJtaXNzaW9ucyI6WyJTdXBlciBVc2VyIiwiRVNTIFVzZXIiLCJQcm9qZWN0IE1hbmFnZXIiLCJDUk0gTWFuYWdlciJdLCJlbXBsb3llZUlkIjoiUkQxMDAxIiwidXNlcm5hbWUiOiJBZG1pbiAiLCJjb21wYW55TmFtZSI6IkZsb3VyaXNoIEluZGlhIiwiaWF0IjoxNzU0Mjg4NDg2LCJleHAiOjE3NTk0NzI0ODZ9.g9-_b71pd--klmPKQd4xfqMqO_o2W45Vp0FlRizTubI';
    private static final String ranger_token_for_chatservice = 'ranger-4e1b2a0c-3d7f-4f8b-bc5d-6a9e0f1a2b3c_gRUMAteb4274lJ21KTc2g4FCXyw83HX8Q1NuPCz6e5YUysj-lW5r82luwlAA';
    private static final String userId = userinfo.getUserName();
    private static final String orgId = userinfo.getOrganizationId();


    public class Conversation {
        @AuraEnabled public String conversation_id { get; set; }
        @AuraEnabled public String user_id { get; set; }
        @AuraEnabled public String topic { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String created_at { get; set; }
        @AuraEnabled public String updatedAt { get; set; }


        public Conversation() {}

        public Conversation(Map<String, Object> inputMap) {
            this.conversation_id = (String)inputMap.get('conversation_id');
            this.user_id = (String)inputMap.get('user_id');
            this.topic = (String)inputMap.get('topic');
            this.created_at = (String)inputMap.get('created_at');
            this.status = (String)inputMap.get('status');
            this.updatedAt = (String)inputMap.get('updatedAt');
            
        }

    }

    public class Message {
        @AuraEnabled public String message_id { get; set; }
        @AuraEnabled public String conversation_id { get; set; }
        @AuraEnabled public String sender_type { get; set; } // user or bot
        @AuraEnabled public String sender_id { get; set; }
        @AuraEnabled public String message_text { get; set; }
        @AuraEnabled public String created_at { get; set; }
        @AuraEnabled public Boolean is_error { get; set; }
        @AuraEnabled public String reply_to_message_id { get; set; }
    public Message() {}

    public Message(Map<String, Object> inputMap) {
        this.message_id = (String)inputMap.get('message_id');
        this.conversation_id = (String)inputMap.get('conversation_id');
        this.sender_type = (String)inputMap.get('sender_type');
        this.sender_id = (String)inputMap.get('sender_id');
        this.message_text = (String)inputMap.get('message_text');
        this.created_at = (String)inputMap.get('created_at');
        this.is_error = inputMap.containsKey('is_error') && inputMap.get('is_error') != null ? (Boolean) inputMap.get('is_error') : false;
        this.reply_to_message_id = (String)inputMap.get('reply_to_message_id');
    }

    }

    @AuraEnabled
    public static String getCurrentUser() {
        String Name = UserInfo.getName();
        return Name;
        
    }

    // upsert Conversation

    @AuraEnabled
    public static Map<String, String> upsertConversation(Conversation convo) {
        String user_id = 'admin@demo.valarhr';
        if (convo.conversation_id == null || String.isBlank(convo.conversation_id)) {
            convo.conversation_id = generateUniqueId('conversation');
            convo.user_id = UserInfo.getUserEmail();
            convo.user_id = user_id;
            convo.status = 'active';
            postToExternal('POST','conversation', convo);
        } else {
            postToExternal('PATCH','conversation', convo);
        }

        Map<String, String> result = new Map<String, String>{
            'conversation_id' => convo.conversation_id,
            'user_id' => user_id
        };

        return result;
    }

    // @AuraEnabled
    // public static void upsertConversations(List<Conversation> convos) {
    //     //create
    //     for(Conversation convo : convos){
    //         if (convo.conversation_id == null || String.isBlank(convo.conversation_id)) {
    //         convo.conversation_id = generateUniqueId('conversation');
    //         convo.user_id = UserInfo.getUserEmail();
    //         convo.user_id = 'thoufic@aswinpdo.org';
    //         convo.status = 'active';
    //         postToExternal('POST','conversation', convo);
    //     }else{
    //         postToExternal('PATCH','conversation', convo);
    //     }
    //     }
    // }   

    // GET Conversations
    @AuraEnabled
    public static List<Conversation> getConversations() {
        String userId = UserInfo.getUserId();
        userId = 'admin@demo.valarhr';
        String url = chatservice_endpoint + '/postgre?table=conversation&user_id=' + EncodingUtil.urlEncode(userId, 'UTF-8');

        String response = getFromExternal(url);
        List<Object> rawList = (List<Object>) JSON.deserializeUntyped(response);
        List<Conversation> result = new List<Conversation>();

        for (Object obj : rawList) {
            Map<String, Object> inputmap = (Map<String, Object>) obj;
            result.add(new Conversation(inputmap));
        }
        return result;
    }

    // DELETE Conversation
    @AuraEnabled
    public static Boolean deleteConversation(String conversationId) {
        List<Message> related_messages = getMessagesByConversation(conversationId);
        for(Message msg : related_messages){
           Boolean msgResult = deleteMessage(msg.message_id);
           if(!msgResult){
               throw new AuraHandledException('Error deleting message with ID: '+msg.message_id);
           }
        }
        return deleteFromExternal('conversation', conversationId); 
    }
   

    // CREATE Message
    @AuraEnabled
    public static String upsertMessage(Message msg) {
        if (msg.message_id == '' || msg.message_id == null || String.isBlank(msg.message_id)) {
            msg.message_id = generateUniqueId('message');
            msg.sender_id = 'admin@demo.valarhr';
            postToExternal('POST','message', msg);
            System.debug('upert message'+msg.message_id);
        }else{
            postToExternal('PATCH','message', msg);
        }
        return msg.message_id;
    }

    // GET Messages by Conversation
    @AuraEnabled
    public static List<Message> getMessagesByConversation(String conversationId) {
        System.debug('getmessages');
        String url = chatservice_endpoint + '/postgre?table=message&conversation_id=' + EncodingUtil.urlEncode(conversationId, 'UTF-8');
        System.debug('response munn');
        String response = getFromExternal(url);
        System.debug('response pinn');


        List<Object> rawList = (List<Object>) JSON.deserializeUntyped(response);
        List<Message> result = new List<Message>();

        for (Object obj : rawList) {
            result.add(new Message((Map<String, Object>) obj));
        }
        System.debug('resullt munn'+result);
        return result;
    }


    // DELETE Message
    @AuraEnabled
    public static Boolean deleteMessage(String messageId) {
        return deleteFromExternal('message', messageId);
    }

    // Utility: uniqueid generator
    public static String generateUniqueId(String prefix) {
    DateTime now = DateTime.now();
    String datePart = now.format('yyyyMMdd-HHmmssSSS'); // 20250713-135122348
    String randomPart = String.valueOf(Math.abs(Crypto.getRandomInteger())).substring(0, 6);
    return prefix + '-' + datePart + '-' + randomPart;
    }

    // Utility: POST
    private static void postToExternal(String method, String table, Object payload) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(chatservice_endpoint + '?table=' + table);
            req.setMethod(method);
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('token', Org_token_for_chatservice);
            req.setBody(JSON.serialize(payload));
            System.debug('body'+JSON.serialize(payload));

            HttpResponse res = new Http().send(req);

            if (res.getStatusCode() != 200 && res.getStatusCode() != 201) {
                throw new AuraHandledException('POST failed: ' + res.getStatus() + ' - ' + res.getBody());
            }
            System.debug('POST successful: ' + res.getBody());

        } catch (Exception ex) {
            throw new AuraHandledException('HTTP POST exception: ' + ex.getMessage());
        }
    }


    // Utility: GET
    private static String getFromExternal(String url) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(url);
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('token', Org_token_for_chatservice);

            HttpResponse res = new Http().send(req);

            if (res.getStatusCode() == 200) {
                return res.getBody();
            } else {
                throw new AuraHandledException('GET failed: ' + res.getStatus() + ' - ' + res.getBody());
            }
        } catch (Exception ex) {
            throw new AuraHandledException('HTTP GET exception: ' + ex.getMessage());
        }
    }


    // Utility: DELETE
    private static Boolean deleteFromExternal(String table, String id) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(chatservice_endpoint + '?table=' + table + '&' + table + '_id=' + EncodingUtil.urlEncode(id, 'UTF-8'));
            req.setMethod('DELETE');
            req.setHeader('token', Org_token_for_chatservice);

            HttpResponse res = new Http().send(req);

            if (res.getStatusCode() == 200 || res.getStatusCode() == 204) {
                return true;
            } else {
                throw new AuraHandledException('DELETE failed: ' + res.getStatus() + ' - ' + res.getBody());
            }
        } catch (Exception ex) {
            throw new AuraHandledException('HTTP DELETE exception: ' + ex.getMessage());
        }
    }


    @AuraEnabled
    public static String shareKnowledge(List<String> urls, List<Object> manualDocuments, List<Object> fileDocuments) {
        try {
            // Build JSON payload
            String jsonPayload = JSON.serialize(new Map<String, Object>{
                'knowledge_map' => manualDocuments,
                'URLs' => urls,
                'Documents' => fileDocuments
            });

            // HTTP Setup
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://ai-api.valarhr.com/api/share_knowledge'); // Replace with real endpoint
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + ranger_token_for_chatservice);
            req.setBody(jsonPayload);
            System.debug('Status: ');
            Http http = new Http();
            HttpResponse res = http.send(req);

            System.debug('Status: ' + res.getStatus());
            System.debug('Response Body: ' + res.getBody());
            return res.getBody();

        } catch (Exception e) {
            System.debug('Error: ' + e.getMessage());
            throw new AuraHandledException('Failed to send knowledge data: ' + e.getMessage());
        }
    }

}