public with sharing class billItemsTabHandler {

@AuraEnabled
public static void createTaxDetailRecords(List<Map<String, Object>> taxDetailsList, Id billId,Boolean isReverseChargeActive) {
    try {
        if(taxDetailsList.isEmpty()) return;
        
        System.debug('Creating Tax Detail records for Bill ID: ' + billId);
        System.debug('Tax Details List: ' + taxDetailsList);
        
        // First, query existing tax details for this bill
        List<Tax_Detail__c> existingTaxDetails = [
            SELECT Id, Bill_Item__c, Tax__c
            FROM Tax_Detail__c 
            WHERE Bill__c = :billId 
            WITH SECURITY_ENFORCED
        ];
        
        // Create a map to store existing tax details
        Map<String, Tax_Detail__c> existingTaxDetailMap = new Map<String, Tax_Detail__c>();
        for(Tax_Detail__c td : existingTaxDetails) {
            String key = td.Bill_Item__c + '_' + td.Tax__c;
            existingTaxDetailMap.put(key, td);
        }
        
        // Query bill items ordered by Item_Order__c instead of CreatedDate
        List<Bill_Item__c> billItems = [
            SELECT Id, Name, Item_Order__c
            FROM Bill_Item__c 
            WHERE Bill__c = :billId 
            WITH SECURITY_ENFORCED 
            ORDER BY Item_Order__c ASC
        ];
        
        if(billItems.isEmpty()) {
            throw new AuraHandledException('No bill items found for this bill');
        }

        List<Tax_Detail__c> taxDetailsToUpsert = new List<Tax_Detail__c>();
        
        // Process each tax group
        for(Map<String, Object> taxGroup : taxDetailsList) {
            Object detailsObj = taxGroup.get('details');
            if(detailsObj == null) continue;
            
            List<Object> details = (List<Object>)detailsObj;
            
            for(Object detailObj : details) {
                Map<String, Object> detail = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(detailObj));
                
                Object lineItemIndexObj = detail.get('lineItemIndex');
                if(lineItemIndexObj == null) continue;
                
                Integer lineItemIndex = Integer.valueOf(lineItemIndexObj);
                
                if(lineItemIndex < billItems.size()) {
                    Bill_Item__c currentBillItem = billItems[lineItemIndex];
                    String taxId = String.valueOf(detail.get('taxId'));
                    
                    // Create key for lookup
                    String key = currentBillItem.Id + '_' + taxId;
                    
                    // Either get existing record or create new one
                    Tax_Detail__c td = existingTaxDetailMap.containsKey(key) ? 
                        existingTaxDetailMap.get(key) : new Tax_Detail__c();
                    
                    // Update fields
                    td.Name = 'Tax Detail for ' + String.valueOf(detail.get('taxName'));
                    td.Bill_Item__c = currentBillItem.Id;
                    td.Tax_Percentage__c = Decimal.valueOf(String.valueOf(detail.get('percentage')));
                    td.Amount__c = Decimal.valueOf(String.valueOf(detail.get('taxAmount')));
                    td.Type__c = 'Input Tax';
                    td.Tax__c = taxId;
                    td.Bill__c = billId;
                    td.Is_RCM__c=isReverseChargeActive;
                    
                    taxDetailsToUpsert.add(td);
                }
            }
        }

        if (!taxDetailsToUpsert.isEmpty() && 
            Schema.sObjectType.Tax_Detail__c.isCreateable() &&
            Schema.sObjectType.Tax_Detail__c.isUpdateable() &&
            Schema.sObjectType.Tax_Detail__c.fields.Tax_Percentage__c.isCreateable() &&
            Schema.sObjectType.Tax_Detail__c.fields.Bill_Item__c.isCreateable() &&
            Schema.sObjectType.Tax_Detail__c.fields.Amount__c.isCreateable() &&
            Schema.sObjectType.Tax_Detail__c.fields.Bill__c.isCreateable()) {
            
            // Delete any old tax details that aren't in the new list
            List<Tax_Detail__c> taxDetailsToDelete = new List<Tax_Detail__c>();
            for(Tax_Detail__c oldTd : existingTaxDetails) {
                Boolean found = false;
                for(Tax_Detail__c newTd : taxDetailsToUpsert) {
                    if(oldTd.Id == newTd.Id) {
                        found = true;
                        break;
                    }
                }
                if(!found) {
                    taxDetailsToDelete.add(oldTd);
                }
            }
            
            if(!taxDetailsToDelete.isEmpty() && Schema.sObjectType.Tax_Detail__c.isDeletable()) {
                delete taxDetailsToDelete;
            }
            
            // Perform the upsert
            upsert taxDetailsToUpsert;
            System.debug('Successfully upserted ' + taxDetailsToUpsert.size() + ' Tax Detail records');
            
        } else {
            throw new AuraHandledException('Insufficient permissions to create/update Tax Detail records');
        }
        
    } catch (Exception e) {
        System.debug('Error: ' + e.getMessage() + ' at line ' + e.getLineNumber());
        throw new AuraHandledException('Error managing Tax Detail records: ' + e.getMessage());
    }
}
    @AuraEnabled
    public static void deleteTaxDetails(Id billId) {
        try {
            List<Tax_Detail__c> taxDetailsToDelete = [
                SELECT Id 
                FROM Tax_Detail__c 
                WHERE Bill__c = :billId 
                WITH SECURITY_ENFORCED
            ];
            
            if (!taxDetailsToDelete.isEmpty() && Schema.sObjectType.Tax_Detail__c.isDeletable()) {
                delete taxDetailsToDelete;
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error deleting tax details: ' + e.getMessage());
        }
    }
    @AuraEnabled(cacheable=true)
public static List<PaymentWrapper> getPaymentsForBill(Id billId) {
    List<Payment__c> payments = [
        SELECT Id,
               Name,
               Payment_Amount1__c,
               Balance_Amount1_to_be_Paid__c,
               Payment_Done_Date__c,
               (SELECT Bill__c, Bill__r.Name FROM Payment_References__r WHERE Bill__c = :billId)
        FROM Payment__c
        WHERE Id IN (
            SELECT Payment__c
            FROM Payment_Reference__c
            WHERE Bill__c = :billId
        )
    ];

    List<PaymentWrapper> result = new List<PaymentWrapper>();
    for (Payment__c p : payments) {
        result.add(new PaymentWrapper(p, billId));
    }
    return result;
}


    public class PaymentWrapper {
    @AuraEnabled public Id paymentId;
    @AuraEnabled public String paymentName;
    @AuraEnabled public String billId;
    @AuraEnabled public String billName;
    @AuraEnabled public Decimal paymentAmount;
    @AuraEnabled public Decimal balanceAmount;
    @AuraEnabled public Date paymentDate;

    // Constructor to map Payment__c to wrapper
    public PaymentWrapper(Payment__c p, Id billIdParam) {
        this.paymentId = p.Id;
        this.paymentName = p.Name;
        this.paymentAmount = p.Payment_Amount1__c;
        this.balanceAmount = p.Balance_Amount1_to_be_Paid__c;
        this.paymentDate = p.Payment_Done_Date__c;

        if (p.Payment_References__r != null && !p.Payment_References__r.isEmpty()) {
            // Optional: filter based on passed billId, in case multiple refs
            for (Payment_Reference__c ref : p.Payment_References__r) {
                if (ref.Bill__c == billIdParam) {
                    this.billId = ref.Bill__c;
                    this.billName = ref.Bill__r != null ? ref.Bill__r.Name : null;
                    break;
                }
            }
        }
    }
}


    
    @AuraEnabled
    public static String saveBill(String billWrapperJson) {
        try {
            System.debug('Received JSON: ' + billWrapperJson);
            
            // Deserialize the wrapper
            BillWrapper wrapper = (BillWrapper)JSON.deserialize(billWrapperJson, BillWrapper.class);
            System.debug('Deserialized wrapper: ' + wrapper);
            
            // Determine if this is an update
            Boolean isUpdate = wrapper.billId != null;
            
            // Calculate total amount from bill items
            Decimal totalAmount = 0;
            Decimal subTotal = 0;
            Decimal taxTotal = 0;
            
            // Create or update Bill record
            Bill__c bill;
            if (isUpdate) {
                // For update, first delete existing bill items
                List<Bill_Item__c> existingItems = [SELECT Id FROM Bill_Item__c WHERE Bill__c = :wrapper.billId WITH SECURITY_ENFORCED];
                if (!existingItems.isEmpty() && Bill_Item__c.SObjectType.getDescribe().isDeletable()) {
                    delete existingItems;
                }
                bill = [SELECT Id FROM Bill__c WHERE Id = :wrapper.billId WITH SECURITY_ENFORCED LIMIT 1];
                bill.Name = wrapper.name;
                bill.VendorAccount__c = wrapper.vendorId;
                bill.Contract__c = wrapper.contractId;
                bill.RFQ__c = wrapper.rfqId;
                bill.Bill_Date__c = wrapper.billDate;
                bill.Due_Date__c = wrapper.dueDate;
                bill.Status__c = wrapper.status;
                bill.Create_Journal_Entry__c = wrapper.createJournalEntry;
                bill.Total_Amount__c = wrapper.grandTotal;
                bill.Amounts_Are__c = wrapper.amountsAre;
                bill.Is_RCM__c = wrapper.isRCM;
                bill.Message_Of_Bill__c = wrapper.message;
            } else {
                bill = new Bill__c(
                    Name = wrapper.name,
                    VendorAccount__c = wrapper.vendorId,
                    Contract__c = wrapper.contractId,
                    RFQ__c = wrapper.rfqId,
                    Bill_Date__c = wrapper.billDate,
                    Due_Date__c = wrapper.dueDate,
                    Status__c = wrapper.status,
                    Create_Journal_Entry__c = wrapper.createJournalEntry,
                    Total_Amount__c = wrapper.grandTotal,
                    Amounts_Are__c = wrapper.amountsAre,
                    Is_RCM__c = wrapper.isRCM,
                    Message_Of_Bill__c = wrapper.message
                );
            }

            // Check create/update access for Bill
            if (isUpdate) {
                if (!Bill__c.SObjectType.getDescribe().isUpdateable()) {
                    throw new AuraHandledException('Insufficient permissions to update Bill record');
                }
                update bill;
            } else {
                if (!Bill__c.SObjectType.getDescribe().isCreateable()) {
                    throw new AuraHandledException('Insufficient permissions to create Bill record');
                }
                insert bill;
            }
            System.debug('Bill created with ID: ' + bill.Id);

            // Create Bill Items
            List<Bill_Item__c> billItems = new List<Bill_Item__c>();
            
            // First collect all product IDs
            Set<Id> productIds = new Set<Id>();
            for (BillItemWrapper itemWrapper : wrapper.billItems) {
                if (itemWrapper.productId != null) {
                    productIds.add(itemWrapper.productId);
                }
            }
            
            // Query all products at once
            Map<Id, Product__c> productsMap = new Map<Id, Product__c>();
            if (!productIds.isEmpty()) {
                productsMap = new Map<Id, Product__c>([SELECT Id, Name FROM Product__c WHERE Id IN :productIds WITH SECURITY_ENFORCED]);
            }
            
            for (Integer i = 0; i < wrapper.billItems.size(); i++) {
                BillItemWrapper itemWrapper = wrapper.billItems[i];
                
                // Skip empty rows
                if (itemWrapper.productId == null && 
                    (itemWrapper.description == null || itemWrapper.description.trim() == '') &&
                    (itemWrapper.unitPrice == null || itemWrapper.unitPrice == 0) &&
                    (itemWrapper.quantity == null || itemWrapper.quantity == 0)) {
                    continue;
                }
                
                // Tax rate comes as percentage from UI (e.g., 2 for 2%) - store as is
                //Decimal taxRate = itemWrapper.taxRate != null ? itemWrapper.taxRate : 0;
                
                // Get Product name for the Bill Item name
                String itemName = '';
                if (itemWrapper.productId != null && productsMap.containsKey(itemWrapper.productId)) {
                    itemName = 'Bill Item for ' + productsMap.get(itemWrapper.productId).Name;
                }

                Bill_Item__c item = new Bill_Item__c(
                    Name = itemName,
                    Bill__c = bill.Id,
                    Item_Order__c = (itemWrapper.keyField != null) ? 
                        Decimal.valueOf(itemWrapper.keyField) : 
                        Decimal.valueOf(i + 1), // Use keyField instead of itemOrder or index
                    Product__c = itemWrapper.productId,
                    Description__c = itemWrapper.description,
                    Unit_Price__c = itemWrapper.unitPrice,
                    Quantity__c = itemWrapper.quantity,
                    Tax__c = itemWrapper.taxRate
                );
                billItems.add(item);
            }

            // Only insert if we have valid bill items
            if (!billItems.isEmpty()) {
                // Check create access for Bill Items
                if (!Bill_Item__c.SObjectType.getDescribe().isCreateable()) {
                    throw new AuraHandledException('Insufficient permissions to create Bill Item records');
                }

                // Insert Bill Items
                insert billItems;
                System.debug('Bill Items created: ' + billItems.size());

                // Process serial numbers if present
                processSerialNumbers(wrapper.billItems, billItems);
            }

            return bill.Id;

        } catch (Exception e) {
            System.debug('Error in saveBill: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error saving bill: ' + e.getMessage());
        }
    }
    
    private static void processSerialNumbers(List<BillItemWrapper> itemWrappers, List<Bill_Item__c> billItems) {
        try {
            // Create a map to link bill items to their products
            Map<Id, Bill_Item__c> productToBillItem = new Map<Id, Bill_Item__c>();
            for (Bill_Item__c billItem : billItems) {
                if (billItem.Product__c != null) {
                    productToBillItem.put(billItem.Product__c, billItem);
                }
            }
            
            // Collect all serial numbers that need to be processed
            Set<String> allSerialNumbers = new Set<String>();
            Map<Id, List<String>> productToSerialNumbers = new Map<Id, List<String>>();
            
            for (BillItemWrapper itemWrapper : itemWrappers) {
                if (itemWrapper.selectedSerialNumbers != null && 
                    !itemWrapper.selectedSerialNumbers.isEmpty() &&
                    itemWrapper.productId != null) {
                    
                    allSerialNumbers.addAll(itemWrapper.selectedSerialNumbers);
                    if (!productToSerialNumbers.containsKey(itemWrapper.productId)) {
                        productToSerialNumbers.put(itemWrapper.productId, new List<String>());
                    }
                    productToSerialNumbers.get(itemWrapper.productId).addAll(itemWrapper.selectedSerialNumbers);
                }
            }
            
            // Query and update stock records if there are serial numbers
            if (!allSerialNumbers.isEmpty()) {
                List<Stock__c> stocksToUpdate = [
                    SELECT Id, Serial_Number__c, Product__c
                    FROM Stock__c 
                    WHERE Id IN :allSerialNumbers
                    AND Product__c IN :productToBillItem.keySet()
                    WITH SECURITY_ENFORCED
                ];
                
                for (Stock__c stock : stocksToUpdate) {
                    // Verify that this stock record's product matches the expected product
                    if (stock.Product__c != null && 
                        productToSerialNumbers.containsKey(stock.Product__c) &&
                        productToSerialNumbers.get(stock.Product__c).contains(stock.Id)) {
                            
                        // We don't need to set Stock_Bill_Item__c as it doesn't exist
                        // The relationship is maintained through the Product__c field
                        System.debug('Processed stock record ' + stock.Id + ' for product ' + stock.Product__c);
                    }
                }
                
                if (!stocksToUpdate.isEmpty()) {
                    // Since we're not actually updating any fields, we don't need to perform an update
                    // The relationship is maintained through the existing Product__c field
                    System.debug('Processed ' + stocksToUpdate.size() + ' stock records');
                }
            }
        } catch (Exception e) {
            System.debug('Error processing serial numbers: ' + e.getMessage());
            // Don't throw here - serial number processing is secondary to bill creation
        }
    }

    
    @AuraEnabled
public static Map<String, Object> getBillDetails(Id billId) {
    try {
        Bill__c bill = [
            SELECT Id, Name, 
                   VendorAccount__c, VendorAccount__r.Name, VendorAccount__r.Preferred_Currency_Code__c,
                   Contract__c, Contract__r.ContractNumber,Contract__r.Name,Amounts_Are__c,
                   RFQ__c, RFQ__r.Name,Is_RCM__c,
                   Bill_Date__c, Due_Date__c, Status__c,
                   Create_Journal_Entry__c,Message_Of_Bill__c,
                   (SELECT Id, Item_Order__c, Product__c, Product__r.Name, 
                           Product__r.ProductCode__c, Product__r.Actual_Cost__c,
                           Description__c, Unit_Price__c, Quantity__c, 
                           Tax_Rate__c, Tax_Amount__c, Tax__c
                    FROM Bill_Items1__r
                    ORDER BY Item_Order__c)
            FROM Bill__c
            WHERE Id = :billId
            WITH SECURITY_ENFORCED
        ];

        // Prepare response with null checks
        Map<String, Object> response = new Map<String, Object>{
            'name' => bill.Name,
            'vendorId' => bill.VendorAccount__c,
            'amountsAre' => bill.Amounts_Are__c,
            'vendorName' => bill.VendorAccount__r?.Name,
            'isRCM' => bill.Is_RCM__c, 
            'contractId' => bill.Contract__c,
            'contractName' => bill.Contract__r?.Name, // Added contract name
            'contractNumber' => bill.Contract__r?.ContractNumber,
            'rfqId' => bill.RFQ__c,
            'rfqNumber' => bill.RFQ__r?.Name,
            'billDate' => bill.Bill_Date__c,
            'dueDate' => bill.Due_Date__c,
            'status' => bill.Status__c,
            'createJournalEntry' => bill.Create_Journal_Entry__c,
            'currencyCode' => bill.VendorAccount__r?.Preferred_Currency_Code__c,
            'message' => bill.Message_Of_Bill__c
        };

        // Handle bill items with null checks
        List<Map<String, Object>> billItems = new List<Map<String, Object>>();
        if(bill.Bill_Items1__r != null) {
            for (Bill_Item__c item : bill.Bill_Items1__r) {
                Decimal subtotal = (item.Unit_Price__c != null ? item.Unit_Price__c : 0) * 
                                 (item.Quantity__c != null ? item.Quantity__c : 1);
                
                // Safe tax calculation
                Decimal taxRate = item.Tax_Rate__c != null ? item.Tax_Rate__c : 0;
                Decimal taxAmount = item.Tax_Amount__c != null ? item.Tax_Amount__c : 0;
                
                Map<String, Object> itemMap = new Map<String, Object>{
                    'itemOrder' => item.Item_Order__c,
                    'keyField' => item.Item_Order__c,
                    'productId' => item.Product__c,
                    'description' => item.Description__c,
                    'unitPrice' => item.Unit_Price__c != null ? item.Unit_Price__c : 0,
                    'quantity' => item.Quantity__c != null ? item.Quantity__c : 1,
                    'taxRate' => item.Tax__c,
                    'total' => subtotal,
                    'taxAmount' => taxAmount,
                    'amount' => subtotal + taxAmount,
                    'productName' => item.Product__r?.Name,
                    'productCode' => item.Product__r?.ProductCode__c,
                    'productCost' => item.Product__r?.Actual_Cost__c
                };
                billItems.add(itemMap);
            }
        }
        
        response.put('billItems', billItems);
        return response;

    } catch (Exception e) {
        System.debug('Error in getBillDetails: ' + e.getMessage() + ' at line: ' + e.getLineNumber());
        throw new AuraHandledException('Error retrieving bill details: ' + e.getMessage() + e.getLineNumber());
    }
}

    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getStatusPicklistValues() {
        Map<String, List<String>> picklistMap = new Map<String, List<String>>();

        List<String> billStatusValues = new List<String>();
        Schema.DescribeFieldResult billStatusField = Bill__c.Status__c.getDescribe();
        for (Schema.PicklistEntry entry : billStatusField.getPicklistValues()) {
            billStatusValues.add(entry.getLabel());
        }
        picklistMap.put('BillStatus', billStatusValues);

        List<String> invoiceAmountsAreValues = new List<String>();
        Schema.DescribeFieldResult invoiceAmountsField = Invoice__c.Amounts_are__c.getDescribe();
        for (Schema.PicklistEntry entry : invoiceAmountsField.getPicklistValues()) {
            invoiceAmountsAreValues.add(entry.getLabel());
        }
        picklistMap.put('InvoiceAmountsAre', invoiceAmountsAreValues);

        return picklistMap;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<BillWrapper> getAttachments(List<Id> billIds) {
        if (billIds == null || billIds.isEmpty()) {
            return new List<BillWrapper>();
        }

    // Query Bills with their ContentDocumentLinks and ContentDocuments
    // AB 26JUN25 added file type and extension to the query
    List<Bill__c> bills = [
        SELECT Id, Name, Bill_Date__c, Total_Amount__c, Paid_Amount__c, Balance_Due__c,Amounts_are__c,
               VendorAccount__c, VendorAccount__r.Name, Status__c, Create_Journal_Entry__c,Is_RCM__c,
               Contract__c, Contract__r.ContractNumber, RFQ__c, RFQ__r.Name, Due_Date__c,
               LastModifiedDate,Message_Of_Bill__c,
               (SELECT ContentDocumentId, ContentDocument.Title, 
                       ContentDocument.FileExtension, ContentDocument.FileType 
                FROM ContentDocumentLinks)
        FROM Bill__c
        WHERE Id IN :billIds
        WITH SECURITY_ENFORCED
    ];

    List<BillWrapper> wrappers = new List<BillWrapper>();
    
    for (Bill__c bill : bills) {
        BillWrapper wrapper = new BillWrapper(bill);
        wrappers.add(wrapper);
    }

    return wrappers;
}
    @AuraEnabled
    public static Id uploadFileToServer(String fileName, String base64Data, String contentType,Id billId) {
        System.debug('Uploading file: ' + fileName + ', Content Type: ' + contentType + ', Bill ID: ' + billId);
        // Decode the base64 string
        Blob fileBody = EncodingUtil.base64Decode(base64Data);

        ContentVersion cv = new ContentVersion();
        cv.Title = fileName;
        cv.PathOnClient = '/' + fileName;
        cv.VersionData = fileBody;
        cv.IsMajorVersion = true;
        insert cv;

        if (cv.Id != null) {
                        
            ContentVersion insertedCv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
                        
            ContentDocumentLink cdl = new ContentDocumentLink(
                LinkedEntityId = billId,
                ContentDocumentId = insertedCv.ContentDocumentId,
                ShareType = 'V',
                Visibility = 'AllUsers'
            );
            insert cdl;
        }
            return cv.Id;
        }

    @AuraEnabled
    public static void deletePayment(Id paymentId) {
        try {
            Payment__c payment = [SELECT Id FROM Payment__c WHERE Id = :paymentId LIMIT 1];
            if (!Payment__c.SObjectType.getDescribe().isDeletable()) {
                throw new AuraHandledException('Insufficient permissions to delete Payment record');
            }
            delete payment;
        } catch (Exception e) {
            throw new AuraHandledException('Error deleting payment: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void deleteAttachment(Id contentDocumentId) {
    try {
        System.debug('Attempting to delete ContentDocument with ID: ' + contentDocumentId);
        
        // Get ContentDocument details
        List<ContentDocument> contentDocs = [
            SELECT Id, Title, FileExtension, ContentSize, CreatedDate, CreatedById
            FROM ContentDocument 
            WHERE Id = :contentDocumentId
        ];
        
        if (contentDocs.isEmpty()) {
            throw new AuraHandledException('File not found with ID: ' + contentDocumentId);
        }
        
        ContentDocument doc = contentDocs[0];
        System.debug('Found ContentDocument: ' + doc.Title + ' (.' + doc.FileExtension + ')');
        
        // Get ContentDocumentLinks
        List<ContentDocumentLink> links = [
            SELECT Id, LinkedEntityId, ShareType, Visibility, ContentDocumentId
            FROM ContentDocumentLink 
            WHERE ContentDocumentId = :contentDocumentId
        ];
        
        System.debug('Found ' + links.size() + ' ContentDocumentLinks');
        for (ContentDocumentLink link : links) {
            System.debug('Link ID: ' + link.Id + ', LinkedEntity: ' + link.LinkedEntityId + ', ShareType: ' + link.ShareType);
        }
        
        // Get ContentVersions
        List<ContentVersion> versions = [
            SELECT Id, Title, VersionNumber, IsLatest, ContentDocumentId
            FROM ContentVersion 
            WHERE ContentDocumentId = :contentDocumentId
        ];
        
        System.debug('Found ' + versions.size() + ' ContentVersions');
        
        // Try the simple delete approach first
        Database.DeleteResult result = Database.delete(doc, false);
        
        if (result.isSuccess()) {
            System.debug('Successfully deleted ContentDocument');
        } else {
            System.debug('Delete failed. Errors:');
            String errorDetails = '';
            for (Database.Error error : result.getErrors()) {
                System.debug('Error: ' + error.getMessage());
                System.debug('Status Code: ' + error.getStatusCode());
                System.debug('Fields: ' + error.getFields());
                errorDetails += error.getStatusCode() + ': ' + error.getMessage() + '; ';
            }
            throw new AuraHandledException('Delete failed: ' + errorDetails);
        }
        
    } catch (Exception e) {
        System.debug('Exception occurred: ' + e.getMessage());
        System.debug('Exception type: ' + e.getTypeName());
        System.debug('Stack trace: ' + e.getStackTraceString());
        throw new AuraHandledException('Error deleting attachment: ' + e.getMessage());
    }
}

}