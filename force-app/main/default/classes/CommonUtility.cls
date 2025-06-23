/*
S.NO      Date          Createdby                   Description                                         LastModifiedBy              LastModifiedDate
1.     08/12/2023    Mohamed Abdul Kadher       Common class for repeated functionality                       -                             -
*/
public with sharing class CommonUtility {
    //Common api url connectivity
    //public static final String EXTERNAL_SYSTEM_ENDPOINT = 'https://dev-api.rangerfusion.com';
    //'https://api.rangerfusion.com';
    
    //By passing permission name we can check is the user having the permission or not.
    public static Boolean permissionCheck(string psName) {
        List<PermissionSetAssignment> lstcurrentUserPerSet = [SELECT Id, PermissionSet.Name,AssigneeId FROM PermissionSetAssignment WHERE AssigneeId = :Userinfo.getUserId() With User_Mode];
        Boolean userHasUserpermission = false;
        for ( PermissionSetAssignment psa : lstcurrentUserPerSet ) {
            if ( psa.PermissionSet.Name.contains(psName) ) {
                userHasUserpermission = true;
            }
        }
        return userHasUserpermission;
    }

    //This will return managed package Namespace when it was installed to any system. 
    public static String getNameSpace() {
        ApexClass cs = [ SELECT NamespacePrefix FROM ApexClass WHERE Name = 'ApprovalProcessController' WITH SECURITY_ENFORCED ];
        return ((cs.NamespacePrefix != null) ? cs.NamespacePrefix+'__' : null);
    }
    
    //Benefit Master object query
    Public static List<Benefit_Master__c> getBMDetails(){
        List<Benefit_Master__c> bmList= [SELECT Id, Name, Type__c, Is_Employee_Editable__c, Cost__c, Is_Active__c, 
                                        Cost_Type__c, Calculate_From__c, Regime__c, Slab_Ranges_From__c, Slab_Ranges_To__c, 
                                        Maximum_Limit__c, Tax_Percentage__c, FY_Start__c, FY_End__c, Category__c, Is_Tax_Deductible__c, 
                                        Is_Add_to_PF_Calculate__c, SIF_Type__c, 
                                        Add_To_TDS__c, Benefit_Master__c, Benefit_Master__r.Category__c, RecordTypeId, RecordType.Name 
                                        FROM Benefit_Master__c WHERE Is_Active__c = true WITH SECURITY_ENFORCED
                                        ];
        return bmList;
    }

     // Class to return fiscal year start and end
    @AuraEnabled(cacheable=true)
    public static Map<String, Date> getFiscalYearRange() {
        Integer fiscalStartMonth = [SELECT FiscalYearStartMonth FROM Organization LIMIT 1].FiscalYearStartMonth;

        Date today = Date.today();
        Integer year = (today.month() >= fiscalStartMonth) ? today.year() : today.year() - 1;

        Date fiscalStartDate = Date.newInstance(year, fiscalStartMonth, 1);
        Date fiscalEndDate = fiscalStartDate.addMonths(12).addDays(-1);

        Map<String, Date> result = new Map<String, Date>();
        result.put('startDate', fiscalStartDate);
        result.put('endDate', fiscalEndDate);

        return result;
    }

    
}