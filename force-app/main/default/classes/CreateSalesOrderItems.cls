// <!--AR 21/05/2025 So item Component with Discount and tax -->
// GV - 26-06-25 --> wrapper changes 
//<!-- AR 2/07/2025  Change Actual coast to listing price , Name Fixed-->
public with sharing class CreateSalesOrderItems {

        /**
     * Fetches Payment_Term__c, Shipping_Term__c, Preferred_Currency_Code__c from Account by Id
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getAccountDetails(Id accountId) {
        Map<String, String> result = new Map<String, String>();
        if (accountId == null) return result;
        try {
            Account acc = [SELECT Id, Payment_Term__c, Shipping_Term__c, Preferred_Currency_Code__c FROM Account WHERE Id = :accountId LIMIT 1];
            result.put('paymentTerms', acc.Payment_Term__c);
            result.put('shippingTerms', acc.Shipping_Term__c);
            result.put('currencyCode', acc.Preferred_Currency_Code__c);
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching Account details: ' + e.getMessage());
        }
        return result;
    }

    @AuraEnabled
    public static String savesalesOrderItems(String wrappersJson, Id salesOrderId) {
        System.debug('wrapper--->'+ wrappersJson);
        try {
            if (String.isBlank(wrappersJson)) {
                throw new AuraHandledException('Input JSON is empty or null.');
            }
            // Additional null/empty check before parsing
            if (wrappersJson == null || wrappersJson.trim() == '') {
                throw new AuraHandledException('Input JSON is empty or null.');
            }
            // Parse the incoming JSON string as a List<Map<String, Object>>
            List<Object> rawList = (List<Object>) JSON.deserializeUntyped(wrappersJson);
            List<SOItemWrapper> wrappers = new List<SOItemWrapper>();
            for (Object obj : rawList) {
            Map<String, Object> mapObj = (Map<String, Object>) obj;
            SOItemWrapper wrapper = new SOItemWrapper();
            wrapper.id = (String) mapObj.get('id');
            wrapper.key = mapObj.get('key') != null ? Integer.valueOf(String.valueOf(mapObj.get('key'))) : null;
            wrapper.productId = (String) mapObj.get('productId');
            wrapper.productName = (String) mapObj.get('productName');
            wrapper.listingPrice = mapObj.get('listingPrice') != null ? Decimal.valueOf(String.valueOf(mapObj.get('listingPrice'))) : null;
            wrapper.quantity = mapObj.get('quantity') != null ? Integer.valueOf(String.valueOf(mapObj.get('quantity'))) : null;
            wrapper.unitPrice = mapObj.get('unitPrice') != null ? Decimal.valueOf(String.valueOf(mapObj.get('unitPrice'))) : null;
            wrapper.taxPercentage = mapObj.get('taxPercentage') != null ? String.valueOf(mapObj.get('taxPercentage')) : null;
            wrapper.discountAmount = mapObj.get('discountAmount') != null ? Decimal.valueOf(String.valueOf(mapObj.get('discountAmount'))) : null;
            wrapper.discountPercentage = mapObj.get('discountPercentage') != null ? Decimal.valueOf(String.valueOf(mapObj.get('discountPercentage'))) : null;
            wrapper.discountType = (String) mapObj.get('discountType');
            wrappers.add(wrapper);
            }
            List<SO_Items__c> recordsToUpsert = new List<SO_Items__c>();
            for (SOItemWrapper wrapper : wrappers) {
                // Skip records without Product__c
                if (String.isBlank(wrapper.productId)) {
                    continue;
                }
                SO_Items__c item = new SO_Items__c();
                // Only set Id if wrapper.id is not blank
                if (String.isNotBlank(wrapper.id)) {
                    try {
                        item.Id = Id.valueOf(wrapper.id);
                    } catch (Exception idException) {
                        System.debug('Invalid ID found, treating as new record: ' + wrapper.id);
                    }
                }
                // Required fields
                item.Name = wrapper.productName;
                item.Product__c = wrapper.productId;
                item.Quantity__c = wrapper.quantity;
                item.Unit_Price__c = wrapper.unitPrice ?? wrapper.listingPrice;
                item.Tax_Percentage__c = wrapper.taxPercentage;
                item.Discount_Amount__c = wrapper.discountAmount;
                item.Discount_Percentage__c = wrapper.discountPercentage;
                item.Discount_Type__c = wrapper.discountType;
                item.Key__c = wrapper.key;
                item.Unit_of_Measure__c = 'Each';
                // Only set Sales_Order__c for new records (those without valid IDs)
                if (item.Id == null) {
                    item.Sales_Order__c = salesOrderId;
                }
                recordsToUpsert.add(item);
            }

            // Only perform upsert if there are valid records
            if (!recordsToUpsert.isEmpty()) {
                upsert recordsToUpsert;
            }

            return 'SO Items Created Successfully';
            
        } catch (Exception e) {
            throw new AuraHandledException('Error saving SO Items: ' + e.getMessage());
        }
    }


    @AuraEnabled
    public static Id savesalesOrder(SalesOrderWrapper salesOrderWrapper) {
        try {
            Sales_Order__c salesOrder = salesOrderWrapper.toSalesOrder();
            if (salesOrder.id != null) {
                update salesOrder;
            } else {
                insert salesOrder;
            }
            return salesOrder.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Error updating Sales Order: ' + e.getMessage());
        }
    }
    @AuraEnabled(cacheable=true)
    public static List<ProductWrapper> searchProducts(String searchKey) {
        try {
            List<Product__c> products = [
                SELECT Id, Name, SKU__c, Lead_Time__c,Stock_Available__c, Listing_Price__c, Actual_Cost__c, Product_Quantity__c
                FROM Product__c
                WHERE Name LIKE :('%' + searchKey + '%') OR SKU__c LIKE :('%' + searchKey + '%')
                LIMIT 10  // GV 26-06-25 --> ordering code for search
            ];

            List<ProductWrapper> productWrappers = new List<ProductWrapper>();
            for (Product__c prod : products) {
                productWrappers.add(new ProductWrapper(prod));
            }

            return  productWrappers;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving products: ' + e.getMessage());
        }
    }
    @AuraEnabled(cacheable=true)
    public static List<String> getPicklistValue(String objectApiName, String fieldApiName) {
        List<String> options = new List<String>();
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();

        if (globalDescribe.containsKey(objectApiName)) {
            Schema.SObjectType objType = globalDescribe.get(objectApiName);
            Schema.DescribeSObjectResult objDescribe = objType.getDescribe();

            Schema.SObjectField fieldToken = objDescribe.fields.getMap().get(fieldApiName);

            if (fieldToken != null) {
                Schema.DescribeFieldResult fieldResult = fieldToken.getDescribe();
                List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();

                for (Schema.PicklistEntry entry : picklistValues) {
                    options.add(entry.getLabel());
                }
            }
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static SalesOrderWrapper getsalesOrder(Id salesOrderId) {
        try {
            Sales_Order__c salesOrder = [
                SELECT Id, Name, Customer__c, Customer__r.Name,Customer_PO_Ref__c, Customer__r.Preferred_Currency_Code__c, SO_Number__c, Lumpsum_Discount_Amount__c,
                    Lumpsum_Discount_Percentage__c, Discount_Mode__c, Payment_Terms__c, Shipping_Terms__c, Discount_Type__c, Sales_Date__c, Status__c, Sales__c,
                    Tax_Percentage__c, Title__c
                FROM Sales_Order__c
                WHERE Id = :salesOrderId
                LIMIT 1
            ];

            return new SalesOrderWrapper(salesOrder);

        } catch (Exception e) {

            throw new AuraHandledException('Error retrieving Sales Order: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<SOItemWrapper> getsalesOrderItems(Id salesOrderId) {
        try {
            List<SOItemWrapper> itemWrappers = new List<SOItemWrapper>();
            
            List<SO_Items__c> items = [
                SELECT Id, Product__c, Product__r.Name, Product__r.SKU__c,Product__r.Lead_Time__c,
                        Product__r.Stock_Available__c, Product__r.Listing_Price__c, 
                        Quantity__c, Tax_Percentage__c, Unit_Price__c, Discount_Amount__c,
                        Discount_Percentage__c, Sales_Order__r.Discount_Type__c,
                        Discount_Type__c, Key__c
                FROM SO_Items__c
                WHERE Sales_Order__c = :salesOrderId 
                ORDER BY Key__c ASC
            ];
            
            for (SO_Items__c item : items) {
                itemWrappers.add(new SOItemWrapper(item));
            }
            
            return itemWrappers;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving Sales Order Items: ' + e.getMessage());
        }
    }
    @AuraEnabled
    public static void deleteEstimationItem(Id itemId) {
        try {
            delete [SELECT Id FROM SO_Items__c WHERE Id = :itemId];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}