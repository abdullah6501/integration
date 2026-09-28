public with sharing class ZatcaJsonController {
    @AuraEnabled
    public static String validateInvoiceRecord(String invoiceId) {
        System.debug('invoiceId-->' + invoiceId);
        // Invoice
        Invoice__c inv = [SELECT Id, Name, Invoice_Date__c, Due_Date__c, Amounts_are__c, Currency_Code__c, Invoice_Indicator__c,
                                Account__c, Invoice_Type__c, Invoice_Name_Type__c, Additional_Fee_Reason__c, Discount_Reason__c,
                                Currency__c, Lumpsum_Discount_Amount__c, Lumpsum_Discount_Percentage__c, Payment_Type__c, Discount_Reason_Amount__c,
                                Discount_Reason_Percentage__c, Discount_Type__c, Latest_Delivery_Date__c, CreatedDate, Additional_Fee_Amount__c FROM Invoice__c WHERE Id = :invoiceId WITH SECURITY_ENFORCED LIMIT 1];
        System.debug('inv-->' + inv);

        // Invoice Items
        List<Invoice_Item__c> invItemList = [SELECT Id, Name, Product1__r.Name, Quantity__c, Rate__c, Tax_ID__c, Tax_Exemption_Reason__c, Tax_Amount__c,
                                                    Amount_With_GST__c, GST_Amount__c, Tax__r.Tax_Label__c, 
                                                    Tax__r.Tax_Percentage__c, Discount_Amount__c, Discount_Percentage__c, Discount_Reason__c,
                                                    Discount_Type__c, Discount_Reason_Amount__c, Discount_Reason_Percentage__c
                                            FROM Invoice_Item__c 
                                            WHERE Invoice__c = :invoiceId WITH SECURITY_ENFORCED];
        System.debug('invItemList-->' + invItemList);

        // Seller Details
        List<Company_Settings__mdt> companySettingList = new List<Company_Settings__mdt>();
        if (Schema.sObjectType.Company_Settings__mdt.isAccessible()) {
            companySettingList = [SELECT Name__c, Company_Email__c, Phone_Number__c, GSTIN__c, Address1__c, Address2__c, Pincode__c, City__c, State__c FROM Company_Settings__mdt LIMIT 1];
        }
        Company_Settings__mdt company = companySettingList.isEmpty() ? null : companySettingList[0];
        System.debug('company-->' + company);

        // Customer Details
        Account acc = [SELECT Id, Name, Email__c, Phone, Preferred_Currency_Code__c, GSTIN__c, BillingStreet, BillingCity, BillingState, BillingPostalCode FROM Account WHERE Id = :inv.Account__c WITH SECURITY_ENFORCED LIMIT 1];
        System.debug('acc-->' + acc);

        JSONGenerator jsonGen = JSON.createGenerator(true);
        jsonGen.writeStartObject(); //JSON

        // Seller Information
        jsonGen.writeFieldName('SellerInformation');
        jsonGen.writeStartObject();
        jsonGen.writeStringField('SellerVatNumber', company.GSTIN__c); 
        jsonGen.writeStringField('SellerIdNumber', company.GSTIN__c);
        jsonGen.writeStringField('SellerId', 'Commercial Registration Number'); 
        jsonGen.writeStringField('SellerRegisteredName', company.Name__c);
        jsonGen.writeStringField('EmailId', company.Company_Email__c);
        jsonGen.writeStringField('ContactNo', company.Phone_Number__c);
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
        jsonGen.writeFieldName('BuyerInformation');
        jsonGen.writeStartObject();
        jsonGen.writeStringField('BuyerVatNumber', acc.GSTIN__c);
        jsonGen.writeStringField('BuyerRegisteredName', acc.Name);
        jsonGen.writeStringField('BuyerId', 'National ID');
        jsonGen.writeStringField('BuyerIdNumber', '73654534');
        jsonGen.writeStringField('EmailId', acc.Email__c);
        jsonGen.writeStringField('ContactNo', acc.Phone);
        jsonGen.writeStringField('Country', acc.Preferred_Currency_Code__c?.split(' ')[0]);

        jsonGen.writeStringField('SubDivision', acc.BillingState); // State
        jsonGen.writeStringField('City', acc.BillingCity); // Riyadh Region
        
        jsonGen.writeFieldName('Address');
        jsonGen.writeStartObject();
        jsonGen.writeStringField('BuildingNumber', '23');
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
        
        String indicator = inv.Invoice_Indicator__c != null ? inv.Invoice_Indicator__c.toLowerCase() : '';

        jsonGen.writeBooleanField('ThirdParty', indicator == 'third party');
        jsonGen.writeBooleanField('Nominal', indicator == 'nominal');
        jsonGen.writeBooleanField('Export', indicator == 'export');
        jsonGen.writeBooleanField('Summary', indicator == 'summary');
        jsonGen.writeBooleanField('SelfBilled', indicator == 'self billed');
 
        // if((inv.Invoice_Type__c == 'Simplified') && (inv.Invoice_Indicator__c == 'summary')) {
        //     jsonGen.writeStringField('LatestDeliveryDate', inv.Latest_Delivery_Date__c != null ? String.valueOf(inv.Latest_Delivery_Date__c) : '');
        // }

        jsonGen.writeStringField('Currency', inv.Currency_Code__c?.split(' ')[0]); // SAR
        jsonGen.writeStringField('TaxCurrency', 'SAR'); 
        jsonGen.writeStringField('PaymentMethod', inv.Payment_Type__c); // Cash

        if (inv.Discount_Reason__c != null && inv.Discount_Reason__c != '') {
            jsonGen.writeStringField('InvoiceDiscountReason', inv.Discount_Reason__c); 
            // jsonGen.writeStringField('InvoiceDiscountReason', 'Discount'); 
            if (inv.Discount_Type__c == 'Amount') {
                jsonGen.writeNumberField('InvoiceDiscountAmount', Integer.valueOf(inv.Discount_Reason_Amount__c));
            } else if (inv.Discount_Type__c == 'Percentage') {
                jsonGen.writeNumberField('InvoiceDiscountAmount', Integer.valueOf(inv.Discount_Reason_Percentage__c));
            }
        }

        if (inv.Discount_Reason__c != null && inv.Discount_Reason__c != '') {
            jsonGen.writeStringField('InvoiceAdditionalFeeReason', inv.Additional_Fee_Reason__c);
            jsonGen.writeNumberField('InvoiceAdditionalFeeAmount', Integer.valueOf(inv.Additional_Fee_Amount__c));
        }

        // Invoice Items
        jsonGen.writeFieldName('Items');
        jsonGen.writeStartArray();
        for (Invoice_Item__c invItem : invItemList) {
            jsonGen.writeStartObject();
            jsonGen.writeStringField('ProductName', invItem.Product1__r.Name);
            jsonGen.writeNumberField('Price', Integer.valueOf(invItem.Rate__c));
            jsonGen.writeNumberField('Quantity', invItem.Quantity__c);
            // jsonGen.writeNumberField('BaseQuantity', '');
            if (invItem.Discount_Reason__c != null && invItem.Discount_Reason__c != '') {
                jsonGen.writeStringField('ItemDiscountReason', invItem.Discount_Reason__c); // Discount Reason
                if (invItem.Discount_Type__c == 'Amount') {
                    jsonGen.writeNumberField('ItemDiscountAmount', Integer.valueOf(invItem.Discount_Reason_Amount__c));
                } else if (invItem.Discount_Type__c == 'Percentage') {
                    jsonGen.writeNumberField('ItemDiscountPercent', Integer.valueOf(invItem.Discount_Reason_Percentage__c));
                }
            }
            // jsonGen.writeStringField('ItemAdditionalFeeType', 'Cleaning');
            // jsonGen.writeStringField('ItemAdditionalFeeAmount', '1');
            // jsonGen.writeStringField('TaxID', invItem.Tax__r.Tax_Label__c);
            jsonGen.writeStringField('TaxID', invItem.Tax_ID__c);
            // jsonGen.writeStringField('TaxExemptionReason', invItem.Tax_Exemption_Reason__c);
            if (invItem.Tax_ID__c != null) {
                String taxIdLower = invItem.Tax_ID__c.toLowerCase();
                if (taxIdLower == 'zero rate' || taxIdLower == 'exempted from tax') {
                    jsonGen.writeStringField('TaxExemptionReason', invItem.Tax_Exemption_Reason__c);
                } // need to write else
            }
            jsonGen.writeNumberField('TaxPercentage', invItem.Tax_Amount__c);
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
        String apiRequestJson = dataList[0].JSON__c;

        List<Company_Settings__mdt> companySettingList = new List<Company_Settings__mdt>();
        if (Schema.sObjectType.Company_Settings__mdt.isAccessible()) {
            companySettingList = [SELECT GSTIN__c, MasterLabel FROM Company_Settings__mdt LIMIT 1];
        }
        Company_Settings__mdt company = companySettingList.isEmpty() ? null : companySettingList[0];

        Invoice__c inv = [SELECT Name, Invoice_Date__c, CreatedDate FROM Invoice__c WHERE Id = :invoiceId WITH SECURITY_ENFORCED LIMIT 1];
        if (dataList.isEmpty()) {
            throw new AuraHandledException('No record found for the given invoice ID: ' + invoiceId);
        }

        List<CSR_Configuration__c> auth = new List<CSR_Configuration__c>();
        if (Schema.sObjectType.CSR_Configuration__c.isAccessible()) {
            auth = [SELECT Id, Production_CSID_Secret__c, Production_CSID_Token__c
                    FROM CSR_Configuration__c WHERE Company_Name__c =: company.MasterLabel LIMIT 1];
        } else {
            throw new AuraHandledException('No permission to access CSR_Configuration__c records.');
        }

        String binarySecurityToken = auth[0].Production_CSID_Token__c;
        String secret = auth[0].Production_CSID_Secret__c;

        try {
            String authString = binarySecurityToken + ':' + secret;
            String encodedAuth = 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(authString));

            HttpRequest req = new HttpRequest();
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Accept', 'application/pdf');
            req.setHeader('Accept-Language', 'en');
            // req.setHeader('Accept-Version', 'V2');
            req.setHeader('Clearance-Status', '1');
            req.setHeader('Authorization', encodedAuth);
            req.setHeader('SellerVatNumber', company.GSTIN__c);
            req.setHeader('IssueDate', String.valueOf(inv.Invoice_Date__c));
            req.setHeader('IssueTime', String.valueOf(inv.CreatedDate.format('HH:mm:ss')));
            req.setHeader('InvoiceId', inv.Name);
            req.setBody(apiRequestJson);
            req.setEndpoint('https://zatca-api.rangerfusion.com/clearanceAPI');
            req.setMethod('POST');
            System.debug('Request body: ' + apiRequestJson);

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
            if (res.getStatusCode() == 200 || res.getStatusCode() == 202) {
                Blob pdfBlob = res.getBodyAsBlob(); 
            
                ContentVersion cv = new ContentVersion();
                cv.Title = 'ZATCA_Clearance_' + inv.Name;
                cv.PathOnClient = 'ZATCA_Clearance_' + inv.Name + '.pdf';
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
    }
}