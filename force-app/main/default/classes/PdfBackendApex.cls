public with sharing class PdfBackendApex {
    public Message__c record { get; private set; }

    public PdfBackendApex() {
        Id recordId = ApexPages.currentPage().getParameters().get('id');
        if (recordId != null) {
            record = [SELECT Sender__c, Receiver__c, Status__c FROM Message__c WHERE Id = :recordId LIMIT 1];
        }
    }
}