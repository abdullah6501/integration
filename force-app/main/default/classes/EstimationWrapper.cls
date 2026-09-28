public with sharing class EstimationWrapper {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public Id customerId { get; set; }
        @AuraEnabled public String supplierName { get; set; }
        @AuraEnabled public String supplierNameField { get; set; }
        @AuraEnabled public String shippingTerms { get; set; }
        @AuraEnabled public String paymentTerms { get; set; }
        @AuraEnabled public String preferredCurrency { get; set; }
        @AuraEnabled public Double lumpsumDiscountAmount { get; set; }
        @AuraEnabled public Double lumpsumDiscountPercentage { get; set; }
        @AuraEnabled public String discountMode { get; set; }
        @AuraEnabled public String discountType { get; set; }
        @AuraEnabled public String taxPercentage { get; set; }
        @AuraEnabled public Decimal taxPercent { get; set; } 
        @AuraEnabled public String porefnum { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public Date quoteDate { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public List<ESItemWrapper> ESItems { get; set; }
        
        public EstimationWrapper() {
            this.ESItems = new List<ESItemWrapper>();
        }
        
        public EstimationWrapper(Estimation__c Estimtion) {
            this.id = Estimtion.Id != null ? (String) Estimtion.Id : null;
            this.customerId = Estimtion.Customer__c;
            this.supplierName = Estimtion.Customer__r?.Name;
            this.shippingTerms = Estimtion.Shipping_Terms__c;
            this.paymentTerms = Estimtion.Payment_Terms__c;
            this.preferredCurrency = Estimtion.Preferred_Currency__c;
            this.lumpsumDiscountAmount = Estimtion.Total_Discount_Amount__c  != null ? Double.valueOf(Estimtion.Total_Discount_Amount__c ) : null;
            this.lumpsumDiscountPercentage = Estimtion.Total_Discount_Percentage__c  != null ? Double.valueOf(Estimtion.Total_Discount_Percentage__c ) : null;
            this.discountMode = Estimtion.Discount_Mode__c;
            this.discountType = Estimtion.Discount_Type__c;
            this.taxPercentage = Estimtion.Tax__c;
            this.taxPercent = Estimtion.Tax_Percentage__c;
            this.porefnum = Estimtion.PO_Ref_Num__c;
            this.name = Estimtion.Name;
            this.quoteDate = Estimtion.Order_Date__c;
            this.status = Estimtion.Status__c;
            this.ESItems = new List<ESItemWrapper>();
        }
        public Estimation__c toEstimation() {
            Id estimationId = null;
            if (this.id != null) {
                try {
                    estimationId = (Id)this.id;
                } catch (Exception e) {
                    System.debug('Invalid ID format: ' + this.id);
                }
            }
            
            Estimation__c estimation = new Estimation__c(
                Id = estimationId,
                Name = this.name,
                Order_Date__c = this.quoteDate,
                Status__c = this.status,
                Customer__c = this.customerId,
                Shipping_Terms__c = this.shippingTerms,
                Payment_Terms__c = this.paymentTerms,
                Discount_Type__c = this.discountType,
                Discount_Mode__c = this.discountMode,
                Total_Discount_Amount__c = this.lumpsumDiscountAmount,
                Total_Discount_Percentage__c = this.lumpsumDiscountPercentage,
                Tax_Percentage__c = this.taxPercent,
                Preferred_Currency__c = this.preferredCurrency,
                PO_Ref_Num__c = this.porefnum
            );
            
            if (String.isNotBlank(this.taxPercentage)) {
                estimation.Tax__c = this.taxPercentage;
            }
            
            return estimation;
        }
}