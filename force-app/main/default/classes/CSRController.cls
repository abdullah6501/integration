public with sharing class CSRController {
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getCountryPicklistValues() {
        List<Map<String, String>> countryList = new List<Map<String, String>>();
        
        Schema.DescribeFieldResult fieldResult = CSR_Configuration__c.Country__c.getDescribe();
        List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();

        for (Schema.PicklistEntry entry : picklistValues) {
            Map<String, String> countryMap = new Map<String, String>();
            countryMap.put('label', entry.getLabel());
            countryMap.put('value', entry.getValue());
            countryList.add(countryMap);
        }
        return countryList;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getInvoiceTypeValues() {
        List<Map<String, String>> invoiceTypeList = new List<Map<String, String>>();
        
        Schema.DescribeFieldResult fieldResult = CSR_Configuration__c.Invoice_Type__c.getDescribe();
        List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();

        for (Schema.PicklistEntry entry : picklistValues) {
            Map<String, String> invoiceTypeMap = new Map<String, String>();
            invoiceTypeMap.put('label', entry.getLabel());
            invoiceTypeMap.put('value', entry.getValue());
            invoiceTypeList.add(invoiceTypeMap);
        }
        return invoiceTypeList;
    }

    @AuraEnabled
    public static String saveCSRData(CSR_Configuration__c csr) {
        if (Schema.sObjectType.CSR_Configuration__c.isCreateable()) {
            insert csr;
            System.debug('CSR Configuration record created: ' + csr.Id);
            return csr.Id;
        } else {
            throw new SecurityException('Insufficient permissions to create CSR_Configuration__c records.');
        }
    }

    @AuraEnabled
    public static void sendCSRData(Map<String, String> requestData, String recId) {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        
        request.setEndpoint('https://zatca-api.rangerfusion.com/onbordingCSID');
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setBody(JSON.serialize(requestData));
        System.debug('Request Data: ' + requestData);

        HttpResponse response = http.send(request);

        if (response.getStatusCode() == 200) {
            System.debug('Response: ' + response.getBody());
            String jsonData = response.getBody();
            try {
            Map<String, Object> parsedJson = (Map<String, Object>) JSON.deserializeUntyped(jsonData);
            
            if (parsedJson.containsKey('onbordingCSIDResponse')) {
                Map<String, Object> onbordingCSIDResponse = (Map<String, Object>) parsedJson.get('onbordingCSIDResponse');

                if (onbordingCSIDResponse.containsKey('complianceCSID')) {
                    Map<String, Object> complianceCSID = (Map<String, Object>) onbordingCSIDResponse.get('complianceCSID');

                    if (complianceCSID.containsKey('productionCSID')) {
                        Map<String, Object> productionCSID = (Map<String, Object>) complianceCSID.get('productionCSID');
                        
                        String binarySecurityToken = (String) productionCSID.get('binarySecurityToken');
                        String secret = (String) productionCSID.get('secret');

                        System.debug('Binary Security Token: ' + binarySecurityToken);
                        System.debug('Secret: ' + secret);
                        System.debug('Record Id: ' + recId);

                        CSR_Configuration__c csrconfig = [SELECT Id FROM CSR_Configuration__c WHERE Id = :recId LIMIT 1];

                        csrconfig.Production_CSID_Token__c = binarySecurityToken;
                        csrconfig.Production_CSID_Secret__c = secret;

                        if (Schema.sObjectType.CSR_Configuration__c.isUpdateable()) {
                            update csrconfig;
                        } else {
                            throw new SecurityException('Insufficient permissions to update CSR_Configuration__c records.');
                        }
                    }
                }
            }
        } catch (Exception e) {
            System.debug('Error processing JSON: ' + e.getMessage());
        }
            // return response.getBody();
        } else {
            // return 'Error: ' + response.getStatus();
            system.debug('Error: ' + response.getStatus());
        }
    }
}