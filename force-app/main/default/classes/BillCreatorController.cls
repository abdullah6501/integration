public with sharing class BillCreatorController {
    
    @AuraEnabled
    public static String createBillFromPurchaseOrder(Id purchaseOrderId) {
        try {
            // Query Purchase Order with related PO Items
            RFAB__Purchase_Order__c purchaseOrder = [
                SELECT Id, Name, RFAB__Vendor_Account__c
                FROM RFAB__Purchase_Order__c 
                WHERE Id = :purchaseOrderId 
                LIMIT 1
            ];
            
            // Query related PO Items
            List<RFAB__PO_Item__c> poItems = [
                SELECT Id, Name, RFAB__Product__c, RFAB__Quantity__c, RFAB__Unit_Price__c
                FROM RFAB__PO_Item__c 
                WHERE RFAB__Purchase_Order__c = :purchaseOrderId
            ];
            
            if (poItems.isEmpty()) {
                throw new AuraHandledException('No PO Items found for this Purchase Order.');
            }
            
            // Create Bill record
            RFAB__Bill__c newBill = new RFAB__Bill__c();
            newBill.Name = 'Bill - ' + purchaseOrder.Name;
            newBill.RFAB__VendorAccount__c = purchaseOrder.RFAB__Vendor_Account__c;
            newBill.RFAB__Bill_Date__c = Date.today();
            newBill.RFAB__Status__c = 'Draft';
            newBill.RFAB__Amounts_are__c = 'Out of scope of Tax';
            newBill.Purchase_Order__c = purchaseOrderId; // Lookup to Purchase Order
            
            insert newBill;
            
            // Create Bill Item records
            List<RFAB__Bill_Item__c> billItems = new List<RFAB__Bill_Item__c>();
            
            for (RFAB__PO_Item__c poItem : poItems) {
                RFAB__Bill_Item__c billItem = new RFAB__Bill_Item__c();
                billItem.Name = poItem.Name;
                billItem.RFAB__Bill__c = newBill.Id; // Master-Detail relationship
                billItem.RFAB__Product__c = poItem.RFAB__Product__c;
                billItem.RFAB__Quantity__c = poItem.RFAB__Quantity__c;
                billItem.RFAB__Unit_Price__c = poItem.RFAB__Unit_Price__c;
                
                billItems.add(billItem);
            }
            
            if (!billItems.isEmpty()) {
                insert billItems;
            }
            
            return newBill.Id;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error creating bill: ' + e.getMessage());
        }
    }
    
    // Helper method to get Purchase Order information for confirmation modal
    @AuraEnabled
    public static Map<String, Object> getPurchaseOrderInfo(Id purchaseOrderId) {
        try {
            RFAB__Purchase_Order__c purchaseOrder = [
                SELECT Id, Name,GRN_Status__c
                FROM RFAB__Purchase_Order__c 
                WHERE Id = :purchaseOrderId 
                LIMIT 1
            ];
            
            Integer itemsCount = [
                SELECT COUNT() 
                FROM RFAB__PO_Item__c 
                WHERE RFAB__Purchase_Order__c = :purchaseOrderId
            ];
            
            Map<String, Object> result = new Map<String, Object>();
            result.put('name', purchaseOrder.Name);
            result.put('itemsCount', itemsCount);
            
            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving Purchase Order information: ' + e.getMessage());
        }
    }
    
    //Helper method to check if bill already exists for this PO (optional validation)
    @AuraEnabled
    public static Boolean billExistsForPurchaseOrder(Id purchaseOrderId) {
        System.debug('Checking if bill exists for Purchase Order: ' + purchaseOrderId);
        try {
            Integer billCount = [
                SELECT COUNT() 
                FROM RFAB__Bill__c 
                WHERE Purchase_Order__c = :purchaseOrderId
            ];
            System.debug('Bill count: ' + billCount);
            return billCount > 0;
        } catch (Exception e) {
            return false;
        }
    }
}