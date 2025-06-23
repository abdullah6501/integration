trigger SOnumber on RFAB__Sales_Order__c (after insert, after update, after delete) {
    if(Trigger.isInsert) {
        FusionApiHandler.handleTrigger(Trigger.new, Trigger.isInsert, Trigger.isUpdate, false);
        GenericAutoNumberUtil.assignAutoNumbers('RFAB__Sales_Order__c', Trigger.new);
    } else if (Trigger.isUpdate) {
        FusionApiHandler.handleTrigger(Trigger.new, Trigger.isInsert, Trigger.isUpdate, false);
    } else if (Trigger.isDelete) {
        FusionApiHandler.handleTrigger(Trigger.old, false, false, Trigger.isDelete);
    }
}