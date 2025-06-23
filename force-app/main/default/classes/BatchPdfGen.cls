public class BatchPdfGen implements Database.Batchable<SObject> {
    private Id recordIds;

    public BatchPdfGen(Id recordId) {
        this.recordIds = recordId;
    }

    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([
            SELECT Id, Sender__c, Receiver__c, Status__c, Message_Body__c
            FROM Message__c
            WHERE Id =:recordIds
        ]);
    }

    public void execute(Database.BatchableContext context, List<Message__c> scope) {

        for (Message__c record : scope) {
            try {
                PageReference pdfPage = Page.Generatepdf;
                pdfPage.getParameters().put('id', record.Id);

                Blob pdfBlob = pdfPage.getContentAsPDF();
                system.debug('pdfblob');

                ContentVersion contentVersion = new ContentVersion();
                system.debug('contentversion');
                contentVersion.Title = 'Message PDF - ' + record.Id;
                System.debug('title');
                contentVersion.PathOnClient = 'MessageDetails.pdf';
                System.debug('path on client');
                contentVersion.VersionData = pdfBlob;
                System.debug('versiondata');
                contentVersion.IsMajorVersion = true;
                System.debug('ismajor version');

                insert contentVersion;
                System.debug('Inserted');
            } catch (Exception e) {
                System.debug('Error generating PDF for record: ' + record.Id + ' - ' + e.getMessage());
            }
        }
    }

    public void finish(Database.BatchableContext context) {
        System.debug('Batch processing completed.');
    }
}