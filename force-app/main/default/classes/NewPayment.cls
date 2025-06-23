public with sharing class NewPayment {
   // Add this method to your existing class
@AuraEnabled(cacheable=true)
public static List<AccountWrapper> searchAccounts(String searchKey) {
    List<AccountWrapper> accountWrappers = new List<AccountWrapper>();
    List<Account> accounts = [
        SELECT Id, Name
        FROM Account
        WHERE Name LIKE :('%' + searchKey + '%')
        LIMIT 10
    ];
    
    for (Account acc : accounts) {
        accountWrappers.add(new AccountWrapper(acc));
    }
    return accountWrappers;
}

// Add this wrapper class
public class AccountWrapper {
    @AuraEnabled public String id { get; set; }
    @AuraEnabled public String name { get; set; }
    
    public AccountWrapper(Account acc) {
        this.id = acc.Id;
        this.name = acc.Name;
    }
}
@AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getPicklistValue() {
        Map<String, List<String>> picklistMap = new Map<String, List<String>>();
 
        Schema.DescribeFieldResult field = Payment__c.Payment_Mode1__c.getDescribe();
 
        List<Schema.PicklistEntry> paymentmode = field.getPicklistValues();
 
        List<String> paymentOptions = new List<String>();
        for (Schema.PicklistEntry entry : paymentmode) {
            paymentOptions.add(entry.getLabel());
        }
 
        picklistMap.put('paymentOptions', paymentOptions);
        System.debug('Picklist Map: ' + JSON.serializePretty(picklistMap));
        return picklistMap;
    }
 
@AuraEnabled
public static String savePayment(String name, String paymentMode, Decimal paymentAmount, Date paymentDate, String accountId) {
    System.debug('name'+name);
    System.debug('paymentMode'+paymentMode);
    System.debug('paymentAmount'+paymentAmount);
    System.debug('paymentDate'+paymentDate);
    try {
        Payment__c payment = new Payment__c(
            Name = name,
            Payment_Mode1__c = paymentMode,
            Payment_Amount1__c = paymentAmount,
            Payment_Done_Date__c = paymentDate,
            Account__c = accountId
        );
        
        insert payment;
        return payment.Id;
    } catch(Exception e) {
        throw new AuraHandledException(e.getMessage());
    }
 }

@AuraEnabled(cacheable=true)
public static Map<String, Object> getInvoiceDetails(String invoiceId) {
        Map<String, Object> result = new Map<String, Object>();
        
        Invoice__c invoice = [
            SELECT Id, 
                Name,
                Balance_Amount_to_be_Paid__c,
                Sum_of_Paid_Amount__c,
                Account__r.Name
            FROM Invoice__c
            WHERE Id = :invoiceId
            LIMIT 1
        ];
        
        result.put('invoiceName', invoice.Name);
        result.put('dueBalance', invoice.Balance_Amount_to_be_Paid__c);
        result.put('earlyPaidAmount', invoice.Sum_of_Paid_Amount__c);
        result.put('accountName', invoice.Account__r.Name);
        
        return result;
  }
  @AuraEnabled
    public static String saveInvoicePayment(String invoiceId, Decimal paymentAmount, String paymentMode, 
                                        Date paymentDate, Decimal tdsAmount) {
        try {
            Invoice__c invoice = [
                SELECT Id, Name,Account__c
                FROM Invoice__c 
                WHERE Id = :invoiceId 
                LIMIT 1
            ];
            
            Payment__c payment = new Payment__c(
                Name = 'Payment for Invoice ' + invoice.Name,
                Payment_Mode1__c = paymentMode,
                Payment_Amount1__c = paymentAmount,
                Payment_Done_Date__c = paymentDate,
                Account__c = invoice.Account__c,
                Invoice__c = invoice.Id,
                TDS_Amount1__c = tdsAmount
            );
            
            insert payment;
            return payment.Id;
        } catch(Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
   }
}