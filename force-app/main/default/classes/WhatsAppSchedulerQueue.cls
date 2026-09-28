public class WhatsAppSchedulerQueue implements Queueable {

    public void execute(QueueableContext context) {
        List<RFAB__Project__c> projects = [
            SELECT Id, Name, RFAB__Account__c, RFAB__Account__r.Name
            FROM RFAB__Project__c
            WHERE RFAB__Account__c != null
        ];

        Set<Id> accountIds = new Set<Id>();
        for (RFAB__Project__c proj : projects) {
            accountIds.add(proj.RFAB__Account__c);
        }

        Map<Id, List<Contact>> accountToContactsMap = new Map<Id, List<Contact>>();
        for (Contact con : [
            SELECT Id, Name, MobilePhone, AccountId
            FROM Contact
            WHERE AccountId IN :accountIds
        ]) {
            if (!accountToContactsMap.containsKey(con.AccountId)) {
                accountToContactsMap.put(con.AccountId, new List<Contact>());
            }
            accountToContactsMap.get(con.AccountId).add(con);
        }

        List<WhatsApp_Template__c> templates = [SELECT Id, Template_Name__c, language__c 
            FROM WhatsApp_Template__c WHERE Template_Name__c = 'three_products' LIMIT 1];
        // List<WhatsApp_Template__c> templates = [SELECT Id, Template_Name__c, language__c 
        //     FROM WhatsApp_Template__c WHERE Template_Name__c = 'welcome_mior_link' LIMIT 1];

        if (templates.isEmpty()) {
            System.debug('No WhatsApp template found.');
            return;
        }

        String temp = templates[0].Template_Name__c;
        String lang = templates[0].language__c;

        for (RFAB__Project__c proj : projects) {
            List<Contact> contacts = accountToContactsMap.get(proj.RFAB__Account__c);

            if (contacts != null) {
                for (Contact con : contacts) {
                    if (String.isNotBlank(con.MobilePhone)) {
                        String phone = con.MobilePhone;
                        // List<String> data = new List<String>{
                        //     con.Name,
                        //     'https://mior.my.site.com/materialrequest/'
                        // };
                        List<String> data = new List<String>();

                        WhatsAppTemplateController.sendTemplateMessageForRequest(phone, temp, lang, data);
                    }
                }
            }
        }
    }
}