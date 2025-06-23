public class InvoicePaymentWrapper {
    @AuraEnabled public String invoiceName;
    @AuraEnabled public String accountName;
    @AuraEnabled public Decimal dueBalance;
    @AuraEnabled public Decimal earlyPaidAmount;
    @AuraEnabled public String recordId;
}
