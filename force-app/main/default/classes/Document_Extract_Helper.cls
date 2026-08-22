// Thoufic-28JUL25 to extract document download link
public with sharing class Document_Extract_Helper {
    @AuraEnabled
    public static String extract_doc_url (String docId) {
        System.debug('docId: ' + docId);
        
        try {
            ContentVersion version = [SELECT Id, Title, ContentDocumentId, FileExtension FROM ContentVersion WHERE ContentDocumentId = :docId LIMIT 1];
            String viewTitle = version.Title;
            String DocExtension = version.FileExtension;

            String viewUrl = viewTitle + '.' + DocExtension;
            System.debug('Preview URL: title :  ' + viewUrl);

            
            // Check if a public link already exists
            List<ContentDistribution> existingLinks = [
                SELECT Id, Name, DistributionPublicUrl
                FROM ContentDistribution
                WHERE ContentDocumentId = :docId
                AND PreferencesAllowViewInBrowser = true
                LIMIT 1
            ];

            if (!existingLinks.isEmpty()) {
                system.debug('existing doc'+ existingLinks[0].DistributionPublicUrl);
            }

            // Create new public link
            ContentDistribution cd = new ContentDistribution();
            cd.Name = version.Title;
            cd.ContentVersionId = version.Id;
            cd.PreferencesAllowViewInBrowser = true;
            cd.PreferencesAllowOriginalDownload = true;
            insert cd;

            ContentDistribution cdWithUrl = [
                SELECT Id, DistributionPublicUrl, ContentDownloadUrl
                FROM ContentDistribution
                WHERE Id = :cd.Id
                LIMIT 1
            ];
            System.debug('Download Link: ' + cdWithUrl.ContentDownloadUrl);

            return cdWithUrl.ContentDownloadUrl;
        } catch (Exception e) {
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }
    public Document_Extract_Helper() {

    }
}