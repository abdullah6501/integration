public with sharing class InvoiceItemWrapper {
    @AuraEnabled public String invItemId;
    @AuraEnabled public String key;
    @AuraEnabled public Date serviceDate;
    @AuraEnabled public String pdtId;
    @AuraEnabled public Boolean isKnownPdt;
    @AuraEnabled public String pdtDraftName;
    @AuraEnabled public String hsn;
    @AuraEnabled public String description;
    @AuraEnabled public String discountReason;
    @AuraEnabled public Decimal qty;
    @AuraEnabled public Decimal rate;
    @AuraEnabled public Decimal amt;
    @AuraEnabled public String tax;
    @AuraEnabled public String taxId;
    @AuraEnabled public String taxCategory;
    @AuraEnabled public String taxExemptionReason;
    @AuraEnabled public String taxLabel;
    @AuraEnabled public Decimal taxAmt;
    @AuraEnabled public Decimal amtWithTax;
    @AuraEnabled public Decimal paidAmount;
    @AuraEnabled public Decimal discountAmount;
    @AuraEnabled public Decimal discountPercentage;
    @AuraEnabled public Decimal beforeDisAmount;
    @AuraEnabled public Decimal taxAmount;
}