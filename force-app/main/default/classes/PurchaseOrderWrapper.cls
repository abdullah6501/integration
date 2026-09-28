public with sharing class PurchaseOrderWrapper {
    @AuraEnabled public String id { get; set; }
    @AuraEnabled public String poName { get; set; }
    @AuraEnabled public Date requiredDate { get; set; }
    @AuraEnabled public String status { get; set; }
    @AuraEnabled public String poType { get; set; }
    @AuraEnabled public String title { get; set; }
    @AuraEnabled public Id vendorId { get; set; }
    @AuraEnabled public String vendorShippingTerm { get; set; }
    @AuraEnabled public String shippingTerms { get; set; }
    @AuraEnabled public String paymentTerms { get; set; }
    @AuraEnabled public String discountType { get; set; }
    @AuraEnabled public String discountMode { get; set; }
    @AuraEnabled public Decimal lumpsumDiscountAmount { get; set; }
    @AuraEnabled public Decimal lumpsumDiscountPercentage { get; set; }
    @AuraEnabled public String taxPercentage { get; set; }
    @AuraEnabled public List<POItemWrapper> poItems { get; set; }
    @AuraEnabled public String supplierName { get; set; }
    @AuraEnabled public String supplierNameField { get; set; }

    public PurchaseOrderWrapper() {
        this.poItems = new List<POItemWrapper>();
    }
    
    public PurchaseOrderWrapper(Purchase_Order__c po) {
        // Change this line to use toString()
        this.id = po.Id?.toString();
        this.supplierName = po.Supplier__r?.Name;
        this.supplierNameField = po.Vendor_Account__r?.Name;
        this.shippingTerms = po.Shipping_Terms__c;//po.Vendor_Account__r?.Shipping_Terms__c;
       // this.paymentTerms = po.Payment_Terms__c;//po.Vendor_Account__r?.Payment_Terms__c;
        this.lumpsumDiscountAmount = po.Lumpsum_Discount_Amount__c;
        this.lumpsumDiscountPercentage = po.Lumpsum_Discount_Percentage__c;
        this.discountMode = po.Discount_Mode__c;
        this.discountType = po.Discount_Type__c;
        this.taxPercentage = po.Tax_Percentage__c;
        this.poName = po.Name;
        this.requiredDate = po.Required_Date__c;
        this.status = po.Status__c;
        this.poType = po.PO_Type__c;
        this.title = po.Title__c;
        this.vendorId = po.Vendor_Account__c;
        this.vendorShippingTerm=po.Vendor_Account__r.Shipping_Terms__c;
        this.poItems = new List<POItemWrapper>();
    }
    
    public Purchase_Order__c toPurchaseOrder() {
        Id purchaseOrderId = null;
        if (this.id != null) {
            try {
                purchaseOrderId = (Id)this.id;
            } catch (Exception e) {
                // Handle invalid ID conversion
                System.debug('Invalid ID format: ' + this.id);
            }
        }
        
        return new Purchase_Order__c(
            Id = purchaseOrderId,
            Name = this.poName,
            Required_Date__c = this.requiredDate,
            Status__c = this.status,
            PO_Type__c = this.poType,
            Title__c = this.title,
            Vendor_Account__c = this.vendorId,
            Shipping_Terms__c = this.shippingTerms,
            Discount_Type__c = this.discountType,
            Discount_Mode__c = this.discountMode,
            Lumpsum_Discount_Amount__c = this.lumpsumDiscountAmount,
            Lumpsum_Discount_Percentage__c = this.lumpsumDiscountPercentage,
            Tax_Percentage__c = this.taxPercentage
        );
    }
}