public with sharing class InvoiceCreationStockUpdate {
   
    @AuraEnabled
    public static String createInvoice(Id salesOrderId,String soItemsJson,
    List<String> description,List<String> serialNumbers,Boolean journalEntry, Boolean deliveryNotes){
        System.debug('soItemsJson--->'+soItemsJson);

        List<RFAB__SO_Items__c> soItems;
        try {
            if (String.isBlank(soItemsJson)) {
                throw new AuraHandledException('Sales order items data cannot be empty');
            }
            soItems = (List<RFAB__SO_Items__c>)JSON.deserialize(
                soItemsJson, 
                List<RFAB__SO_Items__c>.class
            );
            if (soItems == null || soItems.isEmpty()) {
                throw new AuraHandledException('No sales order items found in the data');
            }
        } catch (JSONException e) {
            throw new AuraHandledException('Error parsing sales order data: ' + e.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException('Unexpected error: ' + e.getMessage());
        }
                RFAB__Sales_Order__c so = [SELECT Id,Name,RFAB__Customer__c ,Invoice_Status__c,Final_Total_Amount__c,RFAB__Lumpsum_Discount_Percentage__c,RFAB__Lumpsum_Discount_Amount__c,RFAB__Tax_Percentage__c,RFAB__Discount_Type__c,
                RFAB__Discount_Mode__c
                FROM RFAB__Sales_Order__c WHERE Id = :salesOrderId  limit 1];
 
                 Map<Id, RFAB__SO_Items__c> soItemMap = new Map<Id, RFAB__SO_Items__c>(
                    [SELECT Id, RFAB__Quantity__c,RFAB__Tax_Percentage__c FROM RFAB__SO_Items__c WHERE RFAB__Sales_Order__c = :salesOrderId]
                );
         String invoice;                      
        if(so.Invoice_Status__c!='Fully Created'){
 
            RFAB__Invoice__c inv = new RFAB__Invoice__c();
            inv.RFAB__Account__c = so.RFAB__Customer__c;
            inv.Sales_Order__c= so.Id;
            inv.RFAB__Invoice_Date__c =system.today();
            inv.RFAB__Term__c = 'Net 15';
            inv.RFAB__Amounts_are__c='Exclusive of Tax';
            inv.Is_Delivery_note__c=deliveryNotes;
            inv.Is_Journal_Entry__c=journalEntry;
            if(so.RFAB__Discount_Type__c == 'Lumpsum Discount'){
                inv.RFAB__Lumpsum_Discount_Percentage__c = so.RFAB__Lumpsum_Discount_Percentage__c != null ? so.RFAB__Lumpsum_Discount_Percentage__c : 0;
                inv.RFAB__Lumpsum_Discount_Amount__c = so.RFAB__Lumpsum_Discount_Amount__c != null ? so.RFAB__Lumpsum_Discount_Amount__c : 0;
                inv.Tax_Percentage__c = so.RFAB__Tax_Percentage__c != null ? so.RFAB__Tax_Percentage__c : '0';
                System.debug('inv.Tax_Percentage__c--->'+inv.Tax_Percentage__c);
                inv.RFAB__Discount_Type__c = so.RFAB__Discount_Mode__c;
                inv.RFAB__Discount_Mode__c=so.RFAB__Discount_Type__c;
            }
            else if(so.RFAB__Discount_Type__c == 'Line Item Discount' || so.RFAB__Discount_Type__c == null){
                inv.Discount_Percentage__c = soItems[0].RFAB__Discount_Percentage__c != null ? soItems[0].RFAB__Discount_Percentage__c : 0;
                inv.Discount_Amount__c = soItems[0].RFAB__Discount_Amount__c     != null ? soItems[0].RFAB__Discount_Amount__c     : 0;
                inv.Tax_Percentage__c = soItems[0].RFAB__Tax_Percentage__c != null ? soItems[0].RFAB__Tax_Percentage__c : '0';
                inv.RFAB__Discount_Type__c = so.RFAB__Discount_Mode__c;
                inv.RFAB__Discount_Mode__c=so.RFAB__Discount_Type__c;
            }
            if (inv.Sales_Order__c != null) {
                insert inv;
                invoice=inv.Id;
            }
            // Loop through soItems and create invoice items (RFAB__Invoice_Item__c)
            List<RFAB__Invoice_Item__c> invoiceItems = new List<RFAB__Invoice_Item__c>();
            Integer i = 0;
            for (RFAB__SO_Items__c item : soItems) {
                System.debug('inside item '+item);
                                String serialNumber = (serialNumbers != null && serialNumbers.size() > i) ? serialNumbers[i] : null;
                String descriptions = (description != null && description.size() > i) ? description[i] : null;
                System.debug('soItemMap.get(item.Id)--->'+soItemMap.get(item.Id));
                Decimal oldQuantity = soItemMap.get(item.Id).RFAB__Quantity__c ;
                // Decimal oldQuantity;
                // if (serialNumber != null && soItemMap.containsKey(item.Id)) {
                //     oldQuantity = soItemMap.get(item.Id).RFAB__Quantity__c;
                // }
                RFAB__Invoice_Item__c invItem = new RFAB__Invoice_Item__c();
                invItem.SO_Item__c = item.Id;
                invItem.RFAB__Invoice__c = inv.Id;
                invItem.RFAB__Product1__c = item.RFAB__Product__c;
                invItem.RFAB__IsKnownPdt__c= true;
                // if(so.Discount_Type__c == 'Line Item Discount' || so.Discount_Type__c == null){
                    if(so.RFAB__Discount_Type__c != 'Lumpsum Discount'){
                      invItem.Tax_Percentage__c = item.RFAB__Tax_Percentage__c != null ? item.RFAB__Tax_Percentage__c : '0';
                    }
                    invItem.RFAB__Discount_Percentage__c = item.RFAB__Discount_Percentage__c != null ? item.RFAB__Discount_Percentage__c : 0;
                    invItem.RFAB__Discount_Amount__c     = item.RFAB__Discount_Amount__c     != null ? item.RFAB__Discount_Amount__c     : 0;
                    invItem.Discount_Type__c       = item.RFAB__Discount_Type__c;
                    // Decimal taxPercentage = Decimal.valueOf(invItem.Tax_Percentage__c);
                if (item.RFAB__Product__r.RFAB__Is_Serial_Number__c) {
                    invItem.RFAB__Quantity__c = 1;
                }else{
                    invItem.RFAB__Quantity__c = item.RFAB__Quantity__c;
                }
                invItem.RFAB__Rate__c = item.RFAB__Unit_Price__c;
                    if(so.RFAB__Discount_Type__c == 'Line Item Discount' || so.RFAB__Discount_Type__c == null){
                        Decimal taxPercentage = Decimal.valueOf(invItem.Tax_Percentage__c);
                        if(invItem.Discount_Type__c == 'Percentage'){
                            invItem.RFAB__Amount__c = item.RFAB__Quantity__c * item.RFAB__Unit_Price__c - ((item.RFAB__Quantity__c * item.RFAB__Unit_Price__c) * item.RFAB__Discount_Percentage__c / 100) ;
                            // invItem.RFAB__Amount__c= invItem.RFAB__Amount__c + (invItem.RFAB__Amount__c * taxPercentage / 100);
                        }
                        else if(invItem.Discount_Type__c == 'Amount' && invItem.Discount_Type__c != null){
                            invItem.RFAB__Amount__c = item.RFAB__Quantity__c * item.RFAB__Unit_Price__c - ((item.RFAB__Discount_Amount__c /(oldQuantity != null ? oldQuantity : 1))* item.RFAB__Quantity__c ) ;
                            System.debug('RFAB__Amount__c -Amount'+invItem.RFAB__Amount__c);
                            // invItem.RFAB__Amount__c= invItem.RFAB__Amount__c + (invItem.RFAB__Amount__c * taxPercentage / 100);
                        }
                        else{
                        invItem.RFAB__Amount__c = invItem.RFAB__Quantity__c * invItem.RFAB__Rate__c ;
                        }
                        invItem.Total_Amount__c = invItem.RFAB__Amount__c + (invItem.RFAB__Amount__c * taxPercentage / 100);
                        invItem.RFAB__Description__c = descriptions;
                        invItem.Serial_Number__c = serialNumber;
                                Decimal totalTaxAmount = invItem.RFAB__Amount__c * taxPercentage / 100 + invItem.RFAB__Amount__c;
                        invItem.RFAB__Amount_With_GST__c = totalTaxAmount;
                        invItem.RFAB__GST_Amount__c = invItem.RFAB__Amount__c * taxPercentage / 100;
                    }
                    else{
                        if(so.RFAB__Discount_Mode__c == 'Percentage'){
                            invItem.RFAB__Amount__c = item.RFAB__Quantity__c * item.RFAB__Unit_Price__c - ((item.RFAB__Quantity__c * item.RFAB__Unit_Price__c) * so.RFAB__Lumpsum_Discount_Percentage__c / 100) ;
                            // invItem.RFAB__Amount__c= invItem.RFAB__Amount__c + (invItem.RFAB__Amount__c * taxPercentage / 100);
                        }
                        else if(so.RFAB__Discount_Mode__c == 'Amount'){
                            invItem.RFAB__Amount__c = item.RFAB__Quantity__c * item.RFAB__Unit_Price__c - ((so.RFAB__Lumpsum_Discount_Amount__c /oldQuantity)* item.RFAB__Quantity__c ) ;
                            System.debug('RFAB__Amount__c -Amount'+invItem.RFAB__Amount__c);
                            // invItem.RFAB__Amount__c= invItem.RFAB__Amount__c + (invItem.RFAB__Amount__c * taxPercentage / 100);
                        }
                        else{
                        invItem.RFAB__Amount__c = invItem.RFAB__Quantity__c * invItem.RFAB__Rate__c ;
                        }
                        Decimal taxPercentageLum = Decimal.valueOf(so.RFAB__Tax_Percentage__c);
                        // Decimal taxPercentageLum = String.isNotBlank(so.Tax_Percentage__c)
                        //     ? Decimal.valueOf(so.Tax_Percentage__c.trim())
                        //     : 0;
                       System.debug('taxPercentageLum--->'+taxPercentageLum);
                        invItem.Total_Amount__c = invItem.RFAB__Amount__c + (invItem.RFAB__Amount__c * taxPercentageLum / 100);
                        invItem.RFAB__Description__c = descriptions;
                        invItem.Serial_Number__c = serialNumber;
                        Decimal totalTaxAmount = invItem.RFAB__Amount__c * taxPercentageLum / 100 + invItem.RFAB__Amount__c;
                        invItem.RFAB__Amount_With_GST__c = totalTaxAmount;
                        invItem.RFAB__GST_Amount__c = invItem.RFAB__Amount__c * taxPercentageLum / 100;
 
                    }
                    // invItem.Total_Amount__c = invItem.RFAB__Amount__c + (invItem.RFAB__Amount__c * taxPercentage / 100);
                    // invItem.RFAB__Description__c = descriptions;
                    // invItem.Serial_Number__c = serialNumber;
                    // Decimal totalTaxAmount = invItem.RFAB__Amount__c * taxPercentage / 100 + invItem.RFAB__Amount__c;
                    // invItem.RFAB__Amount_With_GST__c = totalTaxAmount;
                    // invItem.RFAB__GST_Amount__c = invItem.RFAB__Amount__c * taxPercentage / 100;
                
                
                invoiceItems.add(invItem);
                i++;
            }
 
            // Insert invoice items
            if (!invoiceItems.isEmpty()) {
                insert invoiceItems;
            }
        }       
        return invoice;
    }
 
    @AuraEnabled(cacheable=true )
    public static RFAB__Sales_Order__c  getSalesOrder(Id soId) {
        return[SELECT Id, RFAB__Customer__r.Name,RFAB__Customer__r.BillingAddress,Total_Amount__c,
        RFAB__Customer__r.Payment_Terms__c,RFAB__Customer__r.Shipping_Terms__c,RFAB__Status__c,RFAB__Discount_Type__c
        FROM RFAB__Sales_Order__c WHERE Id = :soId WITH SECURITY_ENFORCED LIMIT 1];
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getSoItems(Id soId) {
        Map<String, Object> result = new Map<String, Object>();
        
        RFAB__Sales_Order__c salesOrder = [
            SELECT Id, Name,Invoiced_Quantity__c,Invoice_Status__c  FROM RFAB__Sales_Order__c WHERE Id = :soId
        ];
 
        if (salesOrder.Invoice_Status__c == 'Fully Created') {
            result.put('errorMessage', 'Invoice already created for this Sales Order.');
        }
        List<RFAB__SO_Items__c> soItems = [
            SELECT Id, RFAB__Product__c, RFAB__Product__r.Name,RFAB__Product__r.Name__c,RFAB__Quantity__c,RFAB__Unit_Price__c,RFAB__Total_Price__c,
            RFAB__Tax_Percentage__c,Balance_Quantity__c,Invoiced_Quantity__c,RFAB__Product__r.RFAB__Is_Serial_Number__c,RFAB__Total_Amount_with_Tax__c,
            RFAB__Tax_Amount__c,RFAB__Discount_Amount__c,RFAB__Discount_Percentage__c,RFAB__Discount_Type__c,RFAB__Product__r.RFAB__SKU__c,RFAB__Product__r.RFAB__Product_Quantity__c 
            FROM RFAB__SO_Items__c WHERE RFAB__Sales_Order__c = :soId  AND Balance_Quantity__c > 0 Order by CreatedDate ASC
        ];
        Set<Id> productIds = new Set<Id>();
        for (RFAB__SO_Items__c item : soItems) {
            if (item.RFAB__Product__c != null) {
                productIds.add(item.RFAB__Product__c);
            }
        }
        
        // Step 3: Get Stock Items for those Products
        List<RFAB__Stock__c> stockList = [
            SELECT Id,Name, Serial_Number__c,RFAB__Product__c
            FROM RFAB__Stock__c
            WHERE RFAB__Product__c IN :productIds AND Is_Delivered__c != true
        ];
        // Map<Id, List<String>> productToSerials = new Map<Id, List<String>>();
        // for (RFAB__Stock__c stock : stockList) {
        //     if (stock.Serial_Number__c != null) {
        //         if (!productToSerials.containsKey(stock.RFAB__Product__c)) {
        //             productToSerials.put(stock.RFAB__Product__c, new List<String>());
        //         }
        //         productToSerials.get(stock.RFAB__Product__c).add(stock.Serial_Number__c);
        //     }
        // }
        
 
        List<Map<String, Object>> items = new List<Map<String, Object>>();
 
        for (RFAB__SO_Items__c soItem : soItems) {
            if (soItem.RFAB__Product__r.RFAB__Is_Serial_Number__c) {
                for (Integer i = 0; i < soItem.Balance_Quantity__c; i++) {
                    Map<String, Object> soItemData = new Map<String, Object>();
                    soItemData.put('Id', soItem.Id);
                    soItemData.put('Name', soItem.RFAB__Product__r.Name__c);
                    soItemData.put('RFAB__Product__c', soItem.RFAB__Product__c);
                    soItemData.put('RFAB__Quantity__c', 1);
                    soItemData.put('RFAB__Unit_Price__c', soItem.RFAB__Unit_Price__c);
                    soItemData.put('RFAB__Tax_Percentage__c', soItem.RFAB__Tax_Percentage__c);
                    Decimal totalAmount= soItem.RFAB__Unit_Price__c + (soItem.RFAB__Tax_Amount__c / soItem.RFAB__Quantity__c);
                    // soItemData.put('RFAB__Total_Price__c', soItem.Total_Amount_with_Tax__c);
                    soItemData.put('RFAB__Total_Price__c', totalAmount);
                    soItemData.put('RFAB__Is_Serial_Number__c', soItem.RFAB__Product__r.RFAB__Is_Serial_Number__c);
                    soItemData.put('RFAB__Discount_Type__c', soItem.RFAB__Discount_Type__c);
                    soItemData.put('RFAB__Discount_Percentage__c', soItem.RFAB__Discount_Percentage__c);
                    soItemData.put('RFAB__Discount_Amount__c', soItem.RFAB__Discount_Amount__c);
                    soItemData.put('RFAB__Product__r', new Map<String, Object>{
                        'RFAB__SKU__c' => soItem.RFAB__Product__r.RFAB__SKU__c,
                        'RFAB__Product_Quantity__c' => soItem.RFAB__Product__r.RFAB__Product_Quantity__c
                    });
                   // soItemData.put('RFAB__Product__r.RFAB__Product_Quantity__c', soItem.RFAB__Product__r.RFAB__Product_Quantity__c);
                    items.add(soItemData);
                }
            } else {
                Map<String, Object> soItemData = new Map<String, Object>();
                soItemData.put('Id', soItem.Id);
                soItemData.put('Name', soItem.RFAB__Product__r.Name__c);
                soItemData.put('RFAB__Product__c', soItem.RFAB__Product__c);
                soItemData.put('RFAB__Quantity__c', soItem.Balance_Quantity__c);
                soItemData.put('RFAB__Unit_Price__c', soItem.RFAB__Unit_Price__c);
                soItemData.put('RFAB__Tax_Percentage__c', soItem.RFAB__Tax_Percentage__c);
                soItemData.put('RFAB__Total_Price__c', soItem.RFAB__Total_Amount_with_Tax__c);
                soItemData.put('RFAB__Discount_Type__c', soItem.RFAB__Discount_Type__c);
                soItemData.put('RFAB__Discount_Percentage__c', soItem.RFAB__Discount_Percentage__c);
                soItemData.put('RFAB__Discount_Amount__c', soItem.RFAB__Discount_Amount__c);
                soItemData.put('RFAB__Product__r', new Map<String, Object>{
                    'RFAB__SKU__c' => soItem.RFAB__Product__r.RFAB__SKU__c,
                    'RFAB__Product_Quantity__c' => soItem.RFAB__Product__r.RFAB__Product_Quantity__c
                });
                //soItemData.put('RFAB__Product__r.RFAB__Product_Quantity__c', soItem.RFAB__Product__r.RFAB__Product_Quantity__c);
                items.add(soItemData);
            }
        }
       // result.put('stockSerials', productToSerials);
        system.debug('result--->'+result);
        result.put('items', items);
        system.debug('result--->'+result);
        return result;
    }
    //,List<String> serialnumber
    @AuraEnabled
    public static void CreateJournalDliveryNotes(Id inId, Id soId,List<String> serialnumber) {
        RFAB__Invoice__c invlist = [SELECT Id, Name,Sales_Order__r.Name,RFAB__Account__c,RFAB__Account__r.Name,RFAB__Total_Amount__c,Is_Journal_Entry__c,Is_Delivery_note__c
        FROM RFAB__Invoice__c WHERE Id =:inId WITH SECURITY_ENFORCED];
        // Step 1: Get related Invoice Items with Serial Numbers
        List<RFAB__Invoice_Item__c> invItems = [
            SELECT Id, Serial_Number__c ,RFAB__Rate__c,RFAB__Quantity__c,RFAB__Amount__c,
            RFAB__Product1__c, RFAB__Product1__r.RFAB__Is_Serial_Number__c, RFAB__Product1__r.Name,
            RFAB__Invoice__r.RFAB__Account__c,RFAB__Description__c
            FROM RFAB__Invoice_Item__c
            WHERE RFAB__Invoice__c = :inId
        ];
        system.debug('inId-'+inId +'  soId-'+soId);
        System.debug('Serial Number--->'+serialnumber);
        System.debug('invItems--->'+invItems);
        RFAB__Delivery_Note__c dn = new RFAB__Delivery_Note__c();
        if(invlist.Is_Delivery_Note__c == true){
            dn.Name = 'DN for SO ' + invlist.Sales_Order__r.Name;
            dn.RFAB__Sales_Order__c = soId;
            dn.Invoice__c=inId;
            dn.RFAB__Status__c = 'Draft';
            dn.RFAB__Date__c = system.today();
            if(RFAB__Delivery_Note__c.SObjectType.getDescribe().isCreateable() &&
            Schema.sObjectType.RFAB__Delivery_Note__c.fields.Name.isCreateable() &&
            Schema.sObjectType.RFAB__Delivery_Note__c.fields.RFAB__Sales_Order__c.isCreateable() &&
            Schema.sObjectType.RFAB__Delivery_Note__c.fields.RFAB__Status__c.isCreateable() &&
            Schema.sObjectType.RFAB__Delivery_Note__c.fields.RFAB__Date__c.isCreateable() ){
                insert dn;
                List<RFAB__Delivery_Note_Item__c> dnList = new List<RFAB__Delivery_Note_Item__c>();
                for(RFAB__Invoice_Item__c deliveryItem : invItems){
                    RFAB__Delivery_Note_Item__c newItem = new RFAB__Delivery_Note_Item__c();
                    newItem.RFAB__Delivery_Note__c = dn.Id;
                    // newItem.Name = 'DN Item for SO ' + invlist.Sales_Order__r.Name;
                    newItem.RFAB__Product__c = deliveryItem.RFAB__Product1__c;   
                    newItem.RFAB__Quantity__c = deliveryItem.RFAB__Quantity__c;
                    newItem.RFAB__Description__c = deliveryItem.RFAB__Description__c;
                    dnList.add(newItem);
                    System.debug('dnList---'+dnList);
                }
                insert dnList;
            }
            System.debug('dnList------>'+dn.id);
            List<RFAB__Stock__c> stockRecords = new List<RFAB__Stock__c>();
            List<RFAB__Invoice_Item__c> invoice = new List<RFAB__Invoice_Item__c>();
            RFAB__Location__c loc=[SELECT Id,Name FROM RFAB__Location__c WITH SECURITY_ENFORCED LIMIT 1];
            Id consumptionRecordTypeId = Schema.SObjectType.RFAB__Stock__c.getRecordTypeInfosByDeveloperName().get('Consumption').getRecordTypeId();
            for (RFAB__Invoice_Item__c invItem : invItems) {
                RFAB__Stock__c stock = new RFAB__Stock__c();
                if (invItem.RFAB__Product1__r.RFAB__Is_Serial_Number__c) {
                    // If serial number tracking is enabled, create separate records for each unit
                    for (Integer i = 0; i < invItem.RFAB__Quantity__c; i++) {
                        Stock.Name = invItem.RFAB__Product1__r.Name;
                        Stock.RFAB__Location__c = loc.Id;
                        stock.RFAB__Delivery_Note__c =dn.Id;
                        stock.Invoice__c= inId;
                        stock.RFAB__Product__c = invItem.RFAB__Product1__c;
                        stock.Serial_Number__c = serialnumber[i];
                        stock.RFAB__Quantity__c = 1; // Each stock record has quantity = 1
                        // stock.RFAB__Purchase_Price__c = soItem.RFAB__Unit_Price__c; // Setting Sales Price
                        // stock.RFAB__Unit_Of_Measure__c = soItem.RFAB__Unit_of_Measure__c;
                        stock.RecordTypeId = consumptionRecordTypeId; // Setting record type as consumption
                        stock.RFAB__VendorName__c = invItem.RFAB__Invoice__r.RFAB__Account__c;
                        stockRecords.add(stock);
                    }
                } else {
                    // If serial number tracking is disabled, create one stock record for the entire quantity
                    Stock.Name = invItem.RFAB__Product1__r.Name;
                    Stock.RFAB__Location__c = loc.Id;
                    stock.RFAB__Delivery_Note__c = dn.Id;
                    stock.Invoice__c = inId;
                    stock.RFAB__Product__c = invItem.RFAB__Product1__c;
                    stock.RFAB__Quantity__c = invItem.RFAB__Quantity__c; // Each stock record has quantity = 1
                    // stock.RFAB__Purchase_Price__c = soItem.RFAB__Unit_Price__c; // Setting Sales Price
                    // stock.RFAB__Unit_Of_Measure__c = soItem.RFAB__Unit_of_Measure__c;
                    stock.RecordTypeId = consumptionRecordTypeId; // Setting record type as consumption
                    stock.RFAB__VendorName__c = invItem.RFAB__Invoice__r.RFAB__Account__c;
                    stockRecords.add(stock);
                }
            }
            System.debug('stockRecords--->'+stockRecords);
            if (!stockRecords.isEmpty()) {
                insert stockRecords;
            }
                
            if (invItems.isEmpty()) return;
            Id receiptRecordTypeId = Schema.SObjectType.RFAB__Stock__c.getRecordTypeInfosByDeveloperName().get('Receipt').getRecordTypeId();
 
            // Extract all serial numbers
            Set<String> serialNumbers = new Set<String>();
            for (RFAB__Invoice_Item__c item : invItems) {
                If(item.Serial_Number__c !=null){
                    serialNumbers.add(item.Serial_Number__c);
                }
            }
            system.debug('serialNumbers-->'+serialNumbers);
            // Step 2: Get matching Stock records based on Serial Number
            List<RFAB__Stock__c> matchingStock = [
                SELECT Id, RFAB__Product__c,Serial_Number__c, Is_Delivered__c, RFAB__Product__r.Is_Unique_Identifier__c
                FROM RFAB__Stock__c
                WHERE Serial_Number__c IN :serialNumbers and RFAB__Product__r.Is_Unique_Identifier__c =true and Is_Delivered__c =false and RecordTypeId =: receiptRecordTypeId
            ];
            system.debug('matchingStock-->'+matchingStock);
            // Step 3: Update Is_Delivered__c = true
            for (RFAB__Stock__c stock : matchingStock) {
                stock.Is_Delivered__c = true;
            }
 
            if (!matchingStock.isEmpty()) {
                update matchingStock;
            }       
        }
        if(invlist.Is_Journal_Entry__c == true){
            RFAB__Chart_of_Accounts__c customercoa= new RFAB__Chart_of_Accounts__c();
            RFAB__Chart_of_Accounts__c salesrevenue = [SELECT Id FROM RFAB__Chart_of_Accounts__c WHERE Name = 'Sales Revenue' WITH SECURITY_ENFORCED LIMIT 1];
           
            String accountName = invlist.RFAB__Account__r.Name;
            try{
                customercoa = [SELECT Id FROM RFAB__Chart_of_Accounts__c WHERE Name =: accountName WITH SECURITY_ENFORCED LIMIT 1];
            }
            catch(Exception e){
                customercoa = null;
                system.debug('Exception-->'+e.getMessage());
            }
            if(customercoa == null){
                List<RecordType> recordTypes = [SELECT Id FROM RecordType WHERE SObjectType = 'RFAB__Chart_of_Accounts__c' AND Name = 'Assets' WITH SECURITY_ENFORCED LIMIT 1];
                RFAB__Chart_of_Accounts__c sundry = [SELECT Id FROM RFAB__Chart_of_Accounts__c WHERE Name = 'Sundry Debtors' WITH SECURITY_ENFORCED LIMIT 1];
                RFAB__Chart_of_Accounts__c customerAccount = new RFAB__Chart_of_Accounts__c();
                customerAccount.Name = accountName;
                customerAccount.RecordTypeId  = recordTypes[0].Id;
                customerAccount.RFAB__Parent_Account__c = sundry.Id;
                if(RFAB__Chart_of_Accounts__c.SObjectType.getDescribe().isCreateable() &&
                Schema.sObjectType.RFAB__Chart_of_Accounts__c.fields.Name.isCreateable() &&
                Schema.sObjectType.RFAB__Chart_of_Accounts__c.fields.RecordTypeId.isCreateable() &&
                Schema.sObjectType.RFAB__Chart_of_Accounts__c.fields.RFAB__Parent_Account__c.isCreateable() ){
                insert customerAccount;
                }
                RFAB__Journal_Entry__c journalEntry = new RFAB__Journal_Entry__c();
                 journalEntry.Name = invlist.Name;
                 journalEntry.RFAB__Invoice__c = invlist.Id;
                 journalEntry.RFAB__Status__c = 'Draft';
                 journalEntry.RFAB__Type__c = 'Journal';
                 journalEntry.RFAB__Final_Amount__c = invlist.RFAB__Total_Amount__c;
                 journalEntry.RFAB__Entry_Date__c = Date.today();
                 journalEntry.RFAB__Debit_Chart_of_Accounts__c = customerAccount.Id;
                 journalEntry.RFAB__Credit_Chart_of_Accounts__c = salesrevenue.Id;  
                 journalEntry.RFAB__Debit_Amount__c = invlist.RFAB__Total_Amount__c;
                 journalEntry.RFAB__Credit_Amount__c = invlist.RFAB__Total_Amount__c;
                 if(RFAB__Journal_Entry__c.SObjectType.getDescribe().isCreateable() &&
                 Schema.sObjectType.RFAB__Journal_Entry__c.fields.Name.isCreateable() &&
                 Schema.sObjectType.RFAB__Journal_Entry__c.fields.RFAB__Status__c.isCreateable() &&
                 Schema.sObjectType.RFAB__Journal_Entry__c.fields.RFAB__Type__c.isCreateable() &&
                 Schema.sObjectType.RFAB__Journal_Entry__c.fields.RFAB__Entry_Date__c.isCreateable() &&
                 Schema.sObjectType.RFAB__Journal_Entry__c.fields.RFAB__Debit_Chart_of_Accounts__c.isCreateable() &&
                 Schema.sObjectType.RFAB__Journal_Entry__c.fields.RFAB__Credit_Chart_of_Accounts__c.isCreateable() &&
                 Schema.sObjectType.RFAB__Journal_Entry__c.fields.RFAB__Debit_Amount__c.isCreateable() &&
                 Schema.sObjectType.RFAB__Journal_Entry__c.fields.RFAB__Credit_Amount__c.isCreateable()
                 ){
                    insert journalEntry;
                 }
   
            }
            else{
                RFAB__Journal_Entry__c journalEntry = new RFAB__Journal_Entry__c();
                journalEntry.Name = invlist.Name;
                journalEntry.RFAB__Invoice__c = invlist.Id;
                journalEntry.RFAB__Status__c = 'Draft';
                journalEntry.RFAB__Type__c = 'Journal';
                journalEntry.RFAB__Final_Amount__c = invlist.RFAB__Total_Amount__c;
                journalEntry.RFAB__Entry_Date__c = Date.today();
                journalEntry.RFAB__Debit_Chart_of_Accounts__c = customercoa.Id;
                journalEntry.RFAB__Credit_Chart_of_Accounts__c = salesrevenue.Id;   
                journalEntry.RFAB__Debit_Amount__c = invlist.RFAB__Total_Amount__c;
                journalEntry.RFAB__Credit_Amount__c = invlist.RFAB__Total_Amount__c;
                if(RFAB__Journal_Entry__c.SObjectType.getDescribe().isCreateable() &&
                     Schema.sObjectType.RFAB__Journal_Entry__c.fields.Name.isCreateable() &&
                     Schema.sObjectType.RFAB__Journal_Entry__c.fields.RFAB__Status__c.isCreateable() &&
                     Schema.sObjectType.RFAB__Journal_Entry__c.fields.RFAB__Type__c.isCreateable() &&
                     Schema.sObjectType.RFAB__Journal_Entry__c.fields.RFAB__Entry_Date__c.isCreateable() &&
                     Schema.sObjectType.RFAB__Journal_Entry__c.fields.RFAB__Debit_Chart_of_Accounts__c.isCreateable() &&
                     Schema.sObjectType.RFAB__Journal_Entry__c.fields.RFAB__Credit_Chart_of_Accounts__c.isCreateable() &&
                     Schema.sObjectType.RFAB__Journal_Entry__c.fields.RFAB__Debit_Amount__c.isCreateable() &&
                     Schema.sObjectType.RFAB__Journal_Entry__c.fields.RFAB__Credit_Amount__c.isCreateable()
                     ){
                        insert journalEntry;
                     }
            }
            RFAB__Chart_of_Accounts__c costofgoods = [SELECT Id FROM RFAB__Chart_of_Accounts__c WHERE Name = 'Cost of Goods Sold' WITH SECURITY_ENFORCED LIMIT 1];
            RFAB__Chart_of_Accounts__c inventory = [SELECT Id FROM RFAB__Chart_of_Accounts__c WHERE Name = 'Inventory Account' WITH SECURITY_ENFORCED LIMIT 1];  
            RFAB__Journal_Entry__c journalEntry1 = new RFAB__Journal_Entry__c();
             journalEntry1.Name = invlist.Name;
             journalEntry1.RFAB__Invoice__c = invlist.Id;
             journalEntry1.RFAB__Status__c = 'Draft';
             journalEntry1.RFAB__Type__c = 'Journal';
             journalEntry1.RFAB__Final_Amount__c = invlist.RFAB__Total_Amount__c;
             journalEntry1.RFAB__Entry_Date__c = Date.today();
             journalEntry1.RFAB__Debit_Chart_of_Accounts__c = costofgoods.Id;
             journalEntry1.RFAB__Credit_Chart_of_Accounts__c = inventory.Id;  
             journalEntry1.RFAB__Debit_Amount__c = invlist.RFAB__Total_Amount__c;
             journalEntry1.RFAB__Credit_Amount__c = invlist.RFAB__Total_Amount__c;
             if(RFAB__Journal_Entry__c.SObjectType.getDescribe().isCreateable() &&
             Schema.sObjectType.RFAB__Journal_Entry__c.fields.Name.isCreateable() &&
             Schema.sObjectType.RFAB__Journal_Entry__c.fields.RFAB__Status__c.isCreateable() &&
             Schema.sObjectType.RFAB__Journal_Entry__c.fields.RFAB__Type__c.isCreateable() &&
             Schema.sObjectType.RFAB__Journal_Entry__c.fields.RFAB__Entry_Date__c.isCreateable() &&
             Schema.sObjectType.RFAB__Journal_Entry__c.fields.RFAB__Debit_Chart_of_Accounts__c.isCreateable() &&
             Schema.sObjectType.RFAB__Journal_Entry__c.fields.RFAB__Credit_Chart_of_Accounts__c.isCreateable() &&
             Schema.sObjectType.RFAB__Journal_Entry__c.fields.RFAB__Debit_Amount__c.isCreateable() &&
             Schema.sObjectType.RFAB__Journal_Entry__c.fields.RFAB__Credit_Amount__c.isCreateable()
             ){
                insert journalEntry1;
             }
        }
       
    }
   public static void updateinvoiceitem(List<RFAB__Invoice_Item__c> invoiceitem){
    RFAB__Tax__c tax =[Select Id,RFAB__Tax_Percentage__c from RFAB__Tax__c WITH SECURITY_ENFORCED limit 1];
    for (RFAB__Invoice_Item__c item : invoiceitem) {
        
        if (item.RFAB__Quantity__c != null && item.RFAB__Rate__c != null) {
            item.RFAB__Amount__c = item.RFAB__Quantity__c * item.RFAB__Rate__c;
            item.RFAB__Amount_With_GST__c = item.RFAB__Amount__c* tax.RFAB__Tax_Percentage__c/100 + item.RFAB__Amount__c;
        }
    }
   }
   @AuraEnabled
   public static void createExpense(List<RFAB__GRN__c> grnlist){
    if (grnlist[0].RFAB__Status__c != 'Completed') {
        Id companyExpenseRecordTypeId = Schema.SObjectType.RFAB__Expense__c.getRecordTypeInfosByDeveloperName().get('Company_Expense').getRecordTypeId();
        Schema.DescribeFieldResult fieldResult = RFAB__Expense__c.Expense_Type__c.getDescribe();
        List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();
        List<RFAB__Expense__c> expenseList = new List<RFAB__Expense__c>();
        // from the picklist values, create expense records for each picklist value
        for(Schema.PicklistEntry picklistValue : picklistValues)
        {
            RFAB__Expense__c expense = new RFAB__Expense__c();
            expense.Name = picklistValue.getLabel();
            expense.Expense_Type__c = picklistValue.getValue();
            expense.RecordTypeId=companyExpenseRecordTypeId;
            expense.RFAB__GRN__c= grnlist[0].Id;
            expenseList.add(expense);
        }
        insert expenseList;
    }
  }
  public static void checkTotalAmount(List<RFAB__GRN__c> grnlist){
    List<Id> grnIds = new List<Id>();
    for (RFAB__GRN__c grn : grnlist) {
        if (grn.RFAB__Status__c == 'Completed') {
            grnIds.add(grn.Id);
        }
    }
 
    if (!grnIds.isEmpty()) {
        // Query Expenses related to those GRNs
        List<RFAB__Expense__c> expenses = [SELECT Id, RFAB__Total_Amount__c
                                     FROM RFAB__Expense__c
                                     WHERE RFAB__GRN__c IN :grnIds WITH SECURITY_ENFORCED];
 
        for (RFAB__Expense__c exp : expenses) {
            if (exp.RFAB__Total_Amount__c == null || exp.RFAB__Total_Amount__c == 0) {
                throw new AuraHandledException('Total Amount is required for all Expense');
            }
        }
    }
  }
}