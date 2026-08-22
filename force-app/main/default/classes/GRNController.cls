public without sharing class GRNController {
    //AAB 25SEP2025 Function to fetch GRN related to PO
    @AuraEnabled(cacheable=true)
    public static List<RFAB__GRN__c> getGRN(Id purchaseOrderId) {
        return [
            SELECT Id, Name, Quantity__c, Total_Amount_with_Tax1__c,
                   RFAB__Purchase_Order__r.RFAB__Vendor_Account__c,
                   RFAB__Purchase_Order__r.RFAB__Vendor_Account__r.Name
            FROM RFAB__GRN__c
            WHERE RFAB__Purchase_Order__c = :purchaseOrderId
        ];
    }

    @AuraEnabled(cacheable=true)
    public static RFAB__GRN__c fetchGRN(Id grnId) {
        return [
            SELECT Id, Name, RFAB__Batch_Info__c, RFAB__Currency__c, RFAB__Status__c, RFAB__Date__c, RFAB__Purchase_Order__r.Name, GRN_Number__c, Quantity__c, Total_Amount_with_Tax1__c, Total_Expense_Amount__c, (SELECT Id, RFAB__Quantity__c, RFAB__Product__c, RFAB__Product__r.Name, Serial_Number__c, RFAB__Purchase_Price__c FROM RFAB__Stocks__r),(SELECT Id, Name, RFAB__Date__c, RFAB__Description__c, RFAB__Amount_excluding__c, Tax_Amount__c, RFAB__Total_Amount__c, RFAB__Chart_of_Accounts__c, RFAB__Chart_of_Accounts__r.Name, RFAB__GRN__c FROM RFAB__Expenses__r) FROM RFAB__GRN__c
            WHERE ID =: grnId
        ];
    }

// MR 03MAR25 Function to read existing Draft GRN
// Added Status to the Query to check if the GRN is Draft
    @AuraEnabled(cacheable=true)
    public static List<RFAB__Location__c> searchLocation(String searchKey) {
        String sanitizedSearchString = String.isNotBlank(searchKey) ? '%' + searchKey.trim() + '%' : null;

        return [
            SELECT Id, Name
            FROM RFAB__Location__c
            WHERE Name LIKE :sanitizedSearchString
            LIMIT 10
        ];
    }
    @AuraEnabled(cacheable=true)
    public static string getPaymentAccountId(Id paId) {
        try {
            List<RFAB__Payment__c> payList = [SELECT Id, RFAB__Account__c,RFAB__Invoice__r.RFAB__Balance_Amount_to_be_Paid__c 
            FROM RFAB__Payment__c WHERE Id = :paId AND RFAB__Invoice__r.RFAB__Balance_Amount_to_be_Paid__c > 0 LIMIT 100];

            // If Draft Exist, return the Draft Id
            for(RFAB__Payment__c pay: payList) {
                return pay.Id;
            }
            return getPaymentAccountId(paId);
        } catch (Exception e) {
            throw new AuraHandledException('Error while processing Payment: ' + e.getMessage());
        }
    }
    @AuraEnabled
    public static string getDraftGRN(Id poId) {
        try {
            List<RFAB__GRN__c> grnList = [SELECT Id,RFAB__Status__c FROM RFAB__GRN__c WHERE RFAB__Purchase_Order__c =: poId LIMIT 100];
            // If Draft Exist, return the Draft Id
            for(RFAB__GRN__c grn: grnList) {
                // If the GRN is not required through an error
                if(grn.RFAB__Status__c == 'Draft') {
                    return grn.Id;
                }
            }
            
            return stockCreation(poId);
        } catch (Exception e) {
            throw new AuraHandledException('Error while processing GRN and Stock: ' + e.getMessage());
        }
    }
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getPurchaseOrderData(Id poId) {
        Map<String, Object> result = new Map<String, Object>();
        //AAB 25SEP2025 Fetch PO with Tax fields as per latest PO Component changes
        RFAB__Purchase_Order__c purchaseOrder = [
            SELECT Id, Name, RFAB__Vendor_Account__c,RFAB__Discount_Type__c, RFAB__Vendor_Account__r.Name,Received_Quantity__c,Total_Quantity__c,GRN_Status__c ,RFAB__Status__c,RFAB__Tax__c,RFAB__Tax_Percent__c FROM RFAB__Purchase_Order__c WHERE Id = :poId
        ];

        if(purchaseOrder.RFAB__Status__c == 'Draft' || purchaseOrder.RFAB__Status__c == 'Cancelled')  {
            result.put('errorMessage', 'Purchase Order Status is not approved');
        }
        if (purchaseOrder.GRN_Status__c == 'Fully Created') {
            List<RFAB__GRN__c> completedGRNs = [
                SELECT Id, RFAB__Status__c 
                FROM RFAB__GRN__c 
                WHERE RFAB__Purchase_Order__c = :poId 
                AND RFAB__Status__c != 'Completed'
            ];
            if (completedGRNs.isEmpty()) {
                result.put('errorMessage', 'GRN already created for this Purchase Order.');
                // return result;
            }
        }
        List<RFAB__PO_Item__c> poItems = [
            SELECT Id, RFAB__Product__c,RFAB__Product__r.RFAB__SKU__c, RFAB__Quantity__c, Received_Quantity__c, Balance_Qty__c,RFAB__Product__r.RFAB__Is_Serial_Number__c,
            RFAB__Product__r.Name,RFAB__Product__r.Name__c,RFAB__Unit_Price__c,Tax_Percentage__c,RFAB__Purchase_Order__r.RFAB__Vendor_Account__c,RFAB__Tax__c,RFAB__Tax_Percent__c
            FROM RFAB__PO_Item__c WHERE RFAB__Purchase_Order__c = :poId AND Balance_Qty__c > 0
        ];
        
        List<Map<String, Object>> items = new List<Map<String, Object>>();

        for (RFAB__PO_Item__c poItem : poItems) {
            if (poItem.RFAB__Product__r.RFAB__Is_Serial_Number__c) {
                for (Integer i = 0; i < poItem.Balance_Qty__c; i++) {
                    Map<String, Object> poItemData = new Map<String, Object>();
                    poItemData.put('Id', poItem.Id);
                    poItemData.put('Name', poItem.RFAB__Product__r.Name);
                    poItemData.put('RFAB__Product__c', poItem.RFAB__Product__c);
                    poItemData.put('RFAB__Quantity__c', 1); // Each stock record has quantity = 1
                    poItemData.put('RFAB__Unit_Price__c', poItem.RFAB__Unit_Price__c);
                    //poItemData.put('Tax_Percentage__c', poItem.Tax_Percentage__c);
                    poItemData.put('RFAB__Tax_Percent__c', poItem.RFAB__Tax_Percent__c);
                    poItemData.put('RFAB__Tax__c', poItem.RFAB__Tax__c);
                    poItemData.put('RFAB__Is_Serial_Number__c', poItem.RFAB__Product__r.RFAB__Is_Serial_Number__c);
                    poItemData.put('RFAB__Product__r.RFAB__SKU__c',poItem.RFAB__Product__r.RFAB__SKU__c);
                    items.add(poItemData);
                }
            }else{
                Map<String, Object> poItemData = new Map<String, Object>();
                poItemData.put('Id', poItem.Id);
                poItemData.put('Name', poItem.RFAB__Product__r.Name);
                poItemData.put('RFAB__Product__c', poItem.RFAB__Product__c);
                poItemData.put('RFAB__Quantity__c', poItem.Balance_Qty__c); // Each stock record has quantity = 1
                poItemData.put('RFAB__Unit_Price__c', poItem.RFAB__Unit_Price__c);
                poItemData.put('RFAB__Tax__c', poItem.RFAB__Tax__c);
                poItemData.put('RFAB__Tax_Percent__c', poItem.RFAB__Tax_Percent__c);
                poItemData.put('RFAB__Product__r.RFAB__SKU__c',poItem.RFAB__Product__r.RFAB__SKU__c);
                //poItemData.put('Tax_Percentage__c', poItem.Tax_Percentage__c);
                
                items.add(poItemData);
            }
        }
        result.put('purchaseOrder', purchaseOrder);
        result.put('items', items);
        return result;
    }

    
    @AuraEnabled
    public static String CreateGRN(Id purchaseOrderId, Id existingGRNId, 
                                    RFAB__Purchase_Order__c updatedpurchaseOrder,
                                    List<RFAB__PO_Item__c> poItems, 
                                    List<String> serialNumbers,
                                    List<RFAB__Expense__c> expenseItems, 
                                    List<List<Id>> expenseFileIdLists,
                                    String grnDeliveryDate,
                                    Id grnChartOfAccountId,
                                    List<Id> grnFileIds,
                                    List<Id> grnRemovedFileIds) {
        try {

            System.debug('=== Create GRN Debug ===');
        System.debug('grnFileIds received: ' + grnFileIds);
        System.debug('grnRemovedFileIds received: ' + grnRemovedFileIds);
        System.debug('existingGRNId: ' + existingGRNId);
            // Fetch Purchase Order
            RFAB__Purchase_Order__c po = [
                SELECT Id, Name, Sales_Order__c, RFAB__Vendor_Account__c, RFAB__Status__c
                FROM RFAB__Purchase_Order__c
                WHERE Id = :purchaseOrderId
            ];
            
            RFAB__GRN__c grn;
            Boolean isUpdate = (existingGRNId != null);
            
            if (isUpdate) {
                // Update existing Draft GRN to Completed
                grn = [SELECT Id, RFAB__Status__c, Chart_of_Accounts__c FROM RFAB__GRN__c WHERE Id = :existingGRNId LIMIT 1];
                
                // Delete removed GRN files FIRST (before updating status)
                if (grnRemovedFileIds != null && !grnRemovedFileIds.isEmpty()) {
                    deleteGRNFiles(existingGRNId, grnRemovedFileIds);
                }
                
                grn.RFAB__Date__c = String.isNotBlank(grnDeliveryDate) ? Date.valueOf(grnDeliveryDate) : System.today();
                grn.RFAB__Status__c = 'Completed';
                grn.Chart_of_Accounts__c = grnChartOfAccountId; 
                update grn;
                
                // Delete existing records
                deleteRelatedRecords(existingGRNId);
            } else {
                // Create new GRN with Completed status
                grn = new RFAB__GRN__c();
                grn.RFAB__Date__c = String.isNotBlank(grnDeliveryDate) ? Date.valueOf(grnDeliveryDate) : System.today();
                grn.RFAB__Status__c = 'Completed';
                grn.RFAB__Purchase_Order__c = po.Id;
                grn.RFAB__Batch_Info__c = 'Serial Number';
                grn.Chart_of_Accounts__c = grnChartOfAccountId;
                insert grn;
            }
            
            // Create Stock Records
            Id receiptRecordTypeId = Schema.SObjectType.RFAB__Stock__c.getRecordTypeInfosByDeveloperName().get('Receipt').getRecordTypeId();
            Id companyExpenseRecordTypeId = Schema.SObjectType.RFAB__Expense__c.getRecordTypeInfosByDeveloperName().get('Company_Expense').getRecordTypeId();
            RFAB__Location__c loc = [SELECT Id, Name FROM RFAB__Location__c WITH SECURITY_ENFORCED LIMIT 1];
            
            List<RFAB__Stock__c> stockRecords = new List<RFAB__Stock__c>();
            Integer i = 0;
            for (RFAB__PO_Item__c poItem : poItems) {
                String serialNumber = (serialNumbers != null && serialNumbers.size() > i) ? serialNumbers[i] : null;
                
                RFAB__Stock__c stock = new RFAB__Stock__c();
                String trimmedName = poItem.Name != null ? 
                    (poItem.Name.length() > 80 ? poItem.Name.substring(0, 80) : poItem.Name) : null;
                stock.Name = trimmedName;
                stock.RFAB__GRN__c = grn.Id;
                stock.RFAB__Product__c = poItem.RFAB__Product__c;
                
                if (poItem.RFAB__Product__r.RFAB__Is_Serial_Number__c) {
                    stock.RFAB__Quantity__c = 1;
                } else {
                    stock.RFAB__Quantity__c = poItem.RFAB__Quantity__c;
                }
                
                stock.RFAB__Purchase_Price__c = poItem.RFAB__Unit_Price__c;
                stock.RFAB__Unit_Of_Measure__c = 'Each';
                stock.RecordTypeId = receiptRecordTypeId;
                stock.RFAB__Vendor_Account__c = po.RFAB__Vendor_Account__c;
                stock.Serial_Number__c = serialNumber;
                stock.PO_Items__c = poItem.Id;
                stock.RFAB__Location__c = loc.Id;
                stockRecords.add(stock);
                
                if (serialNumbers != null) {
                    i++;
                }
            }
            insert stockRecords;
            
            // Create Expense Items
            List<RFAB__Expense__c> expenseRecords = new List<RFAB__Expense__c>();
            for (RFAB__Expense__c expItem : expenseItems) {
                if (expItem.RFAB__Date__c != null && 
                    expItem.RFAB__Description__c != null && 
                    expItem.RFAB__Amount_excluding__c != null && 
                    expItem.Tax_Amount__c != null && 
                    expItem.RFAB__Total_Amount__c != null && 
                    expItem.RFAB__Chart_of_Accounts__c != null) {
                    
                    RFAB__Expense__c exp = new RFAB__Expense__c();
                    exp.Name = expItem.Name;
                    exp.RFAB__GRN__c = grn.Id;
                    exp.RecordTypeId = companyExpenseRecordTypeId;
                    exp.RFAB__Date__c = expItem.RFAB__Date__c;
                    exp.RFAB__Description__c = expItem.RFAB__Description__c;
                    exp.RFAB__Amount_excluding__c = expItem.RFAB__Amount_excluding__c;
                    exp.Tax_Amount__c = expItem.Tax_Amount__c;
                    exp.RFAB__Total_Amount__c = expItem.RFAB__Total_Amount__c;
                    exp.RFAB__Chart_of_Accounts__c = expItem.RFAB__Chart_of_Accounts__c;
                    exp.Purchase_Order__c = po.Id;
                    expenseRecords.add(exp);
                }
            }
            insert expenseRecords;
            
            // Get existing file links to avoid duplicates
            Set<Id> existingGRNFileIds = new Set<Id>();
            Set<Id> existingExpenseFileIds = new Set<Id>();
            
            if (isUpdate) {
                List<ContentDocumentLink> existingLinks = [
                    SELECT ContentDocumentId, LinkedEntityId
                    FROM ContentDocumentLink
                    WHERE LinkedEntityId = :grn.Id
                ];
                for (ContentDocumentLink link : existingLinks) {
                    existingGRNFileIds.add(link.ContentDocumentId);
                }
            }
            
            // Link expense files
            List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();
            for (Integer j = 0; j < expenseRecords.size(); j++) {
                RFAB__Expense__c insertedExp = expenseRecords[j];
                List<Id> fileIds = (j < expenseFileIdLists.size()) ? expenseFileIdLists[j] : new List<Id>();
                
                for (Id fileId : fileIds) {
                    linksToInsert.add(new ContentDocumentLink(
                        LinkedEntityId = insertedExp.Id,
                        ContentDocumentId = fileId,
                        ShareType = 'V'
                    ));
                }
            }
            
            // NEW: Link GRN files (only if not already linked)
            if (grnFileIds != null && !grnFileIds.isEmpty()) {
                for (Id fileId : grnFileIds) {
                    if (!existingGRNFileIds.contains(fileId)) {
                        linksToInsert.add(new ContentDocumentLink(
                            LinkedEntityId = grn.Id,
                            ContentDocumentId = fileId,
                            ShareType = 'V'
                        ));
                    }
                }
            }
            
            if (!linksToInsert.isEmpty()) {
                insert linksToInsert;
            }
            
            return grn.Id;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error while processing GRN and Stock: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static Map<Id, Map<String, Object>> getTaxInfoFromPOItems(List<Id> poItemIds) {
        Map<Id, Map<String, Object>> taxInfoMap = new Map<Id, Map<String, Object>>();
        
        List<RFAB__PO_Item__c> poItems = [
            SELECT Id, RFAB__Tax__c, RFAB__Tax_Percent__c,
                RFAB__Tax__r.Name, RFAB__Tax__r.RFAB__Tax_Percentage__c
            FROM RFAB__PO_Item__c
            WHERE Id IN :poItemIds
        ];
        
        for (RFAB__PO_Item__c poItem : poItems) {
            Map<String, Object> taxInfo = new Map<String, Object>();
            taxInfo.put('taxId', poItem.RFAB__Tax__c);
            taxInfo.put('taxPercent', poItem.RFAB__Tax_Percent__c != null ? 
                        poItem.RFAB__Tax_Percent__c : 
                        (poItem.RFAB__Tax__r != null ? poItem.RFAB__Tax__r.RFAB__Tax_Percentage__c : 0));
            taxInfo.put('taxName', poItem.RFAB__Tax__r != null ? poItem.RFAB__Tax__r.Name : '');
            taxInfoMap.put(poItem.Id, taxInfo);
        }
        
        return taxInfoMap;
    }
    
    @AuraEnabled
    public static string stockCreation(Id poId) {
        try {
            // AAB 25SEP2025 Fetch PO Items with tax details as per latest PO Component changes
            List<RFAB__PO_Item__c> poItems = [SELECT Id, Name,RFAB__Unit_Price__c, RFAB__Unit_of_Measure__c, RFAB__Quantity__c, RFAB__Product__c,RFAB__Tax__c,RFAB__Tax_Percent__c,
                                        RFAB__Product__r.Name,RFAB__Product__r.Name__c,RFAB__Purchase_Order__r.Name,RFAB__Purchase_Order__r.RFAB__Vendor_Account__c, RFAB__Product__r.RFAB__Is_Serial_Number__c 
                                        FROM RFAB__PO_Item__c 
                                        WHERE RFAB__purchase_Order__c = :poId WITH SECURITY_ENFORCED];
    
            if (poItems.isEmpty()) {
                throw new AuraHandledException('No PO Items found for this Purchase Order.');
            }
    
            // Step 2: Create GRN Record Linked to PO
            RFAB__GRN__c grn = new RFAB__GRN__c();
            grn.Name = 'GRN for PO ' + poItems[0].RFAB__Purchase_Order__r.Name;
            grn.RFAB__Purchase_Order__c = poId;
            grn.RFAB__Status__c = 'Draft';
            grn.RFAB__Date__c = system.today();
            insert grn;
            RFAB__Location__c loc=[SELECT Id,Name FROM RFAB__Location__c WITH SECURITY_ENFORCED LIMIT 1];
            // Step 3: Create Stock Records from PO Items (Linked to GRN)
            List<RFAB__Stock__c> stockRecords = new List<RFAB__Stock__c>();
            Id receiptRecordTypeId = Schema.SObjectType.RFAB__Stock__c.getRecordTypeInfosByDeveloperName().get('Receipt').getRecordTypeId();
            for (RFAB__PO_Item__c poItem : poItems) {
                if (poItem.RFAB__Product__r.RFAB__Is_Serial_Number__c) {
                    // If serial number tracking is enabled, create separate records for each unit
                    for (Integer i = 0; i < poItem.RFAB__Quantity__c; i++) {
                        RFAB__Stock__c stock = new RFAB__Stock__c();
                        Stock.Name = poItem.RFAB__Product__r.Name;
                        stock.RFAB__GRN__c = grn.Id;
                        stock.RFAB__Product__c = poItem.RFAB__Product__c;
                        stock.RFAB__Quantity__c = 1; // Each stock record has quantity = 1
                        stock.RFAB__Purchase_Price__c = poItem.RFAB__Unit_Price__c; // Setting Purchase Price as Stock Price initially
                        stock.RFAB__Unit_Of_Measure__c = poItem.RFAB__Unit_of_Measure__c;
                        stock.RecordTypeId = receiptRecordTypeId; // Setting record type as Receipt
                        stock.RFAB__Vendor_Account__c = poItem.RFAB__Purchase_Order__r.RFAB__Vendor_Account__c;
                        stock.RFAB__Location__c= loc.Id;
                        stockRecords.add(stock);
                    }
                } else {
                    // If serial number tracking is disabled, create one stock record for the entire quantity
                    RFAB__Stock__c stock = new RFAB__Stock__c();
                    Stock.Name = poItem.RFAB__Product__r.Name;
                    stock.RFAB__GRN__c = grn.Id;
                    stock.RFAB__Product__c = poItem.RFAB__Product__c;
                    stock.RFAB__Quantity__c = poItem.RFAB__Quantity__c; // Entire quantity in one record
                    stock.RFAB__Purchase_Price__c = poItem.RFAB__Unit_Price__c; // Setting Purchase Price as Stock Price initially
                    stock.RFAB__Unit_Of_Measure__c = poItem.RFAB__Unit_of_Measure__c;
                    stock.RecordTypeId = receiptRecordTypeId; // Setting record type as Receipt
                    stock.RFAB__Vendor_Account__c = poItem.RFAB__Purchase_Order__r.RFAB__Vendor_Account__c;
                    stock.RFAB__Location__c= loc.Id;
                    stockRecords.add(stock);
                }
            }
     
            System.debug('Stock Records to insert: ' + stockRecords);
            if (!stockRecords.isEmpty()) {
                insert stockRecords;
            }
            return grn.Id; // Return the GRN ID to LWC
        } catch (Exception e) {
            throw new AuraHandledException('Error while processing GRN and Stock: ' + e.getMessage());
        }
    }

    public static void stockFinalPriceUpdate(Id grnId) {
        try {
            // Fetch all Stock records related to this GRN
            List<RFAB__Stock__c> stockRecords = [SELECT Id, RFAB__Purchase_Price__c , RFAB__Quantity__c, RFAB__Final_Price__c 
                                           FROM RFAB__Stock__c WHERE RFAB__GRN__c = :grnId WITH SECURITY_ENFORCED];
            if (stockRecords.isEmpty()) {
                throw new AuraHandledException('No Stock records found for this GRN.');
            }

            // Step 2: Calculate Total Stock Value
            Decimal totalStockValue = 0;
            for (RFAB__Stock__c stock : stockRecords) {
                totalStockValue += (stock.RFAB__Purchase_Price__c  * stock.RFAB__Quantity__c);
            }

            // Step 3: Fetch Expenses Linked to GRN
            List<RFAB__Expense__c> expenses = [SELECT Id, RFAB__Total_Amount__c  FROM RFAB__Expense__c WHERE RFAB__GRN__c = :grnId WITH SECURITY_ENFORCED];
            Decimal totalExpenseValue = 0;
            for (RFAB__Expense__c exp : expenses) {
                totalExpenseValue += exp.RFAB__Total_Amount__c ;
            }

            // Step 4: Allocate Expenses to Stock Proportionally
            List<RFAB__Stock__c> updatedStockList = new List<RFAB__Stock__c>();

            for (RFAB__Stock__c stock : stockRecords) {
                Decimal stockTotalValue = stock.RFAB__Purchase_Price__c * stock.RFAB__Quantity__c;
                Decimal allocationRatio = stockTotalValue / totalStockValue;

                Decimal allocatedExpense = totalExpenseValue * allocationRatio;
                Decimal newTotalValue = stockTotalValue + allocatedExpense;
                Decimal finalPricePerUnit = newTotalValue / stock.RFAB__Quantity__c;

                stock.RFAB__Final_Price__c = finalPricePerUnit.setScale(2, RoundingMode.HALF_UP);
                updatedStockList.add(stock);
            }
            // Step 5: Perform DML Update
            if (!updatedStockList.isEmpty()) {
                update updatedStockList;
            }
        } catch (Exception e) {
            System.debug('Error in allocateExpensesToStock: ' + e.getMessage());
        }
    }
    @AuraEnabled
    public static string stockConsumption(Id soId) {
        try {
            // Step 1: Fetch PO Items
            List<RFAB__SO_Items__c> soItems = [SELECT Id, RFAB__Unit_Price__c, RFAB__Unit_of_Measure__c, RFAB__Quantity__c, RFAB__Product__c,
            RFAB__Product__r.Name,RFAB__Product__r.Name__c,RFAB__Sales_Order__r.Name,RFAB__Sales_Order__r.RFAB__Customer__c, 
            RFAB__Product__r.RFAB__Is_Serial_Number__c FROM RFAB__SO_Items__c 
            WHERE RFAB__Sales_Order__c = :soId WITH SECURITY_ENFORCED];
    
            if (soItems.isEmpty()) {
                throw new AuraHandledException('No PO Items found for this Purchase Order.');
            }
            RFAB__Location__c loc=[SELECT Id,Name FROM RFAB__Location__c WITH SECURITY_ENFORCED LIMIT 1];
            // Step 2: Create GRN Record Linked to PO
            RFAB__Delivery_Note__c dn = new RFAB__Delivery_Note__c();
            dn.Name = 'DN for SO ' + soItems[0].RFAB__Sales_Order__r.Name;
            dn.RFAB__Sales_Order__c = soId;
            dn.RFAB__Status__c = 'Draft';
            dn.RFAB__Date__c = system.today();
            insert dn;
        
            // Step 3: Create Stock Records from PO Items (Linked to Delivery Note)
            List<RFAB__Stock__c> stockRecords = new List<RFAB__Stock__c>();
            Id consumptionRecordTypeId = Schema.SObjectType.RFAB__Stock__c.getRecordTypeInfosByDeveloperName().get('Consumption').getRecordTypeId();
            for (RFAB__SO_Items__c soItem : soItems) {
                if (soItem.RFAB__Product__r.RFAB__Is_Serial_Number__c) {
                    
                    // If serial number tracking is enabled, create separate records for each unit
                    for (Integer i = 0; i < soItem.RFAB__Quantity__c; i++) {
                        RFAB__Stock__c stock = new RFAB__Stock__c();
                        Stock.Name = soItem.RFAB__Product__r.Name;
                        stock.RFAB__Delivery_Note__c = dn.Id;
                        stock.RFAB__Product__c = soItem.RFAB__Product__c;
                        stock.RFAB__Quantity__c = 1; // Each stock record has quantity = 1
                        stock.RFAB__Purchase_Price__c = soItem.RFAB__Unit_Price__c; // Setting Sales Price 
                        stock.RFAB__Unit_Of_Measure__c = soItem.RFAB__Unit_of_Measure__c;
                        stock.RecordTypeId = consumptionRecordTypeId; // Setting record type as consumption
                        stock.RFAB__VendorName__c = soItem.RFAB__Sales_Order__r.RFAB__Customer__c;
                        stock.RFAB__Location__c= loc.Id;
                        stockRecords.add(stock);
                    }
                } else {
                    // If serial number tracking is disabled, create one stock record for the entire quantity
                    RFAB__Stock__c stock = new RFAB__Stock__c();
                    Stock.Name = soItem.RFAB__Product__r.Name;
                    stock.RFAB__Delivery_Note__c = dn.Id;
                    stock.RFAB__Product__c = soItem.RFAB__Product__c;
                    stock.RFAB__Quantity__c = soItem.RFAB__Quantity__c; // Entire quantity in one record
                    stock.RFAB__Purchase_Price__c = soItem.RFAB__Unit_Price__c; // Setting Sales Price 
                    stock.RFAB__Unit_Of_Measure__c = soItem.RFAB__Unit_of_Measure__c;
                    stock.RecordTypeId = consumptionRecordTypeId; // Setting record type as consumption
                    stock.RFAB__VendorName__c = soItem.RFAB__Sales_Order__r.RFAB__Customer__c;
                    stock.RFAB__Location__c= loc.Id;
                    stockRecords.add(stock);
                }
            }
    
            if (!stockRecords.isEmpty()) {
                insert stockRecords;
            }
            return dn.Id; // Return the DN ID to LWC
        } catch (Exception e) {
            throw new AuraHandledException('Error while processing DN and Stock: ' + e.getMessage());
        }
    }
    @AuraEnabled
    public static void linkFilesToGRN(Id grnId, List<Id> contentDocumentIds) {
        List<ContentDocumentLink> links = new List<ContentDocumentLink>();

        for (Id docId : contentDocumentIds) {
            links.add(new ContentDocumentLink(
                LinkedEntityId = grnId, // Link to GRN record
                ContentDocumentId = docId,
                ShareType = 'V', // Viewer access
                Visibility = 'AllUsers' // File is visible to all users
            ));
        }

        if (!links.isEmpty()) {
            insert links;
        }
    }
    @AuraEnabled
    public static void updateFilesToGRN(List<Id> fileIds, Id grnId) {
        List<ContentDocumentLink> linksToDelete = [ 
            SELECT Id FROM ContentDocumentLink 
            WHERE ContentDocumentId IN :fileIds 
        ];

        if (!linksToDelete.isEmpty()) {
            delete linksToDelete;
        }

        // Grant access to GRN & Insert new links
        List<ContentDocumentLink> newLinks = new List<ContentDocumentLink>();
        for (Id fileId : fileIds) {
            newLinks.add(new ContentDocumentLink(
                LinkedEntityId = grnId,
                ContentDocumentId = fileId,
                ShareType = 'V' // Viewer access
            ));
        }

        insert newLinks;

        // Ensure the file is accessible by setting the Owner or modifying the library
        List<ContentDocument> docsToUpdate = [
            SELECT Id, OwnerId FROM ContentDocument WHERE Id IN :fileIds
        ];

        for (ContentDocument doc : docsToUpdate) {
            doc.OwnerId = UserInfo.getUserId(); // Change owner if needed
        }

        update docsToUpdate;
    }
    // AAB 25SEP2025 Utility methods for searching Chart of Accounts and uploading files to Salesforce.
    @AuraEnabled(cacheable=true)
    public static List<RFAB__Chart_of_Accounts__c> searchChartOfAccounts(String searchKey) {
        return [SELECT Id, Name FROM RFAB__Chart_of_Accounts__c WHERE Name LIKE :('%' + searchKey + '%') LIMIT 10];
    }
    @AuraEnabled
    public static Id uploadFileToServer(String fileName, String base64Data, String contentType) {
        // Decode the base64 string
        Blob fileBody = EncodingUtil.base64Decode(base64Data);

        ContentVersion cv = new ContentVersion();
        cv.Title = fileName;
        cv.PathOnClient = '/' + fileName;
        cv.VersionData = fileBody;
        cv.IsMajorVersion = true;
        insert cv;

        // Retrieve ContentDocumentId
        ContentVersion insertedCV = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
        System.debug('Inserted ContentVersion: ' + insertedCV.Id + ', ContentDocumentId: ' + insertedCV.ContentDocumentId);
        return insertedCV.ContentDocumentId;
    }
    //AAB 25OCT2025 Delete related Stock records when GRN is deleted
    public static void deleteRelatedStocks(List<RFAB__GRN__c> grnList) {
        if (grnList == null || grnList.isEmpty()) {
            return;
        }

        Set<Id> grnIds = new Set<Id>();
        for (RFAB__GRN__c grn : grnList) {
            grnIds.add(grn.Id);
        }

        if (!grnIds.isEmpty()) {
            List<RFAB__Stock__c> stocksToDelete = [
                SELECT Id
                FROM RFAB__Stock__c
                WHERE RFAB__GRN__c IN :grnIds
            ];

            List<RFAB__Expense__c> expensesToDelete = [
                SELECT Id
                FROM RFAB__Expense__c
                WHERE RFAB__GRN__c IN :grnIds
            ];

            if (!stocksToDelete.isEmpty()) {
                try {
                    delete stocksToDelete;
                    System.debug('Related Stock records deleted successfully: ' + stocksToDelete.size());
                } catch (DmlException e) {
                    System.debug('Error deleting related Stock records: ' + e.getMessage());
                }
            }

            if (!expensesToDelete.isEmpty()) {
                try {
                    delete expensesToDelete;
                    System.debug('Related Expense records deleted successfully: ' + expensesToDelete.size());
                } catch (DmlException e) {
                    System.debug('Error deleting related Expense records: ' + e.getMessage());
                }
            }
        }
    }

    @AuraEnabled
    public static Map<String, Object> getOrCreateDraftGRN(Id poId) {
        try {
            Map<String, Object> result = new Map<String, Object>();
            
            List<RFAB__GRN__c> existingDraftGRN = [
                SELECT Id, Name, RFAB__Date__c, RFAB__Status__c, RFAB__Purchase_Order__c,
                    Chart_of_Accounts__c, Chart_of_Accounts__r.Name,
                    (SELECT Id, Name, RFAB__Product__c, RFAB__Product__r.Name, 
                            RFAB__Product__r.RFAB__SKU__c, 
                            RFAB__Product__r.RFAB__Is_Serial_Number__c,
                            RFAB__Quantity__c, RFAB__Purchase_Price__c, 
                            Serial_Number__c, PO_Items__c, RFAB__Location__c
                        FROM RFAB__Stocks__r),
                    (SELECT Id, Name, RFAB__Date__c, RFAB__Description__c, 
                            RFAB__Amount_excluding__c, Tax_Amount__c, 
                            RFAB__Total_Amount__c, RFAB__Chart_of_Accounts__c,
                            RFAB__Chart_of_Accounts__r.Name
                        FROM RFAB__Expenses__r)
                FROM RFAB__GRN__c
                WHERE RFAB__Purchase_Order__c = :poId
                AND RFAB__Status__c = 'Draft'
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            
            if (!existingDraftGRN.isEmpty()) {
                result.put('isDraft', true);
                result.put('grnId', existingDraftGRN[0].Id);
                result.put('grn', existingDraftGRN[0]);
                result.put('stockRecords', existingDraftGRN[0].RFAB__Stocks__r);
                result.put('expenseRecords', existingDraftGRN[0].RFAB__Expenses__r);
                
                // Get expense files
                Set<Id> expenseIds = new Set<Id>();
                for (RFAB__Expense__c exp : existingDraftGRN[0].RFAB__Expenses__r) {
                    expenseIds.add(exp.Id);
                }
                
                if (!expenseIds.isEmpty()) {
                    Map<Id, List<ContentDocumentLink>> expenseFileMap = getExpenseFiles(new List<Id>(expenseIds));
                    result.put('expenseFiles', expenseFileMap);
                }
                
                // NEW: Get GRN files
                List<ContentDocumentLink> grnFiles = [
                    SELECT Id, ContentDocumentId, ContentDocument.Title, 
                        ContentDocument.FileType, ContentDocument.ContentSize
                    FROM ContentDocumentLink
                    WHERE LinkedEntityId = :existingDraftGRN[0].Id
                ];
                result.put('grnFiles', grnFiles);
                
            } else {
                result.put('isDraft', false);
                result.put('grnId', null);
            }
            
            return result;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving Draft GRN: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static Map<Id, List<ContentDocumentLink>> getExpenseFiles(List<Id> expenseIds) {
        Map<Id, List<ContentDocumentLink>> fileMap = new Map<Id, List<ContentDocumentLink>>();
        
        List<ContentDocumentLink> links = [
            SELECT Id, ContentDocumentId, LinkedEntityId, ContentDocument.Title, 
                ContentDocument.FileType, ContentDocument.ContentSize
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :expenseIds
        ];
        
        for (ContentDocumentLink link : links) {
            if (!fileMap.containsKey(link.LinkedEntityId)) {
                fileMap.put(link.LinkedEntityId, new List<ContentDocumentLink>());
            }
            fileMap.get(link.LinkedEntityId).add(link);
        }
        
        return fileMap;
    }


    // Keep this helper method
    private static void deleteRelatedRecords(Id grnId) {
        // Delete existing Stock records
        List<RFAB__Stock__c> existingStocks = [
            SELECT Id FROM RFAB__Stock__c WHERE RFAB__GRN__c = :grnId
        ];
        if (!existingStocks.isEmpty()) {
            delete existingStocks;
        }
        
        // Delete existing Expense records (this will cascade delete expense file links)
        List<RFAB__Expense__c> existingExpenses = [
            SELECT Id FROM RFAB__Expense__c WHERE RFAB__GRN__c = :grnId
        ];
        if (!existingExpenses.isEmpty()) {
            delete existingExpenses;
        }
        
    }

    // NEW: Helper method to delete specific GRN files
    private static void deleteGRNFiles(Id grnId, List<Id> fileIdsToDelete) {
        if (fileIdsToDelete == null || fileIdsToDelete.isEmpty()) {
            System.debug('No files to delete');
            return;
        }
        
        System.debug('Attempting to delete files: ' + fileIdsToDelete);
        System.debug('From GRN: ' + grnId);
        
        // Query ContentDocumentLinks for the specific files linked to this GRN
        List<ContentDocumentLink> linksToDelete = [
            SELECT Id, ContentDocumentId, LinkedEntityId, ShareType
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :grnId
            AND ContentDocumentId IN :fileIdsToDelete
        ];
        
        System.debug('Found links to delete: ' + linksToDelete.size());
        
        if (!linksToDelete.isEmpty()) {
            Database.DeleteResult[] results = Database.delete(linksToDelete, false);
            for(Database.DeleteResult dr : results) {
                if (!dr.isSuccess()) {
                    System.debug('Error deleting link: ' + dr.getErrors());
                }
            }
            
            // Delete the actual ContentDocument if this was the last link
            Set<Id> documentsToCheck = new Set<Id>();
            for(ContentDocumentLink cdl : linksToDelete) {
                documentsToCheck.add(cdl.ContentDocumentId);
            }
            
            // Check for any remaining links to these documents
            List<ContentDocumentLink> remainingLinks = [
                SELECT ContentDocumentId 
                FROM ContentDocumentLink 
                WHERE ContentDocumentId IN :documentsToCheck
            ];
            
            Set<Id> documentsWithLinks = new Set<Id>();
            for(ContentDocumentLink cdl : remainingLinks) {
                documentsWithLinks.add(cdl.ContentDocumentId);
            }
            
            // Delete documents that have no more links
            List<ContentDocument> documentsToDelete = [
                SELECT Id 
                FROM ContentDocument 
                WHERE Id IN :documentsToCheck 
                AND Id NOT IN :documentsWithLinks
            ];
            
            if(!documentsToDelete.isEmpty()) {
                Database.delete(documentsToDelete);
            }
            
            System.debug('Successfully processed file deletions');
        } else {
            System.debug('No matching ContentDocumentLinks found for deletion');
        }
    }

    @AuraEnabled
    public static String saveDraftGRN(Id purchaseOrderId, Id existingGRNId,
                                    RFAB__Purchase_Order__c updatedpurchaseOrder,
                                    List<RFAB__PO_Item__c> poItems, 
                                    List<String> serialNumbers,
                                    List<RFAB__Expense__c> expenseItems, 
                                    List<List<Id>> expenseFileIdLists,
                                    String grnDeliveryDate,
                                    Id grnChartOfAccountId,
                                    List<Id> grnFileIds,
                                    List<Id> grnRemovedFileIds) {

        System.debug('=== Save Draft GRN Debug ===');
        System.debug('grnFileIds received: ' + grnFileIds);
        System.debug('grnRemovedFileIds received: ' + grnRemovedFileIds);
        System.debug('existingGRNId: ' + existingGRNId);
        try {
            RFAB__Purchase_Order__c po = [
                SELECT Id, Name, Sales_Order__c, RFAB__Vendor_Account__c, RFAB__Status__c
                FROM RFAB__Purchase_Order__c
                WHERE Id = :purchaseOrderId
            ];
            
            RFAB__GRN__c grn;
            Boolean isUpdate = (existingGRNId != null);
            
            if (isUpdate) {
                // Update existing Draft GRN
                grn = [SELECT Id FROM RFAB__GRN__c WHERE Id = :existingGRNId LIMIT 1];
                
                // Delete removed GRN files FIRST (before updating)
                if (grnRemovedFileIds != null && !grnRemovedFileIds.isEmpty()) {
                    deleteGRNFiles(existingGRNId, grnRemovedFileIds);
                }
                
                grn.RFAB__Date__c = String.isNotBlank(grnDeliveryDate) ? Date.valueOf(grnDeliveryDate) : System.today();
                grn.Chart_of_Accounts__c = grnChartOfAccountId;
                update grn;
                
                // Delete existing records
                deleteRelatedRecords(existingGRNId);
            }
            else {
                // Create new Draft GRN
                grn = new RFAB__GRN__c();
                grn.RFAB__Date__c = String.isNotBlank(grnDeliveryDate) ? Date.valueOf(grnDeliveryDate) : System.today();
                grn.RFAB__Status__c = 'Draft';
                grn.RFAB__Purchase_Order__c = po.Id;
                grn.RFAB__Batch_Info__c = 'Serial Number';
                grn.Chart_of_Accounts__c = grnChartOfAccountId;
                insert grn;
            }
            
            // Create Stock Records (same as CreateGRN)
            Id receiptRecordTypeId = Schema.SObjectType.RFAB__Stock__c.getRecordTypeInfosByDeveloperName().get('Receipt').getRecordTypeId();
            RFAB__Location__c loc = [SELECT Id, Name FROM RFAB__Location__c WITH SECURITY_ENFORCED LIMIT 1];
            
            List<RFAB__Stock__c> stockRecords = new List<RFAB__Stock__c>();
            Integer i = 0;
            for (RFAB__PO_Item__c poItem : poItems) {
                String serialNumber = (serialNumbers != null && serialNumbers.size() > i) ? serialNumbers[i] : null;
                
                RFAB__Stock__c stock = new RFAB__Stock__c();
                String trimmedName = poItem.Name != null ? 
                    (poItem.Name.length() > 80 ? poItem.Name.substring(0, 80) : poItem.Name) : null;
                stock.Name = trimmedName;
                stock.RFAB__GRN__c = grn.Id;
                stock.RFAB__Product__c = poItem.RFAB__Product__c;
                stock.RFAB__Quantity__c = poItem.RFAB__Product__r.RFAB__Is_Serial_Number__c ? 1 : poItem.RFAB__Quantity__c;
                stock.RFAB__Purchase_Price__c = poItem.RFAB__Unit_Price__c;
                stock.RFAB__Unit_Of_Measure__c = 'Each';
                stock.RecordTypeId = receiptRecordTypeId;
                stock.RFAB__Vendor_Account__c = po.RFAB__Vendor_Account__c;
                stock.Serial_Number__c = serialNumber;
                stock.PO_Items__c = poItem.Id;
                stock.RFAB__Location__c = loc.Id;
                stockRecords.add(stock);
                
                if (serialNumbers != null) {
                    i++;
                }
            }
            insert stockRecords;
            
            // Create Expense Records
            Id companyExpenseRecordTypeId = Schema.SObjectType.RFAB__Expense__c.getRecordTypeInfosByDeveloperName().get('Company_Expense').getRecordTypeId();
            List<RFAB__Expense__c> expenseRecords = new List<RFAB__Expense__c>();
            
            for (RFAB__Expense__c expItem : expenseItems) {
                if (expItem.RFAB__Date__c != null && 
                    expItem.RFAB__Description__c != null && 
                    expItem.RFAB__Amount_excluding__c != null && 
                    expItem.Tax_Amount__c != null && 
                    expItem.RFAB__Total_Amount__c != null && 
                    expItem.RFAB__Chart_of_Accounts__c != null) {
                    
                    RFAB__Expense__c exp = new RFAB__Expense__c();
                    exp.Name = expItem.Name;
                    exp.RFAB__GRN__c = grn.Id;
                    exp.RecordTypeId = companyExpenseRecordTypeId;
                    exp.RFAB__Date__c = expItem.RFAB__Date__c;
                    exp.RFAB__Description__c = expItem.RFAB__Description__c;
                    exp.RFAB__Amount_excluding__c = expItem.RFAB__Amount_excluding__c;
                    exp.Tax_Amount__c = expItem.Tax_Amount__c;
                    exp.RFAB__Total_Amount__c = expItem.RFAB__Total_Amount__c;
                    exp.RFAB__Chart_of_Accounts__c = expItem.RFAB__Chart_of_Accounts__c;
                    exp.Purchase_Order__c = po.Id;
                    expenseRecords.add(exp);
                }
            }
            insert expenseRecords;
            
            // Get existing file links to avoid duplicates
            Set<Id> existingGRNFileIds = new Set<Id>();
            
            if (isUpdate) {
                List<ContentDocumentLink> existingLinks = [
                    SELECT ContentDocumentId
                    FROM ContentDocumentLink
                    WHERE LinkedEntityId = :grn.Id
                ];
                for (ContentDocumentLink link : existingLinks) {
                    existingGRNFileIds.add(link.ContentDocumentId);
                }
            }
            
            // Link files
            List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();
            
            // Link expense files
            for (Integer j = 0; j < expenseRecords.size(); j++) {
                RFAB__Expense__c insertedExp = expenseRecords[j];
                List<Id> fileIds = (j < expenseFileIdLists.size()) ? expenseFileIdLists[j] : new List<Id>();
                
                for (Id fileId : fileIds) {
                    linksToInsert.add(new ContentDocumentLink(
                        LinkedEntityId = insertedExp.Id,
                        ContentDocumentId = fileId,
                        ShareType = 'V'
                    ));
                }
            }
            
            // NEW: Link GRN files (only if not already linked)
            if (grnFileIds != null && !grnFileIds.isEmpty()) {
                for (Id fileId : grnFileIds) {
                    if (!existingGRNFileIds.contains(fileId)) {
                        linksToInsert.add(new ContentDocumentLink(
                            LinkedEntityId = grn.Id,
                            ContentDocumentId = fileId,
                            ShareType = 'V'
                        ));
                    }
                }
            }
            
            if (!linksToInsert.isEmpty()) {
                insert linksToInsert;
            }
            
            return grn.Id;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error saving Draft GRN: ' + e.getMessage());
        }
    }
}
