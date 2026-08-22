public class InvoiceHelper {
    @AuraEnabled
    public static void createInvoiceForSaleOrder(Id saleOrderId){
        RFAB__Sales_Order__c saleOrder = [Select Id, Project__c, RFAB__Customer__c, Warehouse__c, Request__c, Request__r.RFAB__Contact__c, Request__r.RFAB__Contact__r.Name,
        (Select Id, RFAB__Product__c, RFAB__Tax__c, RFAB__Tax_Percent__c, RFAB__Quantity__c, RFAB__Unit_Price__c from RFAB__SO_Items__r) from RFAB__Sales_Order__c where Id =:saleOrderId];

        RFAB__Invoice__c invoice = new RFAB__Invoice__c(
            RFAB_Sales_Order__c = saleOrder.Id,         // need to be crdeleetedeated
            RFAB__Account__c	 = saleOrder.RFAB__Customer__c,
            RFAB__Contact__c = saleOrder.Request__r.RFAB__Contact__c,
            Warehouse__c = saleOrder.Warehouse__c,
            RFAB__Create_Delivery_Notes__c = true,
            RFAB__Invoice_Date__c = Date.today()
        );

        insert invoice;

        RFAB__Delivery_Note__c DeliveryNote = new RFAB__Delivery_Note__c(
            Name = 'DN-' + saleOrder.Request__r.RFAB__Contact__r.Name + '-' +String.valueOf(Date.today()),
            RFAB__Invoice__c = invoice.Id,
            RFAB__Sales_Order__c = saleOrder.Id,         
            RFAB__Date__c = Date.today(),
            RFAB__Status__c = 'New'
            // Warehouse__c = saleOrder.Warehouse__c
        );

        insert DeliveryNote;

        List<RFAB__Invoice_Item__c> invoiceItemsToInsert = new List<RFAB__Invoice_Item__c>();
        List<RFAB__Delivery_Note_Item__c> deliveryNoteItemsToInsert = new List<RFAB__Delivery_Note_Item__c>();

        for (RFAB__SO_Items__c soItem : saleOrder.RFAB__SO_Items__r) {
                RFAB__Invoice_Item__c invoiceItem = new RFAB__Invoice_Item__c(
                RFAB__Invoice__c = invoice.Id,
                RFAB__Product1__c = soItem.RFAB__Product__c,
                RFAB__Rate__c = soItem.RFAB__Unit_Price__c,
                RFAB__Quantity__c = soItem.RFAB__Quantity__c,
                RFAB__Amount__c = soItem.RFAB__Unit_Price__c * soItem.RFAB__Quantity__c,
                RFAB__Tax__c = soItem.RFAB__Tax__c,
                RFAB__Amount_With_GST__c = ((soItem.RFAB__Unit_Price__c * soItem.RFAB__Quantity__c) * (soItem.RFAB__Tax_Percent__c)) / 100
            );
            invoiceItemsToInsert.add(invoiceItem);

            RFAB__Delivery_Note_Item__c deliveryNoteItem = new RFAB__Delivery_Note_Item__c(
                RFAB__Delivery_Note__c = DeliveryNote.Id,
                RFAB__Product__c = soItem.RFAB__Product__c,
                RFAB__Quantity__c = soItem.RFAB__Quantity__c
            );
            deliveryNoteItemsToInsert.add(deliveryNoteItem);

        }

        if (!invoiceItemsToInsert.isEmpty() && !deliveryNoteItemsToInsert.isEmpty()) {
            insert invoiceItemsToInsert;
            insert deliveryNoteItemsToInsert;
            RequestHelper.changeStateOfRequest(saleOrder.Request__c, 'Approved');

        }


    }
    public InvoiceHelper() {

    }
}