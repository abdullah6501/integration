public with sharing class EstimationItemController {
    // AR 14/06/2025 Added saveEstimationItemsWithWrapper, getEstimationWithItems, searchProductsWrapper, savesEstimation, getPicklistValue, getEstimation, getestimationItems, deleteEstimationItem
    // AR 1/07/2025 Added description and Name in estimation item

    //AR Tax Details Section
//     @AuraEnabled
//    public static void createTaxDetailRecords(List<Map<String, Object>> taxDetailsList, Id estimationId) {
//     try {
//         if (taxDetailsList == null || taxDetailsList.isEmpty()) {
//             System.debug('No tax details provided');
//             return;
//         }

//         System.debug('Input tax details: ' + JSON.serializePretty(taxDetailsList));

//         // Fetch existing Tax_Detail__c records
//         Map<String, Tax_Detail__c> existingTaxDetailsMap = new Map<String, Tax_Detail__c>();
//         for (Tax_Detail__c td : [
//             SELECT Id, Estimation_Item__c, Tax__c 
//             FROM Tax_Detail__c 
//             WHERE Estimation__c = :estimationId 
//             WITH SECURITY_ENFORCED
//         ]) {
//             String key = (td.Estimation_Item__c != null ? td.Estimation_Item__c + '_' + td.Tax__c : 'LS_' + td.Tax__c);
//             existingTaxDetailsMap.put(key, td);
//         }

//         // Map key__c → Estimation_Item__c for line item taxes
//         Map<String, Estimation_Item__c> estimationItemKeyMap = new Map<String, Estimation_Item__c>();
//         for (Estimation_Item__c item : [
//             SELECT Id, Name, key__c 
//             FROM Estimation_Item__c 
//             WHERE Estimation__c = :estimationId
//         ]) {
//             if (item.key__c != null) {
//                 String itemKey = 'item' + item.key__c.setScale(0).toPlainString();
//                 estimationItemKeyMap.put(itemKey, item);
//             }
//         }

//         List<Tax_Detail__c> taxDetailsToUpsert = new List<Tax_Detail__c>();
//         Set<String> processedKeys = new Set<String>();

//         // Process each tax group
//         for (Map<String, Object> taxGroup : taxDetailsList) {
//             String taxId = String.valueOf(taxGroup.get('taxId'));
//             String taxName = String.valueOf(taxGroup.get('taxName'));
//             Decimal percentage = Decimal.valueOf(String.valueOf(taxGroup.get('percentage')));
//             Decimal taxAmount = Decimal.valueOf(String.valueOf(taxGroup.get('taxAmount')));
            
//             Object detailsObj = taxGroup.get('details');
            
//             if (detailsObj != null) {
//                 // Line Item Tax - process each detail
//                 List<Object> details = (List<Object>)detailsObj;
                
//                 for (Object detailObj : details) {
//                     Map<String, Object> detail = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(detailObj));
                    
//                     String estimationItemKey = detail.containsKey('estimationItemId') ? String.valueOf(detail.get('estimationItemId')) : null;
//                     if (String.isBlank(estimationItemKey) || !estimationItemKeyMap.containsKey(estimationItemKey)) {
//                         System.debug('Skipping invalid estimation item key: ' + estimationItemKey);
//                         continue;
//                     }
                    
//                     Estimation_Item__c estimationItem = estimationItemKeyMap.get(estimationItemKey);
//                     String mapKey = estimationItem.Id + '_' + taxId;
//                     processedKeys.add(mapKey);
                    
//                     Tax_Detail__c td = existingTaxDetailsMap.containsKey(mapKey) ?
//                         existingTaxDetailsMap.get(mapKey) : new Tax_Detail__c();
                    
//                     if (td.Id == null) {
//                         td.Estimation__c = estimationId;
//                         td.Estimation_Item__c = estimationItem.Id;
//                         td.Tax__c = taxId;
//                     }
                    
//                     td.Name = 'Tax Detail for ' + taxName;
//                     td.Tax_Percentage__c = percentage;
//                     td.Amount__c = taxAmount;
//                     //td.Type__c = 'Output Tax';
                    
//                     taxDetailsToUpsert.add(td);
//                 }
//             } else {
//                 // Lumpsum Tax
//                 String mapKey = 'LS_' + taxId;
//                 processedKeys.add(mapKey);
                
//                 Tax_Detail__c td = existingTaxDetailsMap.containsKey(mapKey) ?
//                     existingTaxDetailsMap.get(mapKey) : new Tax_Detail__c();
                
//                 if (td.Id == null) {
//                     td.Estimation__c = estimationId;
//                     td.Tax__c = taxId;
//                 }
                
//                 td.Name = 'Tax Detail for ' + taxName;
//                 td.Tax_Percentage__c = percentage;
//                 td.Amount__c = taxAmount;
//                 //td.Type__c = 'Output Tax';
                
//                 taxDetailsToUpsert.add(td);
//             }
//         }

//         // Delete stale records
//         List<Tax_Detail__c> taxDetailsToDelete = new List<Tax_Detail__c>();
//         for (String key : existingTaxDetailsMap.keySet()) {
//             if (!processedKeys.contains(key)) {
//                 taxDetailsToDelete.add(existingTaxDetailsMap.get(key));
//             }
//         }

//         if (!taxDetailsToDelete.isEmpty()) {
//             delete taxDetailsToDelete;
//         }

//         if (!taxDetailsToUpsert.isEmpty()) {
//             upsert taxDetailsToUpsert;
//         }

//     } catch (Exception e) {
//         System.debug('Error: ' + e.getMessage() + ' at line ' + e.getLineNumber());
//         throw new AuraHandledException('Error creating tax details: ' + e.getMessage());
//     }
// }
@AuraEnabled
public static void createTaxDetailRecords(List<Map<String, Object>> taxDetailsList, Id estimationId) {
    try {
        if (taxDetailsList == null || taxDetailsList.isEmpty()) {
            System.debug('No tax details provided');
            return;
        }

        System.debug('Input tax details: ' + JSON.serializePretty(taxDetailsList));

        // Fetch existing Tax_Detail__c records
        Map<String, Tax_Detail__c> existingTaxDetailsMap = new Map<String, Tax_Detail__c>();
        for (Tax_Detail__c td : [
            SELECT Id, Estimation_Item__c, Tax__c 
            FROM Tax_Detail__c 
            WHERE Estimation__c = :estimationId 
            WITH SECURITY_ENFORCED
        ]) {
            String key = (td.Estimation_Item__c != null ? td.Estimation_Item__c + '_' + td.Tax__c : 'LS__' + td.Tax__c);
            existingTaxDetailsMap.put(key, td);
        }

        // Map key__c → Estimation_Item__c for line item taxes
        Map<String, Estimation_Item__c> estimationItemKeyMap = new Map<String, Estimation_Item__c>();
        for (Estimation_Item__c item : [
            SELECT Id, Name, key__c 
            FROM Estimation_Item__c 
            WHERE Estimation__c = :estimationId
        ]) {
            if (item.key__c != null) {
                String itemKey = 'item' + item.key__c.setScale(0).toPlainString();
                estimationItemKeyMap.put(itemKey, item);
            }
        }

        List<Tax_Detail__c> taxDetailsToUpsert = new List<Tax_Detail__c>();
        Set<String> processedKeys = new Set<String>();

        // Process each tax group
        for (Map<String, Object> taxGroup : taxDetailsList) {
            String taxId = String.valueOf(taxGroup.get('taxId'));
            String taxName = String.valueOf(taxGroup.get('taxName'));
            Decimal percentage = Decimal.valueOf(String.valueOf(taxGroup.get('percentage')));
            Decimal taxAmount = Decimal.valueOf(String.valueOf(taxGroup.get('taxAmount')));
            
            // Check if this is a line item tax (has details) or lumpsum tax
            Object detailsObj = taxGroup.get('details');
            
            if (detailsObj != null) {
                // Line Item Tax - process each detail
                List<Object> details = (List<Object>) detailsObj;
                
                for (Object detailObj : details) {
                    Map<String, Object> detail = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(detailObj));
                    
                    String estimationItemKey = detail.containsKey('estimationItemId') ? String.valueOf(detail.get('estimationItemId')) : null;
                    if (String.isBlank(estimationItemKey) || !estimationItemKeyMap.containsKey(estimationItemKey)) {
                        System.debug('Skipping invalid estimation item key: ' + estimationItemKey);
                        continue;
                    }
                    
                    Estimation_Item__c estimationItem = estimationItemKeyMap.get(estimationItemKey);
                    String mapKey = estimationItem.Id + '_' + taxId;
                    processedKeys.add(mapKey);
                    
                    Decimal itemPercentage = Decimal.valueOf(String.valueOf(detail.get('percentage')));
                    Decimal itemTaxAmount = Decimal.valueOf(String.valueOf(detail.get('taxAmount')));
                    
                    Tax_Detail__c td = existingTaxDetailsMap.containsKey(mapKey) ?
                        existingTaxDetailsMap.get(mapKey) : new Tax_Detail__c();
                    
                    if (td.Id == null) {
                        td.Estimation__c = estimationId;
                        td.Estimation_Item__c = estimationItem.Id;
                        td.Tax__c = taxId;
                        System.debug('Creating new line-item tax for: ' + estimationItem.Name);
                    } else {
                        System.debug('Updating line-item tax: ' + td.Id);
                    }
                    
                    td.Name = 'Tax Detail for ' + taxName;
                    td.Tax_Percentage__c = itemPercentage;
                    td.Amount__c = itemTaxAmount;
                    
                    taxDetailsToUpsert.add(td);
                }
            } else {
                // Lumpsum Tax - single tax record
                String mapKey = 'LS__' + taxId;
                processedKeys.add(mapKey);
                
                Tax_Detail__c td = existingTaxDetailsMap.containsKey(mapKey) ?
                    existingTaxDetailsMap.get(mapKey) : new Tax_Detail__c();
                
                if (td.Id == null) {
                    td.Estimation__c = estimationId;
                    td.Tax__c = taxId;
                    System.debug('Creating new lumpsum tax for: ' + taxName);
                } else {
                    System.debug('Updating lumpsum tax: ' + td.Id);
                }
                
                td.Name = 'Tax Detail for ' + taxName;
                td.Tax_Percentage__c = percentage;
                td.Amount__c = taxAmount;
                
                taxDetailsToUpsert.add(td);
            }
        }

        // Delete tax records that are no longer needed
        List<Tax_Detail__c> taxDetailsToDelete = new List<Tax_Detail__c>();
        for (String key : existingTaxDetailsMap.keySet()) {
            if (!processedKeys.contains(key)) {
                Tax_Detail__c stale = existingTaxDetailsMap.get(key);
                taxDetailsToDelete.add(stale);
                System.debug('Deleting stale tax detail: ' + stale.Id);
            }
        }

        if (!taxDetailsToDelete.isEmpty()) {
            delete taxDetailsToDelete;
            System.debug('Deleted ' + taxDetailsToDelete.size() + ' stale tax details');
        }

        if (!taxDetailsToUpsert.isEmpty()) {
            upsert taxDetailsToUpsert;
            System.debug('Upserted ' + taxDetailsToUpsert.size() + ' tax details');
        }

    } catch (Exception e) {
        System.debug('Error: ' + e.getMessage() + ' at line ' + e.getLineNumber());
        throw new AuraHandledException('Error creating tax details: ' + e.getMessage());
    }
}
    //Tax Detail Ends
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getAccountDetails(Id accId) {
        Account acc = [SELECT Id, Shipping_Term__c, Payment_Term__c FROM Account WHERE Id = :accId LIMIT 1];
        Map<String, String> result = new Map<String, String>();
        result.put('shippingTerm', acc.Shipping_Term__c);
        result.put('paymentTerm', acc.Payment_Term__c);
        return result;
    }
    @AuraEnabled
    public static String saveEstimationItemsWithWrapper( List<ESItemWrapper> itemWrappers, String EstimationId) {
        System.debug('Purchase Order ID: ' + EstimationId);
        System.debug('Item Wrappers to process: ' + itemWrappers);
        try {
            List<Estimation_Item__c> recordsToUpsert = new List<Estimation_Item__c>();
            
            for (ESItemWrapper itemWrapper : itemWrappers) {
                Estimation_Item__c item = itemWrapper.toESItem(EstimationId);
                item.Name=itemWrapper.productName;
                recordsToUpsert.add(item);
            }
            upsert recordsToUpsert id;    
 
            return 'Estimation Items Created Successfully';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void syncCostRecords(Id estimationId) {
        // Step 1: Get all estimation items
        List<Estimation_Item__c> items = [
            SELECT Id, Product__c, Quantity__c
            FROM Estimation_Item__c
            WHERE Estimation__c = :estimationId
        ];

        // Step 2: Get all related Cost__c records
        Map<Id, Cost__c> existingCostsMap = new Map<Id, Cost__c>();
        for (Cost__c cost : [
            SELECT Id, Product__c, Quantity__c
            FROM Cost__c
            WHERE Estimation__c = :estimationId
        ]) {
            if (cost.Product__c != null) {
                existingCostsMap.put(cost.Product__c, cost);
            }
        }

        Set<Id> productIdsInEstimation = new Set<Id>();
        List<Cost__c> toInsert = new List<Cost__c>();
        List<Cost__c> toUpdate = new List<Cost__c>();

        for (Estimation_Item__c item : items) {
            if (item.Product__c == null) continue;

            productIdsInEstimation.add(item.Product__c);

            if (existingCostsMap.containsKey(item.Product__c)) {
                Cost__c existing = existingCostsMap.get(item.Product__c);
                if (existing.Quantity__c != item.Quantity__c) {
                    existing.Quantity__c = item.Quantity__c;
                    toUpdate.add(existing);
                }
            } else {
                toInsert.add(new Cost__c(
                    Estimation__c = estimationId,
                    Product__c = item.Product__c,
                    Quantity__c = item.Quantity__c,
                    Group__c = 'Material',
                    Type__c = 'Estimation Cost',
                    Version__c = 'V1.0'
                ));
            }
        }

        // Step 3: Delete Cost__c if the product is not in estimation item
        List<Cost__c> toDelete = new List<Cost__c>();
        for (Cost__c cost : existingCostsMap.values()) {
            if (!productIdsInEstimation.contains(cost.Product__c)) {
                toDelete.add(cost);
            }
        }

        // Step 4: Commit to DB
        if (!toInsert.isEmpty()) insert toInsert;
        if (!toUpdate.isEmpty()) update toUpdate;
        if (!toDelete.isEmpty()) delete toDelete;
    }

    @AuraEnabled
    public static EstimationWrapper getEstimationWithItems(String EstimationId) {
        try {
            List<Estimation__c> estList = [
                SELECT Id,Customer__c,Customer__r.Name,Shipping_Terms__c,Payment_Terms__c,
                Total_Discount_Amount__c ,Total_Discount_Percentage__c ,Discount_Mode__c,
                Discount_Type__c,Tax_Percentage__c,PO_Ref_Num__c,Name,Order_Date__c,Status__c
                FROM Estimation__c
                WHERE Id = :EstimationId WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            if (estList.isEmpty()) {
                throw new AuraHandledException(' Estimation not found');
            }
            
            EstimationWrapper wrapper = new EstimationWrapper(estList[0]);
            
            List<Estimation_Item__c> ESItems = [
                SELECT Id,Name, Product__c, Product__r.Name, Product__r.SKU__c,
                Product__r.Product_Quantity__c, Product__r.Listing_Price__c,Product__r.Actual_Cost__c,
                Quantity__c, Tax_Percentage__c,Unit_Price__c,Discount_Amount__c,Discount_Percentage__c,
                Estimation__r.Discount_Type__c,Discount_Type__c ,key__c
                FROM Estimation_Item__c
                WHERE Estimation__c = :EstimationId WITH SECURITY_ENFORCED
                ORDER BY key__c ASC
            ];
            
            for (Estimation_Item__c item : ESItems) {
                wrapper.ESItems.add(new ESItemWrapper(item));
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
            SELECT Id, Name, SKU__c, Product_Quantity__c, Stock_Available__c,Listing_Price__c,Actual_Cost__c,Lead_Time__c
            FROM Product__c
            WHERE Name LIKE :('%' + searchKey + '%') OR SKU__c LIKE :('%' + searchKey + '%')
            WITH SECURITY_ENFORCED
            LIMIT 10 // GV 26-06-25 --> ordering code for search  
        ];
        
        for (Product__c product : products) {
            productWrappers.add(new ProductWrapper(product));
        }
 
        System.debug('Search Results: ' + JSON.serializePretty(productWrappers));
        return productWrappers;
    }
    @AuraEnabled
public static Id saveEstimation(EstimationWrapper wrapper) {
    Savepoint sp = Database.setSavepoint();
    try {
        Estimation__c estimation = wrapper.toEstimation();
        upsert estimation;
        
        if (wrapper.ESItems != null && !wrapper.ESItems.isEmpty()) {
            List<Estimation_Item__c> itemsToUpsert = new List<Estimation_Item__c>();
            Set<Id> processedIds = new Set<Id>();
            
            // First pass - create/update all items
            for (ESItemWrapper itemWrapper : wrapper.ESItems) {
                Estimation_Item__c item = itemWrapper.toESItem(estimation.Id);
                if (item.Id != null) {
                    processedIds.add(item.Id);
                }
                itemsToUpsert.add(item);
            }
            
            // Handle deletions if this is an update
            if (estimation.Id != null) {
                List<Estimation_Item__c> itemsToDelete = [
                    SELECT Id 
                    FROM Estimation_Item__c 
                    WHERE Estimation__c = :estimation.Id 
                    AND Id NOT IN :processedIds
                ];
                
                if (!itemsToDelete.isEmpty()) {
                    delete itemsToDelete;
                }
            }
            
            if (!itemsToUpsert.isEmpty()) {
                upsert itemsToUpsert;
            }
        }
        
        return estimation.Id;
    } catch (Exception e) {
        Database.rollback(sp);
        System.debug('Error saving estimation: ' + e.getMessage() + '\n' + e.getStackTraceString());
        throw new AuraHandledException('Error saving estimation: ' + e.getMessage());
    }
}
    
    @AuraEnabled(cacheable=true)
    public static List<Product__c> searchProducts(String searchKey) {
        return [
            SELECT Id, Name, SKU__c, Product_Quantity__c, Listing_Price__c,Actual_Cost__c,Lead_Time__c
            FROM Product__c
            WHERE Name LIKE :('%' + searchKey + '%') WITH SECURITY_ENFORCED
            LIMIT 10
        ];
    }
    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getPicklistValue() {
        Map<String, List<String>> picklistMap = new Map<String, List<String>>();

        Schema.DescribeFieldResult field1 = Estimation__c.Tax_Percentage__c.getDescribe();
        Schema.DescribeFieldResult field2 = Estimation__c.Discount_Mode__c.getDescribe();
        Schema.DescribeFieldResult field3 = Estimation__c.Discount_Type__c.getDescribe();
        Schema.DescribeFieldResult field4 = Estimation__c.Status__c.getDescribe();

        List<Schema.PicklistEntry> taxPercentageValue = field1.getPicklistValues();
        List<Schema.PicklistEntry> discountModeValues = field2.getPicklistValues();
        List<Schema.PicklistEntry> discountTypeValues = field3.getPicklistValues();
        List<Schema.PicklistEntry> statusValues = field4.getPicklistValues();

        List<String> taxOptions = new List<String>();
        for (Schema.PicklistEntry entry : taxPercentageValue) {
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

        picklistMap.put('taxOptions', taxOptions);
        picklistMap.put('discOptions', discOptions);
        picklistMap.put('discountType', discountType);
        picklistMap.put('statusOptions', statusOptions);
        return picklistMap;
    }
    // Enhanced wrapper methods for individual data retrieval
    @AuraEnabled
    public static EstimationWrapper getEstimation(String EstimationId) {
        try {
            List<Estimation__c> estList = [
                SELECT Id,Name,Customer__r.Name,Customer__r.Preferred_Currency_Code__c,Shipping_Terms__c,Payment_Terms__c,
                Total_Discount_Amount__c ,Total_Discount_Percentage__c ,Discount_Mode__c,Order_Date__c,Status__c,
                Discount_Type__c,Tax_Percentage__c,PO_Ref_Num__c,Tax__c,Preferred_Currency__c
                FROM Estimation__c
                WHERE Id = :EstimationId WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            if (estList.isEmpty()) {
                throw new AuraHandledException('Estimation not found');
            }
            
            return new EstimationWrapper(estList[0]);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
 
    @AuraEnabled
    public static List<ESItemWrapper> getestimationItems(String EstimationId) {
        try {
            List<ESItemWrapper> itemWrappers = new List<ESItemWrapper>();
            List<Estimation_Item__c> ESItems = [
                SELECT Id,Name, Product__c, Product__r.Name, Product__r.SKU__c,
                Product__r.Product_Quantity__c,Product__r.Stock_Available__c, Product__r.Listing_Price__c,Product__r.Actual_Cost__c,
                Quantity__c, Tax_Percentage__c,Unit_Price__c,Discount_Amount__c,Discount_Percentage__c,Description__c,
                Estimation__r.Discount_Type__c,Discount_Type__c ,key__c,Lead_Time__c,Tax__c
                FROM Estimation_Item__c
                WHERE Estimation__c = :EstimationId WITH SECURITY_ENFORCED
                ORDER BY key__c ASC
            ];
            
            for (Estimation_Item__c item : ESItems) {
                itemWrappers.add(new ESItemWrapper(item));
            }
            
            return itemWrappers;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void deleteEstimationItem(Id itemId) {
        try {
            delete [SELECT Id FROM Estimation_Item__c WHERE Id = :itemId WITH SECURITY_ENFORCED];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage()); 
        }
    }
}