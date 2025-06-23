@isTest
private class WhatsAppWebhookHandlerTest {
    
    @isTest
    static void testValidateWebhookSuccess() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        String correctVerifyToken = 'horizon_verify'; 
        
        req.requestURI = '/services/apexrest/whatsappwebhook';
        req.httpMethod = 'GET';
        req.addParameter('hub.mode', 'subscribe');
        req.addParameter('hub.verify_token', correctVerifyToken);
        req.addParameter('hub.challenge', 'challenge_token_123');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        WhatsAppWebhookHandler.validateWebhook();
        Test.stopTest();
        
        System.assertEquals(200, res.statusCode);
        System.assertEquals('challenge_token_123', res.responseBody.toString());
    }
    
    @isTest
    static void testValidateWebhookFailure() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/whatsappwebhook';
        req.httpMethod = 'GET';
        req.addParameter('hub.mode', 'subscribe');
        req.addParameter('hub.verify_token', 'invalid_token');
        req.addParameter('hub.challenge', 'challenge_token_123');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        WhatsAppWebhookHandler.validateWebhook();
        Test.stopTest();
        
        System.assertEquals(403, res.statusCode);
    }
    
    @isTest
    static void testHandleWebhookTextMessage() {
        String textMessagePayload = '{"object":"whatsapp_business_account","entry":[{"id":"12345","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"1234567890","phone_number_id":"987654321"},"contacts":[{"profile":{"name":"Test User"},"wa_id":"1234567890"}],"messages":[{"from":"1234567890","id":"wamid.123","timestamp":"1654321098","text":{"body":"Hello, this is a test message"}}]},"field":"messages"}]}]}';
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/whatsappwebhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(textMessagePayload);
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        WhatsAppWebhookHandler.handleWebhook();
        Test.stopTest();
        
        List<Message__c> messages = [SELECT Sender__c, Receiver__c, Message_Body__c, Status__c, Type__c FROM Message__c];
        System.assertEquals(1, messages.size());
        System.assertEquals('1234567890', messages[0].Sender__c);
        System.assertEquals('Me', messages[0].Receiver__c);
        System.assertEquals('Hello, this is a test message', messages[0].Message_Body__c);
        System.assertEquals('Received', messages[0].Status__c);
        System.assertEquals('text', messages[0].Type__c);
    }
    
    @isTest
    static void testHandleWebhookButtonMessage() {
        String buttonMessagePayload = '{"object":"whatsapp_business_account","entry":[{"id":"12345","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"1234567890","phone_number_id":"987654321"},"contacts":[{"profile":{"name":"Test User"},"wa_id":"1234567890"}],"messages":[{"from":"1234567890","id":"wamid.123","timestamp":"1654321098","button":{"payload":"button_1","text":"Yes"}}]},"field":"messages"}]}]}';
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/whatsappwebhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(buttonMessagePayload);
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        WhatsAppWebhookHandler.handleWebhook();
        Test.stopTest();
        
        List<Message__c> messages = [SELECT Sender__c, Receiver__c, Message_Body__c, Status__c, Type__c, Button_ID__c FROM Message__c];
        System.assertEquals(1, messages.size());
        System.assertEquals('1234567890', messages[0].Sender__c);
        System.assertEquals('Me', messages[0].Receiver__c);
        System.assertEquals('Yes', messages[0].Message_Body__c);
        System.assertEquals('Received', messages[0].Status__c);
        System.assertEquals('text', messages[0].Type__c);
        System.assertEquals('button_1', messages[0].Button_ID__c);
    }
    
    @isTest
    static void testHandleWebhookImageMessage() {
        MockHttpResponseGenerator mock = new MockHttpResponseGenerator();
        Test.setMock(HttpCalloutMock.class, mock);
        
        String imageMessagePayload = '{"object":"whatsapp_business_account","entry":[{"id":"12345","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"1234567890","phone_number_id":"987654321"},"contacts":[{"profile":{"name":"Test User"},"wa_id":"1234567890"}],"messages":[{"from":"1234567890","id":"wamid.123","timestamp":"1654321098","image":{"id":"12345","mime_type":"image/jpeg"}}]},"field":"messages"}]}]}';
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/whatsappwebhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(imageMessagePayload);
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        WhatsAppWebhookHandler.handleWebhook();
        Test.stopTest();
        
        List<ContentVersion> contentVersions = [SELECT Title, PathOnClient FROM ContentVersion];
        System.assertEquals(1, contentVersions.size());
        System.assertEquals('WhatsApp Image from 1234567890', contentVersions[0].Title);
        System.assertEquals('whatsapp_image.jpg', contentVersions[0].PathOnClient);
        
        List<Message__c> messages = [SELECT Sender__c, Receiver__c, Message_Body__c, Status__c, Type__c FROM Message__c];
        System.assertEquals(1, messages.size());
        System.assertEquals('1234567890', messages[0].Sender__c);
        System.assertEquals('Me', messages[0].Receiver__c);
        System.assertEquals('Image Received from 1234567890', messages[0].Message_Body__c);
        System.assertEquals('Received', messages[0].Status__c);
        System.assertEquals('image', messages[0].Type__c);
    }
    
    @isTest
    static void testHandleWebhookVideoMessage() {
        MockHttpResponseGenerator mock = new MockHttpResponseGenerator();
        Test.setMock(HttpCalloutMock.class, mock);
        
        String videoMessagePayload = '{"object":"whatsapp_business_account","entry":[{"id":"12345","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"1234567890","phone_number_id":"987654321"},"contacts":[{"profile":{"name":"Test User"},"wa_id":"1234567890"}],"messages":[{"from":"1234567890","id":"wamid.123","timestamp":"1654321098","video":{"id":"12345","mime_type":"video/mp4"}}]},"field":"messages"}]}]}';
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/whatsappwebhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(videoMessagePayload);
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        WhatsAppWebhookHandler.handleWebhook();
        Test.stopTest();
        
        List<ContentVersion> contentVersions = [SELECT Title, PathOnClient FROM ContentVersion WHERE Title = 'WhatsApp Video from 1234567890'];
        System.assertEquals(1, contentVersions.size());
        System.assertEquals('whatsapp_video.mp4', contentVersions[0].PathOnClient);
        
        List<Message__c> messages = [SELECT Sender__c, Receiver__c, Message_Body__c, Status__c, Type__c FROM Message__c WHERE Type__c = 'video'];
        System.assertEquals(1, messages.size());
        System.assertEquals('1234567890', messages[0].Sender__c);
        System.assertEquals('Me', messages[0].Receiver__c);
        System.assertEquals('Video Received from 1234567890', messages[0].Message_Body__c);
        System.assertEquals('Received', messages[0].Status__c);
    }
    
    @isTest
    static void testHandleWebhookDocumentMessage() {
        MockHttpResponseGenerator mock = new MockHttpResponseGenerator();
        Test.setMock(HttpCalloutMock.class, mock);
        
        String docMessagePayload = '{"object":"whatsapp_business_account","entry":[{"id":"12345","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"1234567890","phone_number_id":"987654321"},"contacts":[{"profile":{"name":"Test User"},"wa_id":"1234567890"}],"messages":[{"from":"1234567890","id":"wamid.123","timestamp":"1654321098","document":{"id":"12345","mime_type":"application/pdf"}}]},"field":"messages"}]}]}';
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/whatsappwebhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(docMessagePayload);
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        WhatsAppWebhookHandler.handleWebhook();
        Test.stopTest();
        
        List<ContentVersion> contentVersions = [SELECT Title, PathOnClient FROM ContentVersion WHERE Title = 'WhatsApp Document from 1234567890'];
        System.assertEquals(1, contentVersions.size());
        System.assertEquals('whatsapp_document.pdf', contentVersions[0].PathOnClient);
        
        List<Message__c> messages = [SELECT Sender__c, Receiver__c, Message_Body__c, Status__c, Type__c FROM Message__c WHERE Type__c = 'document'];
        System.assertEquals(1, messages.size());
        System.assertEquals('1234567890', messages[0].Sender__c);
        System.assertEquals('Me', messages[0].Receiver__c);
        System.assertEquals('Document Received from 1234567890', messages[0].Message_Body__c);
        System.assertEquals('Received', messages[0].Status__c);
    }
    
    @isTest
    static void testHandleWebhookWithInvalidPayload() {
        String invalidPayload = '{"invalid": "json';
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/whatsappwebhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(invalidPayload);
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        WhatsAppWebhookHandler.handleWebhook();
        Test.stopTest();
        
        List<Message__c> messages = [SELECT Id FROM Message__c];
        System.assertEquals(0, messages.size());
    }
    
    @isTest
    static void testFetchAndSaveMediaFailedURL() {
        MockHttpResponseFailedURLGenerator mock = new MockHttpResponseFailedURLGenerator();
        Test.setMock(HttpCalloutMock.class, mock);
        
        Test.startTest();
        WhatsAppWebhookHandler.fetchAndSaveMedia('12345', '1234567890', 'image/jpeg', 'image');
        Test.stopTest();
        
        List<ContentVersion> contentVersions = [SELECT Id FROM ContentVersion];
        System.assertEquals(0, contentVersions.size());
        
        List<Message__c> messages = [SELECT Id FROM Message__c];
        System.assertEquals(0, messages.size());
    }
    
    @isTest
    static void testFetchAndSaveMediaFailedDownload() {
        MockHttpResponseFailedDownloadGenerator mock = new MockHttpResponseFailedDownloadGenerator();
        Test.setMock(HttpCalloutMock.class, mock);
        
        Test.startTest();
        WhatsAppWebhookHandler.fetchAndSaveMedia('12345', '1234567890', 'image/jpeg', 'image');
        Test.stopTest();
        
        List<ContentVersion> contentVersions = [SELECT Id FROM ContentVersion];
        System.assertEquals(0, contentVersions.size());
        
        List<Message__c> messages = [SELECT Id FROM Message__c];
        System.assertEquals(0, messages.size());
    }
    
    @isTest
    static void testGetFileExtensionFromMimeType() {
        System.assertEquals('.jpg', WhatsAppWebhookHandler.getFileExtensionFromMimeType('image/jpeg'));
        System.assertEquals('.mp4', WhatsAppWebhookHandler.getFileExtensionFromMimeType('video/mp4'));
        System.assertEquals('.pdf', WhatsAppWebhookHandler.getFileExtensionFromMimeType('application/pdf'));
        System.assertEquals('.txt', WhatsAppWebhookHandler.getFileExtensionFromMimeType('text/plain'));
        System.assertEquals('.bin', WhatsAppWebhookHandler.getFileExtensionFromMimeType('unknown/type'));
    }
    
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            
            if (request.getEndpoint().contains('graph.facebook.com')) {
                response.setBody('{"url":"https://media.example.com/media/12345"}');
            } 
            else if (request.getEndpoint().contains('media.example.com')) {
                response.setBodyAsBlob(Blob.valueOf('test media content'));
            }
            
            return response;
        }
    }
    
    private class MockHttpResponseFailedURLGenerator implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(404);
            response.setBody('{"error": "Not found"}');
            return response;
        }
    }
    
    private class MockHttpResponseFailedDownloadGenerator implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            
            if (request.getEndpoint().contains('graph.facebook.com')) {
                response.setStatusCode(200);
                response.setBody('{"url":"https://media.example.com/media/12345"}');
            } 
            else if (request.getEndpoint().contains('media.example.com')) {
                response.setStatusCode(404);
                response.setBody('{"error": "Media not found"}');
            }
            
            return response;
        }
    }
}