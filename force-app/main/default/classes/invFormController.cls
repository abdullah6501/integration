public with sharing class InvoiceFormController {
    public InvoiceFormController() {
        //system.debug('InvoiceFormController const');
    }
    @AuraEnabled
    public static String saveInvoiceRecord(String invWrap, Boolean sendEmailFlag, Boolean checkboxjournalflag){
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
                // if (checkboxjournalflag) {
                //     inv.Create_Journal_Entry__c = true;
                //     upsert inv;
                // }
                try{
                    List<Invoice__c> invList = new List<Invoice__c>();
                    invList.add(inv);
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
                                            GST_Amount__c,Key__c,Product1__r.Name,IsKnownPdt__c,Tax__r.name,Tax__r.Tax_Percentage__c
                                            FROM Invoice_Item__c WHERE Invoice__c =:inv.Id WITH SECURITY_ENFORCED])).keySet();
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
                            //createAttachmentRecord(inv.Id,inv.Name);
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
                            if(checkboxjournalflag!= false && inv.Id != null){
                                //system.debug('Inside the checkboxjournalflag section');
                                createJournalEntryRecord(inv.Id);
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
        Invoice__c inv = [SELECT Id, Name, Invoice_Date__c, Due_Date__c, Amounts_are__c, Currency_Code__c, 
                                Account__c, Account__r.Name, Account__r.Id, Invoice_Type__c, Invoice_Name_Type__c
                                FROM Invoice__c WHERE Id = :invoiceId WITH SECURITY_ENFORCED LIMIT 1];
        System.debug('inv-->' + inv);

        // Invoice Items
        List<Invoice_Item__c> invItemList = [SELECT Id, Name, Product1__r.Name, Quantity__c, Rate__c, 
                                                    Amount_With_GST__c, GST_Amount__c, Tax__r.Tax_Label__c, 
                                                    Tax__r.Tax_Percentage__c
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
        jsonGen.writeStringField('SchemeID', company.GSTIN__c); // Commercial Registration Number
        jsonGen.writeStringField('TaxRegistrationName', company.Name__c);
        jsonGen.writeStringField('TaxNumber', company.GSTIN__c); // GSTIN
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
        jsonGen.writeStringField('TaxNumber', acc.GSTIN__c);
        jsonGen.writeStringField('Country', acc.Preferred_Currency_Code__c);
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
        jsonGen.writeStringField('DeliveryDate', String.valueOf(inv.Due_Date__c));
        jsonGen.writeStringField('InvoiceType', inv.Invoice_Type__c);
        jsonGen.writeStringField('InvoiceName', inv.Invoice_Name_Type__c); // Standard Tax
        jsonGen.writeStringField('Currency', acc.Preferred_Currency_Code__c);
        jsonGen.writeStringField('TaxCurrency', acc.Preferred_Currency_Code__c);
        jsonGen.writeStringField('PaymentMethod', ''); // Cash

        // Invoice Items
        jsonGen.writeFieldName('Items');
        jsonGen.writeStartArray();
        for (Invoice_Item__c invItem : invItemList) {
            jsonGen.writeStartObject();
            jsonGen.writeStringField('ProductName', invItem.Product1__r.Name);
            jsonGen.writeNumberField('Price', invItem.Rate__c);
            jsonGen.writeNumberField('Quantity', invItem.Quantity__c);
            jsonGen.writeNumberField('AfterDiscountPrice', invItem.Amount_With_GST__c);
            jsonGen.writeStringField('TaxID', invItem.Tax__r.Tax_Label__c);
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
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://zatca-api.rangerfusion.com/generateInvoiceXml');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(invoiceData);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                String responseStr = res.getBody();
                try {
                    Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseStr);
                    if (responseMap.containsKey('ApiRequest')) {
                        String apiRequestJson = JSON.serialize(responseMap.get('ApiRequest')); 
                        saveInvoiceResponse(invoiceId, apiRequestJson);
                    }  
                    return responseStr;
                } catch (Exception e) {
                    throw new AuraHandledException('Error parsing API response: ' + e.getMessage());
                }
            } else if (res.getStatusCode() == 400) {
                throw new AuraHandledException('Validation failed: ' + res.getBody());
            } else if (res.getStatusCode() == 500) {
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
            req.setHeader('Accept-Version', 'V2');
            req.setHeader('Clearance-Status', '1');
            req.setHeader('Authorization', encodedAuth);
            req.setBody(apiRequestJson);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                String responseStr = res.getBody();
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseStr);
                if (responseMap.containsKey('QrCode-Base64Encoded')) {
                    String qrCode = (String) responseMap.get('QrCode-Base64Encoded');
                    String qr = generateQRCodeFromBase64(qrCode, invoiceId);
                    return qr;
                }
            } else {
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

    @AuraEnabled
    public static String getInvoiceFormData(String invId){
        JSONGenerator jsonGen = JSON.createGenerator(true);
        jsonGen.writeStartObject();
        try{
            Invoice__c inv = [SELECT Id,Name,Email_Bcc__c ,Email_CC__c,Contact__C,Contact__r.email,Sum_Of_GST_Amount__c,Account__c,Billing_Address__c,
                                Term__c,Invoice_Date__c,Due_Date__c,Amounts_are__c,Message_Of_Invoice__c,Message_On_Statement__c,
                                Invoice_status__c,PlaceOfSupply__c,Authorized_Sign__c,To_Email_Addresses__c,Account__r.Name,Contact__r.Name,Sum_of_Paid_Amount__c,
                                Currency_Code__c,Company_Name__c,Terms_And_Condition__c,Amount_In_Words__c, Invoice_Type__c, Invoice_Name_Type__c
                                FROM Invoice__c WHERE id =:invId WITH SECURITY_ENFORCED LIMIT 1 ];
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
            invWrapObj.invoiceNameType = inv.Invoice_Name_Type__c;
            invWrapObj.parentTaxSelectedOption = inv.Amounts_are__c;
            invWrapObj.msgOnInv = inv.Message_Of_Invoice__c;
            invWrapObj.termsAndCond = inv.Terms_And_Condition__c;
            invWrapObj.amtInWords = inv.Amount_In_Words__c;
            invWrapObj.msgOnStmt = inv.Message_On_Statement__c;
            invWrapObj.paidAmount = inv.Sum_of_Paid_Amount__c;
            invWrapObj.companyName = inv.Company_Name__c;
            invWrapObj.currencyCode = inv.Currency_Code__c;
            //invWrapObj.subTotal;
            //invWrapObj.total;
            //invWrapObj.balanceDue;
            //invWrapObj.totalTaxAmt;
            List<InvoiceItemWrapper> iiwList = new List<InvoiceItemWrapper>();
            for(Invoice_Item__c invItem : [SELECT Id,Name,Invoice__c,Service_Date__c ,Product1__c,HsnSac__c,Description__c,
                                            Quantity__c,Rate__c,Amount__c,Tax__c,Amount_With_GST__c,GST_Amount__c,Key__c,
                                            Product1__r.Name,IsKnownPdt__c,Tax__r.name,Tax__r.Tax_Percentage__c,
                                            Tax__r.Tax_Label__c
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
                iiw.qty =  invItem.Quantity__c;
                iiw.rate =  invItem.Rate__c;
                iiw.amt =  invItem.Amount__c;
                iiw.taxId =  invItem.Tax__c;  //iiw.taxLabel, iiw.tax ==> Not used
                iiw.taxLabel = invItem.Tax__c != null ? invItem.Tax__r.name : null;
                iiw.tax = invItem.Tax__r.Tax_Label__c;
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
    public static List<Map<String, String>> getInvoiceType() {
        List<Map<String, String>> invoiceTypeList = new List<Map<String, String>>();
        
        Schema.DescribeFieldResult fieldResult = Invoice__c.Invoice_Type__c.getDescribe();
        List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();

        for (Schema.PicklistEntry entry : picklistValues) {
            Map<String, String> invoiceTypeMap = new Map<String, String>();
            invoiceTypeMap.put('label', entry.getLabel());
            invoiceTypeMap.put('value', entry.getValue());
            invoiceTypeList.add(invoiceTypeMap);
        }
        return invoiceTypeList;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getInvoiceNameType() {
        List<Map<String, String>> invoiceNameTypeList = new List<Map<String, String>>();
        
        Schema.DescribeFieldResult fieldResult = Invoice__c.Invoice_Name_Type__c.getDescribe();
        List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();

        for (Schema.PicklistEntry entry : picklistValues) {
            Map<String, String> invoiceNameTypeMap = new Map<String, String>();
            invoiceNameTypeMap.put('label', entry.getLabel());
            invoiceNameTypeMap.put('value', entry.getValue());
            invoiceNameTypeList.add(invoiceNameTypeMap);
        }
        return invoiceNameTypeList;
    }

    @AuraEnabled(Cacheable=true)
    //RP - 02May2023 - removed param "accName" - Commanded since we will be having only one row in this table here after
    public static List<Company_Settings__mdt> getAccBankInfo(){ 
        ActiveCompanyName__c companyName =[SELECT Company_Name__c, Active__c FROM ActiveCompanyName__c 
                                            where Active__c =true WITH SECURITY_ENFORCED Limit 1];
        List<Company_Settings__mdt> companySettingList = new List<Company_Settings__mdt>();
        companySettingList = [SELECT Id,Name__c,Address1__c, Address2__c,City__c, State__c,Pincode__c, Phone_Number__c, 
        Company_Email__c, Account_Number__c, Account_Type__c, IFSC_Code__c, Branch__c,Terms_And_Condition__c FROM Company_Settings__mdt 
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
                createJournalEntryRecord(inv.Id);
            }
        }
    }
    @AuraEnabled
    public static void createJournalEntryRecord(Id invId) {
        try {
            // Get invoice and related data
            Invoice__c inv = [SELECT Id, Name, Account__c, Account__r.Name, Total_Amount__c, 
                             Sum_Of_GST_Amount__c, Amounts_are__c 
                             FROM Invoice__c WHERE Id = :invId LIMIT 1];
            // Get chart of accounts
            Chart_of_Accounts__c coac = [SELECT Id FROM Chart_of_Accounts__c WHERE Name = 'Sales Revenue' LIMIT 1];
            Chart_of_Accounts__c cacd = new Chart_of_Accounts__c();
            Chart_of_Accounts__c cogs = [SELECT Id FROM Chart_of_Accounts__c WHERE Name = 'Cost of Goods' LIMIT 1];
            Chart_of_Accounts__c cgst = [SELECT Id FROM Chart_of_Accounts__c WHERE Name = 'CGST' LIMIT 1];
            Chart_of_Accounts__c sgst = [SELECT Id FROM Chart_of_Accounts__c WHERE Name = 'SGST' LIMIT 1];
            Chart_of_Accounts__c inventorycoa = [SELECT Id FROM Chart_of_Accounts__c WHERE Name = 'Inventory' LIMIT 1];
            try {
                cacd = [SELECT Id FROM Chart_of_Accounts__c WHERE Account__c = :inv.Account__c LIMIT 1];
                ////system.debug('cacd-->' + (cacd != null ? cacd.Id : 'null'));
            } catch(QueryException qe) {
                cacd = null;
                ////system.debug('No Chart of Accounts found for Account');
            }
            // ////system.debug('coac-->' + coac);
            // ////system.debug('inv-->' + inv);
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
                ////system.debug('inside if');
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
            List<Invoice_Item__c> invoiceItems = [SELECT Id, Name, Amount__c, GST_Amount__c, 
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
                                   cacd, coac, cgst, sgst);
            }
            // Handle product items if they exist
            if(!productItems.isEmpty()) {
                createProductEntries(inv, productItems, productTotalAmount, productTotalTaxAmount,
                                   cacd, coac, cgst, sgst, cogs, inventorycoa);
            }
        } catch(Exception e) {
            throw new AuraHandledException('Error creating journal entries: ' + e.getMessage());
        }
    }
 private static void createServiceEntries(Invoice__c inv, List<Invoice_Item__c> serviceItems, 
                                           Decimal totalAmount, Decimal totalTaxAmount,
                                           Chart_of_Accounts__c cacd, Chart_of_Accounts__c coac, 
                                           Chart_of_Accounts__c cgst, Chart_of_Accounts__c sgst) {
        Boolean hasTax = totalTaxAmount > 0;
        Boolean hasMultipleItems = serviceItems.size() > 1;
        Boolean needsChildRecords = hasMultipleItems || hasTax;
        // Create parent service entry
        Journal_Entry__c parentEntry = new Journal_Entry__c(
            Name = inv.Name + ' - Services',
            Status__c = 'Draft',
            Type__c = 'Journal',
            Invoice__c = inv.Id,
            Debit_Chart_of_Accounts__c = cacd.Id,
            Credit_Chart_of_Accounts__c = coac.Id,
            Entry_Date__c = Date.Today(),
            Has_Credit_Child__c = needsChildRecords
        );
        // Set debit and credit amounts to be equal
        if(inv.Amounts_are__c == 'Inclusive of Tax') {
            parentEntry.Debit_Amount__c = totalAmount;
            parentEntry.Credit_Amount__c = totalAmount;
        } else if(inv.Amounts_are__c == 'Exclusive of Tax') {
            parentEntry.Debit_Amount__c = totalAmount + totalTaxAmount;
            parentEntry.Credit_Amount__c = totalAmount + totalTaxAmount;
        } else {
            parentEntry.Debit_Amount__c = totalAmount;
            parentEntry.Credit_Amount__c = totalAmount;
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
                childEntries.add(new Journal_Entry__c(
                    Name = inv.Name + ' - Service: ' + item.Product1__r.Name,
                    Status__c = 'Draft',
                    Type__c = 'Journal',
                    Invoice__c = inv.Id,
                    Credit_Description__c = item.Product1__r.Name,
                    Credit_Chart_of_Accounts__c = coac.Id,
                    Credit_Amount__c = itemCredit,
                    Parent_Journal_Entry__c = parentEntry.Id,
                    Entry_Date__c = Date.Today()
                ));
            }
            // Create tax entries if applicable
            if(hasTax) {
                Decimal cgstAmount = totalTaxAmount / 2;
                childEntries.add(new Journal_Entry__c(
                    Name = inv.Name + ' - Service CGST',
                    Status__c = 'Draft',
                    Type__c = 'Journal',
                    Invoice__c = inv.Id,
                    Credit_Chart_of_Accounts__c = cgst.Id,
                    Credit_Amount__c = cgstAmount,
                    Parent_Journal_Entry__c = parentEntry.Id,
                    Entry_Date__c = Date.Today()
                ));
                childEntries.add(new Journal_Entry__c(
                    Name = inv.Name + ' - Service SGST',
                    Status__c = 'Draft',
                    Type__c = 'Journal',
                    Invoice__c = inv.Id,
                    Credit_Chart_of_Accounts__c = sgst.Id,
                    Credit_Amount__c = cgstAmount,
                    Parent_Journal_Entry__c = parentEntry.Id,
                    Entry_Date__c = Date.Today()
                ));
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
                                           Chart_of_Accounts__c cogs, Chart_of_Accounts__c inventorycoa) {
        Boolean hasTax = totalTaxAmount > 0;
        Boolean hasMultipleItems = productItems.size() > 1;
        // Create parent product entry
        Journal_Entry__c parentEntry = new Journal_Entry__c(
            Name = inv.Name + ' - Products',
            Status__c = 'Draft',
            Type__c = 'Journal',
            Invoice__c = inv.Id,
            Debit_Chart_of_Accounts__c = cacd.Id,
            Credit_Chart_of_Accounts__c = coac.Id,
            Entry_Date__c = Date.Today(),
            Has_Credit_Child__c = (hasMultipleItems || hasTax)
        );
        // Update parent entry debit/credit amounts to be equal
        if(inv.Amounts_are__c == 'Inclusive of Tax') {
            parentEntry.Debit_Amount__c = totalAmount;
            parentEntry.Credit_Amount__c = totalAmount;
        } else if(inv.Amounts_are__c == 'Exclusive of Tax') {
            parentEntry.Debit_Amount__c = totalAmount + totalTaxAmount;
            parentEntry.Credit_Amount__c = totalAmount + totalTaxAmount;
        } else {
            parentEntry.Debit_Amount__c = totalAmount;
            parentEntry.Credit_Amount__c = totalAmount;
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
                    childEntries.add(new Journal_Entry__c(
                        Name = inv.Name + ' - Product: ' + item.Product1__r.Name,
                        Status__c = 'Draft',
                        Type__c = 'Journal',
                        Invoice__c = inv.Id,
                        Credit_Chart_of_Accounts__c = coac.Id,
                        Credit_Amount__c = itemCredit,
                        Parent_Journal_Entry__c = parentEntry.Id,
                        Entry_Date__c = Date.Today()
                    ));
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
                    childEntries.add(new Journal_Entry__c(
                        Name = inv.Name + ' - Product CGST ' + taxRate + '%',
                        Status__c = 'Draft',
                        Type__c = 'Journal',
                        Invoice__c = inv.Id,
                        Credit_Chart_of_Accounts__c = cgst.Id,
                        Credit_Amount__c = splitAmount,
                        Parent_Journal_Entry__c = parentEntry.Id,
                        Entry_Date__c = Date.Today()
                    ));
                    childEntries.add(new Journal_Entry__c(
                        Name = inv.Name + ' - Product SGST ' + taxRate + '%',
                        Status__c = 'Draft',
                        Type__c = 'Journal',
                        Invoice__c = inv.Id,
                        Credit_Chart_of_Accounts__c = sgst.Id,
                        Credit_Amount__c = splitAmount,
                        Parent_Journal_Entry__c = parentEntry.Id,
                        Entry_Date__c = Date.Today()
                    ));
                }
            }
            if(!childEntries.isEmpty()) {
                insert childEntries;
            }
        }
        // Create COGS entry
        Journal_Entry__c cogsEntry = new Journal_Entry__c(
            Name = inv.Name + ' - COGS',
            Status__c = 'Draft',
            Type__c = 'Journal',
            Invoice__c = inv.Id,
            Debit_Chart_of_Accounts__c = cogs.Id,
            Credit_Chart_of_Accounts__c = inventorycoa.Id,
            Debit_Amount__c = totalAmount,
            Credit_Amount__c = totalAmount,
            Entry_Date__c = Date.Today()
        );
        insert cogsEntry;
    }
}
 





















public with sharing class InvoiceFormHelper {
    public InvoiceFormHelper() {
        System.debug('Inside the InvoiceFormHelper constr');
    }
    @AuraEnabled
    public static Invoice__c convertWrapperToInv(InvoiceFormWrapper invWrapObj){
        Invoice__c inv = new Invoice__c();
        if(invWrapObj.invId != null && invWrapObj.invId != ''){
            inv = new Invoice__c(Id=invWrapObj.invId);
        }else{
            inv.Invoice_status__c = invWrapObj.invStatus; //Always passing Draft as value incase of creation
        }
        //inv.Name = invWrapObj.name; //Need to know the naming convention
        inv.Account__c = invWrapObj.accId;
        inv.Contact__c = invWrapObj.conId;
        inv.To_Email_Addresses__c = invWrapObj.primaryConEmailAddresses; //NewlyCreated - Need to create a field for this
        inv.Email_CC__c = invWrapObj.ccEmailAddresses;
        inv.Email_Bcc__c = invWrapObj.bccEmailAddresses;
        inv.Billing_Address__c = invWrapObj.billingAddress;
        inv.Term__c = invWrapObj.termLabel; //term ==> Not use
        inv.Invoice_Date__c = invWrapObj.invoiceDate;
        inv.Due_Date__c = invWrapObj.dueDate;
        inv.PlaceOfSupply__c = invWrapObj.placeOfSupply; //NewlyCreated - Need to create a field for this
        inv.Authorized_Sign__c= invWrapObj.authSign;
        inv.Invoice_Type__c=invWrapObj.invoiceType;
        inv.Invoice_Name_Type__c=invWrapObj.invoiceNameType;
        inv.Amounts_are__c = invWrapObj.parentTaxSelectedOption;
        inv.Message_Of_Invoice__c = invWrapObj.msgOnInv;
        inv.Terms_And_Condition__c = invWrapObj.termsAndCond;
        Decimal strToDec = invWrapObj.total != null ? decimal.valueOf(invWrapObj.total) : 0.0;
        inv.Amount_In_Words__c =  (invWrapObj.currencyCode != null ? invWrapObj.currencyCode + ' ' : '') +
                                  (invWrapObj.currencyCodeName != null ?  invWrapObj.currencyCodeName + ' ' : '') + 
                                    InvoiceFormController.getCurrencyInWords(strToDec) + ' Only';
        inv.Message_On_Statement__c = invWrapObj.msgOnStmt;
        inv.Company_Name__c = invWrapObj.companyName;
        return inv;
    }
    public class ConvertWrapperToInvItemResultant{
        public List<Invoice_Item__c> invList = new List<Invoice_Item__c>();
        public Set<Id> newInvItemIds = new Set<Id>();
        public ConvertWrapperToInvItemResultant(){
            invList = new List<Invoice_Item__c>();
            newInvItemIds = new Set<Id>();
        }
    }
    @AuraEnabled
    public static ConvertWrapperToInvItemResultant convertWrapperToInvItem(InvoiceFormWrapper invWrapObj, String invId){
        ConvertWrapperToInvItemResultant cwt = new ConvertWrapperToInvItemResultant();
        Integer tempKeyValue = 1;
        Map<String,String> invItemPdtMap = new Map<String,String>();
        Set<Id> pdtSuccessIds = new Set<Id>();
        List<Product__c> newPdtInsList = new List<Product__c>();
        for(InvoiceItemWrapper iiw : invWrapObj.invoiceItemList){
            if(iiw.pdtDraftName != null && !iiw.isKnownPdt && iiw.pdtId == '_new_'){ //pdtMap.get(iiw.pdtId) != null 
                Product__c pdtObj = new Product__c(Name = iiw.pdtDraftName);
                pdtObj.ProductCode__c = tempKeyValue+'&&&'+iiw.pdtDraftName+'&&&'+invId;
                newPdtInsList.add(pdtObj);
            }
            tempKeyValue++;
        }
        if(newPdtInsList.size() > 0 && Product__c.SObjectType.getDescribe().isCreateable() &&
            Schema.sObjectType.Product__c.fields.Name.isCreateable() &&
            Schema.sObjectType.Product__c.fields.ProductCode__c.isCreateable()){
                Database.SaveResult[] srList = Database.insert(newPdtInsList, false);
                for (Database.SaveResult sr : srList) {
                    if (sr.isSuccess()) {
                        pdtSuccessIds.add(sr.getId());
                    }
                }
        }
        if(pdtSuccessIds.size() > 0 ){
            for(Product__c pd : [SELECT Id,Name,ProductCode__c FROM Product__c WHERE Id IN: pdtSuccessIds WITH SECURITY_ENFORCED]){
                invItemPdtMap.put(pd.ProductCode__c,pd.Id);
            }
        }
        Map<String,String> invItemKeyPdtMap = new Map<String,String>();
        Integer keyValue = 1;
        for(InvoiceItemWrapper iiw : invWrapObj.invoiceItemList){
            Invoice_Item__c invItem = new Invoice_Item__c();
            if(iiw.invItemId != null && iiw.invItemId != ''){
                invItem = new Invoice_Item__c(Id=iiw.invItemId);
                cwt.newInvItemIds.add(iiw.invItemId);
            }else{
                invItem.Invoice__c = invId;
            }
            invItem.Key__c = String.ValueOf(keyValue);//invItem.Key__c = iiw.key; //NewlyCreated - Need to create a field for this
            invItem.Service_Date__c = iiw.serviceDate;
            invItem.IsKnownPdt__c = iiw.isKnownPdt; //NewlyCreated - Need to create a field for this
            if(iiw.pdtDraftName != null && !iiw.isKnownPdt && iiw.pdtId == '_new_'){ //pdtMap.get(iiw.pdtId) != null 
                String tempPdtCode = keyValue+'&&&'+iiw.pdtDraftName+'&&&'+invId;
                if(invItemPdtMap.get(tempPdtCode) != null) {
                    invItem.Product1__c = invItemPdtMap.get(tempPdtCode);
                }
            }else{
                invItem.Product1__c = iiw.pdtId;
            }
            invItem.HsnSac__c = iiw.hsn;
            if(iiw.description != null && iiw.description.length() > 500){
                iiw.description = iiw.description.SubString(0,499);
            }
            invItem.Description__c = iiw.description;
            invItem.Quantity__c = iiw.qty;
            invItem.Rate__c = iiw.rate;
            invItem.Amount__c = iiw.amt;
            if(invWrapObj.parentTaxSelectedOption != 'Out of scope of Tax'){                           
                invItem.Tax__c = iiw.taxId; //taxLabel, tax ==> Not used
                invItem.Amount_With_GST__c = iiw.amtWithTax;
                invItem.GST_Amount__c = iiw.taxAmt;
            }else{                         
                invItem.Tax__c = null; //taxLabel, tax ==> Not used
                invItem.Amount_With_GST__c = iiw.amt;
                invItem.GST_Amount__c = 0;
            }
            //Not Used field:==> Name
            cwt.invList.add(invItem);
            keyValue++;
        }
        return cwt;
    }
 @AuraEnabled
    public static Boolean invItemPermissionCheck(){
        if (Invoice_Item__c.SObjectType.getDescribe().isCreateable() &&
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
            return true;
        }else{
            return false;
        }
    }
    @AuraEnabled
    public static Invoice__c invUpsertPermissionCheck(List<Invoice__c> invList){
        // Save the updated record
        //update invoiceRecord;
        if (Invoice__c.SObjectType.getDescribe().isCreateable() &&
            Schema.sObjectType.Invoice__c.fields.Invoice_status__c.isCreateable() &&
            Schema.sObjectType.Invoice__c.fields.Account__c.isCreateable() &&
            Schema.sObjectType.Invoice__c.fields.Contact__c.isCreateable() &&
            Schema.sObjectType.Invoice__c.fields.To_Email_Addresses__c.isCreateable() &&
            Schema.sObjectType.Invoice__c.fields.Email_CC__c.isCreateable() &&
            Schema.sObjectType.Invoice__c.fields.Email_Bcc__c.isCreateable() &&
            Schema.sObjectType.Invoice__c.fields.Billing_Address__c.isCreateable() &&
            Schema.sObjectType.Invoice__c.fields.Term__c.isCreateable() &&
            Schema.sObjectType.Invoice__c.fields.Invoice_Date__c.isCreateable() &&
            Schema.sObjectType.Invoice__c.fields.Due_Date__c.isCreateable() &&
            Schema.sObjectType.Invoice__c.fields.PlaceOfSupply__c.isCreateable() &&
            Schema.sObjectType.Invoice__c.fields.Authorized_Sign__c.isCreateable() &&
            Schema.sObjectType.Invoice__c.fields.Amounts_are__c.isCreateable() &&
            Schema.sObjectType.Invoice__c.fields.Message_Of_Invoice__c.isCreateable() &&
            Schema.sObjectType.Invoice__c.fields.Message_On_Statement__c.isCreateable() &&
            Schema.sObjectType.Invoice__c.fields.Terms_And_Condition__c.isCreateable() &&
            Schema.sObjectType.Invoice__c.fields.Amount_In_Words__c.isCreateable() &&
            Schema.sObjectType.Invoice__c.fields.Company_Name__c.isCreateable() &&
            Invoice__c.SObjectType.getDescribe().isUpdateable() &&
            Schema.sObjectType.Invoice__c.fields.Invoice_status__c.isUpdateable() &&
            Schema.sObjectType.Invoice__c.fields.Account__c.isUpdateable() &&
            Schema.sObjectType.Invoice__c.fields.Contact__c.isUpdateable() &&
            Schema.sObjectType.Invoice__c.fields.To_Email_Addresses__c.isUpdateable() &&
            Schema.sObjectType.Invoice__c.fields.Email_CC__c.isUpdateable() &&
            Schema.sObjectType.Invoice__c.fields.Email_Bcc__c.isUpdateable() &&
            Schema.sObjectType.Invoice__c.fields.Billing_Address__c.isUpdateable() &&
            Schema.sObjectType.Invoice__c.fields.Term__c.isUpdateable() &&
            Schema.sObjectType.Invoice__c.fields.Invoice_Date__c.isUpdateable() &&
            Schema.sObjectType.Invoice__c.fields.Due_Date__c.isUpdateable() &&
            Schema.sObjectType.Invoice__c.fields.PlaceOfSupply__c.isUpdateable() && 
            Schema.sObjectType.Invoice__c.fields.Authorized_Sign__c.isUpdateable() &&
            Schema.sObjectType.Invoice__c.fields.Amounts_are__c.isUpdateable() &&
            Schema.sObjectType.Invoice__c.fields.Message_Of_Invoice__c.isUpdateable() &&
            Schema.sObjectType.Invoice__c.fields.Message_On_Statement__c.isUpdateable() &&
            Schema.sObjectType.Invoice__c.fields.Terms_And_Condition__c.isUpdateable() &&
            Schema.sObjectType.Invoice__c.fields.Amount_In_Words__c.isUpdateable() &&
            Schema.sObjectType.Invoice__c.fields.Company_Name__c.isUpdateable()
        ) {
            upsert invList[0];
            return invList[0];
        }else{
            return null;
        }
    }
}
 

























public with sharing class InvoiceFormWrapper {
    
    @AuraEnabled public String name;
    @AuraEnabled public String invId;
    @AuraEnabled public String accId;
    @AuraEnabled public String conId;
    @AuraEnabled public String primaryConEmailAddresses;
    @AuraEnabled public String ccEmailAddresses;
    @AuraEnabled public String bccEmailAddresses;
    @AuraEnabled public String billingAddress;
    @AuraEnabled public String term;
    @AuraEnabled public String termLabel;
    @AuraEnabled public Date invoiceDate;
    @AuraEnabled public Date dueDate;
    @AuraEnabled public String placeOfSupply;
    @AuraEnabled public String authSign;
    @AuraEnabled public String invoiceType;
    @AuraEnabled public String invoiceNameType;
    // @AuraEnabled public Boolean createJournalEntry;
    @AuraEnabled public String parentTaxSelectedOption;
    @AuraEnabled public List<InvoiceItemWrapper> invoiceItemList;
    @AuraEnabled public String msgOnInv;
    @AuraEnabled public String termsAndCond;
    @AuraEnabled public String amtInWords;
    @AuraEnabled public String msgOnStmt;
    @AuraEnabled public String subTotal;
    @AuraEnabled public String total;
    @AuraEnabled public String balanceDue;
    @AuraEnabled public String totalTaxAmt;
    @AuraEnabled public String companyName;
    @AuraEnabled public String currencyCode;
    @AuraEnabled public String currencyCodeName;
    @AuraEnabled public String invStatus;
    @AuraEnabled public Decimal paidAmount;
}


























public with sharing class InvoiceItemWrapper {
    @AuraEnabled public String invItemId;
    @AuraEnabled public String key;
    @AuraEnabled public Date serviceDate;
    @AuraEnabled public String pdtId;
    @AuraEnabled public Boolean isKnownPdt;
    @AuraEnabled public String pdtDraftName;
    @AuraEnabled public String hsn;
    @AuraEnabled public String description;
    @AuraEnabled public Decimal qty;
    @AuraEnabled public Decimal rate;
    @AuraEnabled public Decimal amt;
    @AuraEnabled public String tax;
    @AuraEnabled public String taxId;
    @AuraEnabled public String taxLabel;
    @AuraEnabled public Decimal taxAmt;
    @AuraEnabled public Decimal amtWithTax;
    @AuraEnabled public Decimal paidAmount;
}