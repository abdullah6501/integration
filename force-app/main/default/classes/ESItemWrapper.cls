// AR 1/07/2025 Added description
public with sharing class ESItemWrapper {
        @AuraEnabled public String id { get; set; } 
        @AuraEnabled public String Name { get; set; }
        @AuraEnabled public String productId { get; set; }
        @AuraEnabled public String productName { get; set; }
        @AuraEnabled public String productSku { get; set; }
        @AuraEnabled public String leadTime { get; set; }
        @AuraEnabled public Double productQuantity { get; set; }
        @AuraEnabled public Double stockAvailable { get; set; }
        @AuraEnabled public Double listingPrice { get; set; }
        @AuraEnabled public Double actualCost { get; set; }
        @AuraEnabled public Double quantity { get; set; }
        @AuraEnabled public String tax { get; set; }
        @AuraEnabled public Decimal taxPercent { get; set; } 
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public Double unitPrice { get; set; }
        @AuraEnabled public Double discountAmount { get; set; }
        @AuraEnabled public Double discountPercentage { get; set; }
        @AuraEnabled public String EstimationitemDiscountType { get; set; }
        @AuraEnabled public String discountMode { get; set; }
        @AuraEnabled public Double keyField { get; set; }
        
        public ESItemWrapper() {}
        
        public ESItemWrapper(Estimation_Item__c  ESItem) {
            this.id = ESItem.Id != null ? (String) ESItem.Id : null;
            this.Name= ESItem.Name;
            this.productId = ESItem.Product__c != null ? (String) ESItem.Product__c : null;
            this.productName = ESItem.Product__r?.Name;
            this.productSku = ESItem.Product__r?.SKU__c;
            this.productQuantity = ESItem.Product__r?.Product_Quantity__c != null ? Double.valueOf(ESItem.Product__r.Product_Quantity__c) : null;
            this.stockAvailable = ESItem.Product__r?.Stock_Available__c != null ? Double.valueOf(ESItem.Product__r.Stock_Available__c) : null;
            this.listingPrice = ESItem.Product__r?.Listing_Price__c != null ? Double.valueOf(ESItem.Product__r.Listing_Price__c) : null;
            this.actualCost = ESItem.Product__r?.Actual_Cost__c != null ? Double.valueOf(ESItem.Product__r.Actual_Cost__c) : null;
            this.quantity = ESItem.Quantity__c != null ? Double.valueOf(ESItem.Quantity__c) : null;
            this.tax = ESItem.Tax__c;
            this.taxPercent = ESItem.Tax_Percentage__c;
            this.description = ESItem.Description__c;
            this.leadTime = ESItem.Lead_Time__c != null ? (String) ESItem.Lead_Time__c : null;
            this.unitPrice = ESItem.Unit_Price__c != null ? Double.valueOf(ESItem.Unit_Price__c) : null;
            this.discountAmount = ESItem.Discount_Amount__c != null ? Double.valueOf(ESItem.Discount_Amount__c) : null;
            this.discountPercentage = ESItem.Discount_Percentage__c != null ? Double.valueOf(ESItem.Discount_Percentage__c) : null;
            this.EstimationitemDiscountType = ESItem.Estimation__r?.Discount_Type__c;
            this.discountMode = ESItem.Discount_Type__c ;
            this.keyField = ESItem.key__c != null ? Double.valueOf(ESItem.key__c) : null;
        }
        
        // public  Estimation_Item__c  toESItem(String EstimationId) {
        //     Estimation_Item__c  ESItem = new Estimation_Item__c ();
        //     if (String.isNotBlank(this.id)) {
        //         ESItem.Id = this.id;
        //     }
        //     else{
        //         ESItem.Estimation__c = EstimationId;
        //     }
            
        //     if (String.isNotBlank(this.productId)) {
        //         ESItem.Product__c = this.productId;
        //     }
        //     ESItem.Quantity__c = this.quantity != null ? Decimal.valueOf(this.quantity) : null;
        //     ESItem.Tax__c = this.taxPercentage;
        //     EsItem.Description__c = this.description;
        //     ESItem.Lead_Time__c = this.leadTime;
        //     ESItem.Unit_Price__c = this.unitPrice != null ? Decimal.valueOf(this.unitPrice) : null;
        //     ESItem.Discount_Amount__c = this.discountAmount != null ? Decimal.valueOf(this.discountAmount) : null;
        //     ESItem.Discount_Percentage__c = this.discountPercentage != null ? Decimal.valueOf(this.discountPercentage) : null;
        //     ESItem.Discount_Type__c  = this.discountMode;
        //     ESItem.key__c = this.keyField != null ? Decimal.valueOf(this.keyField) : null;
        //     ESItem.Unit_of_Measure__c = 'Each';
        //     return ESItem;
        // }
        public Estimation_Item__c toESItem(String EstimationId) {
            Estimation_Item__c ESItem = new Estimation_Item__c();
            
            // Handle ID conversion safely
            if (String.isNotBlank(this.id)) {
                try {
                    ESItem.Id = (Id)this.id;
                } catch (Exception e) {
                    System.debug('Invalid ID format: ' + this.id);
                    // Continue without setting Id for new items
                }
            }
        
            if (String.isBlank(this.id)) {
                ESItem.Estimation__c = EstimationId;
            }
            
            if (String.isNotBlank(this.productId)) {
                ESItem.Product__c = this.productId;
            }
            EsItem.Name = this.productName;
            ESItem.Quantity__c = this.quantity != null ? Decimal.valueOf(this.quantity) : null;
            if(String.isNotBlank(this.tax)) {
                ESItem.Tax__c = this.tax; // Assuming tax is a string representation of the percentage
            }
            else{
                ESItem.Tax__c = null; 
            }
            //ESItem.Tax__c = this.tax ?? null; 
            ESItem.Description__c = this.description;
            ESItem.Lead_Time__c = this.leadTime;
            ESItem.Unit_Price__c = this.unitPrice != null ? Decimal.valueOf(this.unitPrice) : null;
            ESItem.Discount_Amount__c = this.discountAmount != null ? Decimal.valueOf(this.discountAmount) : null;
            ESItem.Discount_Percentage__c = this.discountPercentage != null ? Decimal.valueOf(this.discountPercentage) : null;
            ESItem.Discount_Type__c = this.discountMode;
            ESItem.key__c = this.keyField != null ? Decimal.valueOf(this.keyField) : null;
            ESItem.Tax_Percentage__c = this.taxPercent;
            ESItem.Unit_of_Measure__c = 'Each';
            
            return ESItem;
        }
}