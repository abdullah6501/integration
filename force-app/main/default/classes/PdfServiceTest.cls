@isTest
public class PdfServiceTest {
    
    @testSetup
    static void setupData() {
        insert new BatchLabelPDF__c(Name = 'Default', PDFGenerateEndpoint__c = 'https://mockendpoint.com/generatePdf');
    }

    @isTest
    static void testFetchAndStorePDF_Success() {
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        String relatedRecordId = testAccount.Id;

        Test.startTest();
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, '{"success": true, "data": "JVBERi0xLjQKJf////0K"}'));

        Map<String, Object> result = PdfService.fetchAndStorePDF('{"key":"value"}', relatedRecordId);
        
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Expected success response');
    }

    @isTest
    static void testFetchAndStorePDF_CustomSettingMissing() {
        delete [SELECT Id FROM BatchLabelPDF__c];

        Test.startTest();
        Map<String, Object> result = PdfService.fetchAndStorePDF('{"key":"value"}', '001XXXXXXXXXXXXXXX');
        Test.stopTest();

        System.assertEquals(false, result.get('success'), 'Expected failure due to missing custom setting');
        System.assertEquals('PDF Generate Endpoint not configured in Custom Settings.', result.get('message'));
    }

    @isTest
    static void testFetchAndStorePDF_EmptyBase64Data() {
        Test.startTest();
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, '{"success": true, "data": ""}'));

        Map<String, Object> result = PdfService.fetchAndStorePDF('{"key":"value"}', '001XXXXXXXXXXXXXXX');
        
        Test.stopTest();

        System.assertEquals(false, result.get('success'));
        System.assertEquals('Base64 data is empty.', result.get('message'));
    }

    @isTest
    static void testFetchAndStorePDF_APIResponseUnsuccessful() {
        Test.startTest();
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, '{"success": false}'));

        Map<String, Object> result = PdfService.fetchAndStorePDF('{"key":"value"}', '001XXXXXXXXXXXXXXX');
        
        Test.stopTest();

        System.assertEquals(false, result.get('success'));
        System.assertEquals('API Response unsuccessful.', result.get('message'));
    }

    @isTest
    static void testFetchAndStorePDF_HTTPError() {
        Test.startTest();
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(500, ''));

        Map<String, Object> result = PdfService.fetchAndStorePDF('{"key":"value"}', '001XXXXXXXXXXXXXXX');
        
        Test.stopTest();

        System.assert(result.get('message') != null && ((String) result.get('message')).contains('HTTP Error: 500'), 'Expected HTTP error message');
    }

    @isTest
    static void testFetchAndStorePDF_ExceptionHandling() {
        Test.startTest();
        
        BatchLabelPDF__c settings = [SELECT Id FROM BatchLabelPDF__c LIMIT 1];
        settings.PDFGenerateEndpoint__c = 'invalid-url';
        update settings;

        Map<String, Object> result = PdfService.fetchAndStorePDF('{"key":"value"}', '001XXXXXXXXXXXXXXX');
        
        Test.stopTest();

        System.assert(result.get('message') != null && ((String) result.get('message')).contains('Exception'), 'Expected exception handling message');
    }
}