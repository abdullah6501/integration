public with sharing class BillWrapper {
    @AuraEnabled public Id billId { get; set; }// Used for both insert and update
    @AuraEnabled public String billNumber { get; set; }
    @AuraEnabled public Decimal totalCost { get; set; }
    @AuraEnabled public Decimal paidCost { get; set; }
    @AuraEnabled public Decimal dueBalance { get; set; }
    @AuraEnabled public String lastPaidDate { get; set; }
    @AuraEnabled public String name { get; set; }
    @AuraEnabled public String amountsAre { get; set; }
    @AuraEnabled public String currencycode { get; set; }
    @AuraEnabled public Id vendorId { get; set; }
    @AuraEnabled public String vendorName { get; set; }
    @AuraEnabled public Id contractId { get; set; }
    @AuraEnabled public Id rfqId { get; set; }
    @AuraEnabled public Date billDate { get; set; }
    @AuraEnabled public Date dueDate { get; set; }
    @AuraEnabled public String status { get; set; }
    @AuraEnabled public Decimal grandTotal { get; set; }
    @AuraEnabled public Boolean isRCM { get; set; }
    @AuraEnabled public Boolean createJournalEntry { get; set; }
    @AuraEnabled public List<BillItemWrapper> billItems { get; set; }
    @AuraEnabled public Decimal paymentAmount {get;set;}
    @AuraEnabled public List<DocumentWrapper> document { get; set; }
    @AuraEnabled public String message { get; set; } // For Message_Of_Bill__c
    
    public BillWrapper() {
        this.billItems = new List<BillItemWrapper>();
        document = new List<DocumentWrapper>();
        //this.document = null;
        this.message = '';
    }
    //AB 26JUN25 added file extension and file type to DocumentWrapper
    public BillWrapper(Bill__c bill) {
        this.billId = bill.Id;
        this.billNumber = bill.Name;
        this.amountsAre = bill.Amounts_Are__c;
        this.isRCM = bill.Is_RCM__c;
        this.name = bill.Name;
        this.vendorId = bill.VendorAccount__c;
        this.vendorName = bill.VendorAccount__r.Name;
        this.contractId = bill.Contract__c;
        this.rfqId = bill.RFQ__c;
        this.billDate = bill.Bill_Date__c;
        this.dueDate = bill.Due_Date__c;
        this.status = bill.Status__c;
        this.createJournalEntry = bill.Create_Journal_Entry__c;
        this.totalCost = bill.Total_Amount__c;
        this.paidCost = bill.Paid_Amount__c;
        this.dueBalance = bill.Balance_Due__c;
        this.lastPaidDate = bill.LastModifiedDate?.date()?.format();
        this.billItems = new List<BillItemWrapper>();
        this.paymentAmount = 0;
        this.message = bill.Message_Of_Bill__c;
        // Initialize DocumentWrapper if there's an associated file
        if (bill.ContentDocumentLinks != null && !bill.ContentDocumentLinks.isEmpty()) {
            this.document = new List<DocumentWrapper>();
            for(ContentDocumentLink cdl : bill.ContentDocumentLinks) {
                this.document.add(new DocumentWrapper(
                    cdl.ContentDocumentId,
                    cdl.ContentDocument.Title,
                    this.billDate,
                    this.totalCost,
                    this.vendorName,
                    cdl.ContentDocument.FileExtension,
                    cdl.ContentDocument.FileType
                ));
            }
        }
    }
}