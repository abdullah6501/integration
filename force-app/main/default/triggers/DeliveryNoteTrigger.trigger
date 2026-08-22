trigger DeliveryNoteTrigger on RFAB__Delivery_Note__c (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        DeliveryNoteHandler.sendInAppNotification(Trigger.new);
    }
}