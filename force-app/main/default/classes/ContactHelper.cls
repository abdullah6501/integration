public with sharing class ContactHelper {
    public static void processRequest(RFAB__Request__c req) {
    
    }
    // WhatsAppTemplateController.sendTemplateMessageForRequest(whatsappNumber, temp, lang, data);
}
public with sharing class RequestHelper {
    public static void processRequest(RFAB__Request__c req) {
        List<Contact> phone = [
            SELECT Id, MobilePhone
            FROM Contact
            WHERE Title = 'CEO' LIMIT 1];
        String whatsappNumber = String.valueOf(phone[0].MobilePhone);
        List<WhatsApp_Template__c> templates = [SELECT Id, Template_Name__c, language__c 
            FROM WhatsApp_Template__c WHERE Template_Name__c = 'request_notify' LIMIT 1];
        String temp = templates[0].Template_Name__c;
        String lang = templates[0].language__c;
        List<String> data = new List<String>();
        data.add('Name');
        data.add(req.Name);
        data.add(String.valueOf(req.RFAB__Request_Date__c));
        data.add(req.RFAB__Status__c);
 
        WhatsAppTemplateController.sendTemplateMessageForRequest(whatsappNumber, temp, lang, data);
    }
}