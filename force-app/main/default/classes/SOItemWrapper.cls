public class SOItemWrapper {
    @AuraEnabled
    public Id id { get; set; }
    
    @AuraEnabled
    public Id productId { get; set; }
    
    @AuraEnabled
    public String productName { get; set; }
    
    @AuraEnabled
    public String productSku { get; set; }
    
    @AuraEnabled
    public Decimal stockAvailable { get; set; }
    
    @AuraEnabled
    public Decimal listingPrice { get; set; }
    
    @AuraEnabled
    public Decimal quantity { get; set; }
    
    @AuraEnabled
    public String taxPercentage { get; set; }
    
    @AuraEnabled
    public Decimal unitPrice { get; set; }
    
    @AuraEnabled
    public Decimal discountAmount { get; set; }
    
    @AuraEnabled
    public Decimal discountPercentage { get; set; }
    
    @AuraEnabled
    public String salesOrderDiscountType { get; set; }
    
    @AuraEnabled
    public String discountType { get; set; }
    
    @AuraEnabled
    public Decimal key { get; set; }

    @AuraEnabled
    public List<Object> searchResults { get; set; }
    
    public SOItemWrapper() {}
    
    public SOItemWrapper(SO_Items__c item) {
        this.id = item.Id;
        this.productId = item.Product__c;
        this.productName = item.Product__r?.Name;
        this.productSku = item.Product__r?.SKU__c;
        this.stockAvailable = item.Product__r?.Stock_Available__c;
        this.listingPrice = item.Product__r?.Listing_Price__c;
        this.quantity = item.Quantity__c;
        this.taxPercentage = item.Tax_Percentage__c;
        this.unitPrice = item.Unit_Price__c;
        this.discountAmount = item.Discount_Amount__c;
        this.discountPercentage = item.Discount_Percentage__c;
        this.salesOrderDiscountType = item.Sales_Order__r?.Discount_Type__c;
        this.discountType = item.Discount_Type__c;
        this.key = item.Key__c;
    }
}