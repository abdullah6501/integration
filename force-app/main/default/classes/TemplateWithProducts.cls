public class TemplateWithProducts {
    public static void sendTemplateForProducts() {
        String whatsAppNumber = '919688490676';
        List<WhatsApp_Template__c> templates = [SELECT Id, Template_Name__c, language__c 
            FROM WhatsApp_Template__c WHERE Template_Name__c = 'three_products' LIMIT 1];
        String temp = templates[0].Template_Name__c;
        String lang = templates[0].language__c;
        List<String> data = new List<String>();
 
        WhatsAppTemplateController.sendTemplateMessage(whatsAppNumber, temp, lang, data);
    }
    // WhatsAppTemplateController.sendTemplateMessageForRequest(whatsappNumber, temp, lang, data);
}