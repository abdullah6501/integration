public with sharing class VATReportHandler {
    
    @AuraEnabled(cacheable=true)
    public static List<TaxDetailWrapper> getVATTaxDetails(Date startDate, Date endDate) { 
        List<TaxDetailWrapper> wrapperList = new List<TaxDetailWrapper>();

        List<Tax_Detail__c> taxDetails = [
            SELECT Id,
                   Tax__c,
                   Tax__r.Name,
                   Tax_Percentage__c,
                   Invoice__c,
                   Invoice__r.Name,
                   Bill__c,
                   Bill__r.Name,
                   Bill__r.Total_Amount__c,
                   Invoice__r.Total_Amount__c,
                   Amount__c,
                   Type__c,
                   Is_RCM__c,
                   CreatedDate
            FROM Tax_Detail__c 
            WHERE (Tax__r.Name LIKE :('%VAT%') OR Tax__r.Name LIKE :('%RCM%'))
              AND CreatedDate >= :startDate 
              AND CreatedDate <= :endDate
        ];
        System.debug('Tax Details: ' + taxDetails);
        for (Tax_Detail__c tax : taxDetails) {
            wrapperList.add(new TaxDetailWrapper(tax));
        }
        
        return wrapperList;
    }
    
    public class TaxDetailWrapper {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String taxId { get; set; }
        @AuraEnabled public String taxName { get; set; }
        @AuraEnabled public Decimal taxPercentage { get; set; }
        @AuraEnabled public String invoiceId { get; set; }
        @AuraEnabled public String invoiceName { get; set; }
        @AuraEnabled public Decimal amount { get; set; }
        @AuraEnabled public String type { get; set; }
        @AuraEnabled public Decimal total { get; set; }
        @AuraEnabled public Decimal billtotal { get; set; }
        @AuraEnabled public DateTime createdDate { get; set; }
        @AuraEnabled public Boolean isRCM { get; set; }
        @AuraEnabled public String billId { get; set; } 
        @AuraEnabled public String billName { get; set; } 
        public TaxDetailWrapper() {}

        public TaxDetailWrapper(Tax_Detail__c tax) {
            this.id = tax.Id;
            this.taxId = tax.Tax__c;
            this.taxName = tax.Tax__r?.Name;
            this.billId = tax.Bill__c;
            this.billName = tax.Bill__r?.Name;
            this.taxPercentage = tax.Tax_Percentage__c;
            this.invoiceId = tax.Invoice__c;
            this.invoiceName = tax.Invoice__r?.Name;
            this.amount = tax.Amount__c;
            this.total = tax.Invoice__r?.Total_Amount__c != null ? tax.Invoice__r.Total_Amount__c : 0.00;
            this.billtotal = tax.Bill__r?.Total_Amount__c != null ? tax.Bill__r.Total_Amount__c : 0.00;
            this.isRCM = tax.Is_RCM__c;
            this.type = tax.Type__c;
            this.createdDate = tax.CreatedDate;
        }
        
        public Tax_Detail__c toTaxDetail() {
            return new Tax_Detail__c(
                Id = this.id,
                Tax__c = this.taxId,
                Tax_Percentage__c = this.taxPercentage,
                Invoice__c = this.invoiceId,
                Bill__c = this.billId,
                Amount__c = this.amount,
                Type__c = this.type,
                Is_RCM__c = this.isRCM
            );
        }
    }
}