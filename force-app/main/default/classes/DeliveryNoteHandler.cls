public class DeliveryNoteHandler {
    public static void sendInAppNotification(List<RFAB__Delivery_Note__c> newDeliveryNotes) {
        Set<Id> salesOrderIds = new Set<Id>();
        
        for (RFAB__Delivery_Note__c dn : newDeliveryNotes) {
            if (dn.RFAB__Sales_Order__c != null) {
                salesOrderIds.add(dn.RFAB__Sales_Order__c);
            }
        }
        
        if (salesOrderIds.isEmpty()) {
            System.debug('No Sales Orders found in Delivery Notes');
            return;
        }

        Map<Id, RFAB__Sales_Order__c> salesOrderMap = new Map<Id, RFAB__Sales_Order__c>(
            [SELECT Id, Project__c
            FROM RFAB__Sales_Order__c
            WHERE Id IN :salesOrderIds AND Project__c != null]
        );
        
        Set<Id> projectIds = new Set<Id>();
        for (RFAB__Sales_Order__c so : salesOrderMap.values()) {
            projectIds.add(so.Project__c);
        }
        
        Map<Id, RFAB__Project__c> projectMap = new Map<Id, RFAB__Project__c>(
            [SELECT Id,
                (SELECT Id, RFAB__User__c, RFAB__Role__c 
                 FROM RFAB__Peoples__r 
                 WHERE RFAB__Role__c = 'Warehouse Manager' AND RFAB__User__c != null)
            FROM RFAB__Project__c
            WHERE Id IN :projectIds]
        );

        List<CustomNotificationType> notifyId = [SELECT Id, DeveloperName FROM 
            CustomNotificationType WHERE DeveloperName = 'Creating_Invoice' LIMIT 1];
        
        if (notifyId.isEmpty()) {
            System.debug('Custom notification type "Creating_Invoice" not found');
            return;
        }
        
        Id notifyTypeId = notifyId[0].Id;

        for (RFAB__Delivery_Note__c dn : newDeliveryNotes) {
            if (salesOrderMap.containsKey(dn.RFAB__Sales_Order__c)) {
                RFAB__Sales_Order__c salesOrder = salesOrderMap.get(dn.RFAB__Sales_Order__c);
                Id projectId = salesOrder.Project__c;
                
                if (projectMap.containsKey(projectId)) {
                    RFAB__Project__c project = projectMap.get(projectId);
                    
                    Set<String> warehouseManagerIds = new Set<String>();
                    for (RFAB__People__c person : project.RFAB__Peoples__r) {
                        warehouseManagerIds.add(person.RFAB__User__c);
                    }
                    
                    if (!warehouseManagerIds.isEmpty()) {
                        Messaging.CustomNotification notification = new Messaging.CustomNotification();
                        notification.setTitle('New Delivery Note Created');
                        notification.setBody('A new Delivery Note has been created for your project. Click to view details.');
                        notification.setNotificationTypeId(notifyTypeId);
                        List<RFAB__Delivery_Note__c> dnWithReq = [SELECT Id, RFAB__Sales_Order__c, RFAB__Sales_Order__r.Request__c FROM RFAB__Delivery_Note__c WHERE Id = :dn.Id];
                        notification.setTargetId(dnWithReq[0].RFAB__Sales_Order__r?.Request__c);
                        
                        try {
                            notification.send(warehouseManagerIds);
                            System.debug('Delivery Note notification sent to Warehouse Managers: ' + warehouseManagerIds);
                        } catch (Exception e) {
                            System.debug('Error sending delivery note notification: ' + e.getMessage());
                        }
                    }
                }
            }
        }
    }
}