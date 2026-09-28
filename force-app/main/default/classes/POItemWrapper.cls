public with sharing class POItemWrapper {
    @AuraEnabled public String id { get; set; }
    @AuraEnabled public String productId { get; set; }
    @AuraEnabled public String productName { get; set; }
    @AuraEnabled public String productSku { get; set; }
    @AuraEnabled public Decimal productQuantity { get; set; }
    @AuraEnabled public Decimal listingPrice { get; set; }
    @AuraEnabled public Decimal actualCost { get; set; }
    @AuraEnabled public Decimal quantity { get; set; }
    @AuraEnabled public String taxPercentage { get; set; }
    @AuraEnabled public Decimal unitPrice { get; set; }
    @AuraEnabled public Decimal discountAmount { get; set; }
    @AuraEnabled public Decimal discountPercentage { get; set; }
    @AuraEnabled public String purchaseOrderDiscountType { get; set; }
    @AuraEnabled public String discountMode { get; set; }
    @AuraEnabled public Decimal keyField { get; set; }
    
    public POItemWrapper() {}
    
    public POItemWrapper(PO_Item__c poItem) {
        this.id = poItem.Id;
        this.productId = poItem.Product__c;
        this.productName = poItem.Product__r?.Name;
        this.productSku = poItem.Product__r?.SKU__c;
        this.productQuantity = poItem.Product__r?.Product_Quantity__c;
        this.listingPrice = poItem.Product__r?.Listing_Price__c;
        this.actualCost = poItem.Product__r?.Actual_Cost__c;
        this.quantity = poItem.Quantity__c;
        this.taxPercentage = poItem.Tax_Percentage__c;
        this.unitPrice = poItem.Unit_Price__c;
        this.discountAmount = poItem.Discount_Amount__c;
        this.discountPercentage = poItem.Discount_Percentage__c;
        this.purchaseOrderDiscountType = poItem.Purchase_Order__r?.Discount_Type__c;
        this.discountMode = poItem.Discount_Mode__c;
        this.keyField = poItem.key__c;
    }
    
    public PO_Item__c toPOItem(String purchaseOrderId) {
        PO_Item__c poItem = new PO_Item__c();
        if (String.isNotBlank(this.id)) {
            poItem.Id = this.id;
        } else {
            poItem.Purchase_Order__c = purchaseOrderId;
        }
        
        if (String.isNotBlank(this.productId)) {
            poItem.Product__c = this.productId;
        }
        poItem.Name = this.productName;
        poItem.Quantity__c = this.quantity;
        poItem.Tax_Percentage__c = this.taxPercentage;
        poItem.Unit_Price__c = this.unitPrice;
        poItem.Discount_Amount__c = this.discountAmount;
        poItem.Discount_Percentage__c = this.discountPercentage;
        poItem.Discount_Mode__c = this.discountMode;
        poItem.key__c = this.keyField;
        poItem.Unit_of_Measure__c = 'Each';
        
        return poItem;
    }
}