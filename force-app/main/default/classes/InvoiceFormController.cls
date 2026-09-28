// <!-- AR 17/05/2025 DIscount Logic , Tax amount , Place of supply from metadata,Terms from invoice picklist, default first currency picklist  -->
// <!-- KK 17/05/2025 Invoice Item product lookup , Stock Serial Number tag in line item-->
public with sharing class InvoiceFormController {
    public InvoiceFormController() {
        //system.debug('InvoiceFormController const');
    }
    @AuraEnabled
    public static String saveInvoiceRecord(String invWrap, Boolean sendEmailFlag, Boolean checkboxjournalflag,List<Map<String, Object>> productSerialMapList){
        //system.debug('Inside the saveInvoiceRecord method');
        JSONGenerator jsonGen = JSON.createGenerator(true);
        jsonGen.writeStartObject();
        Boolean successFlag = true;
        String returnStr = null;
        Boolean updateFlag = false;
        try{
            InvoiceFormWrapper invWrapObj = invWrap != null ? (InvoiceFormWrapper) JSON.deserialize(invWrap, InvoiceFormWrapper.class) : null;
            List<Product__c> pdtList = getProductList();
            Map<Id, Product__c> pdtMap = new Map<Id, Product__c>();
            if(pdtList.size() > 0){
                pdtMap.putAll(pdtList);
            }
            if(invWrapObj != null){
                Invoice__c inv = new Invoice__c();
                if(invWrapObj.invId != null && invWrapObj.invId != ''){
                    updateFlag = true;
                }
                inv = InvoiceFormHelper.convertWrapperToInv(invWrapObj);
                if (checkboxjournalflag) {
                    inv.Create_Journal_Entry__c = true;
                }
                else {
                    inv.Create_Journal_Entry__c = false;
                }
                try{
                    List<Invoice__c> invList = new List<Invoice__c>();
                    invList.add(inv);
                    if(updateFlag){
                        Set<Id> existingInvItemIds1 = new Set<Id>();
                        existingInvItemIds1 = (new Map<Id, Invoice_Item__c> ([SELECT Id,Name,Invoice__c,Service_Date__c ,Product1__c,
                                            HsnSac__c,Description__c,Quantity__c,Rate__c,Amount__c,Tax__c,Amount_With_GST__c,
                                            GST_Amount__c,Key__c,Product1__r.Name,IsKnownPdt__c,Tax__r.name,Tax__r.Tax_Percentage__c,
                                            Discount_Amount__c,Discount_Percentage__c,Amount_Before_Discount__c,Tax_Amount__c, Discount_Reason__c
                                            FROM Invoice_Item__c WHERE Invoice__c =:inv.Id WITH SECURITY_ENFORCED])).keySet();
                        InvoiceFormHelper.ConvertWrapperToInvItemResultant cwt1 = InvoiceFormHelper.convertWrapperToInvItem(invWrapObj,inv.Id);
                        //Set<Id> newInvItemIds = new Set<Id>();
                        //List<Invoice_Item__c> invList = new List<Invoice_Item__c>();
                        //system.debug('Inside the sendEmailFlag section1');
                        Set<Id> resultIds1 = new Set<Id>();
                        if(updateFlag && existingInvItemIds1.size() > cwt1.newInvItemIds.size()){
                            resultIds1 = existingInvItemIds1.clone();
                            resultIds1.removeall(cwt1.newInvItemIds);
                        }else if(updateFlag){
                            resultIds1 = cwt1.newInvItemIds.clone();
                            resultIds1.removeall(existingInvItemIds1);
                        }
                        List<Invoice_Item__c> invItemDeleteList1 = new List<Invoice_Item__c>();
                        if(resultIds1.size() > 0){
                            invItemDeleteList1 = [SELECT Id FROM Invoice_Item__c WHERE Id IN:resultIds1 WITH SECURITY_ENFORCED];
                        }
                        if (invItemDeleteList1.size() > 0 &&
                            Invoice_Item__c.SObjectType.getDescribe().isDeletable()
                        ) {
                            delete invItemDeleteList1;
                        }
                        try{
                            //system.debug('Inside the sendEmailFlag section2');
                            if (
                                cwt1.invList.size() > 0 &&
                                Invoice_Item__c.SObjectType.getDescribe().isCreateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.Invoice__c.isCreateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.Key__c.isCreateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.Service_Date__c.isCreateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.IsKnownPdt__c.isCreateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.Product1__c.isCreateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.HsnSac__c.isCreateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.Description__c.isCreateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.Quantity__c.isCreateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.Rate__c.isCreateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.Amount__c.isCreateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.Tax__c.isCreateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.Amount_With_GST__c.isCreateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.GST_Amount__c.isCreateable() &&
                                Invoice_Item__c.SObjectType.getDescribe().isUpdateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.Key__c.isUpdateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.Service_Date__c.isUpdateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.IsKnownPdt__c.isUpdateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.Product1__c.isUpdateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.HsnSac__c.isUpdateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.Description__c.isUpdateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.Quantity__c.isUpdateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.Rate__c.isUpdateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.Amount__c.isUpdateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.Tax__c.isUpdateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.Amount_With_GST__c.isUpdateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.GST_Amount__c.isUpdateable()
                            ) {
                                upsert cwt1.invList;
                            }
// Step 1: Upsert Invoice Items
if (
    cwt1.invList.size() > 0 &&
    Invoice_Item__c.SObjectType.getDescribe().isCreateable() &&
    Invoice_Item__c.SObjectType.getDescribe().isUpdateable()
) {
    upsert cwt1.invList;
}

// Step 2: Handle stock linking if productSerialMapList is present
if (productSerialMapList != null && !productSerialMapList.isEmpty()) {
    // Step 2.1: Build key → Invoice_Item__c.Id map (Key is per UI row)
    Map<String, Id> keyToInvoiceItemMap = new Map<String, Id>();
                                for (Invoice_Item__c item : cwt1.invList) {
        if (item.Key__c != null) {
            keyToInvoiceItemMap.put(String.valueOf(item.Key__c), item.Id);
                                    }
                                }

    // Step 2.2: Build key → stockIds map from JS input
    Map<String, Set<Id>> keyToStockIdsMap = new Map<String, Set<Id>>();
                                for (Map<String, Object> entry : productSerialMapList) {
        String key = String.valueOf(entry.get('key'));
                                    List<Object> stockIdObjs = (List<Object>) entry.get('stockIds');

        if (String.isNotBlank(key)) {
                                        Set<Id> stockIdSet = new Set<Id>();
                                        for (Object o : stockIdObjs) {
                                            if (o != null && String.valueOf(o) != '') {
                                                stockIdSet.add((Id) o);
                                            }
                                        }
            keyToStockIdsMap.put(key, stockIdSet);
                                    }
                                }

                                // Step 3: Fetch all stocks currently linked to Invoice Items
                                List<Stock__c> allTaggedStocks = [
                                    SELECT Id, Invoice_Item__c
                                    FROM Stock__c
                                    WHERE Invoice_Item__c IN :keyToInvoiceItemMap.values()
                                ];

                                List<Stock__c> stockUpdates = new List<Stock__c>();

                                for (Stock__c stock : allTaggedStocks) {
                                    Id invoiceItemId = stock.Invoice_Item__c;

        // Find corresponding key for this invoiceItemId
        String matchingKey = null;
        for (String k : keyToInvoiceItemMap.keySet()) {
            if (keyToInvoiceItemMap.get(k) == invoiceItemId) {
                matchingKey = k;
                break;
            }
        }

        if (matchingKey != null) {
            Set<Id> allowedStockIds = keyToStockIdsMap.get(matchingKey);
                                    if (allowedStockIds == null || !allowedStockIds.contains(stock.Id)) {
                stock.Invoice_Item__c = null; // unlink stock
                                        stockUpdates.add(stock);
                                    }
                                }
    }

    // Step 2.5: Link new stocks to correct invoice item by key
    for (String key : keyToStockIdsMap.keySet()) {
        if (!keyToInvoiceItemMap.containsKey(key)) continue;

        Id invoiceItemId = keyToInvoiceItemMap.get(key);
        Set<Id> selectedStockIds = keyToStockIdsMap.get(key);

                                for (Id stockId : selectedStockIds) {
                                    Boolean alreadyTagged = false;
            for (Stock__c existing : allTaggedStocks) {
                if (existing.Id == stockId && existing.Invoice_Item__c == invoiceItemId) {
                                            alreadyTagged = true;
                                            break;
                                        }
                                    }

                                    if (!alreadyTagged) {
                                        stockUpdates.add(new Stock__c(
                                            Id = stockId,
                                            Invoice_Item__c = invoiceItemId
                                        ));
                                    }
                                }
                            }


                                if (!stockUpdates.isEmpty()) {
                                    update stockUpdates;
                                }
                            }

                            //createAttachmentRecord(inv.Id,inv.Name);
                        } catch(exception e){
                            //system.debug('Inside the insertion of invoiceItem records exception section '+e.getMessage());
                            returnStr = e.getMessage();
                            successFlag = false;
                            jsonGen.writeStringField('errorMessage',returnStr);
                        }
                    }
                    Invoice__c checkedInv = InvoiceFormHelper.invUpsertPermissionCheck(invList);
                    if (checkedInv != null) {
                        inv = checkedInv;
                        if(inv != null){
                            jsonGen.writeStringField('invoiceId',inv.Id);
                    } else {
                       // Handle the case where no Invoice__c record was found/returned.
                        returnStr = 'No Invoice record found.';
                        successFlag = false;
                        jsonGen.writeStringField('errorMessage', returnStr);
                        //system.debug('No Invoice record found by invUpsertPermissionCheck');
                    }
                        Set<Id> existingInvItemIds = new Set<Id>();
                        existingInvItemIds = (new Map<Id, Invoice_Item__c> ([SELECT Id,Name,Invoice__c,Service_Date__c ,Product1__c,
                                            HsnSac__c,Description__c,Quantity__c,Rate__c,Amount__c,Tax__c,Amount_With_GST__c,
                                            GST_Amount__c,Key__c,Product1__r.Name,IsKnownPdt__c,Tax__r.name,Tax__r.Tax_Percentage__c,Amount_Before_Discount__c,Tax_Amount__c,
                                            Discount_Reason__c FROM Invoice_Item__c WHERE Invoice__c =:inv.Id WITH SECURITY_ENFORCED])).keySet();
                        InvoiceFormHelper.ConvertWrapperToInvItemResultant cwt = InvoiceFormHelper.convertWrapperToInvItem(invWrapObj,inv.Id);
                        //Set<Id> newInvItemIds = new Set<Id>();
                        //List<Invoice_Item__c> invList = new List<Invoice_Item__c>();
                        //system.debug('Inside the sendEmailFlag section1');
                        Set<Id> resultIds = new Set<Id>();
                        if(updateFlag && existingInvItemIds.size() > cwt.newInvItemIds.size()){
                            resultIds = existingInvItemIds.clone();
                            resultIds.removeall(cwt.newInvItemIds);
                        }else if(updateFlag){
                            resultIds = cwt.newInvItemIds.clone();
                            resultIds.removeall(existingInvItemIds);
                        }
                        List<Invoice_Item__c> invItemDeleteList = new List<Invoice_Item__c>();
                        if(resultIds.size() > 0){
                            invItemDeleteList = [SELECT Id FROM Invoice_Item__c WHERE Id IN:resultIds WITH SECURITY_ENFORCED];
                        }
                        if (invItemDeleteList.size() > 0 &&
                            Invoice_Item__c.SObjectType.getDescribe().isDeletable()
                        ) {
                            delete invItemDeleteList;
                        }
                        try{
                            //system.debug('Inside the sendEmailFlag section2');
                            if (
                                cwt.invList.size() > 0 &&
                                Invoice_Item__c.SObjectType.getDescribe().isCreateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.Invoice__c.isCreateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.Key__c.isCreateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.Service_Date__c.isCreateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.IsKnownPdt__c.isCreateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.Product1__c.isCreateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.HsnSac__c.isCreateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.Description__c.isCreateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.Quantity__c.isCreateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.Rate__c.isCreateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.Amount__c.isCreateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.Tax__c.isCreateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.Amount_With_GST__c.isCreateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.GST_Amount__c.isCreateable() &&
                                Invoice_Item__c.SObjectType.getDescribe().isUpdateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.Key__c.isUpdateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.Service_Date__c.isUpdateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.IsKnownPdt__c.isUpdateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.Product1__c.isUpdateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.HsnSac__c.isUpdateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.Description__c.isUpdateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.Quantity__c.isUpdateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.Rate__c.isUpdateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.Amount__c.isUpdateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.Tax__c.isUpdateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.Amount_With_GST__c.isUpdateable() &&
                                Schema.sObjectType.Invoice_Item__c.fields.GST_Amount__c.isUpdateable()
                            ) {
                                upsert cwt.invList;
                            }
                            if (!productSerialMapList.isEmpty()) {
    // Step 1: Map Key__c to Invoice_Item__c.Id
    Map<String, Id> keyToInvItemMap = new Map<String, Id>();
                            for (Invoice_Item__c item : cwt.invList) {
        if (item.Key__c != null) {
            keyToInvItemMap.put(String.valueOf(item.Key__c), item.Id);
                                }
                            }

    // Step 2: Process productSerialMapList
                            List<Stock__c> stockUpdates = new List<Stock__c>();

                            for (Map<String, Object> entry : productSerialMapList) {
        Object keyObj = entry.get('key');
                                List<Object> stockIdObjs = (List<Object>) entry.get('stockIds');
                                
        String keyStr = String.valueOf(keyObj);
        if (keyToInvItemMap.containsKey(keyStr)) {
            Id relatedInvoiceItemId = keyToInvItemMap.get(keyStr);

                                    for (Object stockIdObj : stockIdObjs) {
                                        String stockIdStr = (String) stockIdObj;
                                        if (String.isNotBlank(stockIdStr)) {
                                            Stock__c stk = new Stock__c(
                                                Id = stockIdStr,
                                                Invoice_Item__c = relatedInvoiceItemId
                                            );
                                            stockUpdates.add(stk);
                                        }
                                    }
                                }
                            }

                            // Step 4: Update stock records
                            if (!stockUpdates.isEmpty()) {
                                update stockUpdates;
                            }

                            }
                           
                        } catch(exception e){
                            //system.debug('Inside the insertion of invoiceItem records exception section '+e.getMessage());
                            returnStr = e.getMessage();
                            successFlag = false;
                            jsonGen.writeStringField('errorMessage',returnStr);
                        }
                        jsonGen.writeStringField('invoiceItemListSize',''+cwt.invList.size());
                        //system.debug('Inside the sendEmailFlag section3');
                        if(sendEmailFlag && successFlag){
                            InvoiceFormHelper02.sendInvoiceEmail(inv.Id);
                            //system.debug('Inside the sendEmailFlag section');
                            //system.debug('invoice-->'+inv.Id);
                            List<Journal_Entry__c> journalEntryList = [
                            SELECT Id, Invoice__c
                            FROM Journal_Entry__c
                            WHERE Invoice__c = :inv.Id
                            LIMIT 1
                            ];

                            if(checkboxjournalflag!= false && inv.Id != null && journalEntryList.isEmpty()){
                                //system.debug('Inside the checkboxjournalflag section');
                                createJournalEntryRecord(inv.Id, false);
                            }
                        }
                    }
                } catch(exception e){
                    //system.debug('Inside the insertion of invoice record exception section '+e.getMessage());
                    returnStr = e.getMessage();
                    successFlag = false;
                    jsonGen.writeStringField('errorMessage',returnStr);
                }
            }
        }catch(exception e){
            //system.debug('Inside the exception section '+e.getMessage());
            returnStr = e.getMessage();
            successFlag = false;
            jsonGen.writeStringField('errorMessage',returnStr);
        }
        jsonGen.writeBooleanField('successFlag',successFlag);
        jsonGen.writeEndObject();
        return jsonGen.getAsString();
    }

    @AuraEnabled
    public static String validateInvoiceRecord(String invoiceId) {
        System.debug('invoiceId-->' + invoiceId);
        // Invoice
        Invoice__c inv = [SELECT Id, Name, Invoice_Date__c, Due_Date__c, Amounts_are__c, Currency_Code__c, Invoice_Indicator__c,
                                Account__c, Account__r.Name, Account__r.Id, Invoice_Type__c, Invoice_Name_Type__c,
                                Currency__c, Lumpsum_Discount_Amount__c, Lumpsum_Discount_Percentage__c, Payment_Type__c, Discount_Reason__c,
                                Discount_Type__c, Latest_Delivery_Date__c, CreatedDate FROM Invoice__c WHERE Id = :invoiceId WITH SECURITY_ENFORCED LIMIT 1];
        System.debug('inv-->' + inv);

        // Invoice Items
        List<Invoice_Item__c> invItemList = [SELECT Id, Name, Product1__r.Name, Quantity__c, Rate__c, 
                                                    Amount_With_GST__c, GST_Amount__c, Tax__r.Tax_Label__c, 
                                                    Tax__r.Tax_Percentage__c, Discount_Amount__c, Discount_Percentage__c, Discount_Reason__c
                                            FROM Invoice_Item__c 
                                            WHERE Invoice__c = :invoiceId WITH SECURITY_ENFORCED];
        System.debug('invItemList-->' + invItemList);

        // Seller Details
        List<Company_Settings__mdt> companySettingList = new List<Company_Settings__mdt>();
        if (Schema.sObjectType.Company_Settings__mdt.isAccessible()) {
            companySettingList = [SELECT Name__c, GSTIN__c, Address1__c, Address2__c, Pincode__c, City__c, State__c FROM Company_Settings__mdt LIMIT 1];
        }
        Company_Settings__mdt company = companySettingList.isEmpty() ? null : companySettingList[0];
        System.debug('company-->' + company);

        // Customer Details
        Account acc = [SELECT Id, Name, Preferred_Currency_Code__c, GSTIN__c, BillingStreet, BillingCity, BillingState, BillingPostalCode FROM Account WHERE Id = :inv.Account__c WITH SECURITY_ENFORCED LIMIT 1];
        System.debug('acc-->' + acc);

        JSONGenerator jsonGen = JSON.createGenerator(true);
        jsonGen.writeStartObject(); //JSON

        // Seller Information
        jsonGen.writeFieldName('SellerInformation');
        jsonGen.writeStartObject();
        jsonGen.writeStringField('SchemeID', 'Commercial Registration Number'); // Commercial Registration Number
        jsonGen.writeStringField('RegistrationNumber', company.GSTIN__c);
        jsonGen.writeStringField('TaxRegistrationName', company.Name__c);
        jsonGen.writeStringField('EmailId', company.Name__c);
        jsonGen.writeStringField('TaxRegistrationNumber', company.GSTIN__c); // GSTIN
        jsonGen.writeStringField('Country', 'SA'); // SA
        jsonGen.writeStringField('SubDivision', company.State__c); // city/state
        jsonGen.writeStringField('City', company.City__c);
        
        jsonGen.writeFieldName('Address');
        jsonGen.writeStartObject();
        jsonGen.writeStringField('BuildingNumber', company.Address1__c);
        jsonGen.writeStringField('StreetName', company.Address2__c);
        jsonGen.writeStringField('PostalCode', String.valueOf((Integer)company.Pincode__c));
        jsonGen.writeEndObject();

        jsonGen.writeEndObject(); // Seller

        // Customer
        jsonGen.writeFieldName('CustomerInformation');
        jsonGen.writeStartObject();
        jsonGen.writeStringField('TaxRegistrationName', acc.Name);
        jsonGen.writeStringField('TaxRegistrationNumber', acc.GSTIN__c);
        jsonGen.writeStringField('Country', acc.Preferred_Currency_Code__c?.split(' ')[0]);
        // jsonGen.writeStringField('Country', 'USD');
        jsonGen.writeStringField('SubDivision', acc.BillingState); // State
        jsonGen.writeStringField('City', acc.BillingCity); // Riyadh Region
        
        jsonGen.writeFieldName('Address');
        jsonGen.writeStartObject();
        jsonGen.writeStringField('BuildingNumber', '');
        jsonGen.writeStringField('StreetName', acc.BillingStreet);
        jsonGen.writeStringField('PostalCode', acc.BillingPostalCode);
        jsonGen.writeEndObject(); // address

        jsonGen.writeEndObject(); // Customer

        // Invoice Details
        jsonGen.writeFieldName('InvoiceDetails');
        jsonGen.writeStartObject();
        jsonGen.writeStringField('InvoiceId', inv.Name);
        jsonGen.writeStringField('IssueDate', String.valueOf(inv.Invoice_Date__c));
        jsonGen.writeStringField('IssueTime', String.valueOf(inv.CreatedDate.format('HH:mm:ss')));
        jsonGen.writeStringField('DeliveryDate', String.valueOf(inv.Due_Date__c));
        jsonGen.writeStringField('InvoiceType', inv.Invoice_Type__c);
        jsonGen.writeStringField('InvoiceName', inv.Invoice_Name_Type__c); // Standard Tax
        // jsonGen.writeStringField('InvoiceName', 'Standard(b2B) Tax'); // Standard Tax
        jsonGen.writeBooleanField('ThirdParty', (inv.Invoice_Indicator__c == 'Third Party') ? true : false); // Standard Tax
        jsonGen.writeBooleanField('Nominal', (inv.Invoice_Indicator__c == 'Nominal') ? true : false); // Standard Tax
        jsonGen.writeBooleanField('Export', (inv.Invoice_Indicator__c == 'export') ? true : false); // Standard Tax
        jsonGen.writeBooleanField('Summary', (inv.Invoice_Indicator__c == 'summary') ? true : false); // Standard Tax
        jsonGen.writeBooleanField('SelfBilled', (inv.Invoice_Indicator__c == 'self-billed') ? true : false); // Standard Tax
        if((inv.Invoice_Type__c == 'Simplified') && (inv.Invoice_Indicator__c == 'summary')) {
            jsonGen.writeStringField('LatestDeliveryDate', inv.Latest_Delivery_Date__c != null ? String.valueOf(inv.Latest_Delivery_Date__c) : '');
        }
        // jsonGen.writeStringField('Currency', inv.Currency__c);
        jsonGen.writeStringField('Currency', inv.Currency_Code__c?.split(' ')[0]); // SAR
        jsonGen.writeStringField('TaxCurrency', 'SAR'); 
        jsonGen.writeStringField('PaymentMethod', inv.Payment_Type__c); // Cash
        if (inv.Discount_Reason__c != null && inv.Discount_Reason__c != '') {
            jsonGen.writeStringField('InvoiceDiscountType', inv.Discount_Reason__c); // Amount or Percentage
            // jsonGen.writeStringField('InvoiceDiscountType', 'Discount'); // Amount or Percentage
            if (inv.Discount_Type__c == 'Amount') {
                jsonGen.writeNumberField('InvoiceDiscountAmount', Integer.valueOf(inv.Lumpsum_Discount_Amount__c));
            } else if (inv.Discount_Type__c == 'Percentage') {
                jsonGen.writeNumberField('InvoiceDiscountPercent', Integer.valueOf(inv.Lumpsum_Discount_Percentage__c));
            }
        }
        // // jsonGen.writeStringField('InvoiceDiscountPercent', '');
        // jsonGen.writeStringField('InvoiceAdditionalFeeType', 'Cleaning');
        // jsonGen.writeStringField('InvoiceAdditionalFeeAmount', '1');
    
        // Invoice Items
        jsonGen.writeFieldName('Items');
        jsonGen.writeStartArray();
        for (Invoice_Item__c invItem : invItemList) {
            jsonGen.writeStartObject();
            jsonGen.writeStringField('ProductName', invItem.Product1__r.Name);
            jsonGen.writeNumberField('Price', Integer.valueOf(invItem.Rate__c));
            jsonGen.writeNumberField('Quantity', invItem.Quantity__c);
            // jsonGen.writeNumberField('BaseQuantity', '');
            if (inv.Discount_Reason__c != null && inv.Discount_Reason__c != '') {
                jsonGen.writeStringField('ItemDiscountType', invItem.Discount_Reason__c); // Discount Reason
                if (inv.Discount_Type__c == 'Amount') {
                    jsonGen.writeNumberField('ItemDiscountAmount', Integer.valueOf(invItem.Discount_Amount__c));
                } else if (inv.Discount_Type__c == 'Percentage') {
                    jsonGen.writeNumberField('ItemDiscountPercent', Integer.valueOf(invItem.Discount_Percentage__c));
                }
            }
            // jsonGen.writeStringField('ItemAdditionalFeeType', 'Cleaning');
            // jsonGen.writeStringField('ItemAdditionalFeeAmount', '1');
            // jsonGen.writeStringField('TaxID', invItem.Tax__r.Tax_Label__c);
            jsonGen.writeStringField('TaxID', 'Standard rate');
            // jsonGen.writeStringField('TaxExemptionReason', '');
            jsonGen.writeNumberField('TaxPercentage', invItem.Tax__r.Tax_Percentage__c);
            jsonGen.writeEndObject();
        }
        jsonGen.writeEndArray(); // Invoice Items

        jsonGen.writeEndObject(); // InvoiceDetails
        jsonGen.writeEndObject(); // JSON

        String jsonStr = jsonGen.getAsString();
        system.debug('jsonStr-->' + jsonStr);
        // String responseStr = sendJsonToXml(jsonStr);
        return sendJsonToXml(invoiceId, jsonStr);
    }

    @AuraEnabled
    public static String sendJsonToXml(String invoiceId, String invoiceData) {
        System.debug('invoiceData-->' + invoiceData);
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://zatca-api.rangerfusion.com/generateInvoiceXml');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(invoiceData);

            System.debug('req-->' + req);
            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                String responseStr = res.getBody();
                try {
                    Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseStr);
                    if (responseMap.containsKey('ApiRequest')) {
                        String apiRequestJson = JSON.serialize(responseMap.get('ApiRequest'));
                        System.debug('apiRequestJson-->' + apiRequestJson); 
                        saveInvoiceResponse(invoiceId, apiRequestJson);
                    }  
                    return responseStr;
                } catch (Exception e) {
                    throw new AuraHandledException('Error parsing API response: ' + e.getMessage());
                }
            } else if (res.getStatusCode() == 400) {
                System.debug('Validation failed:-----> ' + res.getBody());
                throw new AuraHandledException('Validation failed: ' + res.getBody());
            } else if (res.getStatusCode() == 500) {
                System.debug('Internal server error:-----> ' + res.getBody());
                throw new AuraHandledException('Internal server error: ' + res.getBody());
            } else {
                throw new AuraHandledException('Error sending JSON to XML: ' + res.getBody());
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public static void saveInvoiceResponse(String invoiceId, String apiRequestJson) {
        try {
            ZATCA_Api_Request__c apiRequest = new ZATCA_Api_Request__c();
            apiRequest.Invoice_ID__c = invoiceId;
            apiRequest.JSON__c = apiRequestJson;

            if (Schema.sObjectType.ZATCA_Api_Request__c.isCreateable()) {
                insert apiRequest;
            } else {
                throw new AuraHandledException('No permission to create ZATCA_Api_Request__c records.');
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error saving invoice response: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String clearanceInvoice(String invoiceId) {
        List<ZATCA_Api_Request__c> dataList = [SELECT Id, Invoice_ID__c, JSON__c FROM ZATCA_Api_Request__c 
                                            WHERE Invoice_ID__c = :invoiceId LIMIT 1];

        List<Company_Settings__mdt> companySettingList = new List<Company_Settings__mdt>();
        if (Schema.sObjectType.Company_Settings__mdt.isAccessible()) {
            companySettingList = [SELECT GSTIN__c FROM Company_Settings__mdt LIMIT 1];
        }
        Company_Settings__mdt company = companySettingList.isEmpty() ? null : companySettingList[0];

        Invoice__c inv = [SELECT Invoice_Date__c, CreatedDate FROM Invoice__c WHERE Id = :invoiceId WITH SECURITY_ENFORCED LIMIT 1];

        if (dataList.isEmpty()) {
            throw new AuraHandledException('No record found for the given invoice ID: ' + invoiceId);
        }

        String apiRequestJson = dataList[0].JSON__c;

        List<CSR_Configuration__c> auth = new List<CSR_Configuration__c>();
        if (Schema.sObjectType.CSR_Configuration__c.isAccessible()) {
            auth = [SELECT Id, Production_CSID_Secret__c, Production_CSID_Token__c
                    FROM CSR_Configuration__c WHERE Company_Name__c = 'Ranger' LIMIT 1];
        } else {
            throw new AuraHandledException('No permission to access CSR_Configuration__c records.');
        }

        String binarySecurityToken = auth[0].Production_CSID_Token__c;
        String secret = auth[0].Production_CSID_Secret__c;

        try {
            String authString = binarySecurityToken + ':' + secret;
            String encodedAuth = 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(authString));

            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://zatca-api.rangerfusion.com/clearanceAPI');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Accept', 'application/json');
            req.setHeader('Accept-Language', 'en');
            // req.setHeader('Accept-Version', 'V2');
            req.setHeader('Clearance-Status', '1');
            req.setHeader('Authorization', encodedAuth);
            req.setHeader('SellerVatNumber', company.GSTIN__c);
            req.setHeader('IssueDate', String.valueOf(inv.Invoice_Date__c));
            req.setHeader('IssueTime', String.valueOf(inv.CreatedDate.format('HH:mm:ss')));
            req.setHeader('InvoiceId', invoiceId);
            req.setBody(apiRequestJson);

            Http http = new Http();
            HttpResponse res = http.send(req);

            // if (res.getStatusCode() == 200) {
            //     String responseStr = res.getBody();
            //     Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseStr);
            //     if (responseMap.containsKey('QrCode-Base64Encoded')) {
            //         String qrCode = (String) responseMap.get('QrCode-Base64Encoded');
            //         String qr = generateQRCodeFromBase64(qrCode, invoiceId);
            //         return qr;
            //     }
            // }
            if (res.getStatusCode() == 200) {
                Blob pdfBlob = res.getBodyAsBlob(); 
            
                ContentVersion cv = new ContentVersion();
                cv.Title = 'ZATCA_Clearance_' + invoiceId;
                cv.PathOnClient = 'ZATCA_Clearance_' + invoiceId + '.pdf';
                cv.VersionData = pdfBlob;
                insert cv;
            
                ContentVersion insertedVersion = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
            
                ContentDocumentLink cdl = new ContentDocumentLink();
                cdl.ContentDocumentId = insertedVersion.ContentDocumentId;
                cdl.LinkedEntityId = invoiceId; 
                cdl.ShareType = 'V'; 
                cdl.Visibility = 'AllUsers';
                insert cdl;
            
                return 'PDF saved and linked to invoice.';
            }             
            else {
                System.debug('Clearance failed:-----> ' + res.getBody());
                throw new AuraHandledException('Clearance failed: ' + res.getBody());
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }

        return '';  
    }

    public static String generateQRCodeFromBase64(String base64String, String invoiceId) {
        try {
            if (String.isBlank(base64String)) {
                return ''; 
            }

            String qrCodeUrl = 'https://quickchart.io/qr?text=' + EncodingUtil.urlEncode(base64String, 'UTF-8');
            List<Invoice__c> invList = [SELECT Id, Name, QR_Code__c FROM Invoice__c WHERE Id = :invoiceId LIMIT 1];

            HttpRequest req = new HttpRequest();
            req.setEndpoint(qrCodeUrl);
            req.setMethod('GET');

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                Blob qrImageBlob = res.getBodyAsBlob();
                String publicUrl = saveQRImageAsPublicFile(qrImageBlob, invList[0].Name);

                if (publicUrl != null) {
                    if (!invList.isEmpty()) {
                        Invoice__c inv = invList[0];
                        inv.QR_Code__c = publicUrl;
                        if (Schema.sObjectType.Invoice__c.isUpdateable()) {
                            update inv;
                        } else {
                            throw new AuraHandledException('No permission to update Invoice__c records.');
                        }
                    }
                    return publicUrl;
                }
            }
        } catch (Exception e) {
            System.debug('Exception in generateQRCodeFromBase64: ' + e.getMessage());
        }
        return '';  
    }

    private static String saveQRImageAsPublicFile(Blob imageBlob, String fileName) {
        try {
            if (imageBlob == null) {
                return ''; 
            }

            ContentVersion cv = new ContentVersion();
            cv.Title = fileName;
            cv.PathOnClient = fileName + '.png';
            cv.VersionData = imageBlob;
            cv.IsMajorVersion = true;
            if (Schema.sObjectType.ContentVersion.isCreateable()) {
                insert cv;
            } else {
                return '';
            }

            ContentDocument cd;
            if (Schema.sObjectType.ContentDocument.isAccessible()) {
                cd = [SELECT Id FROM ContentDocument WHERE LatestPublishedVersionId = :cv.Id LIMIT 1];
            } else {
                return ''; 
            }

            ContentDistribution distribution = new ContentDistribution(
                Name = cv.Title,
                ContentVersionId = cv.Id,
                PreferencesAllowViewInBrowser = true
            );
            if (Schema.sObjectType.ContentDistribution.isCreateable()) {
                insert distribution;
            } else {
                return '';
            }

            ContentDistribution shareFile = [
                SELECT Id, ContentDownloadUrl, DistributionPublicUrl 
                FROM ContentDistribution 
                WHERE Id = :distribution.Id
            ];

            return shareFile.DistributionPublicUrl;
        } catch (Exception e) {
            System.debug('Error in saveQRImageAsPublicFile: ' + e.getMessage());
        }
        return ''; 
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getPicklistValue(String fieldApiName) {
        List<String> options = new List<String>();

        // Build full field reference dynamically
        Schema.SObjectField fieldToken = Invoice__c.SObjectType.getDescribe().fields.getMap().get(fieldApiName);
        
        if (fieldToken != null) {
            Schema.DescribeFieldResult fieldResult = fieldToken.getDescribe();
        List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();

        for (Schema.PicklistEntry entry : picklistValues) {
            options.add(entry.getLabel());
        }
        }
        return options;
    }
 @AuraEnabled
    public static String getInvoiceFormData(String invId){
        JSONGenerator jsonGen = JSON.createGenerator(true);
        jsonGen.writeStartObject();
        try{
            Invoice__c inv = [SELECT Id,Name,Email_Bcc__c ,Email_CC__c,Contact__C,Contact__r.email,Sum_Of_GST_Amount__c,Account__c,Billing_Address__c,
                                Term__c,Invoice_Date__c,Due_Date__c,Amounts_are__c,Message_Of_Invoice__c,Message_On_Statement__c,
                                Invoice_status__c,PlaceOfSupply__c,Authorized_Sign__c,To_Email_Addresses__c,Account__r.Name,Contact__r.Name,Sum_of_Paid_Amount__c,
                                Currency_Code__c,Company_Name__c,Terms_And_Condition__c,Amount_In_Words__c,Currency__c,Exchange_rate__c,Discount_Type__c,Discount_Mode__c,Invoice_Indicator__c,
                                Lumpsum_Discount_Amount__c,Lumpsum_Discount_Percentage__c,Amount_After_Discount__c, Invoice_Type__c, Invoice_Name_Type__c, Payment_Type__c, Discount_Reason__c,
                                Latest_Delivery_Date__c FROM Invoice__c WHERE id =:invId WITH SECURITY_ENFORCED LIMIT 1 ];
            InvoiceFormWrapper invWrapObj = new InvoiceFormWrapper();
            invWrapObj.invStatus = inv.Invoice_status__c;
            invWrapObj.invId = inv.Id;
            invWrapObj.name = inv.Name;
            invWrapObj.accId = inv.Account__c;
            invWrapObj.conId = inv.Contact__c;
            invWrapObj.primaryConEmailAddresses = inv.To_Email_Addresses__c; //NewlyCreated - Need to create a field for this
            invWrapObj.ccEmailAddresses = inv.Email_CC__c;
            invWrapObj.bccEmailAddresses = inv.Email_Bcc__c;
            invWrapObj.billingAddress = inv.Billing_Address__c;
            invWrapObj.termLabel = inv.Term__c; //invWrapObj.term ==> Not Stored
            invWrapObj.term = invWrapObj.termLabel != null ? invWrapObj.termLabel.replace('Net ','') : null;
            invWrapObj.invoiceDate = inv.Invoice_Date__c;
            invWrapObj.dueDate = inv.Due_Date__c;
            invWrapObj.placeOfSupply = inv.PlaceOfSupply__c; //NewlyCreated - Need to create a field for this
            invWrapObj.authSign = inv.Authorized_Sign__c;
            invWrapObj.invoiceType = inv.Invoice_Type__c;
            invWrapObj.invoiceIndicator = inv.Invoice_Indicator__c;
            invWrapObj.invoiceNameType = inv.Invoice_Name_Type__c;
            invWrapObj.paymentType = inv.Payment_Type__c;
            invWrapObj.latestDeliveryDate = inv.Latest_Delivery_Date__c;
            invWrapObj.lumpsumDiscountReason = inv.Discount_Reason__c;
            invWrapObj.selectedCurrency=inv.Currency__c;
            invWrapObj.exchangeRate = String.valueOf(inv.Exchange_rate__c);
            invWrapObj.parentTaxSelectedOption = inv.Amounts_are__c;
            invWrapObj.msgOnInv = inv.Message_Of_Invoice__c;
            invWrapObj.termsAndCond = inv.Terms_And_Condition__c;
            invWrapObj.amtInWords = inv.Amount_In_Words__c;
            invWrapObj.msgOnStmt = inv.Message_On_Statement__c;
            invWrapObj.paidAmount = inv.Sum_of_Paid_Amount__c;
            invWrapObj.companyName = inv.Company_Name__c;
            invWrapObj.currencyCode = inv.Currency_Code__c;
            invWrapObj.selectedDiscountType = inv.Discount_Type__c;
            invWrapObj.selectedDiscountMode = inv.Discount_Mode__c;
            invWrapObj.lumpsumDiscountPercentage = inv.Lumpsum_Discount_Percentage__c;
            invWrapObj.lumpsumDiscountAmount = inv.Lumpsum_Discount_Amount__c;
            invWrapObj.amountAfterDiscount = inv.Amount_After_Discount__c;
            //invWrapObj.subTotal;
            //invWrapObj.total;
            //invWrapObj.balanceDue;
            //invWrapObj.totalTaxAmt;
            List<InvoiceItemWrapper> iiwList = new List<InvoiceItemWrapper>();
            for(Invoice_Item__c invItem : [SELECT Id,Name,Invoice__c,Service_Date__c ,Product1__c,HsnSac__c,Description__c,
                                            Quantity__c,Rate__c,Amount__c,Tax__c,Amount_With_GST__c,GST_Amount__c,Key__c,
                                            Product1__r.Name,IsKnownPdt__c,Tax__r.name,Tax__r.Tax_Percentage__c, Tax_ID__c, Tax_Exemption_Reason__c,
                                            Tax__r.Tax_Label__c,Discount_Percentage__c,Discount_Amount__c,Amount_Before_Discount__c,Tax_Amount__c, Discount_Reason__c
                                            FROM Invoice_Item__c WHERE Invoice__c =:invId WITH SECURITY_ENFORCED]){
                InvoiceItemWrapper iiw = new InvoiceItemWrapper();
                iiw.invItemId = invItem.Id;
                iiw.serviceDate =  invItem.Service_Date__c;
                iiw.key = invItem.Key__c;
                iiw.pdtDraftName =  invItem.Product1__r.Name;
                iiw.pdtId =  invItem.Product1__c;
                iiw.isKnownPdt = invItem.IsKnownPdt__c;
                if(!iiw.isKnownPdt){
                    if(invItem.Product1__c != null){
                        iiw.pdtId = '_new_';
                    }else{
                        iiw.pdtId = null;
                    }
                }else{
                    iiw.pdtDraftName = null;
                }
                iiw.hsn =  invItem.HsnSac__c;
                iiw.description =  invItem.Description__c;
                iiw.discountReason = invItem.Discount_Reason__c; 
                iiw.discountPercentage = invItem.Discount_Percentage__c;
                iiw.discountAmount = invItem.Discount_Amount__c;
                iiw.qty =  invItem.Quantity__c;
                iiw.rate =  invItem.Rate__c;
                iiw.amt =  invItem.Amount__c;
                iiw.beforeDisAmount = invItem.Amount_Before_Discount__c;
                iiw.taxAmount = invItem.Tax_Amount__c;
                iiw.taxId =  invItem.Tax__c;  //iiw.taxLabel, iiw.tax ==> Not used
                iiw.taxLabel = invItem.Tax__c != null ? invItem.Tax__r.name : null;
                iiw.tax = invItem.Tax__r.Tax_Label__c;
                iiw.taxCategory = invItem.Tax_ID__c;
                iiw.taxExemptionReason = invItem.Tax_Exemption_Reason__c;
                iiw.amtWithTax =  invItem.Amount_With_GST__c;
                iiw.taxAmt =  invItem.GST_Amount__c;
                iiwList.add(iiw);
            }
            invWrapObj.invoiceItemList = iiwList;
            jsonGen.writeObjectField('invWrapObj',invWrapObj);
        }catch(exception e){
            //system.debug('Inside the exception section '+e.getMessage());
            jsonGen.writeStringField('errorMessage',e.getMessage());
        }
        jsonGen.writeEndObject();
        return jsonGen.getAsString();
    }
    @AuraEnabled(Cacheable=true)
    public static List<Account> fetchAccountList(String searchText){
        searchText = '%'+searchText+'%';
        List<Account> accList = new List<Account>();
        accList = [SELECT Id,Name FROM Account WHERE Name like :searchText WITH security_enforced];
        return accList;
    }
    @AuraEnabled(Cacheable=true)
    public static List<Product__c> getProductList(){
        List<Product__c> pdtList = new List<Product__c>();
        pdtList = [SELECT Id,Name FROM Product__c WITH security_enforced LIMIT 100];
        return pdtList;
    }
    @AuraEnabled(Cacheable=true)
    public static List<Authorized__mdt> getAuthList(){
        List<Authorized__mdt> autList = new List<Authorized__mdt>();
        autList = [SELECT MasterLabel FROM Authorized__mdt WITH SECURITY_ENFORCED Limit 10];
        return autList;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getPicklistValues() {
        Map<String, List<String>> picklistMap = new Map<String, List<String>>();
    // public static Map<String, Object> getPicklistValues() {
    //     Map<String, Object> picklistMap = new Map<String, Object>();
 
        Schema.DescribeFieldResult field1 = Invoice__c.Invoice_Type__c.getDescribe();
        Schema.DescribeFieldResult field2 = Invoice__c.Invoice_Name_Type__c.getDescribe();
        Schema.DescribeFieldResult field3 = Invoice__c.Payment_Type__c.getDescribe();
        Schema.DescribeFieldResult field4 = Invoice__c.Discount_Reason__c.getDescribe();
        Schema.DescribeFieldResult field5 = Invoice__c.Tax_ID__c.getDescribe();
        Schema.DescribeFieldResult field6 = Invoice__c.Tax_Exemption_Reason__c.getDescribe();
        Schema.DescribeFieldResult field7 = Invoice__c.Invoice_Indicator__c.getDescribe();
 
        List<Schema.PicklistEntry> invoiceTypeValues = field1.getPicklistValues();
        List<Schema.PicklistEntry> invoiceNameTypeValues = field2.getPicklistValues();
        List<Schema.PicklistEntry> paymentTypeValues = field3.getPicklistValues();
        List<Schema.PicklistEntry> discountReasonValues = field4.getPicklistValues();
        List<Schema.PicklistEntry> taxIdValues = field5.getPicklistValues();
        List<Schema.PicklistEntry> taxExemptionReasonValues = field6.getPicklistValues();
        List<Schema.PicklistEntry> invoiceIndicatorValues = field7.getPicklistValues();
 
        List<String> invoiceType = new List<String>();
        for (Schema.PicklistEntry entry : invoiceTypeValues) {
            invoiceType.add(entry.getLabel());
        }
 
        List<String> invoiceNameType = new List<String>();
        for (Schema.PicklistEntry entry : invoiceNameTypeValues) {
            invoiceNameType.add(entry.getLabel());
        }

        List<String> paymentType = new List<String>();
        for (Schema.PicklistEntry entry : paymentTypeValues) {
            paymentType.add(entry.getLabel());
        }

        List<String> discountReason = new List<String>();
        for (Schema.PicklistEntry entry : discountReasonValues) {
            discountReason.add(entry.getLabel());
        }

        List<String> taxId = new List<String>();
        for (Schema.PicklistEntry entry : taxIdValues) {
            taxId.add(entry.getLabel());
        }

        List<String> taxExemptionReason = new List<String>();
        for (Schema.PicklistEntry entry : taxExemptionReasonValues) {
            taxExemptionReason.add(entry.getLabel());
        }

        List<String> invoiceIndicator = new List<String>();
        for (Schema.PicklistEntry entry : invoiceIndicatorValues) {
            invoiceIndicator.add(entry.getLabel());
        }
 
        picklistMap.put('invoiceType', invoiceType);
        picklistMap.put('invoiceNameType', invoiceNameType);
        picklistMap.put('paymentType', paymentType);
        picklistMap.put('discountReason', discountReason);
        picklistMap.put('taxId', taxId);
        picklistMap.put('taxExemptionReason', taxExemptionReason);
        // picklistMap.put('taxExemptionReason', taxDependencyMap);
        picklistMap.put('invoiceIndicator', invoiceIndicator);

        return picklistMap;
    }

    @AuraEnabled(Cacheable=true)
    //RP - 02May2023 - removed param "accName" - Commanded since we will be having only one row in this table here after
    public static List<Company_Settings__mdt> getAccBankInfo(){ 
        ActiveCompanyName__c companyName =[SELECT Company_Name__c, Active__c FROM ActiveCompanyName__c 
                                            where Active__c =true WITH SECURITY_ENFORCED Limit 1];
        List<Company_Settings__mdt> companySettingList = new List<Company_Settings__mdt>();
        companySettingList = [SELECT Id,Name__c,Address1__c, Address2__c,City__c, State__c,Pincode__c, Phone_Number__c, 
        Company_Email__c, Account_Number__c, Account_Type__c, IFSC_Code__c, Branch__c,Terms_And_Condition__c,
        Place_of_Supply__c FROM Company_Settings__mdt 
        where label=:companyName.Company_Name__c
        //RP - 02May2023 - accName - Commanded since we will be having only one row in this table here after
        //WHERE Name__c =: accName 
        WITH security_enforced LIMIT 1];
        return companySettingList;
    }
    @AuraEnabled(Cacheable=true)
    public static String getCurrencyInWords(Decimal totalInvAmt){ 
        String aiw;
        if (totalInvAmt != null && totalInvAmt >= 0) {                    
            Long n = totalInvAmt.longValue();
            string amo = ConvertCurrencyToWords.english_number(n);
            string amo1 = amo.remove(',');
            aiw = amo1;
        } else {
            aiw = null;
        } 
        return aiw;
    }
    @AuraEnabled(Cacheable=true)
    public static List<Tax__c> getMainTaxOptions(String countryName){
        List<Tax__c> parentTaxOptions = new List<Tax__c>();
        parentTaxOptions = [SELECT Id,Name,Country__c,Tax_Percentage__c FROM Tax__c WHERE Country__c=:countryName
         WITH security_enforced];
         //system.debug('parentTaxOptions-->'+parentTaxOptions);
        return parentTaxOptions;
    }
    @AuraEnabled(Cacheable=true)
    public static List<Tax_Detail__c> getChildTaxOptions(String parentTaxName){
        List<Tax_Detail__c> childTaxOptions = new List<Tax_Detail__c>();
        childTaxOptions = [SELECT Id, Name, Tax__c, Tax__r.name, Tax_Percentage__c FROM Tax_Detail__c
         WHERE Tax__r.name=:parentTaxName
        WITH security_enforced];
        //system.debug('childTaxOptions-->'+childTaxOptions);
        return childTaxOptions;
    }
    @AuraEnabled(Cacheable=true)
    public static Map<String,List<Tax_Detail__c>> getAllChildTaxOptions(){
        Map<String,List<Tax_Detail__c>> childTaxInfoMap = new Map<String,List<Tax_Detail__c>>();
        String tempParentTaxName = null;
        for(Tax_Detail__c tx : [SELECT Id, Name, Tax__c, Tax__r.name, Tax_Percentage__c FROM Tax_Detail__c
         WITH SECURITY_ENFORCED ORDER BY Tax__r.name DESC LIMIT 100]){
            List<Tax_Detail__c> childTaxOptions = new List<Tax_Detail__c>();
            childTaxOptions = childTaxInfoMap.get(tx.Tax__r.name);
            if(childTaxOptions == null) {childTaxOptions = new List<Tax_Detail__c>();}
            childTaxOptions.add(tx);
            childTaxInfoMap.put(tx.Tax__r.name,childTaxOptions);
        }
        return childTaxInfoMap;
    }
 @AuraEnabled(Cacheable=true)
    public static string emailViewCount(String invId){
        ContentDocumentLink conDocLink = new ContentDocumentLink();
        conDocLink = [SELECT Id, LinkedEntityId, ContentDocumentId, IsDeleted, systemModstamp, ShareType,
         Visibility FROM ContentDocumentLink where LinkedEntityId =: invId WITH security_enforced order by systemModstamp DESC Limit 1];
         ContentDistribution conDis = new ContentDistribution();
         conDis = [SELECT Id, Name,ViewCount,ContentDocumentId FROM ContentDistribution 
         where ContentDocumentId = :conDocLink.ContentDocumentId WITH security_enforced];
        return  String.valueOf(conDis.ViewCount);
    }
    private static List<Invoice_Item__c> invoiceItems1 = new List<Invoice_Item__c>();
    @AuraEnabled
    public static List<Invoice_Item__c> getInvoiceItems(Id invoiceId) {
        if (invoiceId == null) {
            throw new AuraHandledException('Invoice ID cannot be null');
        }
        try {
            // First verify the invoice exists
            Invoice__c inv = [SELECT Id FROM Invoice__c WHERE Id = :invoiceId WITH SECURITY_ENFORCED LIMIT 1];
            // Query invoice items - note we use an empty list as default
            List<Invoice_Item__c> invoiceItems = [
                SELECT Id, Name, Invoice__c, Amount__c, Product1__c, Product1__r.Name,
                Amount_With_GST__c, GST_Amount__c ,Product1__r.Is_Service__c
                FROM Invoice_Item__c 
                WHERE Invoice__c = :inv.Id 
                WITH SECURITY_ENFORCED 
                LIMIT 100
            ];
            //system.debug('Number of invoice items found: ' + invoiceItems.size());
            invoiceItems1 = invoiceItems;
            return invoiceItems;
        } catch (QueryException qe) {
            //system.debug('Query error: ' + qe.getMessage());
            return new List<Invoice_Item__c>(); // Return empty list instead of null
        } catch (Exception e) {
            //system.debug('Error: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving invoice items: ' + e.getMessage());
        }
    }
    @AuraEnabled(Cacheable=true)
    public static void createJournalTrigger(List<Invoice__c> invList, Map<Id, Invoice__c> oldMap) {
        for (Invoice__c inv : invList) {
            // Ensure it's checked and either newly inserted or updated from false → true
            if (inv.Create_Journal_Entry__c &&
                (oldMap == null || oldMap.get(inv.Id) == null || !oldMap.get(inv.Id).Create_Journal_Entry__c)) {
                createJournalEntryRecord(inv.Id, false);
            }
        }
    }
    @AuraEnabled(Cacheable=true)
    public static void createJournalTriggerupdate(List<Invoice__c> invList, Map<Id, Invoice__c> oldMap) {
        List<Invoice__c> invoicesToUpdate = new List<Invoice__c>();
        for (Invoice__c inv : invList) {
            Invoice__c oldInv = oldMap.get(inv.Id);
            // Ensure it's checked and either newly inserted or updated from false → true
            if (inv.Create_Journal_Entry__c &&
                (!oldInv.Create_Journal_Entry__c)) {
                createJournalEntryRecord(inv.Id,false);
            }
            else if(inv.Invoice_status__c == 'Draft' && (oldInv.Invoice_status__c == 'Sent') &&
                (oldInv.Create_Journal_Entry__c)) {
                createJournalEntryRecord(inv.Id,true);
                 // Prepare to update the checkbox field to false
                Invoice__c invUpdate = new Invoice__c(
                    Id = inv.Id,
                    Create_Journal_Entry__c = false
                );
                invoicesToUpdate.add(invUpdate);
            }
        }
         // Perform DML update outside the loop
        if (!invoicesToUpdate.isEmpty()) {
            update invoicesToUpdate;
        }
    }
    @AuraEnabled
    public static void createJournalEntryRecord(Id invId, Boolean flag) {
        try {
            // Get invoice and related data
            Invoice__c inv = [SELECT Id, Name, Account__c, Account__r.Name, Total_Amount__c, 
                             Sum_Of_GST_Amount__c, Amounts_are__c ,Currency__c,Exchange_rate__c
                             FROM Invoice__c WHERE Id = :invId LIMIT 1];
            // Get chart of accounts
            Chart_of_Accounts__c coac = [SELECT Id FROM Chart_of_Accounts__c WHERE Name = 'Sales Revenue' LIMIT 1];
            Chart_of_Accounts__c cacd = new Chart_of_Accounts__c();
            Chart_of_Accounts__c cogs = [SELECT Id FROM Chart_of_Accounts__c WHERE Name = 'Cost of Goods' LIMIT 1];
            Chart_of_Accounts__c cgst = [SELECT Id FROM Chart_of_Accounts__c WHERE Name = 'CGST Output' LIMIT 1];
            Chart_of_Accounts__c sgst = [SELECT Id FROM Chart_of_Accounts__c WHERE Name = 'SGST Output' LIMIT 1];
            Chart_of_Accounts__c inventorycoa = [SELECT Id FROM Chart_of_Accounts__c WHERE Name = 'Inventory' LIMIT 1];
            try {
                cacd = [SELECT Id FROM Chart_of_Accounts__c WHERE Account__c = :inv.Account__c LIMIT 1];
                //system.debug('cacd-->' + (cacd != null ? cacd.Id : 'null'));
            } catch(QueryException qe) {
                cacd = null;
                //system.debug('No Chart of Accounts found for Account');
            }
            //system.debug('coac-->' + coac);
            //system.debug('inv-->' + inv);
            Id assetsRecordTypeId;
            Id revenueRecordTypeId;
            // Fix record type query loop
            List<RecordType> recordTypes = [SELECT Id, Name FROM RecordType WHERE SObjectType = 'Chart_of_Accounts__c'];
            for (RecordType rt : recordTypes) {
                if (rt.Name == 'Assets') {
                    assetsRecordTypeId = rt.Id;
                } else if (rt.Name == 'Revenue') {
                    revenueRecordTypeId = rt.Id;
                }
            }
            if (cacd ==null) {
                //system.debug('inside if');
                Account acc = [SELECT Id, Name FROM Account WHERE Id = :inv.Account__c LIMIT 1];
                cacd = new Chart_of_Accounts__c();
                Chart_of_Accounts__c sundrychartacc = [SELECT Id FROM Chart_of_Accounts__c WHERE Name = 'Sundry Debtors' LIMIT 1];
                //Chart_of_Accounts__c cacd = new Chart_of_Accounts__c();
                cacd.RecordTypeId = assetsRecordTypeId;
                cacd.Name = acc.Name;
                cacd.Account__c = acc.Id;
                cacd.Parent_Account__c = sundrychartacc.Id;
                cacd.SubCategory__c = 'Other Current Asset';
                if (!Schema.sObjectType.Chart_of_Accounts__c.isCreateable() ||
                    !Schema.sObjectType.Chart_of_Accounts__c.fields.Name.isCreateable() ||
                    !Schema.sObjectType.Chart_of_Accounts__c.fields.Account__c.isCreateable() ||
                    !Schema.sObjectType.Chart_of_Accounts__c.fields.Parent_Account__c.isCreateable() ||
                    !Schema.sObjectType.Chart_of_Accounts__c.fields.SubCategory__c.isCreateable() ||
                    !Schema.sObjectType.Chart_of_Accounts__c.fields.RecordTypeId.isCreateable()) {
                    throw new AuraHandledException('Insufficient permissions to create Chart of Accounts record');
                }
                insert cacd;
            }
            // Get invoice items
            List<Invoice_Item__c> invoiceItems = [SELECT Id, Name, Amount__c, GST_Amount__c, Quantity__c,
                                                Product1__c, Product1__r.Name, Product1__r.Is_Service__c,
                                                Tax__c, Tax__r.Tax_Percentage__c 
                                                FROM Invoice_Item__c 
                                                WHERE Invoice__c = :inv.Id];
            // Separate items and calculate totals
            List<Invoice_Item__c> serviceItems = new List<Invoice_Item__c>();
            List<Invoice_Item__c> productItems = new List<Invoice_Item__c>();
            // Calculate separate totals for each type
            Decimal serviceTotalAmount = 0;
            Decimal serviceTotalTaxAmount = 0;
            Decimal productTotalAmount = 0;
            Decimal productTotalTaxAmount = 0;
            for(Invoice_Item__c item : invoiceItems) {
                if(item.Product1__r.Is_Service__c) {
                    serviceItems.add(item);
                    serviceTotalAmount += item.Amount__c;
                    serviceTotalTaxAmount += (item.GST_Amount__c != null ? item.GST_Amount__c : 0);
                } else {
                    productItems.add(item);
                    productTotalAmount += item.Amount__c;
                    productTotalTaxAmount += (item.GST_Amount__c != null ? item.GST_Amount__c : 0);
                }
            }
            // Handle service items if they exist
            if(!serviceItems.isEmpty()) {
                createServiceEntries(inv, serviceItems, serviceTotalAmount, serviceTotalTaxAmount,
                                   cacd, coac, cgst, sgst, flag);
            }
            // Handle product items if they exist
            if(!productItems.isEmpty()) {
                createProductEntries(inv, productItems, productTotalAmount, productTotalTaxAmount,
                                   cacd, coac, cgst, sgst, cogs, inventorycoa, flag);
            }
        } catch(Exception e) {
            throw new AuraHandledException('Error creating journal entries: ' + e.getMessage());
        }
    }
 private static void createServiceEntries(Invoice__c inv, List<Invoice_Item__c> serviceItems, 
                                           Decimal totalAmount, Decimal totalTaxAmount,
                                           Chart_of_Accounts__c cacd, Chart_of_Accounts__c coac, 
                                           Chart_of_Accounts__c cgst, Chart_of_Accounts__c sgst, Boolean flag) {
        Boolean hasTax = totalTaxAmount > 0;
        Boolean hasMultipleItems = serviceItems.size() > 1;
        Boolean needsChildRecords = hasMultipleItems || hasTax;
        // Create parent service entry
        Journal_Entry__c parentEntry = new Journal_Entry__c(
            Name = inv.Name + ' - Services',
            Status__c = 'Draft',
            Type__c = 'Journal',
            Invoice__c = inv.Id,
            Debit_Chart_of_Accounts__c = flag ? (needsChildRecords ? null : coac.Id) : cacd.Id,
            Credit_Chart_of_Accounts__c = flag ? cacd.Id : (needsChildRecords ? null : coac.Id),
            Entry_Date__c = Date.Today(),
            Has_Debit_Child__c = flag ? needsChildRecords : false,
            Has_Credit_Child__c = flag ? false : needsChildRecords,
            Currency__c= inv.Currency__c,
            Exchange_rate__c= inv.Exchange_rate__c
        );
        // Set debit and credit amounts to be equal
        if(inv.Amounts_are__c == 'Inclusive of Tax') {
            parentEntry.Debit_Amount__c = totalAmount * inv.Exchange_rate__c;
            parentEntry.Credit_Amount__c = totalAmount* inv.Exchange_rate__c;
            parentEntry.Final_Amount__c = totalAmount * inv.Exchange_rate__c;

        } else if(inv.Amounts_are__c == 'Exclusive of Tax') {
            parentEntry.Debit_Amount__c = totalAmount + totalTaxAmount* inv.Exchange_rate__c;
            parentEntry.Credit_Amount__c = totalAmount + totalTaxAmount* inv.Exchange_rate__c;
            parentEntry.Final_Amount__c = totalAmount + totalTaxAmount * inv.Exchange_rate__c ;
        } else {
            parentEntry.Debit_Amount__c = totalAmount* inv.Exchange_rate__c;
            parentEntry.Credit_Amount__c = totalAmount* inv.Exchange_rate__c;
            parentEntry.Final_Amount__c = totalAmount* inv.Exchange_rate__c;
        }
        insert parentEntry;
        // Only create child entries if multiple items or has tax
        if(needsChildRecords) {
            List<Journal_Entry__c> childEntries = new List<Journal_Entry__c>();
            // Create individual service item entries
            for(Invoice_Item__c item : serviceItems) {
                Decimal itemCredit = inv.Amounts_are__c == 'Inclusive of Tax' ? 
                    item.Amount__c - (item.GST_Amount__c != null ? item.GST_Amount__c : 0) : 
                    item.Amount__c;
                    Journal_Entry__c childEntry = new Journal_Entry__c(
                    Name = inv.Name + ' - Service: ' + item.Product1__r.Name,
                    Status__c = 'Draft',
                    Type__c = 'Journal',
                    // Invoice__c = inv.Id,
                    Parent_Journal_Entry__c = parentEntry.Id,
                    Entry_Date__c = Date.Today(),
                    ReferenceAmount__c = itemCredit * inv.Exchange_rate__c,
                    Final_Amount__c = itemCredit * inv.Exchange_rate__c
                    );
                    // Set dynamic fields based on flag
                    if (flag == true) {
                        childEntry.Debit_Description__c = item.Product1__r.Name;
                        childEntry.Debit_Chart_of_Accounts__c = coac.Id;
                        childEntry.Debit_Amount__c = itemCredit * inv.Exchange_rate__c;
                        childEntry.Reference_Account__c = parentEntry.Credit_Chart_of_Accounts__c;
                    } else {
                        childEntry.Credit_Description__c = item.Product1__r.Name;
                        childEntry.Credit_Chart_of_Accounts__c = coac.Id;
                        childEntry.Credit_Amount__c = itemCredit * inv.Exchange_rate__c;
                        childEntry.Reference_Account__c = parentEntry.Debit_Chart_of_Accounts__c;
                    }
                    childEntries.add(childEntry);
            }
            // Create tax entries if applicable
            if(hasTax) {
                Decimal cgstAmount = totalTaxAmount / 2;
                Journal_Entry__c childEntry = new Journal_Entry__c(
                    Name = inv.Name + ' - Service CGST',
                    Status__c = 'Draft',
                    Type__c = 'Journal',
                    // Invoice__c = inv.Id,
                    Parent_Journal_Entry__c = parentEntry.Id,
                    Entry_Date__c = Date.Today(),
                    ReferenceAmount__c = cgstAmount* inv.Exchange_rate__c,
                    Final_Amount__c = cgstAmount* inv.Exchange_rate__c
                );
                if (flag == true) {
                    childEntry.Debit_Chart_of_Accounts__c = cgst.Id;
                    childEntry.Debit_Amount__c = cgstAmount* inv.Exchange_rate__c;
                    childEntry.Reference_Account__c = parentEntry.Credit_Chart_of_Accounts__c;
                } else {
                    childEntry.Credit_Chart_of_Accounts__c = cgst.Id;
                    childEntry.Credit_Amount__c = cgstAmount* inv.Exchange_rate__c;
                    childEntry.Reference_Account__c = parentEntry.Debit_Chart_of_Accounts__c;
                }
                childEntries.add(childEntry);
                Journal_Entry__c childEntry1 = new Journal_Entry__c(
                    Name = inv.Name + ' - Service SGST',
                    Status__c = 'Draft',
                    Type__c = 'Journal',
                    // Invoice__c = inv.Id,
                    Parent_Journal_Entry__c = parentEntry.Id,
                    Entry_Date__c = Date.Today(),
                    ReferenceAmount__c = cgstAmount* inv.Exchange_rate__c,
                    Final_Amount__c = cgstAmount* inv.Exchange_rate__c
                );
                if (flag == true) {
                    childEntry1.Debit_Chart_of_Accounts__c = sgst.Id;
                    childEntry1.Debit_Amount__c = cgstAmount* inv.Exchange_rate__c;
                    childEntry1.Reference_Account__c = parentEntry.Credit_Chart_of_Accounts__c;
                } else {
                    childEntry1.Credit_Chart_of_Accounts__c = sgst.Id;
                    childEntry1.Credit_Amount__c = cgstAmount* inv.Exchange_rate__c;
                    childEntry1.Reference_Account__c = parentEntry.Debit_Chart_of_Accounts__c;
                }
                childEntries.add(childEntry1);
            }
            if(!childEntries.isEmpty()) {
                insert childEntries;
            }
        }
    }
 private static void createProductEntries(Invoice__c inv, List<Invoice_Item__c> productItems, 
                                           Decimal totalAmount, Decimal totalTaxAmount,
                                           Chart_of_Accounts__c cacd, Chart_of_Accounts__c coac, 
                                           Chart_of_Accounts__c cgst, Chart_of_Accounts__c sgst,
                                           Chart_of_Accounts__c cogs, Chart_of_Accounts__c inventorycoa, Boolean flag) {
    try {
        Boolean hasTax = totalTaxAmount > 0;
        Boolean hasMultipleItems = productItems.size() > 1;
        // Create parent product entry
        Journal_Entry__c parentEntry = new Journal_Entry__c(
            Name = inv.Name + ' - Products',
            Status__c = 'Draft',
            Type__c = 'Journal',
            Invoice__c = inv.Id,
            Debit_Chart_of_Accounts__c = flag ? (hasMultipleItems || hasTax) ? null : coac.Id : cacd.Id,
            Credit_Chart_of_Accounts__c = flag ? cacd.Id : ((hasMultipleItems || hasTax) ? null : coac.Id),
            Entry_Date__c = Date.Today(),
            Has_Debit_Child__c = flag ? (hasMultipleItems || hasTax) : false,
            Has_Credit_Child__c = flag ? false : (hasMultipleItems || hasTax),
            Currency__c= inv.Currency__c,
            Exchange_rate__c= inv.Exchange_rate__c
        );
        // Update parent entry debit/credit amounts to be equal
        if(inv.Amounts_are__c == 'Inclusive of Tax') {
            parentEntry.Debit_Amount__c = totalAmount * inv.Exchange_rate__c;
            parentEntry.Credit_Amount__c = totalAmount * inv.Exchange_rate__c;
            parentEntry.Final_Amount__c = totalAmount * inv.Exchange_rate__c;
        } else if(inv.Amounts_are__c == 'Exclusive of Tax') {
            parentEntry.Debit_Amount__c = totalAmount + totalTaxAmount * inv.Exchange_rate__c;
            parentEntry.Credit_Amount__c = totalAmount + totalTaxAmount * inv.Exchange_rate__c;
            parentEntry.Final_Amount__c = totalAmount + totalTaxAmount * inv.Exchange_rate__c;
        } else {
            parentEntry.Debit_Amount__c = totalAmount * inv.Exchange_rate__c;
            parentEntry.Credit_Amount__c = totalAmount * inv.Exchange_rate__c;
            parentEntry.Final_Amount__c = totalAmount * inv.Exchange_rate__c;
        }
        insert parentEntry;
        // Create child entries if needed
        if(hasMultipleItems || hasTax) {
            List<Journal_Entry__c> childEntries = new List<Journal_Entry__c>();
            // Create product item entries
            for(Invoice_Item__c item : productItems) {
                Decimal itemCredit = inv.Amounts_are__c == 'Inclusive of Tax' ? 
                    item.Amount__c - (item.GST_Amount__c != null ? item.GST_Amount__c : 0) : 
                    item.Amount__c;
                if(hasMultipleItems || hasTax) {
                    Journal_Entry__c childEntry = new Journal_Entry__c(
                        Name = inv.Name + ' - Product: ' + item.Product1__r.Name,
                        Status__c = 'Draft',
                        Type__c = 'Journal',
                        // Invoice__c = inv.Id,
                        Parent_Journal_Entry__c = parentEntry.Id,
                        Entry_Date__c = Date.Today(),
                        ReferenceAmount__c = itemCredit * inv.Exchange_rate__c,
                        Final_Amount__c = itemCredit * inv.Exchange_rate__c
                    );
                    // Set dynamic fields based on flag
                    if (flag == true) {
                        childEntry.Debit_Description__c = item.Product1__r.Name;
                        childEntry.Debit_Chart_of_Accounts__c = coac.Id;
                        childEntry.Debit_Amount__c = itemCredit * inv.Exchange_rate__c;
                        childEntry.Reference_Account__c = parentEntry.Credit_Chart_of_Accounts__c;
                    } else {
                        childEntry.Credit_Description__c = item.Product1__r.Name;
                        childEntry.Credit_Chart_of_Accounts__c = coac.Id;
                        childEntry.Credit_Amount__c = itemCredit * inv.Exchange_rate__c;
                        childEntry.Reference_Account__c = parentEntry.Debit_Chart_of_Accounts__c;
                    }
                    childEntries.add(childEntry);
                }
            }
            // Create tax entries if applicable
            if(hasTax) {
                Map<Decimal, Decimal> taxRateToAmount = new Map<Decimal, Decimal>();
                for(Invoice_Item__c item : productItems) {
                    if(item.GST_Amount__c != null && item.GST_Amount__c > 0) {
                        Decimal taxRate = item.Tax__r.Tax_Percentage__c;
                        Decimal currentAmount = taxRateToAmount.get(taxRate);
                        taxRateToAmount.put(taxRate, (currentAmount != null ? currentAmount : 0) + item.GST_Amount__c);
                    }
                }
                for(Decimal taxRate : taxRateToAmount.keySet()) {
                    Decimal taxAmount = taxRateToAmount.get(taxRate);
                    Decimal splitAmount = taxAmount / 2;
                    Journal_Entry__c childEntry = new Journal_Entry__c(
                        Name = inv.Name + ' - Product CGST ' + taxRate + '%',
                        Status__c = 'Draft',
                        Type__c = 'Journal',
                        // Invoice__c = inv.Id,
                        Parent_Journal_Entry__c = parentEntry.Id,
                        Entry_Date__c = Date.Today(),
                        ReferenceAmount__c = splitAmount * inv.Exchange_rate__c,
                        Final_Amount__c = splitAmount * inv.Exchange_rate__c
                    );
                    if (flag == true) {
                        childEntry.Debit_Chart_of_Accounts__c = cgst.Id;
                        childEntry.Debit_Amount__c = splitAmount * inv.Exchange_rate__c;
                        childEntry.Reference_Account__c = parentEntry.Credit_Chart_of_Accounts__c;
                    } else {
                        childEntry.Credit_Chart_of_Accounts__c = cgst.Id;
                        childEntry.Credit_Amount__c = splitAmount * inv.Exchange_rate__c;
                        childEntry.Reference_Account__c = parentEntry.Debit_Chart_of_Accounts__c;
                    }
                    childEntries.add(childEntry);

                    Journal_Entry__c childEntry1 = new Journal_Entry__c(
                        Name = inv.Name + ' - Product SGST ' + taxRate + '%',
                        Status__c = 'Draft',
                        Type__c = 'Journal',
                        // Invoice__c = inv.Id,
                        Parent_Journal_Entry__c = parentEntry.Id,
                        Entry_Date__c = Date.Today(),
                        ReferenceAmount__c = splitAmount * inv.Exchange_rate__c,
                        Final_Amount__c = splitAmount * inv.Exchange_rate__c
                    );
                    if (flag == true) {
                        childEntry1.Debit_Chart_of_Accounts__c = sgst.Id;
                        childEntry1.Debit_Amount__c = splitAmount * inv.Exchange_rate__c;
                        childEntry1.Reference_Account__c = parentEntry.Credit_Chart_of_Accounts__c;
                    } else {
                        childEntry1.Credit_Chart_of_Accounts__c = sgst.Id;
                        childEntry1.Credit_Amount__c = splitAmount * inv.Exchange_rate__c;
                        childEntry1.Reference_Account__c = parentEntry.Debit_Chart_of_Accounts__c;
                    }
                    childEntries.add(childEntry1);
                }
            }
            if(!childEntries.isEmpty()) {
                insert childEntries;
            }
        }
        Decimal COGS_Totalamount=0;
        Set<Id> productIds = new Set<Id>();
        for (Invoice_Item__c item : productItems) {
            if (item.Product1__c != null) {
                productIds.add(item.Product1__c);
            }
        }
        List<Product__c> products = [SELECT Id, Valuation_Method__c, Product_Quantity__c FROM Product__c WHERE Id IN :productIds];
        // Get the valuation method (all products have the same one)
        String valuationMethod = products[0].Valuation_Method__c;

        Id receiptRecordTypeId = Schema.SObjectType.Stock__c.getRecordTypeInfosByDeveloperName().get('Receipt').getRecordTypeId();
        Map<Id, Stock__c> firstStockMap = new Map<Id, Stock__c>();
        Map<Id, Stock__c> lastStockMap = new Map<Id, Stock__c>();

        List<Stock__c> stockRecords = [SELECT Id, Product__c, Final_Price__c, GRN__r.Date__c, Quantity__c, RecordTypeId 
                                        FROM Stock__c 
                                        WHERE Product__c IN :productIds 
                                        AND RecordTypeId = :receiptRecordTypeId 
                                        ORDER BY Product__c ASC, GRN__r.Date__c ASC];

        // Iterate through stock records to determine first and last for each Product__c
        for (Stock__c stock : stockRecords) {
            if (!firstStockMap.containsKey(stock.Product__c)) {
                firstStockMap.put(stock.Product__c, stock); // Store first stock record
            }
            lastStockMap.put(stock.Product__c, stock); // Keep overwriting to store the last stock record
        }

        // Map to store totalAmount for each product
        Map<Id, Decimal> productQuantityAmountMap = new Map<Id, Decimal>();
        // Populate the map with Product1__c as the key and Quantity as the value
        for (Invoice_Item__c item : productItems) {
            if (item.Product1__c != null && item.Quantity__c != null) {
                if (productQuantityAmountMap.containsKey(item.Product1__c)) {
                    // If the product already exists, add to the existing quantity
                    productQuantityAmountMap.put(item.Product1__c, 
                    productQuantityAmountMap.get(item.Product1__c) + item.Quantity__c);
                } else {
                    // Otherwise, add a new entry
                    productQuantityAmountMap.put(item.Product1__c, item.Quantity__c);
                }
            }
        }

        // Calculate totalAmount for each product
        if (valuationMethod == 'FIFO') {
            for (Product__c product : products) {
                if (firstStockMap.containsKey(product.Id) && lastStockMap.containsKey(product.Id)) {
                    Stock__c firstStock = firstStockMap.get(product.Id);
                    Stock__c lastStock = lastStockMap.get(product.Id);
                    Decimal invitemquantity=0;
                    if(productQuantityAmountMap.containsKey(product.Id)){
                         invitemquantity=productQuantityAmountMap.get(product.Id);
                    }
                    Decimal firstStockAmount = firstStock.Quantity__c * firstStock.Final_Price__c;
                    Decimal lastStockAmount = (lastStock.Quantity__c - invitemquantity) * lastStock.Final_Price__c;
                    Decimal Calculation = firstStockAmount + lastStockAmount;
                    COGS_Totalamount+= Calculation;
                }
            }
        }else if(valuationMethod == 'LIFO'){
            for(product__c product : products){
                if(lastStockMap.containsKey(product.Id)){
                    Stock__c lastStock = lastStockMap.get(product.Id);
                    Decimal invitemquantity=0;
                    if(productQuantityAmountMap.containsKey(product.Id)){
                         invitemquantity=productQuantityAmountMap.get(product.Id);
                    }
                    Decimal lastStockAmount = invitemquantity * lastStock.Final_Price__c;                   
                    Decimal Calculation = lastStockAmount;
                    COGS_Totalamount+= Calculation;
                }
            }
        }else if(valuationMethod == 'Weighted Average Cost'){
            for(product__c product : products){
                if (firstStockMap.containsKey(product.Id) && lastStockMap.containsKey(product.Id)) {
                    Stock__c firstStock = firstStockMap.get(product.Id);
                    Stock__c lastStock = lastStockMap.get(product.Id);
                    Decimal invitemquantity=0;
                    if(productQuantityAmountMap.containsKey(product.Id)){
                         invitemquantity=productQuantityAmountMap.get(product.Id);
                    }
                    Decimal firstStockAmount = firstStock.Quantity__c * firstStock.Final_Price__c;
                    Decimal lastStockAmount = lastStock.Quantity__c* lastStock.Final_Price__c;
                    Decimal Calculation = firstStockAmount+lastStockAmount/firstStock.Quantity__c+lastStock.Quantity__c*invitemquantity;
                    COGS_Totalamount+= Calculation;
                }
            }
        }
        // Create COGS entry
        Journal_Entry__c cogsEntry = new Journal_Entry__c(
            Name = inv.Name + ' - COGS',
            Status__c = 'Draft',
            Type__c = 'Journal',
            Invoice__c = inv.Id,
            Debit_Chart_of_Accounts__c = flag ? inventorycoa.Id : cogs.Id,
            Credit_Chart_of_Accounts__c = flag ? cogs.Id : inventorycoa.Id,
            Debit_Amount__c = COGS_Totalamount * inv.Exchange_rate__c,
            Credit_Amount__c = COGS_Totalamount* inv.Exchange_rate__c,
            Final_Amount__c = COGS_Totalamount* inv.Exchange_rate__c,
            Entry_Date__c = Date.Today(),
            Currency__c= inv.Currency__c,
            Exchange_rate__c= inv.Exchange_rate__c
        );
        insert cogsEntry;
    } catch (Exception e) {
        System.debug('Error in createProductEntries: ' + e.getMessage());
    }
}
    @AuraEnabled(Cacheable=true)
    public static Product__c getProductDetails(Id productId) {
        return [SELECT Id, Name, Is_Serial_Number__c FROM Product__c WHERE Id = :productId  WITH SECURITY_ENFORCED LIMIT 1];
    }
    @AuraEnabled(cacheable=true)
    public static List<Stock__c> searchStocks(String searchKey, Id productId) {
        return [
                SELECT Id, Name, Serial_Number__c, Product__c, Invoice_Item__c
                FROM Stock__c
                WHERE Product__c =:productId AND Invoice_Item__c=Null AND Serial_Number__c LIKE :('%' + searchKey + '%') 
                WITH SECURITY_ENFORCED LIMIT 100
            ];
    }
    @AuraEnabled(cacheable=true)
    public static Map<Id, List<Stock__c>> getStockByInvoiceItemIds(List<Id> invoiceItemIds) {
        Map<Id, List<Stock__c>> stockMap = new Map<Id, List<Stock__c>>();
        List<Stock__c> stockList = [
            SELECT Id, Name, Serial_Number__c, Invoice_Item__c
            FROM Stock__c
            WHERE Invoice_Item__c IN :invoiceItemIds  WITH SECURITY_ENFORCED
        ];

        for (Stock__c stock : stockList) {
            if (!stockMap.containsKey(stock.Invoice_Item__c)) {
                stockMap.put(stock.Invoice_Item__c, new List<Stock__c>());
            }
            stockMap.get(stock.Invoice_Item__c).add(stock);
        }

        return stockMap;
}
//<!--KK 23/05/2025 NameSpace handle using wrapper-->
//Wrapper for Namespace
     public class NamespaceWrapper {
        @AuraEnabled 
        public string nameSpace {get;set;}
     }

      @AuraEnabled(cacheable=true)
    public static NamespaceWrapper getNslog(){
        string ns = CommonUtility.getNameSpace();
        NamespaceWrapper nsw = new NamespaceWrapper();
        nsw.nameSpace = (ns == null ) ? 'null' : ns;
        return nsw;
    }

    @AuraEnabled
    public static void updateInvoiceValidation(String invoiceId, Boolean isValidated) {
        try {
            Invoice__c inv = new Invoice__c(
                Id = invoiceId,
                Validate__c = isValidated
            );
            update inv;
        } catch(Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void updateInvoiceClearance(String invoiceId, Boolean isCleared) {
        try {
            Invoice__c inv = new Invoice__c(
                Id = invoiceId,
                Clearance__c = isCleared
            );
            update inv;
        } catch(Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}