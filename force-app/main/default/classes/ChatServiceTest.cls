@isTest
private class ChatServiceTest {

    @isTest
    static void testGetCurrentUser() {
        String name = ChatService.getCurrentUser();
        System.assertNotEquals(null, name);
    }

    @isTest
    static void testUpsertConversationInsert() {
        ChatService.Conversation convo = new ChatService.Conversation();
        convo.topic = 'New Chat';

        Test.setMock(HttpCalloutMock.class, new ChatServiceMock());
        Map<String, String> result = ChatService.upsertConversation(convo);

        System.assertNotEquals(null, result.get('conversation_id'));
    }

    @isTest
    static void testUpsertConversationUpdate() {
        ChatService.Conversation convo = new ChatService.Conversation();
        convo.conversation_id = 'conv-456';
        convo.topic = 'Updated Chat';

        Test.setMock(HttpCalloutMock.class, new ChatServiceMock());
        Map<String, String> result = ChatService.upsertConversation(convo);

        System.assertEquals('conv-456', result.get('conversation_id'));
    }

    @isTest
    static void testGetConversations() {
        Test.setMock(HttpCalloutMock.class, new ChatServiceMock());
        List<ChatService.Conversation> Conversationlist = ChatService.getConversations();

        System.assertEquals(1, Conversationlist.size());
        System.assertEquals('conv-123', Conversationlist[0].conversation_id);
    }

    @isTest
    static void testUpsertMessageInsert() {
        ChatService.Message msg = new ChatService.Message();
        msg.conversation_id = 'conv-123';
        msg.sender_type = 'user';
        msg.sender_id = 'admin@demo.valarhr';
        msg.message_text = 'Hello';

        Test.setMock(HttpCalloutMock.class, new ChatServiceMock());
        String id = ChatService.upsertMessage(msg);

        System.assertNotEquals(null, id);
    }

    @isTest
    static void testUpsertMessageUpdate() {
        ChatService.Message msg = new ChatService.Message();
        msg.message_id = 'msg-001';
        msg.conversation_id = 'conv-123';
        msg.sender_type = 'user';
        msg.sender_id = 'admin@demo.valarhr';
        msg.message_text = 'Update message';

        Test.setMock(HttpCalloutMock.class, new ChatServiceMock());
        String id = ChatService.upsertMessage(msg);

        System.assertEquals('msg-001', id);
    }

    @isTest
    static void testGetMessagesByConversation() {
        Test.setMock(HttpCalloutMock.class, new ChatServiceMock());
        List<ChatService.Message> msgs = ChatService.getMessagesByConversation('conv-123');

        System.assertEquals(1, msgs.size());
        System.assertEquals('msg-123', msgs[0].message_id);
    }

    @isTest
    static void testDeleteMessage() {
        Test.setMock(HttpCalloutMock.class, new ChatServiceMock());
        Boolean success = ChatService.deleteMessage('msg-123');

        System.assertEquals(true, success);
    }

    @isTest
    static void testDeleteConversation() {
        Test.setMock(HttpCalloutMock.class, new ChatServiceMock());
        Boolean result = ChatService.deleteConversation('conv-123');

        System.assertEquals(true, result);
    }


    @isTest
    static void testShareKnowledge() {
        List<String> urls = new List<String>{'https://example.com'};
        List<Object> manual = new List<Object>{};
        List<Object> files = new List<Object>{};

        Test.setMock(HttpCalloutMock.class, new ChatServiceMock());
        String res = ChatService.shareKnowledge(urls, manual, files);

        System.assertNotEquals(null, res);
    }
}