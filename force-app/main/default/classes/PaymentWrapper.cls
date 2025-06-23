public class PaymentWrapper {
    @AuraEnabled public Id paymentId { get; set; }
    @AuraEnabled public String name { get; set; }
    @AuraEnabled public Id accountId { get; set; }
    @AuraEnabled public Decimal totalAmount { get; set; }
    @AuraEnabled public Decimal paymentAmount1 { get; set; }
    @AuraEnabled public Decimal invoicedAmount { get; set; }
    @AuraEnabled public List<Invoice__c> invoices { get; set; }
    @AuraEnabled public String paymentType { get; set; }

    public PaymentWrapper() {
    }
    
    public PaymentWrapper(Payment__c payment) {
        this.paymentId = payment.Id;
        this.name = payment.Name;
        this.accountId = payment.Account__c;
        this.totalAmount = payment.Total_Amount1__c;
        this.invoicedAmount = payment.Invoiced_Amount__c;
        this.paymentAmount1 = payment.Payment_Amount1__c;
        this.paymentType = payment.Payment_Type__c;
    }

    public PaymentWrapper(Payment__c payment, List<Invoice__c> invoices) {
        this(payment); 
        this.invoices = invoices;
    }
}