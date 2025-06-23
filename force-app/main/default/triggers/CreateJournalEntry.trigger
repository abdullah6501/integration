trigger CreateJournalEntry on Invoice__c (after insert, after update) {
    InvoiceFormController.createJournalTrigger(Trigger.new, Trigger.oldMap);
}