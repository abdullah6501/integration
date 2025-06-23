public with sharing class InvoicePicklistController {
    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getDependentPicklistValues() {
        Map<String, List<String>> dependentMap = new Map<String, List<String>>();
        
        // Initialize with all controlling values
        Schema.DescribeFieldResult controllingField = Invoice__c.Tax_ID__c.getDescribe();
        for (Schema.PicklistEntry entry : controllingField.getPicklistValues()) {
            if (entry.isActive()) {
                dependentMap.put(entry.getValue(), new List<String>());
            }
        }
        
        // Query existing records to understand relationships
        try {
            List<Invoice__c> existingRecords = [
                SELECT Tax_ID__c, Tax_Exemption_Reason__c 
                FROM Invoice__c 
                WHERE Tax_ID__c != NULL AND Tax_Exemption_Reason__c != NULL
                LIMIT 1000
            ];
            
            // Build relationships from existing data
            Map<String, Set<String>> tempMap = new Map<String, Set<String>>();
            for (Invoice__c record : existingRecords) {
                if (!tempMap.containsKey(record.Tax_ID__c)) {
                    tempMap.put(record.Tax_ID__c, new Set<String>());
                }
                tempMap.get(record.Tax_ID__c).add(record.Tax_Exemption_Reason__c);
            }
            
            // Convert Set to List for each controlling value
            for (String controllingValue : tempMap.keySet()) {
                dependentMap.put(controllingValue, new List<String>(tempMap.get(controllingValue)));
            }
            
        } catch (Exception e) {
            System.debug('Error querying records: ' + e.getMessage());
            // Fall back to getting all possible values if query fails
            Schema.DescribeFieldResult dependentField = Invoice__c.Tax_Exemption_Reason__c.getDescribe();
            List<String> allDependentValues = new List<String>();
            for (Schema.PicklistEntry entry : dependentField.getPicklistValues()) {
                if (entry.isActive()) {
                    allDependentValues.add(entry.getLabel());
                }
            }
            for (String key : dependentMap.keySet()) {
                dependentMap.put(key, allDependentValues);
            }
        }
        
        return dependentMap;
    }
}