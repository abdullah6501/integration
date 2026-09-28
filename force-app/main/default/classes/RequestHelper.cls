public class RequestHelper {
    public static void processRequest(RFAB__Request__c req) {
        String whatsAppNumber = String.valueOf(req.RFAB__Contact__r.MobilePhone);
        List<WhatsApp_Template__c> templates = [SELECT Id, Template_Name__c, language__c 
            FROM WhatsApp_Template__c WHERE Template_Name__c = 'request_notify' LIMIT 1];
        String temp = templates[0].Template_Name__c;
        String lang = templates[0].language__c;
        List<String> data = new List<String>();
        data.add(req.RFAB__Contact__r.Name);
        data.add(req.Name);
        data.add(String.valueOf(req.RFAB__Request_Date__c));
        data.add(req.RFAB__Status__c);
 
        WhatsAppTemplateController.sendTemplateMessageForRequest(whatsAppNumber, temp, lang, data);
    }

    public static void changeStateOfRequest(Id reqId, String status) {
        RFAB__Request__c req = [SELECT Id, RFAB__Status__c FROM RFAB__Request__c WHERE Id = :reqId];
        req.RFAB__Status__c = status;
        update req;
    }
    public static void changeRequestItemName(RFAB__Request_Item__c reqItem) {
        List<RFAB__Product__c> product = [SELECT Id, Name FROM RFAB__Product__c WHERE Id = :reqItem.RFAB__Product__c];
        reqItem.Name = product[0].Name;
    }
    public static void changeRequestName(RFAB__Request__c req) {
        List<Contact> contacts = [SELECT Id, Name FROM Contact WHERE Id = :req.RFAB__Contact__c];
        DateTime now = DateTime.now();
        String dateTimeString = now.format('yyyy-MM-dd_HH:mm:ss');
        req.Name = 'Req-'+contacts[0].Name+'-'+dateTimeString;
    }

    public static void handleDeliveredRequest(RFAB__Request__c req) {
        String whatsAppNumber = String.valueOf(req.RFAB__Contact__r.MobilePhone);
        List<WhatsApp_Template__c> templates = [SELECT Id, Template_Name__c, language__c 
            FROM WhatsApp_Template__c WHERE Template_Name__c = 'discrepancy' LIMIT 1];
        String temp = templates[0].Template_Name__c;
        String lang = templates[0].language__c;
        List<String> data = new List<String>();

        WhatsAppTemplateController.sendTemplateMessageForRequest(whatsAppNumber, temp, lang, data, req.Id);
    }

    public static void handleDeliveryAccept(RFAB__Request__c req) {
        RFAB__Request__c reqWithSO = [SELECT Id, driver__r.MobilePhone, RFAB__Contact__r.MobilePhone, (SELECT Id FROM Sale_Orders__r) FROM RFAB__Request__c WHERE Id = :req.Id];
        RFAB__Delivery_Note__c deliveryNote = [SELECT Id, Name, RFAB__Sales_Order__c FROM RFAB__Delivery_Note__c WHERE RFAB__Sales_Order__c = :reqWithSO.Sale_Orders__r[0].Id];
        String whatsAppNumber = String.valueOf(reqWithSO.driver__r.MobilePhone);
        String delivaryNote = deliveryNote.Name;
        List<WhatsApp_Template__c> templates = [SELECT Id, Template_Name__c, language__c 
            FROM WhatsApp_Template__c WHERE Template_Name__c = 'delivery_note' LIMIT 1];
        String temp = templates[0].Template_Name__c;
        String lang = templates[0].language__c;
        List<String> data = new List<String>();
        data.add(delivaryNote);

        WhatsAppTemplateController.sendTemplateMessageForRequest(whatsAppNumber, temp, lang, data, req.Id);
    }

    public static void handleDeliveryRequest(Id reqId) {
        RFAB__Request__c reqWithSO = [SELECT Id, driver__r.MobilePhone, (SELECT Id FROM Sale_Orders__r) FROM RFAB__Request__c WHERE Id = :reqId];
        RFAB__Delivery_Note__c deliveryNote = [SELECT Id, Name, RFAB__Sales_Order__c FROM RFAB__Delivery_Note__c WHERE RFAB__Sales_Order__c = :reqWithSO.Sale_Orders__r[0].Id];        
        String whatsAppNumber = String.valueOf(reqWithSO.driver__r.MobilePhone);
        String delivaryNote = deliveryNote.Name;
        System.debug('delivaryNote = ' + delivaryNote);
        List<WhatsApp_Template__c> templates = [SELECT Id, Template_Name__c, language__c 
            FROM WhatsApp_Template__c WHERE Template_Name__c = 'deliver_not' ];
        String temp = templates[0].Template_Name__c;
        String lang = templates[0].language__c;
        List<String> data = new List<String>();
        data.add(delivaryNote);

        WhatsAppTemplateController.sendTemplateMessageForRequest(whatsAppNumber, temp, lang, data,  reqId);
    }
}