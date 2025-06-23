public with sharing class InvoiceFormWrapper {
    
    @AuraEnabled public String name;
    @AuraEnabled public String invId;
    @AuraEnabled public String accId;
    @AuraEnabled public String conId;
    @AuraEnabled public String primaryConEmailAddresses;
    @AuraEnabled public String ccEmailAddresses;
    @AuraEnabled public String bccEmailAddresses;
    @AuraEnabled public String billingAddress;
    @AuraEnabled public String term;
    @AuraEnabled public String termLabel;
    @AuraEnabled public Date invoiceDate;
    @AuraEnabled public Date dueDate;
    @AuraEnabled public String placeOfSupply;
    @AuraEnabled public String authSign;
    @AuraEnabled public String invoiceType;
    @AuraEnabled public String invoiceIndicator;
    @AuraEnabled public String paymentType;
    @AuraEnabled public Date latestDeliveryDate;
    @AuraEnabled public String lumpsumDiscountReason;
    @AuraEnabled public String invoiceNameType;
    @AuraEnabled public String selectedCurrency;
    @AuraEnabled public String exchangeRate;
    @AuraEnabled public String parentTaxSelectedOption;
    @AuraEnabled public List<InvoiceItemWrapper> invoiceItemList;
    @AuraEnabled public String msgOnInv;
    @AuraEnabled public String termsAndCond;
    @AuraEnabled public String amtInWords;
    @AuraEnabled public String msgOnStmt;
    @AuraEnabled public String subTotal;
    @AuraEnabled public String total;
    @AuraEnabled public String balanceDue;
    @AuraEnabled public String totalTaxAmt;
    @AuraEnabled public String companyName;
    @AuraEnabled public String currencyCode;
    @AuraEnabled public String currencyCodeName;
    @AuraEnabled public String invStatus;
    @AuraEnabled public Decimal paidAmount;
    @AuraEnabled public String selectedDiscountType;
    @AuraEnabled public String selectedDiscountMode;
    @AuraEnabled public Decimal lumpsumDiscountPercentage;
    @AuraEnabled public Decimal lumpsumDiscountAmount;
    @AuraEnabled public Decimal amountAfterDiscount;
    
}