public with sharing class BillItemWrapper {
    @AuraEnabled public String itemOrder { get; set; }
    @AuraEnabled public Id productId { get; set; }
    @AuraEnabled public String description { get; set; }
    @AuraEnabled public Decimal unitPrice { get; set; }
    @AuraEnabled public Decimal quantity { get; set; }
    @AuraEnabled public Integer keyField; 
    @AuraEnabled public Id taxRate { get; set; } // This will be percentage from UI (e.g., 2 for 2%)
    @AuraEnabled public Decimal subtotal { get; set; }
    @AuraEnabled public Decimal taxAmount { get; set; }
    @AuraEnabled public Decimal totalAmount { get; set; }
    @AuraEnabled public List<String> selectedSerialNumbers { get; set; }

    public BillItemWrapper() {
        this.selectedSerialNumbers = new List<String>();
    }

    public BillItemWrapper(Bill_Item__c billItem) {
        this.itemOrder = String.valueOf(billItem.Item_Order__c);
        this.productId = billItem.Product__c;
        this.description = billItem.Description__c;
        this.unitPrice = billItem.Unit_Price__c;
        this.quantity = billItem.Quantity__c;
        // Convert from decimal to percentage for UI display (0.02 becomes 2)
        this.taxRate = billItem.Tax__c != null ? billItem.Tax__c  : null;
        this.subtotal = (this.unitPrice != null && this.quantity != null) ? this.unitPrice * this.quantity : 0;
        this.taxAmount = (this.subtotal != null && billItem.Tax_Rate__c != null) ? this.subtotal * billItem.Tax_Rate__c : 0;
        this.totalAmount = this.subtotal + this.taxAmount;
        this.selectedSerialNumbers = new List<String>();
    }
}