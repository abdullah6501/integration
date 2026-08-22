public class SalesOrderWrapper {
    @AuraEnabled
    public Id id { get; set; }
    
    @AuraEnabled
    public String customerName { get; set; }
    
    @AuraEnabled
    public String salesOrderName { get; set; } // Maps to Name field
    
    @AuraEnabled
    public Decimal lumpsumDiscountAmount { get; set; }
    
    @AuraEnabled
    public Decimal lumpsumDiscountPercentage { get; set; }
    
    @AuraEnabled
    public String discountMode { get; set; }
    
    @AuraEnabled
    public String discountType { get; set; }
    
    @AuraEnabled
    public String taxPercentage { get; set; }

    @AuraEnabled
    public String customerId { get; set; }

    @AuraEnabled
    public String currencyCode { get; set; }
    
    @AuraEnabled
    public String customerPoRef { get; set; }
    
    @AuraEnabled
    public String shippingTerms { get; set; }

    @AuraEnabled
    public String paymentTerms { get; set; }

    @AuraEnabled
    public Date salesDate { get; set; }

    @AuraEnabled
    public String status { get; set; }

    @AuraEnabled 
    public String type { get; set; }

    @AuraEnabled 
    public String title { get; set; }
    
    public SalesOrderWrapper() {}
    
    public SalesOrderWrapper(Sales_Order__c salesOrder) {
        this.id = salesOrder.Id;
        this.customerName = salesOrder.Customer__r?.Name;
        this.customerPoRef = salesOrder.Customer_PO_Ref__c; // AR Added customer PO ref
        this.customerId = salesOrder.Customer__c;
        this.currencyCode = salesOrder.Customer__r?.Preferred_Currency_Code__c;
        this.shippingTerms = salesOrder.Shipping_Terms__c;
        this.paymentTerms = salesOrder.Payment_Terms__c;
        this.salesDate = salesOrder.Sales_Date__c;
        this.status = salesOrder.Status__c;
        this.type = salesOrder.Sales__c;
        this.title = salesOrder.Title__c ?? '';
        this.salesOrderName = salesOrder.Name; // Map to Name field
        this.lumpsumDiscountAmount = salesOrder.Lumpsum_Discount_Amount__c;
        this.lumpsumDiscountPercentage = salesOrder.Lumpsum_Discount_Percentage__c;
        this.discountMode = salesOrder.Discount_Mode__c;
        this.discountType = salesOrder.Discount_Type__c;
        this.taxPercentage = salesOrder.Tax_Percentage__c;
    }

    public Sales_Order__c toSalesOrder() {
        Sales_Order__c so = new Sales_Order__c();

        if (this.id != null) {
            so.Id = this.id;
        }
        so.Customer__c = this.customerId;
        so.Customer_PO_Ref__c = this.customerPoRef; // AR Added customer PO ref
        so.Sales_Date__c = this.salesDate;
        so.Status__c = this.status;
        so.Sales__c = this.type;
        so.Title__c = this.title;
        so.Shipping_Terms__c = this.shippingTerms;
        so.Payment_Terms__c = this.paymentTerms;
        so.Lumpsum_Discount_Amount__c = this.lumpsumDiscountAmount;
        so.Lumpsum_Discount_Percentage__c = this.lumpsumDiscountPercentage;
        so.Discount_Mode__c = this.discountMode;
        so.Discount_Type__c = this.discountType;
        so.Tax_Percentage__c = this.taxPercentage;
        // Set Name: if user provided, use it; else use record Id (after insert/update)
        if (this.salesOrderName != null && this.salesOrderName.trim() != '') {
            so.Name = this.salesOrderName;
        } else if (this.id != null) {
            so.Name = this.id;
        }
        return so;
    }
}