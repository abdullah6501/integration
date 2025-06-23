public with sharing class InvoicePaymentController {
    
    @AuraEnabled(cacheable=true)
    public static String getInvoicePaymentDetails(Id recordId) {
    // public static InvoicePaymentWrapper getInvoicePaymentDetails(Id recordId) {
        // Invoice__c inv = [SELECT Name, Account__r.Name, Due_Amount__c, Early_Paid__c 
        //                   FROM Invoice__c WHERE Id = :recordId LIMIT 1];

        // InvoicePaymentWrapper wrapper = new InvoicePaymentWrapper();
        // wrapper.invoiceName = inv.Name;
        // wrapper.accountName = inv.Account__r.Name;
        // wrapper.dueBalance = inv.Due_Amount__c;
        // wrapper.earlyPaidAmount = inv.Early_Paid__c;
        // wrapper.recordId = recordId;

        // return wrapper;
        return 'hi';
    }

    @AuraEnabled
    public static void saveInvoicePayment(Id recordId, Decimal paymentCost, String paymentMode, Date paymentDate, Decimal bankCharges) {
        // Save to custom Payment object or update Invoice__c as needed
        // Payment__c pay = new Payment__c(
        //     Invoice__c = recordId,
        //     Payment_Amount__c = paymentCost,
        //     Payment_Mode__c = paymentMode,
        //     Payment_Date__c = paymentDate,
        //     Bank_Charges__c = bankCharges
        // );
        // insert pay;
    }
}
