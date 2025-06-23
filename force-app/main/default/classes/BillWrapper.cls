public with sharing class BillWrapper {
        @AuraEnabled public Id billId { get; set; }
        @AuraEnabled public String billNumber { get; set; }
        @AuraEnabled public Decimal totalCost { get; set; }
        @AuraEnabled public Decimal paidCost { get; set; }
        @AuraEnabled public Decimal dueBalance { get; set; }
        @AuraEnabled public String lastPaidDate { get; set; }
        @AuraEnabled public Decimal paymentAmount {get;set;}
        
        public BillWrapper() {
        }
        public BillWrapper(Bill__c bill) {
            this.billId = bill.Id;
            this.billNumber = bill.Name;
            this.totalCost = bill.Total_Amount__c;
            this.paidCost = bill.Paid_Amount__c;
            this.dueBalance = bill.Balance_Due__c;
            this.lastPaidDate = bill.LastModifiedDate?.date()?.format();
            this.paymentAmount = 0;
        }
}