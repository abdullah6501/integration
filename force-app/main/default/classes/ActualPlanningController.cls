public with sharing class ActualPlanningController {
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getPeopleCostingData(Id recordId) {
        List<RFAB__People__c> peopleList = [
            SELECT Id, RFAB__Billing_Rate__c, RFAB__Amount__c 
            FROM RFAB__People__c WHERE RFAB__Project__c = :recordId
        ];
        
        Decimal totalBillingRate = 0;
        Decimal totalAmount = 0;
        
        for (RFAB__People__c person : peopleList) {
            if (person.RFAB__Billing_Rate__c != null) {
                totalBillingRate += person.RFAB__Billing_Rate__c;
            }
            if (person.RFAB__Amount__c != null) {
                totalAmount += person.RFAB__Amount__c;
            }
        }
        
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        result.add(new Map<String, Object>{ 'costing' => 'Actual', 'amount' => totalBillingRate });
        result.add(new Map<String, Object>{ 'costing' => 'Planning', 'amount' => totalAmount });
		system.debug(result);
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, List<Map<String, Object>>> getGroupedResourceCosting(Id recordId) {
        List<RFAB__Resource__c> resourceList = [
            SELECT RFAB__Billing_Rate__c, RFAB__Amount__c, RFAB__Asset__c, RFAB__Product__c, RFAB__Quantity__c
            FROM RFAB__Resource__c WHERE RFAB__Project__c = :recordId
        ];
        
        Decimal equipmentActual = 0;
        Decimal equipmentPlanning = 0;
        Decimal materialActual = 0;
        Decimal materialPlanning = 0;

        for (RFAB__Resource__c r : resourceList) {
            String grp = (r.RFAB__Asset__c != null) ? 'equipment' : (r.RFAB__Product__c != null) ? 'material' : '';
            if (grp == 'equipment') {
                if (r.RFAB__Billing_Rate__c != null) {
                    equipmentActual += r.RFAB__Billing_Rate__c;
                }
                if (r.RFAB__Amount__c != null) {
                    equipmentPlanning += r.RFAB__Amount__c;
                }
            } else if (grp == 'material') {
                Decimal qty = r.RFAB__Quantity__c != null ? r.RFAB__Quantity__c : 1;

                if (r.RFAB__Billing_Rate__c != null) {
                    materialActual += qty * r.RFAB__Billing_Rate__c;
                }
                if (r.RFAB__Amount__c != null) {
                    materialPlanning += qty * r.RFAB__Amount__c;
                }
            }
        }

        Map<String, List<Map<String, Object>>> groupedResult = new Map<String, List<Map<String, Object>>>();

        groupedResult.put('equipment', new List<Map<String, Object>>{
            new Map<String, Object>{ 'costing' => 'Actual', 'amount' => equipmentActual },
            new Map<String, Object>{ 'costing' => 'Planning', 'amount' => equipmentPlanning }
        });

        groupedResult.put('material', new List<Map<String, Object>>{
            new Map<String, Object>{ 'costing' => 'Actual', 'amount' => materialActual },
            new Map<String, Object>{ 'costing' => 'Planning', 'amount' => materialPlanning }
        });
		system.debug(groupedResult);
        return groupedResult;
    }
}