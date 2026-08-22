public class SalesOrderHandler {
    //Al Thoufic 04AUG2025 to create saleorder for the requesting orders
     public static void createSaleOrdersFromRequestItems(List<Id> requestItemIds) {
        // Query request items with related request and project details
        List<RFAB__Request_Item__c> requestItems = [
            SELECT Id, RFAB__Request__c, RFAB__Quantity__c, RFAB__Product__c,
                RFAB__Product__r.RFAB__Listing_Price__c,
                RFAB__Request__r.RFAB__Project__c,
                RFAB__Request__r.RFAB__Record_Type__c,
                RFAB__Request__r.RFAB__Request_Date__c,
                RFAB__Request__r.RFAB__Contact__r.Name,
                RFAB__Request__r.RFAB__Project__r.RFAB__Account__c,
                RFAB__Request__r.RFAB__Project__r.RFAB__Account__r.RFAB__Payment_Term__c,
                RFAB__Request__r.RFAB__Project__r.RFAB__Account__r.GST__c,
                RFAB__Request__r.RFAB__Project__r.RFAB__Account__r.RFAB__Shipping_Term__c,
                RFAB__Request__r.RFAB__Project__r.RFAB__Account__r.RFAB__Preferred_Currency_Code__c,
                RFAB__Request__r.RFAB__Project__r.Warehouse__c
            FROM RFAB__Request_Item__c
            WHERE Id IN :requestItemIds
        ];

        // Group items by their Request
        Map<Id, List<RFAB__Request_Item__c>> requestIdToItems = new Map<Id, List<RFAB__Request_Item__c>>();

        for (RFAB__Request_Item__c item : requestItems) {
            if (!requestIdToItems.containsKey(item.RFAB__Request__c)) {
                requestIdToItems.put(item.RFAB__Request__c, new List<RFAB__Request_Item__c>());
            }
            requestIdToItems.get(item.RFAB__Request__c).add(item);
        }

        List<RFAB__Sales_Order__c> saleOrdersToInsert = new List<RFAB__Sales_Order__c>();
        Map<Id, RFAB__Sales_Order__c> requestIdToSaleOrder = new Map<Id, RFAB__Sales_Order__c>();
        //to find existyance saleorder
        // List<RFAB__Sales_Order__c> saleorders = [SELECT Id,Request__c FROM RFAB__Sales_Order__c WHERE Request__c IN :requestIdToItems.keySet()];
        List<RFAB__Sales_Order__c> oldsaleorders = [SELECT Id,Request__c FROM RFAB__Sales_Order__c WHERE Request__c IN :requestIdToItems.keySet()];
        // Map<Id, RFAB__Sales_Order__c> requestIdToSaleOrder = new Map<Id, RFAB__Sales_Order__c>();

        for (RFAB__Sales_Order__c so : oldSaleOrders) {
            requestIdToSaleOrder.put(so.Request__c, so);
        }

        // create Sales Order per Request
        for (Id requestId : requestIdToItems.keySet()) {
            RFAB__Request_Item__c firstRequestItem = requestIdToItems.get(requestId)[0];// it can be anyitem due to groupby request
            Date day = firstRequestItem.RFAB__Request__r?.RFAB__Request_Date__c;
            if(requestIdToSaleOrder.get(requestId)!=null){
                continue;
            }
            RFAB__Sales_Order__c so = new RFAB__Sales_Order__c(
                Name = firstRequestItem.RFAB__Request__r?.RFAB__Contact__r?.Name+'-Request For-'+String.valueOf(day),
                Project__c = firstRequestItem.RFAB__Request__r?.RFAB__Project__c,
                RFAB__Customer__c = firstRequestItem.RFAB__Request__r?.RFAB__Project__r?.RFAB__Account__c,
                Warehouse__c = firstRequestItem.RFAB__Request__r?.RFAB__Project__r?.Warehouse__c,
                Request__c = firstRequestItem.RFAB__Request__c,
                RFAB__Shipping_Terms__c = firstRequestItem.RFAB__Request__r?.RFAB__Project__r?.RFAB__Account__r?.RFAB__Shipping_Term__c,
                RFAB__Payment_Terms__c = firstRequestItem.RFAB__Request__r?.RFAB__Project__r?.RFAB__Account__r?.RFAB__Payment_Term__c,
                RFAB__Preferred_Currency__c = firstRequestItem.RFAB__Request__r?.RFAB__Project__r?.RFAB__Account__r?.RFAB__Preferred_Currency_Code__c,
                RFAB__Sales__c = 'Local',
                RFAB__Status__c = 'Draft',
                RFAB__Sales_Date__c = firstRequestItem.RFAB__Request__r?.RFAB__Request_Date__c,
                GST__c = firstRequestItem.RFAB__Request__r?.RFAB__Project__r?.RFAB__Account__r?.GST__c
            );
            saleOrdersToInsert.add(so);
            requestIdToSaleOrder.put(requestId, so);

        }

        if (!saleOrdersToInsert.isEmpty()){
            insert saleOrdersToInsert; 

        } 

        // Create Sale Order Items 
        List<RFAB__SO_Items__c> saleOrderItemsToInsert = new List<RFAB__SO_Items__c>();

            for (RFAB__Request_Item__c item : requestItems) {
                if (item.RFAB__Product__c != null) {
                    String gst = item.RFAB__Request__r.RFAB__Project__r.RFAB__Account__r.GST__c;
                    String warehouse = item.RFAB__Request__r.RFAB__Project__r.Warehouse__c;
                    String selectedGst = 'a1jfI00001rkSQTQA2';
                if (
                    (warehouse == 'TN' && gst == 'Tamil Nadu') ||
                    (warehouse == 'KL' && gst == 'Kerala') ||
                    (warehouse == 'KA' && gst == 'Karnataka')
                ) {
                    selectedGst = 'a1jfI00001qnQZBQA2';
                }
                RFAB__Sales_Order__c so = requestIdToSaleOrder.get(item.RFAB__Request__c);
                if (so != null) {
                    saleOrderItemsToInsert.add(new RFAB__SO_Items__c(
                        RFAB__Sales_Order__c = so.Id,
                        RFAB__Product__c = item.RFAB__Product__c,
                        RFAB__Unit_Price__c = item.RFAB__Product__r?.RFAB__Listing_Price__c,
                        RFAB__Quantity__c = item.RFAB__Quantity__c,
                        RFAB__Unit_of_Measure__c = 'Each',
                        RFAB__Tax_Percent__c = 28,
                        RFAB__Tax__c = selectedGst//tagged tax for demo
                    ));
                }
                }
            }

        if (!saleOrderItemsToInsert.isEmpty()) {
            insert saleOrderItemsToInsert;
        }
    }

    public static void sendInAppNotification(List<RFAB__Sales_Order__c> newOrders) {
        Set<Id> projectIds = new Set<Id>();
        for (RFAB__Sales_Order__c so : newOrders) {
            if (so.Project__c != null) {
                projectIds.add(so.Project__c);
            }
        }

        Map<Id, RFAB__Project__c> projectMap = new Map<Id, RFAB__Project__c>(
            [SELECT Id,
                (SELECT Id, RFAB__User__c, RFAB__Role__c 
                 FROM RFAB__Peoples__r 
                 WHERE RFAB__Role__c = 'Project Manager' AND RFAB__User__c != null)
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
    
        for (RFAB__Sales_Order__c so : newOrders) {
            if (projectMap.containsKey(so.Project__c)) {
                RFAB__Project__c proj = projectMap.get(so.Project__c);

                Set<String> projectManagerIds = new Set<String>();
                for (RFAB__People__c person : proj.RFAB__Peoples__r) {
                    projectManagerIds.add(person.RFAB__User__c);
                }
                
                if (!projectManagerIds.isEmpty()) {
                    Messaging.CustomNotification notification = new Messaging.CustomNotification();
                    notification.setTitle('New Sales Order Created');
                    notification.setBody('A new Sales Order has been created for your project. Click to view details.');
                    notification.setNotificationTypeId(notifyTypeId);
                    notification.setTargetId(so.Id);
                    
                    try {
                        notification.send(projectManagerIds);
                        System.debug('Notification sent to Project Managers: ' + projectManagerIds);
                    } catch (Exception e) {
                        System.debug('Error sending notification: ' + e.getMessage());
                    }
                }
            }
        }
    }    
}