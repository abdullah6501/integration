trigger RequestTrigger on RFAB__Request__c (after insert, after update) {
    for (RFAB__Request__c req : Trigger.new) {
        if((Trigger.isInsert && Trigger.isAfter) ||(Trigger.isUpdate && Trigger.isAfter)){
            System.enqueueJob(new RequestNotificationQueue(req.Id));    
            if(Trigger.isUpdate){
                if(req.driver__c != Trigger.oldMap.get(req.Id).driver__c){
                    RequestHelper.changeStateOfRequest(req.Id, 'Ready to Dispatch');
                    RequestHelper.handleDeliveryAccept(req);
                }
                if(req.RFAB__Status__c == 'Dispatched'){
                    System.enqueueJob(new DeliveryRequestQueue(req.Id));    
                }
                // if(req.RFAB__Status__c == 'Delivered'){
                //     System.enqueueJob(new DeliveryRequestQueue(req.Id));    
                // }
            } 
        }
        // else if(Trigger.isInsert && Trigger.isBefore){
        //     RequestHelper.changeRequestName(req); 
        // }

    }

}