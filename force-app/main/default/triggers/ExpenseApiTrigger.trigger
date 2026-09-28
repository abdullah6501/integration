trigger ExpenseApiTrigger on RFAB__Expense__c (after insert, after update, after delete) {
    if (Trigger.isDelete) {
        FusionApiHandler.handleTrigger(Trigger.old, false, false, Trigger.isDelete);
        return;
    }
    List<SObject> filteredRecords = new List<SObject>();

    if (Trigger.isInsert) {
        for (RFAB__Expense__c expense : Trigger.new) {
            if (expense.External_Id__c != null && expense.External_Id__c.startsWith('external')) {
                continue; 
            }
            filteredRecords.add(expense);
        }
    } else if (Trigger.isUpdate) {
        filteredRecords.addAll(Trigger.new);
    }

    if (!filteredRecords.isEmpty()) {
        FusionApiHandler.handleTrigger(filteredRecords, Trigger.isInsert, Trigger.isUpdate, false);
    } 
}


