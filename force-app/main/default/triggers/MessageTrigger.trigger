trigger MessageTrigger on Message__c (after insert, before insert) {
    MessageHandler.processMessages(Trigger.new);
}
