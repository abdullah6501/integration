public class PDFGenerationJob implements Queueable, Database.AllowsCallouts {
    private Id recordId;

    public PDFGenerationJob(Id recordId) {
        this.recordId = recordId;
    }

    public void execute(QueueableContext context) {
        PDFHelper.generatePDF(recordId);
    }
}