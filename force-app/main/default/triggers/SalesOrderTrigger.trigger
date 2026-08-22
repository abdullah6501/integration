trigger SalesOrderTrigger on RFAB__Sales_Order__c (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        SalesOrderHandler.sendInAppNotification(Trigger.new);
    }
}