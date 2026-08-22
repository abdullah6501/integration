//Abdullah VS 15-May-2025 Handles operations related to project and employee cost records, including retrieving, saving, updating, and managing budget versions in Salesforce.
public with sharing class ProjectActualController {
    // Fetches active cost records associated with a given job order ID.
    @AuraEnabled(cacheable=true)
    public static ProjectActualWrapper getActualList(String Id) {
        System.debug('Id: ' + Id);
        ProjectActualWrapper wrapperList = new ProjectActualWrapper();
        Project__c ActualList = [
            SELECT Id, (SELECT Id, Name, Amount__c, Billing_Rate__c, Billing_Unit__c, Start_date__c, End_date__c, Allocation_Percentage__c, Employee__c, Employee__r.First_Name__c, Cost_Type__c, Is_Billable__c FROM Peoples__r),
                (SELECT Id, Name, Product__c, Product__r.Name, Asset__c, Asset__r.Name, Amount__c, Billing_Rate__c, Billing_Unit__c, Start_date__c, End_date__c, Allocation_Percentage__c, Cost_Type__c, Quantity__c FROM Resources__r)
            FROM Project__c
            WHERE Id = :Id 
        ];
        wrapperList = new ProjectActualWrapper(ActualList);
        return wrapperList;
    }

    // Saves or initializes a new set of cost records for a project (job order) using setup and version data.
    @AuraEnabled
    public static ProjectActualWrapper saveProjectActualList(String joId, String joActualData) {
        System.debug(joId);
        List<ProjectActualWrapper> awList = new List<ProjectActualWrapper>();
        List<People__c> peopleList = new List<People__c>();
        List<Resource__c> resourceList = new List<Resource__c>();
        Map<Integer, Cost__c> indexMap = new Map<Integer, Cost__c>();
        awList = (List<ProjectActualWrapper>) JSON.deserialize(joActualData, List<ProjectActualWrapper>.class);
        try {
            for (Integer i = 0; i < awList.size(); i++) {
                ProjectActualWrapper wrapper = awList[i];
                SObject record = wrapper.toSObject(joId, false);
                if (record == null) continue;

                if (record instanceof People__c) {
                    peopleList.add((People__c)record);
                } else if (record instanceof Resource__c) {
                    resourceList.add((Resource__c)record);
                }
            }
            if (!peopleList.isEmpty()) insert peopleList;
            if (!resourceList.isEmpty()) insert resourceList;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        return getActualList(joId);
    }

    // Updates existing cost records with new values and add new record from a serialized wrapper list.
    @AuraEnabled
    public static ProjectActualWrapper updateProjectActualList(String joId, String joActualData) {
        List<ProjectActualWrapper> awList = (List<ProjectActualWrapper>) JSON.deserialize(joActualData, List<ProjectActualWrapper>.class);

        List<People__c> peopleList = new List<People__c>();
        List<Resource__c> resourceList = new List<Resource__c>();

        Map<Integer, Id> idMap = new Map<Integer, Id>();

        try {
            for (Integer i = 0; i < awList.size(); i++) {
                ProjectActualWrapper wrapper = awList[i];
                SObject record = wrapper.toSObject(joId, true);
                if (record == null) continue;

                if (record instanceof People__c) {
                    peopleList.add((People__c)record);
                    idMap.put(i, ((People__c)record).Id);
                } else if (record instanceof Resource__c) {
                    resourceList.add((Resource__c)record);
                    idMap.put(i, ((Resource__c)record).Id);
                } 
            }

            if (!peopleList.isEmpty()) update peopleList;
            if (!resourceList.isEmpty()) update resourceList;

            for (Integer i = 0; i < awList.size(); i++) {
                if (idMap.containsKey(i)) {
                    awList[i].id = idMap.get(i);
                }
            }

        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        return getActualList(joId);
    }


    @AuraEnabled
    public static void deleteActual(Id recordId, String grp) {
        if (String.isBlank(recordId)) {
            throw new AuraHandledException('Record ID cannot be blank.');
        }
        if (grp == 'labor') {
            delete [SELECT Id FROM People__c WHERE Id = :recordId LIMIT 1];
        } else if (grp == 'equipment' || grp == 'material') {
            delete [SELECT Id FROM Resource__c WHERE Id = :recordId LIMIT 1];
        } 
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getPicklistValues() {
        Map<String, List<String>> picklistMap = new Map<String, List<String>>();

        Schema.DescribeFieldResult field1 = People__c.Billing_Unit__c.getDescribe();
        Schema.DescribeFieldResult field2 = People__c.Cost_Type__c.getDescribe();
        Schema.DescribeFieldResult field3 = Resource__c.Billing_Unit__c.getDescribe();
        Schema.DescribeFieldResult field4 = Resource__c.Cost_Type__c.getDescribe();
    
        List<Schema.PicklistEntry> laborRateTypeValues = field1.getPicklistValues();
        List<Schema.PicklistEntry> loborCostTypeValues = field2.getPicklistValues();
        List<Schema.PicklistEntry> equipmentRateTypeValues = field3.getPicklistValues();
        List<Schema.PicklistEntry> equipmentCostTypeValues = field4.getPicklistValues();

        List<String> laborRateType = new List<String>();
        for (Schema.PicklistEntry entry : laborRateTypeValues) {
            laborRateType.add(entry.getLabel());
        }

        List<String> laborCostType = new List<String>();
        for (Schema.PicklistEntry entry : loborCostTypeValues) {
            laborCostType.add(entry.getLabel());
        }

        picklistMap.put('laborRateType', laborRateType);
        picklistMap.put('laborCostType', laborCostType);
        List<String> equipmentRateType = new List<String>();

        for (Schema.PicklistEntry entry : equipmentRateTypeValues) {
            equipmentRateType.add(entry.getLabel());
        }

        List<String> equipmentCostType = new List<String>();
        for (Schema.PicklistEntry entry : equipmentCostTypeValues) {
            equipmentCostType.add(entry.getLabel());
        }

        picklistMap.put('equipmentRateType', equipmentRateType);
        picklistMap.put('equipmentCostType', equipmentCostType);

        return picklistMap;
    }

    @AuraEnabled(cacheable=true)
    public static NamespaceWrapper getNslog(){
        string ns = CommonUtility.getNameSpace();
        NamespaceWrapper nsw = new NamespaceWrapper();
        nsw.nameSpace = (ns == null ) ? 'null' : ns;
        return nsw;
    }

    public class NamespaceWrapper {
        @AuraEnabled 
        public string nameSpace {get;set;}
     }
    // Wrapper for Project__c with nested PeopleWrapper list
    public class ProjectActualWrapper {
        @AuraEnabled public Id id;
        @AuraEnabled public Id assetId;
        @AuraEnabled public Id productId;
        @AuraEnabled public Id employeeId;
        @AuraEnabled public String assetName;
        @AuraEnabled public String productName;
        @AuraEnabled public String employeeName;
        @AuraEnabled public String name;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public Decimal rate;
        @AuraEnabled public String rateType;
        @AuraEnabled public String costType;
        @AuraEnabled public String grp;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Decimal allocationPercentage;
        @AuraEnabled public String startDate;
        @AuraEnabled public string endDate;
        @AuraEnabled public Boolean isBillable;
        @AuraEnabled public List<ProjectActualWrapper> peopleList;
        @AuraEnabled public List<ProjectActualWrapper> materialList;
        @AuraEnabled public List<ProjectActualWrapper> equipmentList;
        public ProjectActualWrapper() {
            this.peopleList = new List<ProjectActualWrapper>();
            this.equipmentList = new List<ProjectActualWrapper>();
            this.materialList = new List<ProjectActualWrapper>();
        }

        public ProjectActualWrapper(Project__c proj) {
            this.peopleList = new List<ProjectActualWrapper>();
            this.equipmentList = new List<ProjectActualWrapper>();
            this.materialList = new List<ProjectActualWrapper>();
            if (proj.Peoples__r != null) {
                for (People__c p : proj.Peoples__r) {
                    this.peopleList.add(new ProjectActualWrapper(p));
                }
                for (Resource__c r : proj.Resources__r) {
                    if( r.Asset__c != null) {
                        this.equipmentList.add(new ProjectActualWrapper(r));
                    } else if (r.Product__c != null) {
                        this.materialList.add(new ProjectActualWrapper(r));
                    }
                }
            }
        }
        public ProjectActualWrapper(People__c p) {
            this.id = p.Id;
            this.name = p.Name;
            this.employeeId = p.Employee__c;
            this.employeeName = p.Employee__r.First_Name__c;
            this.rate = p.Billing_Rate__c;
            this.amount = p.Amount__c;
            this.rateType = p.Billing_Unit__c;
            this.costType = p.Cost_Type__c;
            this.startDate = String.valueOf(p.Start_date__c);
            this.endDate = String.valueOf(p.End_date__c);
            this.allocationPercentage = p.Allocation_Percentage__c;
            this.isBillable = p.Is_Billable__c;
            this.grp = 'labor';
            this.quantity = 0;
        }
        public ProjectActualWrapper(Resource__c r) {
            this.id = r.Id;
            this.name = r.Name;
            this.rate = r.Billing_Rate__c;
            this.amount = r.Amount__c;
            this.rateType = r.Billing_Unit__c;
            this.costType = r.Cost_Type__c;
            this.startDate = String.valueOf(r.Start_date__c);
            this.endDate = String.valueOf(r.End_date__c);
            this.allocationPercentage = r.Allocation_Percentage__c;
            this.assetId = r.Asset__c;
            this.assetName = (r.Asset__c != null) ? r.Asset__r.Name : '';
            this.productId = r.Product__c;
            this.productName = (r.Product__c != null) ? r.Product__r.Name : '';
            this.grp = (r.Asset__c != null) ? 'equipment' : (r.Product__c != null) ? 'material' : '';
            this.quantity = r.Quantity__c;
        }
        public SObject toSObject(String joId, Boolean isUpdate) {
            SObject record;
            try {
                if (grp == 'labor') {
                    People__c people = new People__c();
                    if (String.isNotBlank(id)) {
                        try {
                            people.Id = id;
                        } catch (Exception e) {
                            System.debug('Invalid People ID: ' + id);
                        }
                    }
                    people.Name = name;
                    people.Start_date__c = String.isNotBlank(startDate) ? Date.valueOf(startDate) : null;
                    people.End_date__c = String.isNotBlank(endDate) ? Date.valueOf(endDate) : null;
                    people.Allocation_Percentage__c = allocationPercentage;
                    people.Billing_Rate__c = rate;
                    people.Amount__c = amount;
                    people.Billing_Unit__c = rateType;
                    people.Employee__c = employeeId;
                    people.Cost_Type__c = costType;
                    people.Is_Billable__c = isBillable;
                    if (String.isNotBlank(joId) && !isUpdate) {
                        people.Project__c = joId;
                    }
                    record = people;
                } else if (grp == 'equipment' || grp == 'material') {
                    Resource__c resource = new Resource__c();
                    if (String.isNotBlank(id)) {
                        try {
                            resource.Id = id;
                        } catch (Exception e) {
                            System.debug('Invalid Resource ID: ' + id);
                        }
                    }
                    resource.Name = name;
                    resource.Billing_Rate__c = rate;
                    resource.Billing_Unit__c = rateType;
                    resource.Start_date__c = String.isNotBlank(startDate) ? Date.valueOf(startDate) : null;
                    resource.End_date__c = String.isNotBlank(endDate) ? Date.valueOf(endDate) : null;
                    resource.Amount__c = amount;
                    resource.Cost_Type__c = costType;
                    resource.Allocation_Percentage__c = allocationPercentage;
                    resource.Quantity__c = quantity;
                    if (grp == 'equipment') {
                        resource.Asset__c = assetId;
                    } else {
                        resource.Product__c = productId;
                    }
                    if (String.isNotBlank(joId) && !isUpdate) {
                        resource.Project__c = joId;
                    }
                    record = resource;
                } 
            } catch (Exception e) {
                System.debug('Error mapping wrapper to sObject: ' + e.getMessage());
            }
            return record;
        }
    }
}