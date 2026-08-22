public class CreditNoteService {
    public static void createCreditNoteFromRequest(Id requestId, Integer quantity) {
        System.debug('createCreditNoteFromRequest');
        System.debug('requestId: ' + requestId);
        System.debug('quantity:');
        RFAB__Request__c req = [
            SELECT Id,
                   (SELECT Id FROM Sale_Orders__r LIMIT 1)
            FROM RFAB__Request__c
            WHERE Id = :requestId
            LIMIT 1
        ];

        if (req.Sale_Orders__r.isEmpty()) {
            System.debug('No Sales Order found for request');
            return;
        }

        Id salesOrderId = req.Sale_Orders__r[0].Id;

        RFAB__Invoice__c invoice = [
            SELECT Id, RFAB__Account__c, RFAB__Exchange_Rate__c, RFAB_Sales_Order__c,
                   (SELECT Id, RFAB__Quantity__c, RFAB__Tax__c, RFAB__Tax__r.RFAB__Tax_Percentage__c, RFAB__Product1__c, RFAB__Rate__c FROM RFAB__Invoice_Items__r LIMIT 1)
            FROM RFAB__Invoice__c
            WHERE RFAB_Sales_Order__c = :salesOrderId
            LIMIT 1
        ];

        if (invoice == null || invoice.RFAB__Invoice_Items__r.isEmpty()) {
            System.debug('No invoice or invoice items found');
            return;
        }

        RFAB__Invoice_Item__c invoiceItem = invoice.RFAB__Invoice_Items__r[0];

        RFAB__Credit_Note__c creditNote = new RFAB__Credit_Note__c();
        creditNote.RFAB__Invoice__c = invoice.Id;
        creditNote.RFAB__Account__c = invoice.RFAB__Account__c;
        creditNote.RFAB__Exchange_Rate__c = invoice.RFAB__Exchange_Rate__c;
        insert creditNote;

        RFAB__Credit_Note_Item__c creditNoteItem = new RFAB__Credit_Note_Item__c();
        creditNoteItem.RFAB__Credit_Note__c = creditNote.Id;
        creditNoteItem.RFAB__Quantity__c = quantity;
        creditNoteItem.RFAB__Product__c = invoiceItem.RFAB__Product1__c;
        creditNoteItem.RFAB__Rate__c = invoiceItem.RFAB__Rate__c;
        creditNoteItem.RFAB__Amount_without_Tax__c = quantity * invoiceItem.RFAB__Rate__c;
        creditNoteItem.RFAB__Tax__c = invoiceItem.RFAB__Tax__c;
        creditNoteItem.RFAB__Tax_Amount__c = ((quantity * invoiceItem.RFAB__Rate__c) * (invoiceItem.RFAB__Tax__r.RFAB__Tax_Percentage__c)) / 100;
        creditNoteItem.RFAB__Total_Amount__c = (quantity * invoiceItem.RFAB__Rate__c) + ((quantity * invoiceItem.RFAB__Rate__c) * (invoiceItem.RFAB__Tax__r.RFAB__Tax_Percentage__c)) / 100;
        insert creditNoteItem;

        System.debug('Credit Note and Item created successfully');
    }

    public static void messageToWhatsApp(List<RFAB__Credit_Note__c> creditNotes) {
        Set<Id> creditNoteIds = new Set<Id>();
        for (RFAB__Credit_Note__c cn : creditNotes) {
            creditNoteIds.add(cn.Id);
        }

        List<RFAB__Credit_Note__c> creditNoteNumber = [
            SELECT Id,
                RFAB__Invoice__r.RFAB_Sales_Order__r.Request__r.RFAB__Contact__r.MobilePhone
            FROM RFAB__Credit_Note__c
            WHERE Id IN :creditNoteIds
        ];

        for (RFAB__Credit_Note__c note : creditNoteNumber) {
            String mobile = null;
            String messageBody = 'Credit Note issued';
            Id requestId = note.RFAB__Invoice__r.RFAB_Sales_Order__r.Request__c;

            try {
                mobile = note.RFAB__Invoice__r.RFAB_Sales_Order__r.Request__r.RFAB__Contact__r.MobilePhone;
            } catch (Exception e) {
                System.debug('Missing relationship: ' + e.getMessage());
            }

            System.enqueueJob(new CreditNoteQueueable(requestId, null, mobile,  messageBody));
            // if (String.isNotBlank(mobile)) 
            //     WhatsAppOutMessage.sendMessageForAgentYes(mobile,messageBody,requestId);
            // } else {
            //     System.debug('MobilePhone not found for Credit Note Id: ' + note.Id);
            // }
        }
    }
}
