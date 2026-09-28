trigger sendMsgtoBot on message__c (after insert) {
    for (message__c msg : Trigger.new) {
        if (msg.Status__c == 'Received') {
            system.debug('okkkkk');
            // List<Contact> cons = [SELECT Id, Name, bot_session__c FROM Contact WHERE Phone = :msg.Receiver__c limit 1];
            // cons[0].botsession__c = '09ef550b-6d13-4db4-a0b4-1ac907195635';
            System.enqueueJob(new ExternalMessagePoster(msg.Message_Body__c, '2a734841-94e8-4a90-9091-0e9994eeaa36', '919655020213'));
            // System.enqueueJob(new ExternalMessagePoster('want to return products', '09ef550b-6d13-4db4-a0b4-1ac907195635', '919655020213'));

        }
    }


}