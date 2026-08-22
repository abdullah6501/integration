trigger RequestItemTrigger on RFAB__Request_Item__c (after insert, after update) {
    List<Id> requestItemIds = new List<Id>();
    for (RFAB__Request_Item__c requestItem : Trigger.new) {
        // if(Trigger.isInsert && Trigger.isBefore){
        //     RequestHelper.changeRequestItemName(requestItem);
        // }
        if (requestItem.RFAB__Quantity__c > 0) {
            requestItemIds.add(requestItem.Id);
        }
    }
    if(requestItemIds.size()>0){
        SalesOrderHandler.createSaleOrdersFromRequestItems(requestItemIds);
    }
    if (Trigger.isInsert && Trigger.isAfter){
        RequestHelper.changeRequestItemName(requestItemIds);
    }
}