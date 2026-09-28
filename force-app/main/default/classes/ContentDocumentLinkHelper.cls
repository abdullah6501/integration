public class ContentDocumentLinkHelper {

    public static void processInsertedFiles(List<ContentDocumentLink> newLinks) {
        Set<Id> invoiceIds = new Set<Id>();
        Map<Id, Id> fileIdToInvoiceIdMap = new Map<Id, Id>();

        for (ContentDocumentLink cdl : newLinks) {
            if (cdl.LinkedEntityId != null && String.valueOf(cdl.LinkedEntityId).startsWith('a0o')) { // Replace 'a01' with your actual RFAB__Invoice__c prefix
                invoiceIds.add(cdl.LinkedEntityId);
                fileIdToInvoiceIdMap.put(cdl.ContentDocumentId, cdl.LinkedEntityId);
            }
        }

        if (invoiceIds.isEmpty()) return;

        Map<Id, RFAB__Invoice__c> invoiceMap = new Map<Id, RFAB__Invoice__c>(
            [SELECT Id, RFAB__Contact__c, RFAB__Contact__r.MobilePhone
             FROM RFAB__Invoice__c
             WHERE Id IN :invoiceIds]
        );

        for (Id fileId : fileIdToInvoiceIdMap.keySet()) {
            Id invoiceId = fileIdToInvoiceIdMap.get(fileId);
            RFAB__Invoice__c invoice = invoiceMap.get(invoiceId);

            if (invoice != null && invoice.RFAB__Contact__r != null && String.isNotBlank(invoice.RFAB__Contact__r.MobilePhone)) {
                WhatsAppImageSenderController.sendImageToWhatsAppForInvoice(invoice.RFAB__Contact__r.MobilePhone, fileId);
            }
        }
    }
}
