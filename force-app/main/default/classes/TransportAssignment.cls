public class TransportAssignment {
    public class TransAssignWrapper {
        @AuraEnabled public Id recordId;
        @AuraEnabled public Id productId;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Id driverId;
        @AuraEnabled public String driverNumber;
        @AuraEnabled public Id transportVendorId;
        @AuraEnabled public String vehicleNumber;
    }

    @AuraEnabled
    public static Id saveTransAssign(TransAssignWrapper wrapperData) {
        Transport_Assignment__c transAssign;
        if(wrapperData.recordId != null){
            transAssign = [SELECT Id FROM Transport_Assignment__c WHERE Id = :wrapperData.recordId LIMIT 1];
        } else {
            transAssign = new Transport_Assignment__c();
        }
        transAssign.Product__c = wrapperData.productId;
        transAssign.Quantity__c = wrapperData.quantity;
        transAssign.Driver_Name__c = wrapperData.driverId;
        transAssign.Driver_Number__c = wrapperData.driverNumber;
        transAssign.Transport_Vendor__c = wrapperData.transportVendorId;
        transAssign.Vehicle_Number__c = wrapperData.vehicleNumber;

        upsert transAssign;
        return transAssign.Id;
    }

    @AuraEnabled(cacheable=true)
    public static TransAssignWrapper getTransAssignById(Id recordId) {
        if(recordId == null) return null;
        Transport_Assignment__c trans = [
            SELECT Id, Product__c, Quantity__c, Driver_Name__c, Driver_Number__c,
                    Transport_Vendor__c, Vehicle_Number__c
            FROM Transport_Assignment__c
            WHERE Id = :recordId
            LIMIT 1
        ];
        TransAssignWrapper wrap = new TransAssignWrapper();
        wrap.recordId = trans.Id;
        wrap.productId = trans.Product__c;
        wrap.quantity = trans.Quantity__c;
        wrap.driverId = trans.Driver_Name__c;
        wrap.driverNumber = trans.Driver_Number__c;
        wrap.transportVendorId = trans.Transport_Vendor__c;
        wrap.vehicleNumber = trans.Vehicle_Number__c;
        return wrap;
    }
}
    