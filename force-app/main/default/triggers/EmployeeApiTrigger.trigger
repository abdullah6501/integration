trigger EmployeeApiTrigger on RFAB__Employee__c (after insert, after update, before delete) {
    if (Trigger.isInsert || Trigger.isUpdate) {
        FusionApiHandler.handleTrigger(Trigger.new, Trigger.isInsert, Trigger.isUpdate, false);
    } else if (Trigger.isDelete) {
        FusionApiHandler.handleTrigger(Trigger.old, false, false, Trigger.isDelete);
    }
}
