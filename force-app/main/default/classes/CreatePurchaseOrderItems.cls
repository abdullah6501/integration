public with sharing class CreatePurchaseOrderItems {
    
    // Wrapper Classes for LWC
    public class PurchaseOrderWrapper {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String supplierName { get; set; }
        @AuraEnabled public String supplierNameField { get; set; }
        @AuraEnabled public String shippingTerms { get; set; }
        @AuraEnabled public String paymentTerms { get; set; }
        @AuraEnabled public Double lumpsumDiscountAmount { get; set; }
        @AuraEnabled public Double lumpsumDiscountPercentage { get; set; }
        @AuraEnabled public String discountMode { get; set; }
        @AuraEnabled public String discountType { get; set; }
        @AuraEnabled public String taxPercentage { get; set; }
        @AuraEnabled public List<POItemWrapper> poItems { get; set; }
        
        public PurchaseOrderWrapper() {
            this.poItems = new List<POItemWrapper>();
        }
        
        public PurchaseOrderWrapper(Purchase_Order__c po) {
            this.id = po.Id != null ? (String) po.Id : null;
            this.supplierName = po.Supplier__r?.Name;
            this.supplierNameField = po.Supplier_Name__c;
            this.shippingTerms = po.Shipping_Terms__c;
            this.paymentTerms = po.Payment_Terms__c;
            this.lumpsumDiscountAmount = po.Lumpsum_Discount_Amount__c != null ? Double.valueOf(po.Lumpsum_Discount_Amount__c) : null;
            this.lumpsumDiscountPercentage = po.Lumpsum_Discount_Percentage__c != null ? Double.valueOf(po.Lumpsum_Discount_Percentage__c) : null;
            this.discountMode = po.Discount_Mode__c;
            this.discountType = po.Discount_Type__c;
            this.taxPercentage = po.Tax_Percentage__c;
            this.poItems = new List<POItemWrapper>();
        }
    }
    
    public class  POItemWrapper {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String productId { get; set; }
        @AuraEnabled public String productName { get; set; }
        @AuraEnabled public String productSku { get; set; }
        @AuraEnabled public Double productQuantity { get; set; }
        @AuraEnabled public Double listingPrice { get; set; }
        @AuraEnabled public Double actualCost { get; set; }
        @AuraEnabled public Double quantity { get; set; }
        @AuraEnabled public String taxPercentage { get; set; }
        @AuraEnabled public Double unitPrice { get; set; }
        @AuraEnabled public Double discountAmount { get; set; }
        @AuraEnabled public Double discountPercentage { get; set; }
        @AuraEnabled public String purchaseOrderDiscountType { get; set; }
        @AuraEnabled public String discountMode { get; set; }
        @AuraEnabled public Double keyField { get; set; }
        
        public POItemWrapper() {}
        
        public POItemWrapper(PO_Item__c poItem) {
            this.id = poItem.Id != null ? (String) poItem.Id : null;
            this.productId = poItem.Product__c != null ? (String) poItem.Product__c : null;
            this.productName = poItem.Product__r?.Name;
            this.productSku = poItem.Product__r?.SKU__c;
            this.productQuantity = poItem.Product__r?.Product_Quantity__c != null ? Double.valueOf(poItem.Product__r.Product_Quantity__c) : null;
            this.listingPrice = poItem.Product__r?.Listing_Price__c != null ? Double.valueOf(poItem.Product__r.Listing_Price__c) : null;
            this.actualCost = poItem.Product__r?.Actual_Cost__c != null ? Double.valueOf(poItem.Product__r.Actual_Cost__c) : null;
            this.quantity = poItem.Quantity__c != null ? Double.valueOf(poItem.Quantity__c) : null;
            this.taxPercentage = poItem.Tax_Percentage__c;
            this.unitPrice = poItem.Unit_Price__c != null ? Double.valueOf(poItem.Unit_Price__c) : null;
            this.discountAmount = poItem.Discount_Amount__c != null ? Double.valueOf(poItem.Discount_Amount__c) : null;
            this.discountPercentage = poItem.Discount_Percentage__c != null ? Double.valueOf(poItem.Discount_Percentage__c) : null;
            this.purchaseOrderDiscountType = poItem.Purchase_Order__r?.Discount_Type__c;
            this.discountMode = poItem.Discount_Mode__c;
            this.keyField = poItem.key__c != null ? Double.valueOf(poItem.key__c) : null;
        }
        
        public  PO_Item__c toPOItem(String purchaseOrderId) {
            PO_Item__c poItem = new PO_Item__c();
            if (String.isNotBlank(this.id)) {
                poItem.Id = this.id;
            }
            else{
                poItem.Purchase_Order__c = purchaseOrderId;
            }
            
            if (String.isNotBlank(this.productId)) {
                poItem.Product__c = this.productId;
            }
            // Add this line to set the Name field
            poItem.Name = this.productName;
            
            poItem.Quantity__c = this.quantity != null ? Decimal.valueOf(this.quantity) : null;
            poItem.Tax_Percentage__c = this.taxPercentage;
            poItem.Unit_Price__c = this.unitPrice != null ? Decimal.valueOf(this.unitPrice) : null;
            poItem.Discount_Amount__c = this.discountAmount != null ? Decimal.valueOf(this.discountAmount) : null;
            poItem.Discount_Percentage__c = this.discountPercentage != null ? Decimal.valueOf(this.discountPercentage) : null;
            poItem.Discount_Mode__c = this.discountMode;
            poItem.key__c = this.keyField != null ? Decimal.valueOf(this.keyField) : null;
            poItem.Unit_of_Measure__c = 'Each';
            return poItem;
        }
    }
    
    public class ProductWrapper {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String sku { get; set; }
        @AuraEnabled public Double productQuantity { get; set; }
        @AuraEnabled public Double listingPrice { get; set; }
        @AuraEnabled public Double actualCost { get; set; }
        
        public ProductWrapper() {}
        
        public ProductWrapper(Product__c product) {
            this.id = product.Id != null ? (String) product.Id : null;
            this.name = product.Name;
            this.sku = product.SKU__c;
            this.productQuantity = product.Product_Quantity__c != null ? Double.valueOf(product.Product_Quantity__c) : null;
            this.listingPrice = product.Listing_Price__c != null ? Double.valueOf(product.Listing_Price__c) : null;
            this.actualCost = product.Actual_Cost__c != null ? Double.valueOf(product.Actual_Cost__c) : null;
        }
    }
    
    @AuraEnabled
    public static String savePurchaseOrderItemsWithWrapper( List<POItemWrapper> itemWrappers, String purchaseOrderId) {
        System.debug('Purchase Order ID: ' + purchaseOrderId);
        System.debug('Item Wrappers to process: ' + itemWrappers);
        try {
            List<PO_Item__c> recordsToUpsert = new List<PO_Item__c>();
            
            for (POItemWrapper itemWrapper : itemWrappers) {
                PO_Item__c item = itemWrapper.toPOItem(purchaseOrderId);
                recordsToUpsert.add(item);
            }
            upsert recordsToUpsert id;     // upsert  recordsToUpsert id;

            return 'PO Items Created Successfully';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static PurchaseOrderWrapper getPurchaseOrderWithItems(String purchaseOrderId) {
        try {
            // Get Purchase Order
            List<Purchase_Order__c> poList = [
                SELECT Id,Supplier__r.Name,Supplier_Name__c,Shipping_Terms__c,Payment_Terms__c,
                Lumpsum_Discount_Amount__c,Lumpsum_Discount_Percentage__c,Discount_Mode__c,
                Discount_Type__c,Tax_Percentage__c
                FROM Purchase_Order__c
                WHERE Id = :purchaseOrderId
                LIMIT 1
            ];
            
            if (poList.isEmpty()) {
                throw new AuraHandledException('Purchase Order not found');
            }
            
            PurchaseOrderWrapper wrapper = new PurchaseOrderWrapper(poList[0]);
            
            // Get PO Items
            List<PO_Item__c> poItems = [
                SELECT Id, Product__c, Product__r.Name, Product__r.SKU__c,
                Product__r.Product_Quantity__c, Product__r.Listing_Price__c,Product__r.Actual_Cost__c, 
                Quantity__c, Tax_Percentage__c,Unit_Price__c,Discount_Amount__c,Discount_Percentage__c,
                Purchase_Order__r.Discount_Type__c,Discount_Mode__c,key__c
                FROM PO_Item__c
                WHERE Purchase_Order__c = :purchaseOrderId 
                ORDER BY key__c ASC
            ];
            
            for (PO_Item__c item : poItems) {
                wrapper.poItems.add(new POItemWrapper(item));
            }
            
            return wrapper;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<ProductWrapper> searchProductsWrapper(String searchKey) {
        List<ProductWrapper> productWrappers = new List<ProductWrapper>();
        List<Product__c> products = [
            SELECT Id, Name, SKU__c, Product_Quantity__c, Listing_Price__c,Actual_Cost__c
            FROM Product__c
            WHERE Name LIKE :('%' + searchKey + '%')
            LIMIT 10
        ];
        
        for (Product__c product : products) {
            productWrappers.add(new ProductWrapper(product));
        }

        System.debug('Search Results: ' + JSON.serializePretty(productWrappers));
        return productWrappers;
    }
    
    // Original Methods (maintained for backward compatibility)
    // @AuraEnabled
    // public static string savePurchaseOrderItems(List<PO_Item__c> items, Id purchaseOrderId) {
    //     System.debug('Purchase Order ID: ' + purchaseOrderId);
    //     System.debug('Items to upsert: ' + items);
    //     try{
    //         List<PO_Item__c> recordsToUpsert = new List<PO_Item__c>();

    //         for (PO_Item__c item : items) {
    //             if (item.Id == null) {
    //                 item.Purchase_Order__c = purchaseOrderId;
    //             }
    //             item.Unit_of_Measure__c = 'Each';
    //             recordsToUpsert.add(item);
    //         }

    //         upsert recordsToUpsert;

    //         return 'PO Items Created Successfully';                          
    //     }catch(Exception e){
    //         throw new AuraHandledException(e.getMessage());
    //     }
    // }
//     @AuraEnabled
//     public static String savePurchaseOrderItemsWithWrapper(List<POItemWrapper> itemWrappers, String purchaseOrderId) {
//     System.debug('Purchase Order ID: ' + purchaseOrderId);
//     System.debug('Item Wrappers to process: ' + itemWrappers);
//     try {
//         List<PO_Item__c> recordsToUpsert = new List<PO_Item__c>();
        
//         for (POItemWrapper itemWrapper : itemWrappers) {
//             if (itemWrapper != null) {
//                 PO_Item__c item = new PO_Item__c();
                
//                 // Set ID if it exists (for updates)
//                 if (String.isNotBlank(itemWrapper.id)) {
//                     item.Id = itemWrapper.id;
//                 }
                
//                 // Set Purchase Order ID
//                 item.Purchase_Order__c = purchaseOrderId;
                
//                 // Map all fields from wrapper to PO Item
//                 if (String.isNotBlank(itemWrapper.productId)) {
//                     item.Product__c = itemWrapper.productId;
//                 }
//                 item.Id= itemWrapper.id;
//                 item.Quantity__c = itemWrapper.quantity;
//                 item.Tax_Percentage__c = itemWrapper.taxPercentage;
//                 item.Unit_Price__c = itemWrapper.unitPrice;
//                 item.Discount_Amount__c = itemWrapper.discountAmount;
//                 item.Discount_Percentage__c = itemWrapper.discountPercentage;
//                 item.Discount_Mode__c = itemWrapper.discountMode;
//                 item.key__c = itemWrapper.keyField;
//                 item.Unit_of_Measure__c = 'Each';
                
//                 recordsToUpsert.add(item);
//             }
//         }
        
//         if (!recordsToUpsert.isEmpty()) {

//             // Use Database.upsert with allOrNone=false to handle partial successes
//             Database.UpsertResult[] results = Database.upsert(recordsToUpsert, false);  
//             // Handle errors
//             List<String> errors = new List<String>();
//             for (Database.UpsertResult result : results) {
//                 if (!result.isSuccess()) {
//                     for (Database.Error err : result.getErrors()) {
//                         errors.add(err.getMessage());
//                     }
//                 }
//             }
            
//             if (!errors.isEmpty()) {
//                 throw new AuraHandledException(String.join(errors, '; '));
//             }
//         }
        
//         return 'PO Items Created Successfully';
//     } catch (Exception e) {
//         throw new AuraHandledException(e.getMessage());
//     }
// }
    
    @AuraEnabled
    public static void savesPurchaseOrder(String discountTypeValue, 
                                    String discountModeValue,
                                    Decimal lumpsumAmount,
                                    Decimal lumpsumPercentage, 
                                    String lumpsumTaxPercentage,
                                    Id purchaseOrderId
                                    ) {
        try {
            Purchase_Order__c purchaseOrder = [
                SELECT Id, Discount_Type__c, Discount_Mode__c, 
                    Lumpsum_Discount_Amount__c, Lumpsum_Discount_Percentage__c ,Tax_Percentage__c
                FROM Purchase_Order__c 
                WHERE Id = :purchaseOrderId
                LIMIT 1
            ];

            purchaseOrder.Discount_Type__c = discountTypeValue;
            purchaseOrder.Discount_Mode__c = discountModeValue;
            
            if (discountTypeValue == 'Lumpsum Discount') {
                purchaseOrder.Tax_Percentage__c = lumpsumTaxPercentage;
                if (discountModeValue == 'Amount') {
                    purchaseOrder.Lumpsum_Discount_Amount__c = lumpsumAmount;
                    purchaseOrder.Lumpsum_Discount_Percentage__c = null;
                } else if (discountModeValue == 'Percentage') {
                    purchaseOrder.Lumpsum_Discount_Percentage__c = lumpsumPercentage;
                    purchaseOrder.Lumpsum_Discount_Amount__c = null;
                }
            } else {
                purchaseOrder.Lumpsum_Discount_Amount__c = null;
                purchaseOrder.Lumpsum_Discount_Percentage__c = null;
            }
            System.debug('Purchase Order before upsert: ' + purchaseOrder);

            upsert purchaseOrder;

        } catch (Exception e) {
            throw new AuraHandledException('Error updating Sales Order: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Product__c> searchProducts(String searchKey) {
        return [
            SELECT Id, Name, SKU__c, Product_Quantity__c, Listing_Price__c,Actual_Cost__c
            FROM Product__c
            WHERE Name LIKE :('%' + searchKey + '%')
            LIMIT 10
        ];
    }
    
    // @AuraEnabled(cacheable=true)
    // public static List<String> getPicklistValue(String objectApiName, String fieldApiName) {
    //     List<String> options = new List<String>();
    //     Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();

    //     if (globalDescribe.containsKey(objectApiName)) {
    //         Schema.SObjectType objType = globalDescribe.get(objectApiName);
    //         Schema.DescribeSObjectResult objDescribe = objType.getDescribe();

    //         Schema.SObjectField fieldToken = objDescribe.fields.getMap().get(fieldApiName);

    //         if (fieldToken != null) {
    //             Schema.DescribeFieldResult fieldResult = fieldToken.getDescribe();
    //             List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();

    //             for (Schema.PicklistEntry entry : picklistValues) {
    //                 options.add(entry.getLabel());
    //             }
    //         }
    //     }
    //     return options;
    // }

    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getPicklistValue() {
        Map<String, List<String>> picklistMap = new Map<String, List<String>>();
 
        Schema.DescribeFieldResult field1 = Purchase_Order__c.Tax_Percentage__c.getDescribe();
        Schema.DescribeFieldResult field2 = Purchase_Order__c.Discount_Mode__c.getDescribe();
        Schema.DescribeFieldResult field3 = Purchase_Order__c.Discount_Type__c.getDescribe();
 
        List<Schema.PicklistEntry> taxPercentagevalue = field1.getPicklistValues();
        List<Schema.PicklistEntry> discountModeValues = field2.getPicklistValues();
        List<Schema.PicklistEntry> discountTypeValues = field3.getPicklistValues();
 
        List<String> taxOptions = new List<String>();
        for (Schema.PicklistEntry entry : taxPercentagevalue) {
            taxOptions.add(entry.getLabel());
        }
 
        List<String> discOptions = new List<String>();
        for (Schema.PicklistEntry entry : discountModeValues) {
            discOptions.add(entry.getLabel());
        }

        List<String> discountType = new List<String>();
        for (Schema.PicklistEntry entry : discountTypeValues) {
            discountType.add(entry.getLabel());
        }
 
        picklistMap.put('taxOptions', taxOptions);
        picklistMap.put('discOptions', discOptions);
        picklistMap.put('discountType', discountType);
        System.debug('Picklist Map: ' + JSON.serializePretty(picklistMap));
        return picklistMap;
    }
    
    // Enhanced wrapper methods for individual data retrieval
    @AuraEnabled
    public static PurchaseOrderWrapper getPurchaseOrder(String purchaseOrderId) {
        try {
            List<Purchase_Order__c> poList = [
                SELECT Id,Supplier__r.Name,Supplier_Name__c,Shipping_Terms__c,Payment_Terms__c,
                Lumpsum_Discount_Amount__c,Lumpsum_Discount_Percentage__c,Discount_Mode__c,
                Discount_Type__c,Tax_Percentage__c
                FROM Purchase_Order__c
                WHERE Id = :purchaseOrderId
                LIMIT 1
            ];
            
            if (poList.isEmpty()) {
                throw new AuraHandledException('Purchase Order not found');
            }
            
            return new PurchaseOrderWrapper(poList[0]);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<POItemWrapper> getpurchaseOrderItems(String purchaseOrderId) {
        try {
            List<POItemWrapper> itemWrappers = new List<POItemWrapper>();
            List<PO_Item__c> poItems = [
                SELECT Id, Product__c, Product__r.Name, Product__r.SKU__c,
                Product__r.Product_Quantity__c, Product__r.Listing_Price__c,Product__r.Actual_Cost__c, 
                Quantity__c, Tax_Percentage__c,Unit_Price__c,Discount_Amount__c,Discount_Percentage__c,
                Purchase_Order__r.Discount_Type__c,Discount_Mode__c,key__c
                FROM PO_Item__c
                WHERE Purchase_Order__c = :purchaseOrderId 
                ORDER BY key__c ASC
            ];
            
            for (PO_Item__c item : poItems) {
                itemWrappers.add(new POItemWrapper(item));
            }
            
            return itemWrappers;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // Original methods (maintained for backward compatibility)
    // @AuraEnabled
    // public static List<Purchase_Order__c> getPurchaseOrder(Id purchaseOrderId) {
    //     return [
    //         SELECT Id,Supplier__r.Name,Supplier_Name__c,Shipping_Terms__c,Payment_Terms__c,Lumpsum_Discount_Amount__c,Lumpsum_Discount_Percentage__c,Discount_Mode__c,Discount_Type__c,
    //         Tax_Percentage__c
    //         FROM Purchase_Order__c
    //         WHERE Id = :purchaseOrderId
    //     ];
    // }

    // @AuraEnabled
    // public static List<PO_Item__c> getpurchaseOrderItems(Id purchaseOrderId) {
    //     return [
    //         SELECT Id, Product__c, Product__r.Name, Product__r.SKU__c,
    //         Product__r.Product_Quantity__c, Product__r.Listing_Price__c,Product__r.Actual_Cost__c, 
    //         Quantity__c, Tax_Percentage__c,Unit_Price__c,Discount_Amount__c,Discount_Percentage__c,
    //         Purchase_Order__r.Discount_Type__c,Discount_Mode__c,key__c
    //         FROM PO_Item__c
    //         WHERE Purchase_Order__c = :purchaseOrderId ORDER BY key__c ASC
    //     ];
    // }
    
    @AuraEnabled
    public static void deletePoItem(Id itemId) {
        try {
            delete [SELECT Id FROM PO_Item__c WHERE Id = :itemId];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}