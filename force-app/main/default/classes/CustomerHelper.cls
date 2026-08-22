public class CustomerHelper {
    public static void processContact(Customer cust) {
        String whatsappNumber = cust.Contact__r.MobilePhone;
        List<WhatsApp_Template__c> templates = [SELECT Id, Template_Name__c, language__c 
            FROM WhatsApp_Template__c WHERE Template_Name__c = 'welcome_mior_customer' LIMIT 1];
        String temp = templates[0].Template_Name__c;
        String lang = templates[0].language__c;

        List<String> data = new List<String>();
        data.add(cust.Name);
 
        WhatsAppTemplateController.sendTemplateMessageForRequest(whatsappNumber, temp, lang, data);
    }
}