trigger CreditNoteTrigger on RFAB__Credit_Note__c (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        CreditNoteService.messageToWhatsApp(Trigger.new);
    }
}
