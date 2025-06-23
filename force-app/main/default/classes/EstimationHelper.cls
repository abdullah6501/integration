public with sharing class EstimationHelper {
    public static void updateEstimationVersion(List<ContentDocumentLink> newFiles) {
        Set<Id> estimationIds = new Set<Id>();

        for (ContentDocumentLink cdl : newFiles) {
            if (cdl.LinkedEntityId.getSObjectType() == Estimation__c.SObjectType) {
            // if (cdl.LinkedEntityId.getSObjectType() == Sales_Order__c.SObjectType) {
                estimationIds.add(cdl.LinkedEntityId);
            }
        }

        if (!estimationIds.isEmpty()) {
            List<Estimation__c> estimationsToUpdate = new List<Estimation__c>();
            // List<Sales_Order__c> estimationsToUpdate = new List<Sales_Order__c>();
            // if (Schema.sObjectType.Estimation__c.isAccessible()) {
            if (Schema.sObjectType.Sales_Order__c.isAccessible()) {
                estimationsToUpdate = [SELECT Id, Estimation_Version__c FROM Estimation__c WHERE Id IN :estimationIds];
                // estimationsToUpdate = [SELECT Id, version__c FROM Sales_Order__c WHERE Id IN :estimationIds];
            } else {
                System.debug('User does not have read permissions for Estimation__c.');
            }

            List<Estimation__c> updatedEstimations = new List<Estimation__c>();
            // List<Sales_Order__c> updatedEstimations = new List<Sales_Order__c>();

            for (Estimation__c est : estimationsToUpdate) {
                est.Estimation_Version__c += 1; 
                updatedEstimations.add(est);
            }
            // for (Sales_Order__c est : estimationsToUpdate) {
            //     est.version__c += 1; 
            //     updatedEstimations.add(est);
            // }

            if (!updatedEstimations.isEmpty()) {
                if (Schema.sObjectType.Estimation__c.isUpdateable()) {
                // if (Schema.sObjectType.Sales_Order__c.isUpdateable()) {
                    update updatedEstimations;
                } else {
                    System.debug('User does not have update permissions for Estimation__c.');
                }
            }
        }
    }
}
