public with sharing class CreatePurchaseOrderItems {
    @AuraEnabled
    public static String savePurchaseOrderItemsWithWrapper( List<POItemWrapper> itemWrappers, String purchaseOrderId) {
        try {
            List<PO_Item__c> recordsToUpsert = new List<PO_Item__c>();
            
            for (POItemWrapper itemWrapper : itemWrappers) {
                PO_Item__c item = itemWrapper.toPOItem(purchaseOrderId);
                recordsToUpsert.add(item);
            }
            upsert recordsToUpsert id;   

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
            SELECT Id, Name, SKU__c, Product_Quantity__c,Stock_Available__c,Lead_Time__c, Listing_Price__c,Actual_Cost__c
            FROM Product__c
            WHERE Name LIKE :('%' + searchKey + '%') OR SKU__c LIKE :('%' + searchKey + '%')
            LIMIT 10 // GV 26-06-25 --> ordering code for search
        ];
        
        for (Product__c product : products) {
            productWrappers.add(new ProductWrapper(product));
        }
        return productWrappers;
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


    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getPicklistValue() {
        Map<String, List<String>> picklistMap = new Map<String, List<String>>();

        Schema.DescribeFieldResult field1 = Purchase_Order__c.Tax_Percentage__c.getDescribe();
        Schema.DescribeFieldResult field2 = Purchase_Order__c.Discount_Mode__c.getDescribe();
        Schema.DescribeFieldResult field3 = Purchase_Order__c.Discount_Type__c.getDescribe();
        Schema.DescribeFieldResult field4 = Purchase_Order__c.Status__c.getDescribe();
        Schema.DescribeFieldResult field5 = Purchase_Order__c.PO_Type__c.getDescribe();

        List<Schema.PicklistEntry> taxPercentageValues = field1.getPicklistValues();
        List<Schema.PicklistEntry> discountModeValues = field2.getPicklistValues();
        List<Schema.PicklistEntry> discountTypeValues = field3.getPicklistValues();
        List<Schema.PicklistEntry> statusValues = field4.getPicklistValues();
        List<Schema.PicklistEntry> poTypeValues = field5.getPicklistValues();

        List<String> taxOptions = new List<String>();
        for (Schema.PicklistEntry entry : taxPercentageValues) {
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

        List<String> statusOptions = new List<String>();
        for (Schema.PicklistEntry entry : statusValues) {
            statusOptions.add(entry.getLabel());
        }

        List<String> poType = new List<String>();
        for (Schema.PicklistEntry entry : poTypeValues) {
            poType.add(entry.getLabel());
        }

        picklistMap.put('taxOptions', taxOptions);
        picklistMap.put('discOptions', discOptions);
        picklistMap.put('discountType', discountType);
        picklistMap.put('statusOptions', statusOptions);
        picklistMap.put('poType', poType);

        return picklistMap;
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

    @AuraEnabled
    public static void deletePoItem(Id itemId) {
        try {
            delete [SELECT Id FROM PO_Item__c WHERE Id = :itemId];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }


@AuraEnabled
public static Id savePurchaseOrder(PurchaseOrderWrapper wrapper) {
    Savepoint sp = Database.setSavepoint();
    try {
        System.debug('PurchaseOrderWrapper wrapper: ' + JSON.serialize(wrapper));
        
        Purchase_Order__c po = new Purchase_Order__c();
        if (wrapper.id != null) {
            po.Id = Id.valueOf(wrapper.id);
        }
        
        po.Name = wrapper.poName;
        po.Required_Date__c = wrapper.requiredDate;
        po.Status__c = wrapper.status;
        po.PO_Type__c = wrapper.poType;
        po.Title__c = wrapper.title;
        po.Vendor_Account__c = wrapper.vendorId;
        po.Shipping_Terms__c = wrapper.shippingTerms;
        po.Discount_Type__c = wrapper.discountType;
        po.Discount_Mode__c = wrapper.discountMode;
        po.Lumpsum_Discount_Amount__c = wrapper.lumpsumDiscountAmount;
        po.Lumpsum_Discount_Percentage__c = wrapper.lumpsumDiscountPercentage;
        po.Tax_Percentage__c = wrapper.taxPercentage;
        
        upsert po;
        
        if (wrapper.poItems != null && !wrapper.poItems.isEmpty()) {
            List<PO_Item__c> itemsToInsert = new List<PO_Item__c>();
            List<PO_Item__c> itemsToUpdate = new List<PO_Item__c>();
            Map<Id, PO_Item__c> existingItems = new Map<Id, PO_Item__c>();
            
            if (po.Id != null) {
                existingItems = new Map<Id, PO_Item__c>(
                    [SELECT Id FROM PO_Item__c WHERE Purchase_Order__c = :po.Id]
                );
            }
            
            Set<Id> processedIds = new Set<Id>();
            
            for (POItemWrapper itemWrapper : wrapper.poItems) {
                PO_Item__c poItem = new PO_Item__c();
                
                if (String.isNotBlank(itemWrapper.id)) {
                    poItem.Id = itemWrapper.id;
                    processedIds.add(poItem.Id);
                    
                    poItem.Product__c = itemWrapper.productId;
                    poItem.Name = itemWrapper.productName;
                    poItem.Quantity__c = itemWrapper.quantity;
                    poItem.Tax_Percentage__c = itemWrapper.taxPercentage;
                    poItem.Unit_Price__c = itemWrapper.unitPrice;
                    poItem.Discount_Amount__c = itemWrapper.discountAmount;
                    poItem.Discount_Percentage__c = itemWrapper.discountPercentage;
                    poItem.Discount_Mode__c = itemWrapper.discountMode;
                    poItem.key__c = itemWrapper.keyField;
                    poItem.Unit_of_Measure__c = 'Each';
                    itemsToUpdate.add(poItem);
                } 
                else {
                    poItem.Purchase_Order__c = po.Id;
                    poItem.Product__c = itemWrapper.productId;
                    poItem.Name = itemWrapper.productName;
                    poItem.Quantity__c = itemWrapper.quantity;
                    poItem.Tax_Percentage__c = itemWrapper.taxPercentage;
                    poItem.Unit_Price__c = itemWrapper.unitPrice;
                    poItem.Discount_Amount__c = itemWrapper.discountAmount;
                    poItem.Discount_Percentage__c = itemWrapper.discountPercentage;
                    poItem.Discount_Mode__c = itemWrapper.discountMode;
                    poItem.key__c = itemWrapper.keyField;
                    poItem.Unit_of_Measure__c = 'Each';
                    
                    itemsToInsert.add(poItem);
                }
            }
            
            List<PO_Item__c> itemsToDelete = new List<PO_Item__c>();
            for (PO_Item__c existingItem : existingItems.values()) {
                if (!processedIds.contains(existingItem.Id)) {
                    itemsToDelete.add(existingItem);
                }
            }
            
            if (!itemsToDelete.isEmpty()) {
                delete itemsToDelete;
            }
            
            if (!itemsToUpdate.isEmpty()) {
                update itemsToUpdate;
            }
            
            if (!itemsToInsert.isEmpty()) {
                insert itemsToInsert;
            }
        }
       return po.Id; 
    } catch (Exception e) {
        Database.rollback(sp);
        String errorMsg = 'Error saving Purchase Order: ' + e.getMessage();
        System.debug('Error: ' + errorMsg);
        throw new AuraHandledException(errorMsg);
    }
}
    @AuraEnabled
    public static PurchaseOrderWrapper getPurchaseOrder(String purchaseOrderId) {
        try {
            Purchase_Order__c po = [
                SELECT Id, Name, Required_Date__c, Status__c, PO_Type__c, Title__c,
                    Vendor_Account__c, Vendor_Account__r.Name,Vendor_Account__r.Shipping_Terms__c, Shipping_Terms__c,
                    Vendor_Account__r.Shipping_Terms__c, Vendor_Account__r.Payment_Terms__c,
                    Supplier__r.Name, Discount_Type__c, Discount_Mode__c,
                    Lumpsum_Discount_Amount__c, Lumpsum_Discount_Percentage__c,
                    Tax_Percentage__c
                FROM Purchase_Order__c
                WHERE Id = :purchaseOrderId
                LIMIT 1
            ];
            
            return new PurchaseOrderWrapper(po);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}