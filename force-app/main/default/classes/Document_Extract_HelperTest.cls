@isTest
public class Document_Extract_HelperTest {

    @isTest
    static void testExtractDocUrl_NewLink() {
        // Create test ContentVersion
        ContentVersion cv = new ContentVersion();
        cv.Title = 'TestDocument';
        cv.PathOnClient = 'TestDocument.pdf';
        cv.VersionData = Blob.valueOf('Test Content');
        insert cv;

        // Retrieve the associated ContentDocumentId
        ContentVersion insertedCv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
        String docId = insertedCv.ContentDocumentId;

        Test.startTest();
        String resultUrl = Document_Extract_Helper.extract_doc_url(docId);
        Test.stopTest();

        System.assertNotEquals(null, resultUrl, 'The returned URL should not be null');
    }

   
}