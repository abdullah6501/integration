public with sharing class ProductSearchController {
    @AuraEnabled(cacheable=true)
    public static List<ResultWrapper> searchProducts(String searchKey) {
        List<Product__c> records = [SELECT Id, Name, ProductCode__c,Product_Quantity__c FROM Product__c WHERE Name LIKE :('%' + searchKey + '%') OR ProductCode__c LIKE :('%' + searchKey + '%') WITH SECURITY_ENFORCED LIMIT 10];
        system.debug('records: ' + records);
        List<ResultWrapper> resultList = new List<ResultWrapper>();
        for (Product__c record : records) {
            ResultWrapper wrapper = new ResultWrapper();
            wrapper.id = record.Id;
            wrapper.mainField = record.Name;
            wrapper.codeField = record.ProductCode__c;
            wrapper.quantityField = record.Product_Quantity__c;
            resultList.add(wrapper);
        }

        return resultList;
    }

    // @AuraEnabled(cacheable=true)
    // public static List<Location__c> getLocations(Id productId) {
    //     return [SELECT Id, Name, ProductCode__c FROM Product__c WHERE Name LIKE :('%' + searchKey + '%') OR ProductCode__c LIKE :('%' + searchKey + '%')WITH SECURITY_ENFORCED LIMIT 10];
    // }

    @AuraEnabled(cacheable=true)
    public static List<ProductAvailabilityWrapper> getProductAvailability(Id productId, Id locationId) {
        String query = 'SELECT Location__r.Name, Quantity__c,Product__r.Product_Quantity__c  FROM Product_Availability__c WHERE Product__c = :productId WITH SECURITY_ENFORCED LIMIT 10';
        
        List<Product_Availability__c> productAvailabilities = Database.query(query);
        
        List<ProductAvailabilityWrapper> results = new List<ProductAvailabilityWrapper>();
        for (Product_Availability__c pa : productAvailabilities) {
            results.add(new ProductAvailabilityWrapper(pa.Location__r.Name, pa.Quantity__c,pa.Product__r.Product_Quantity__c));
        }
        return results;
    }

    

    public class ProductAvailabilityWrapper {
        @AuraEnabled public String locationName { get; set; }
        @AuraEnabled public Decimal quantity { get; set; }
        @AuraEnabled public Decimal productQuantity { get; set; }

        public ProductAvailabilityWrapper(String locationName, Decimal quantity,Decimal productQuantity) {
            this.locationName = locationName;
            this.quantity = quantity;
            this.productQuantity = productQuantity;
        }
    }

    public class ResultWrapper {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String mainField { get; set; } // Maps to Name
        @AuraEnabled public String codeField { get; set; }
        @AuraEnabled public Decimal quantityField { get; set; }
        
    }
}