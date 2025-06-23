public class PDFHelper {
    public static void generatePDF(Id recordId) {
        try {
            PageReference pdfPage = Page.PdfBackend;
            pdfPage.getParameters().put('id', recordId);

            Blob pdfBlob = pdfPage.getContentAsPDF();

            ContentVersion contentVersion = new ContentVersion();
            System.debug('one');
            contentVersion.Title = 'Message PDF - ' + recordId;
            System.debug('two');
            contentVersion.PathOnClient = 'MessageDetails.pdf';
            System.debug('three');
            contentVersion.VersionData = pdfBlob;
            System.debug('four');
            contentVersion.IsMajorVersion = true;
            System.debug('five');
            insert contentVersion;
            System.debug('insert successfully');
        } catch (Exception e) {
            System.debug('Error generating PDF: ' + e.getMessage());
        }
    }
}