public with sharing class search {
    @AuraEnabled(cacheable=true)
    public static List<Project__c> searchProjects(String projectkey) {
        return [SELECT Id, Name
                FROM Project__c
                WHERE Name LIKE :('%' + projectkey + '%') LIMIT 10];
    }
 
    @AuraEnabled(cacheable=true)
    public static List<Location__c> searchLocations(String sitekey) {
        return [SELECT Id, Name
                FROM Location__c
                WHERE Name LIKE :('%' + sitekey + '%') LIMIT 10];
    }
 
    @AuraEnabled(cacheable=true)
    public static List<Product__c> searchProducts(String searchKey) {
        return [SELECT Id, Name
                FROM Product__c
                WHERE Name LIKE :('%' + searchKey + '%') LIMIT 10];
    }
 
    @AuraEnabled(cacheable=true)
    public static List<Employee__c> searchEmployees(String searchTerm) {
        return [SELECT Id, Name, Email_Address__c
                FROM Employee__c
                WHERE Name LIKE :('%' + searchTerm + '%') LIMIT 10];
    }
 
    @AuraEnabled(cacheable=true)
    public static List<Employee__c> getAllEmployees() {
            return [SELECT Id, Name, Email_Address__c FROM Employee__c LIMIT 100];
    }
 
    @AuraEnabled(cacheable=true)
    public static Product__c getProductQuantity(String productName) {
        Product__c product = [
            SELECT Id, Name, Product_Quantity__c
            FROM Product__c
            WHERE Name = :productName
            LIMIT 1
        ];
        return product;
    }
 
    @AuraEnabled
    public static void sendEmail(String project, String location, List<Map<String, String>> tableData, String requestId) {
        Employee__c requestEmployee = [
            SELECT Email_Address__c
            FROM Employee__c
            WHERE Id = :requestId
            LIMIT 1
        ];
 
        if (requestEmployee == null || String.isBlank(requestEmployee.Email_Address__c)) {
            throw new AuraHandledException('Request employee email address is invalid or not found.');
        }
 
        String emailBody = 'Project: ' + project + '\n' +
                           'Location: ' + location + '\n' +
                           'Table Data:\n';
 
        for (Map<String, String> row : tableData) {
            emailBody += 'Product: ' + row.get('product') + ', ' +
                         'Product Availability: ' + row.get('productAvailability') + ', ' +
                         'Quantity: ' + row.get('quantity') + ', ' +
                         'Date: ' + row.get('date') + ', ' +
                         'Comments: ' + row.get('comments') + '\n';
        }
 
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new String[] { requestEmployee.Email_Address__c });
        email.setSubject('Project and Product Details');
        email.setPlainTextBody(emailBody);
 
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
    }
}
 
 