public with sharing class JournalEntryController {

    @AuraEnabled(cacheable=true)
        public static List<Journal_Entry__c> getJournalEntriesForBill(Id billId) {
            return [SELECT Id, Name, Entry_Date__c, Currency__c, Exchange_rate__c 
                    FROM Journal_Entry__c 
                    WHERE Bill__c = :billId];
        }

    @AuraEnabled(cacheable=true)
    //Fetching record from journal entry
    public static List<Journal_Entry__c> getJournalEntryRecords(String recordId){
        
        return [SELECT Id,  Name, Credit_Chart_of_Accounts__c, Credit_Amount__c,Status__c,Bill__c,Foreign_Exchange__c,
                Debit_Chart_of_Accounts__c,  Debit_Amount__c,Entry_Date__c,  Type__c, Total_Amount__c, Final_Amount__c,Foreign_Amount__c,
                (SELECT Id,  Name, Credit_Chart_of_Accounts__c, Credit_Amount__c,
                Debit_Chart_of_Accounts__c,Entry_Date__c, Debit_Amount__c, Debit_Description__c, Credit_Description__c from Journal_Entries__r),
                Description__c,  Debit_Cart_Record_Type__c, Credit_Cart_Record_Type__c,
                Parent_Journal_Entry__c, Has_Debit_Child__c, Has_Credit_Child__c, Debit_Description__c, Credit_Description__c, Currency__c, Exchange_rate__c 
                FROM Journal_Entry__c where id=:recordId WITH SECURITY_ENFORCED]; 
    }

    @AuraEnabled(cacheable=true)
    public static List<ContentVersion> getdocuments(Id recordId) {
        List<ContentDocumentLink> doclink =[SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :recordId With SECURITY_ENFORCED];
        List<Id> contentDocumentIds = new List<Id>();
         for (ContentDocumentLink link : doclink) { 
            contentDocumentIds.add(link.ContentDocumentId);
         }
         List<ContentVersion> cv = [ SELECT Id, Title,ContentDocumentId FROM ContentVersion WHERE ContentDocumentId IN :contentDocumentIds WITH SECURITY_ENFORCED];
         return cv;
    }

    @AuraEnabled
    public static string saveJournalEntries(String jsonRows, Id recordId,string header, string post, List<Map<String, Object>> files, boolean reverseflag) {
        Map<String, Object> head = (Map<String, Object>) JSON.deserializeUntyped(header);
        String comments = (String) head.get('Comments__c');
        // Deserialize the JSON string into a generic List<Object>
        List<Object> rawRows = (List<Object>) JSON.deserializeUntyped(jsonRows);
        List<Map<String, Object>> rows = new List<Map<String, Object>>();
        
        // Safely cast each item in the list to a Map<String, Object>
        for (Object rawRow : rawRows) {
            if (rawRow instanceof Map<String, Object>) {
                rows.add((Map<String, Object>) rawRow);
            }
        }
        if (rows == null || rows.isEmpty() && head == null) {
            throw new AuraHandledException('No data to save.');
        }

        Decimal totalDebit = 0;
        Decimal totalCredit = 0;
        List<Journal_Entry__c> childEntries = new List<Journal_Entry__c>();
        List<Map<String, Object>> debitRows = new List<Map<String, Object>>();
        List<Map<String, Object>> creditRows = new List<Map<String, Object>>();

        // Parent Journal Entry record
        Journal_Entry__c parentEntry = new Journal_Entry__c();
        parentEntry.Comments__c = comments;
      
        // Separate rows with Debit and Credit values
        for (Map<String, Object> row : rows) {
            if (row.get('debit') != null) {
                Decimal debitValue = Decimal.valueOf(String.valueOf(row.get('debit')));
                if (debitValue > 0) {
                    totalDebit += debitValue;
                    debitRows.add(row);
                }
            }

            if (row.get('credit') != null) {
                Decimal creditValue = Decimal.valueOf(String.valueOf(row.get('credit')));
                if (creditValue > 0) {
                    totalCredit += creditValue;
                    creditRows.add(row);
                }
            }
        }
        
        String billIdStr = (String) head.get('billId');
        Id billId;
        if (String.isNotBlank(billIdStr)) {
            billId = (Id) billIdStr;
        } else {
            billId = null;
        }

        System.debug('debitRows: ' + debitRows);
        System.debug('creditRows: ' + creditRows);
        System.debug('reverseflag: ' + reverseflag);
        System.debug('recordId----->'+ recordId);
        
        // Set Parent Entry fields
        // if(recordId != null && reverseflag == true){
        //     Journal_Entry__c reverseEntry = [SELECT Id, Name, Type__c, Entry_Date__c, Debit_Amount__c, Credit_Amount__c,Comments__c,
        //                    Debit_Chart_of_Accounts__c, Credit_Chart_of_Accounts__c, Foreign_Amount__c,
        //                    Has_Debit_Child__c, Has_Credit_Child__c, Status__c, 
        //                    Debit_Description__c, Credit_Description__c, Currency__c, Exchange_rate__c 
        //                    FROM Journal_Entry__c WHERE Id = :recordId LIMIT 1];

        //                 reverseEntry.Status__c = 'Reversed';
        //                 reverseEntry.Comments__c = comments;
        //                 // reverseEntry.Foreign_Amount__c = parentEntry.Foreign_Exchange__c;
        //                 update reverseEntry;              
        // } 
       
        parentEntry.Entry_Date__c = Date.valueOf((String) head.get('date'));
        parentEntry.Name=String.valueOf(head.get('name'));
        parentEntry.Currency__c=String.valueOf(head.get('currency'));
        Decimal exchangeRate = Decimal.valueOf(String.valueOf(head.get('exchangerate')));
        parentEntry.Exchange_rate__c= exchangeRate != null ? exchangeRate : 1.0;
        parentEntry.Type__c='Journal';
        parentEntry.Status__c=String.valueOf(head.get('status')) != '' ? String.valueOf(head.get('status')) : 'Draft';
        // Robust Foreign Exchange boolean handling
        Object fxVal = head.get('isforeignexchange');
        if (fxVal != null) {
            if (fxVal instanceof Boolean) {
                parentEntry.Foreign_Exchange__c = (Boolean)fxVal;
            } else if (fxVal instanceof String) {
                parentEntry.Foreign_Exchange__c = ((String)fxVal).toLowerCase() == 'true';
            } else {
                parentEntry.Foreign_Exchange__c = false;
            }
        }
        // Set Foreign_Amount__c from header.amount
        System.debug('Setting Foreign_Amount__c from header.amount: ' + head.get('amount'));
        if (head.containsKey('amount') && head.get('amount') != null) {
            parentEntry.Foreign_Amount__c = Decimal.valueOf(String.valueOf(head.get('amount')));
            System.debug('Foreign_Amount__c: ' + parentEntry.Foreign_Amount__c);
        }

        if(post == 'true'){
            parentEntry.Status__c='Published';
        }
        parentEntry.Debit_Amount__c = totalDebit;
        parentEntry.Bill__c= billId;
        
        
        // Handle simple entries (less than 3 rows)
        if (rows.size() < 3) {
            for (Map<String, Object> row : rows) {
                Decimal debitValue = row.get('debit') != null ? Decimal.valueOf(String.valueOf(row.get('debit'))) : 0;
                Decimal creditValue = row.get('credit') != null ? Decimal.valueOf(String.valueOf(row.get('credit'))) : 0;
                
                if (debitValue > 0) {
                    parentEntry.Debit_Amount__c = debitValue;
                    if (reverseflag) {
                        // When reversing, debit becomes credit
                        parentEntry.Credit_Chart_of_Accounts__c = (String) row.get('accountId');
                        parentEntry.Credit_Description__c = (String) row.get('description');
                    } else {
                        // Normal case - debit stays debit
                        parentEntry.Debit_Chart_of_Accounts__c = (String) row.get('accountId');
                        parentEntry.Debit_Description__c = (String) row.get('description');
                    }
                    parentEntry.Final_Amount__c = debitValue;
                }
                else if(creditValue > 0){
                    parentEntry.Credit_Amount__c = creditValue;
                    if (reverseflag) {
                        // When reversing, credit becomes debit
                        parentEntry.Debit_Chart_of_Accounts__c = (String) row.get('accountId');
                        parentEntry.Debit_Description__c = (String) row.get('description');
                    } else {
                        // Normal case - credit stays credit
                        parentEntry.Credit_Chart_of_Accounts__c = (String) row.get('accountId');
                        parentEntry.Credit_Description__c = (String) row.get('description');
                    }
                    parentEntry.Final_Amount__c = creditValue;
                }
            }
        } 
        // Handle complex entries (3 or more rows)
        else {
            System.debug('recod-------->'+ recordId);
            // Apply reverse flag logic to parent entry assignments
            if (reverseflag==true) {
                // When reversing, swap debit and credit assignments
                if(creditRows.size() == 1){
                    parentEntry.Debit_Chart_of_Accounts__c = (Id) creditRows[0].get('accountId');
                    parentEntry.Debit_Description__c = (String) creditRows[0].get('description');
                    parentEntry.Final_Amount__c = Decimal.valueOf(string.valueOf(creditRows[0].get('credit')));
                }
                if(debitRows.size() == 1){
                    parentEntry.Credit_Chart_of_Accounts__c = (Id) debitRows[0].get('accountId');
                    parentEntry.Credit_Description__c = (String) debitRows[0].get('description');
                    parentEntry.Final_Amount__c = Decimal.valueOf(string.valueOf(debitRows[0].get('debit')));
                }
                
                // Swap the amounts when reversing
                parentEntry.Debit_Amount__c = totalCredit;
                parentEntry.Credit_Amount__c = totalDebit;
                
                // Swap the child flags when reversing
                if(creditRows.size() > 1){
                    parentEntry.Has_Debit_Child__c = true;
                }
                if(debitRows.size() > 1){
                    parentEntry.Has_Credit_Child__c = true;
                }
            } else {
                // Normal case - no reversal
                if(debitRows.size() == 1){
                    parentEntry.Debit_Chart_of_Accounts__c = (Id) debitRows[0].get('accountId');
                    parentEntry.Debit_Description__c = (String) debitRows[0].get('description');
                    parentEntry.Final_Amount__c = Decimal.valueOf(string.valueOf(debitRows[0].get('debit')));
                }
                if(creditRows.size() == 1){
                    parentEntry.Credit_Chart_of_Accounts__c = (Id) creditRows[0].get('accountId');
                    parentEntry.Credit_Description__c = (String) creditRows[0].get('description');
                    parentEntry.Final_Amount__c = Decimal.valueOf(string.valueOf(creditRows[0].get('credit')));
                }
                
                parentEntry.Debit_Amount__c = totalDebit;
                parentEntry.Credit_Amount__c = totalCredit;
                
                if(debitRows.size() > 1){
                    parentEntry.Has_Debit_Child__c = true;
                }
                if(creditRows.size() > 1){
                    parentEntry.Has_Credit_Child__c = true;
                }
            }
        }

        // Insert or Update parent entry
        if(recordId==null){
            if(Journal_Entry__c.SObjectType.getDescribe().isCreateable() &&
            Schema.sObjectType.Journal_Entry__c.fields.Name.isCreateable() &&
            Schema.sObjectType.Journal_Entry__c.fields.Type__c.isCreateable() &&
            Schema.sObjectType.Journal_Entry__c.fields.Entry_Date__c.isCreateable() &&
            Schema.sObjectType.Journal_Entry__c.fields.Debit_Amount__c.isCreateable() &&
            Schema.sObjectType.Journal_Entry__c.fields.Debit_Chart_of_Accounts__c.isCreateable() &&
            Schema.sObjectType.Journal_Entry__c.fields.Credit_Amount__c.isCreateable() &&
            Schema.sObjectType.Journal_Entry__c.fields.Credit_Chart_of_Accounts__c.isCreateable() &&
            Schema.sObjectType.Journal_Entry__c.fields.Has_Debit_Child__c.isCreateable() &&
            Schema.sObjectType.Journal_Entry__c.fields.Has_Credit_Child__c.isCreateable()&& 
            Schema.sObjectType.Journal_Entry__c.fields.Status__c.isCreateable()&&
            Schema.sObjectType.Journal_Entry__c.fields.Debit_Description__c.isCreateable()&&
            Schema.sObjectType.Journal_Entry__c.fields.Credit_Description__c.isCreateable()&&
            Schema.sObjectType.Journal_Entry__c.fields.Exchange_rate__c.isCreateable()&&
            Schema.sObjectType.Journal_Entry__c.fields.Currency__c.isCreateable()&&
            Schema.sObjectType.Journal_Entry__c.fields.Foreign_Exchange__c.isCreateable() &&
            Schema.sObjectType.Journal_Entry__c.fields.Comments__c.isCreateable()&&
            Schema.sObjectType.Journal_Entry__c.fields.Final_Amount__c.isCreateable())
            {
                Insert parentEntry;

            }                 
        }
        else {
            if(Journal_Entry__c.SObjectType.getDescribe().isUpdateable() &&
            Schema.sObjectType.Journal_Entry__c.fields.Name.isUpdateable() &&
            Schema.sObjectType.Journal_Entry__c.fields.Type__c.isUpdateable() &&
            Schema.sObjectType.Journal_Entry__c.fields.Entry_Date__c.isUpdateable() &&
            Schema.sObjectType.Journal_Entry__c.fields.Debit_Amount__c.isUpdateable() &&
            Schema.sObjectType.Journal_Entry__c.fields.Debit_Chart_of_Accounts__c.isUpdateable() &&
            Schema.sObjectType.Journal_Entry__c.fields.Credit_Amount__c.isUpdateable() &&
            Schema.sObjectType.Journal_Entry__c.fields.Credit_Chart_of_Accounts__c.isUpdateable() &&
            Schema.sObjectType.Journal_Entry__c.fields.Has_Debit_Child__c.isUpdateable() &&
            Schema.sObjectType.Journal_Entry__c.fields.Has_Credit_Child__c.isUpdateable()&&
            Schema.sObjectType.Journal_Entry__c.fields.Status__c.isUpdateable()&&
            Schema.sObjectType.Journal_Entry__c.fields.Debit_Description__c.isUpdateable()&&
            Schema.sObjectType.Journal_Entry__c.fields.Credit_Description__c.isUpdateable()&&
            Schema.sObjectType.Journal_Entry__c.fields.Exchange_rate__c.isUpdateable()&&
            Schema.sObjectType.Journal_Entry__c.fields.Currency__c.isUpdateable()&&
            Schema.sObjectType.Journal_Entry__c.fields.Foreign_Exchange__c.isCreateable() &&
            Schema.sObjectType.Journal_Entry__c.fields.Comments__c.isUpdateable()&&
            Schema.sObjectType.Journal_Entry__c.fields.Final_Amount__c.isUpdateable())
            {   
                parentEntry.Id = recordId;
                Update parentEntry;
            }               
        }

        // Create child entries with reverse flag logic
        // Handle Debit rows (or Credit rows if reversing)
        List<Map<String, Object>> sourceDebitRows = reverseflag ? creditRows : debitRows;
        if (sourceDebitRows.size() > 1) {
            for (Map<String, Object> row : sourceDebitRows) {
                Decimal rowAmount = reverseflag ? 
                    Decimal.valueOf(String.valueOf(row.get('credit'))) : 
                    Decimal.valueOf(String.valueOf(row.get('debit')));
                    
                if(recordId==null){
                    childEntries.add(new Journal_Entry__c(
                        Name = 'Journal Child Debit',
                        Type__c = 'Journal',
                        Debit_Chart_of_Accounts__c = (String) row.get('accountId'),
                        Debit_Amount__c = rowAmount,
                        Entry_Date__c = Date.valueOf((String) head.get('date')),
                        Parent_Journal_Entry__c = parentEntry.Id,
                        Status__c='Draft',
                        Debit_Description__c = (String) row.get('description'),
                        Reference_Account__c = reverseflag ? parentEntry.Debit_Chart_of_Accounts__c : parentEntry.Credit_Chart_of_Accounts__c,
                        ReferenceAmount__c = rowAmount,
                        Final_Amount__c = rowAmount
                    ));
                }else{
                    childEntries.add(new Journal_Entry__c(
                        Name = 'Journal Child Debit',
                        Type__c = 'Journal',
                        Debit_Chart_of_Accounts__c = (String) row.get('accountId'),
                        Debit_Amount__c = rowAmount,
                        Entry_Date__c = Date.valueOf((String) head.get('date')),
                        Parent_Journal_Entry__c = parentEntry.Id,
                        Id=(Id) row.get('recid'),
                        Debit_Description__c = (String) row.get('description'),
                        Reference_Account__c = reverseflag ? parentEntry.Debit_Chart_of_Accounts__c : parentEntry.Credit_Chart_of_Accounts__c,
                        ReferenceAmount__c = rowAmount,
                        Final_Amount__c = rowAmount
                    ));
                }                
            }
        }

        // Handle Credit rows (or Debit rows if reversing)
        List<Map<String, Object>> sourceCreditRows = reverseflag ? debitRows : creditRows;
        if (sourceCreditRows.size() > 1) {
            for (Map<String, Object> row : sourceCreditRows) {
                Decimal rowAmount = reverseflag ? 
                    Decimal.valueOf(String.valueOf(row.get('debit'))) : 
                    Decimal.valueOf(String.valueOf(row.get('credit')));
                    
                if(recordId==null){
                    childEntries.add(new Journal_Entry__c(
                        Name = 'Journal Child Credit',
                        Type__c = 'Journal',
                        Credit_Chart_of_Accounts__c = (String) row.get('accountId'),
                        Credit_Amount__c = rowAmount,
                        Entry_Date__c = Date.valueOf((String) head.get('date')),
                        Parent_Journal_Entry__c = parentEntry.Id,
                        Status__c='Draft',
                        Credit_Description__c = (String) row.get('description'),
                        Reference_Account__c = reverseflag ? parentEntry.Credit_Chart_of_Accounts__c : parentEntry.Debit_Chart_of_Accounts__c,
                        ReferenceAmount__c = rowAmount,
                        Final_Amount__c = rowAmount
                    )); 
                }else{
                    childEntries.add(new Journal_Entry__c(
                        Name = 'Journal Child Credit',
                        Type__c = 'Journal',
                        Credit_Chart_of_Accounts__c = (String) row.get('accountId'),
                        Credit_Amount__c = rowAmount,
                        Entry_Date__c = Date.valueOf((String) head.get('date')),
                        Parent_Journal_Entry__c = parentEntry.Id,
                        Id=(Id) row.get('recid'),
                        Credit_Description__c = (String) row.get('description'),
                        Reference_Account__c = reverseflag ? parentEntry.Credit_Chart_of_Accounts__c : parentEntry.Debit_Chart_of_Accounts__c,
                        ReferenceAmount__c = rowAmount,
                        Final_Amount__c = rowAmount
                    ));
                }
            }
        }
        
        // Insert child entries
        if (!childEntries.isEmpty()) {
            if(recordId==null){
                if(Journal_Entry__c.SObjectType.getDescribe().isCreateable() &&
                Schema.sObjectType.Journal_Entry__c.fields.Name.isCreateable() &&
                Schema.sObjectType.Journal_Entry__c.fields.Type__c.isCreateable() &&
                Schema.sObjectType.Journal_Entry__c.fields.Credit_Chart_of_Accounts__c.isCreateable() &&
                Schema.sObjectType.Journal_Entry__c.fields.Credit_Amount__c.isCreateable() &&
                Schema.sObjectType.Journal_Entry__c.fields.Entry_Date__c.isCreateable() &&
                Schema.sObjectType.Journal_Entry__c.fields.Parent_Journal_Entry__c.isCreateable() &&
                Schema.sObjectType.Journal_Entry__c.fields.Debit_Amount__c.isCreateable() &&
                Schema.sObjectType.Journal_Entry__c.fields.Debit_Chart_of_Accounts__c.isCreateable()&&
                Schema.sObjectType.Journal_Entry__c.fields.Status__c.isCreateable()&&
                Schema.sObjectType.Journal_Entry__c.fields.Debit_Description__c.isCreateable()&&
                Schema.sObjectType.Journal_Entry__c.fields.Credit_Description__c.isCreateable()&&
                Schema.sObjectType.Journal_Entry__c.fields.Reference_Account__c.isCreateable()&&
                Schema.sObjectType.Journal_Entry__c.fields.ReferenceAmount__c.isCreateable()&&
                Schema.sObjectType.Journal_Entry__c.fields.Foreign_Exchange__c.isCreateable() &&
                Schema.sObjectType.Journal_Entry__c.fields.Final_Amount__c.isCreateable())
                {
                    Insert childEntries;
                }                   
            }
            else{
                if(Journal_Entry__c.SObjectType.getDescribe().isUpdateable() &&
                Schema.sObjectType.Journal_Entry__c.fields.Name.isUpdateable() &&
                Schema.sObjectType.Journal_Entry__c.fields.Type__c.isUpdateable() &&
                Schema.sObjectType.Journal_Entry__c.fields.Credit_Chart_of_Accounts__c.isUpdateable() &&
                Schema.sObjectType.Journal_Entry__c.fields.Credit_Amount__c.isUpdateable() &&
                Schema.sObjectType.Journal_Entry__c.fields.Entry_Date__c.isUpdateable() &&
                Schema.sObjectType.Journal_Entry__c.fields.Parent_Journal_Entry__c.isUpdateable() &&
                Schema.sObjectType.Journal_Entry__c.fields.Debit_Amount__c.isUpdateable() &&
                Schema.sObjectType.Journal_Entry__c.fields.Debit_Chart_of_Accounts__c.isUpdateable()&&
                Schema.sObjectType.Journal_Entry__c.fields.Status__c.isUpdateable()&&
                Schema.sObjectType.Journal_Entry__c.fields.Debit_Description__c.isUpdateable()&&
                Schema.sObjectType.Journal_Entry__c.fields.Credit_Description__c.isUpdateable()&&
                Schema.sObjectType.Journal_Entry__c.fields.Reference_Account__c.isUpdateable()&&
                Schema.sObjectType.Journal_Entry__c.fields.ReferenceAmount__c.isUpdateable()&&
                Schema.sObjectType.Journal_Entry__c.fields.Final_Amount__c.isUpdateable()&&
                Journal_Entry__c.SObjectType.getDescribe().isCreateable() &&
                Schema.sObjectType.Journal_Entry__c.fields.Name.isCreateable() &&
                Schema.sObjectType.Journal_Entry__c.fields.Type__c.isCreateable() &&
                Schema.sObjectType.Journal_Entry__c.fields.Credit_Chart_of_Accounts__c.isCreateable() &&
                Schema.sObjectType.Journal_Entry__c.fields.Credit_Amount__c.isCreateable() &&
                Schema.sObjectType.Journal_Entry__c.fields.Entry_Date__c.isCreateable() &&
                Schema.sObjectType.Journal_Entry__c.fields.Parent_Journal_Entry__c.isCreateable() &&
                Schema.sObjectType.Journal_Entry__c.fields.Debit_Amount__c.isCreateable() &&
                Schema.sObjectType.Journal_Entry__c.fields.Debit_Chart_of_Accounts__c.isCreateable()&&
                Schema.sObjectType.Journal_Entry__c.fields.Status__c.isCreateable()&&
                Schema.sObjectType.Journal_Entry__c.fields.Debit_Description__c.isCreateable()&&
                Schema.sObjectType.Journal_Entry__c.fields.Credit_Description__c.isCreateable()&&
                Schema.sObjectType.Journal_Entry__c.fields.Reference_Account__c.isCreateable()&&
                Schema.sObjectType.Journal_Entry__c.fields.ReferenceAmount__c.isCreateable()&&
                Schema.sObjectType.Journal_Entry__c.fields.Foreign_Exchange__c.isCreateable() &&
                Schema.sObjectType.Journal_Entry__c.fields.Final_Amount__c.isCreateable())
                {
                    Upsert childEntries;
                }
            }        
        }
        
        if (parentEntry.Id != null && post == 'true') {
            GeneralLedgerCreator.createGeneralLedgerRecords(String.valueOf(parentEntry.Id));
        }
        
        List<ContentDocumentLink> contentDocumentLinks = new List<ContentDocumentLink>();

        for (map<string,object> cv : files) {
            contentDocumentLinks.add(new ContentDocumentLink(
                ContentDocumentId = (Id) cv.get('documentId'),
                LinkedEntityId = parentEntry.Id,
                ShareType = 'V' , // 'V' for Viewer permission
                Visibility = 'AllUsers'
            ));
        }

        if(ContentDocumentLink.SObjectType.getDescribe().isCreateable() &&
        Schema.sObjectType.ContentDocumentLink.fields.ContentDocumentId.isCreateable() &&
        Schema.sObjectType.ContentDocumentLink.fields.LinkedEntityId.isCreateable() &&
        Schema.sObjectType.ContentDocumentLink.fields.ShareType.isCreateable() &&
        Schema.sObjectType.ContentDocumentLink.fields.Visibility.isCreateable()){
          insert contentDocumentLinks;
        }
        
        System.debug('parentEntry: ' + parentEntry.Id);
        return parentEntry.Id;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getCurrencyPicklistValues() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        
        Schema.DescribeFieldResult fieldResult = Journal_Entry__c.Currency__c.getDescribe();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        
        for(Schema.PicklistEntry entry : ple) {
            options.add(new Map<String, String>{
                'label' => entry.getLabel(),
                'value' => entry.getValue()
            });
        }
        return options;
    }

    //KK 11/12/2023 Remove file from journal entry
    @AuraEnabled
    public static void deleteFileFromJE(Id contentDocumentId, Id journalEntryId) {
        // First, delete the link between the document and the journal entry
        List<ContentDocumentLink> linksToDelete = [
            SELECT Id FROM ContentDocumentLink 
            WHERE ContentDocumentId = :contentDocumentId AND LinkedEntityId = :journalEntryId
        ];

        if (!linksToDelete.isEmpty()) {
            delete linksToDelete;
            //Delete the content document itself
            delete [SELECT Id FROM ContentDocument WHERE Id = :contentDocumentId];
        }
    }

    //KK 14/Jun/25 Automated JE creation Function
    @AuraEnabled
    public static Id createJournalEntry(
        String name,
        String currencycode,
        Decimal exchangeRate,
        Date entryDate,
        Decimal amount,
        List<Map<String, Object>> debitList,
        List<Map<String, Object>> creditList
    ) {
        Decimal totalDebit = 0;
        Decimal totalCredit = 0;

        Journal_Entry__c parentEntry = new Journal_Entry__c();
        parentEntry.Name = name;
        parentEntry.Currency__c = currencycode;
        parentEntry.Exchange_rate__c = exchangeRate != null ? exchangeRate : 1;
        parentEntry.Entry_Date__c = entryDate;
        parentEntry.Type__c = 'Journal';
        parentEntry.Status__c = 'Draft';

        List<Journal_Entry__c> childEntries = new List<Journal_Entry__c>();

        // Calculate total debit and credit
        for (Map<String, Object> row : debitList) {
            Decimal debitValue = Decimal.valueOf(String.valueOf(row.get('amount')));
            totalDebit += debitValue;
        }
        for (Map<String, Object> row : creditList) {
            Decimal creditValue = Decimal.valueOf(String.valueOf(row.get('amount')));
            totalCredit += creditValue;
        }

        parentEntry.Debit_Amount__c = exchangeRate != null ? totalDebit * exchangeRate : totalDebit;
        parentEntry.Credit_Amount__c = exchangeRate != null ? totalCredit * exchangeRate : totalCredit;
        parentEntry.Final_Amount__c = amount;

        // Assign single debit/credit if only one in each list
        if (debitList.size() == 1) {
            Map<String, Object> row = debitList[0];
            parentEntry.Debit_Chart_of_Accounts__c = (String) row.get('COA');
            parentEntry.Debit_Description__c = (String) row.get('Description');
        } else if (debitList.size() > 1) {
            parentEntry.Has_Debit_Child__c = true;
        }

        if (creditList.size() == 1) {
            Map<String, Object> row = creditList[0];
            parentEntry.Credit_Chart_of_Accounts__c = (String) row.get('COA');
            parentEntry.Credit_Description__c = (String) row.get('Description');
        } else if (creditList.size() > 1) {
            parentEntry.Has_Credit_Child__c = true;
        }

        if(Journal_Entry__c.SObjectType.getDescribe().isCreateable() &&
        Schema.sObjectType.Journal_Entry__c.fields.Name.isCreateable() &&
        Schema.sObjectType.Journal_Entry__c.fields.Type__c.isCreateable() &&
        Schema.sObjectType.Journal_Entry__c.fields.Entry_Date__c.isCreateable() &&
        Schema.sObjectType.Journal_Entry__c.fields.Debit_Amount__c.isCreateable() &&
        Schema.sObjectType.Journal_Entry__c.fields.Debit_Chart_of_Accounts__c.isCreateable() &&
        Schema.sObjectType.Journal_Entry__c.fields.Credit_Amount__c.isCreateable() &&
        Schema.sObjectType.Journal_Entry__c.fields.Credit_Chart_of_Accounts__c.isCreateable() &&
        Schema.sObjectType.Journal_Entry__c.fields.Has_Debit_Child__c.isCreateable() &&
        Schema.sObjectType.Journal_Entry__c.fields.Has_Credit_Child__c.isCreateable()&& 
        Schema.sObjectType.Journal_Entry__c.fields.Status__c.isCreateable()&&
        Schema.sObjectType.Journal_Entry__c.fields.Debit_Description__c.isCreateable()&&
        Schema.sObjectType.Journal_Entry__c.fields.Credit_Description__c.isCreateable()&&
        Schema.sObjectType.Journal_Entry__c.fields.Exchange_rate__c.isCreateable()&&
        Schema.sObjectType.Journal_Entry__c.fields.Currency__c.isCreateable()&&
        Schema.sObjectType.Journal_Entry__c.fields.Final_Amount__c.isCreateable())
        {
            insert parentEntry;
        }

        // Child debit entries
        if (debitList.size() > 1) {
            for (Map<String, Object> row : debitList) {
                Decimal debit = Decimal.valueOf(String.valueOf(row.get('amount')));
                childEntries.add(new Journal_Entry__c(
                    Name = 'Journal Child Debit',
                    Type__c = 'Journal',
                    Entry_Date__c = entryDate,
                    Parent_Journal_Entry__c = parentEntry.Id,
                    Debit_Chart_of_Accounts__c = (String) row.get('COA'),
                    Debit_Amount__c = exchangeRate != null ? debit * exchangeRate : debit,
                    Final_Amount__c = exchangeRate != null ? debit * exchangeRate : debit,
                    Debit_Description__c = (String) row.get('Description'),
                    Reference_Account__c = parentEntry.Credit_Chart_of_Accounts__c,
                    ReferenceAmount__c = exchangeRate != null ? debit * exchangeRate : debit,
                    Status__c = 'Draft'
                ));
            }
        }

        // Child credit entries
        if (creditList.size() > 1) {
            for (Map<String, Object> row : creditList) {
                Decimal credit = Decimal.valueOf(String.valueOf(row.get('amount')));
                childEntries.add(new Journal_Entry__c(
                    Name = 'Journal Child Credit',
                    Type__c = 'Journal',
                    Entry_Date__c = entryDate,
                    Parent_Journal_Entry__c = parentEntry.Id,
                    Credit_Chart_of_Accounts__c = (String) row.get('COA'),
                    Credit_Amount__c = exchangeRate != null ? credit * exchangeRate : credit,
                    Final_Amount__c = exchangeRate != null ? credit * exchangeRate : credit,
                    Credit_Description__c = (String) row.get('Description'),
                    Reference_Account__c = parentEntry.Debit_Chart_of_Accounts__c,
                    ReferenceAmount__c = exchangeRate != null ? credit * exchangeRate : credit,
                    Status__c = 'Draft'
                ));
            }
        }

        if (!childEntries.isEmpty()) {
            if(Journal_Entry__c.SObjectType.getDescribe().isCreateable() &&
            Schema.sObjectType.Journal_Entry__c.fields.Name.isCreateable() &&
            Schema.sObjectType.Journal_Entry__c.fields.Type__c.isCreateable() &&
            Schema.sObjectType.Journal_Entry__c.fields.Credit_Chart_of_Accounts__c.isCreateable() &&
            Schema.sObjectType.Journal_Entry__c.fields.Credit_Amount__c.isCreateable() &&
            Schema.sObjectType.Journal_Entry__c.fields.Entry_Date__c.isCreateable() &&
            Schema.sObjectType.Journal_Entry__c.fields.Parent_Journal_Entry__c.isCreateable() &&
            Schema.sObjectType.Journal_Entry__c.fields.Debit_Amount__c.isCreateable() &&
            Schema.sObjectType.Journal_Entry__c.fields.Debit_Chart_of_Accounts__c.isCreateable()&&
            Schema.sObjectType.Journal_Entry__c.fields.Status__c.isCreateable()&&
            Schema.sObjectType.Journal_Entry__c.fields.Debit_Description__c.isCreateable()&&
            Schema.sObjectType.Journal_Entry__c.fields.Credit_Description__c.isCreateable()&&
            Schema.sObjectType.Journal_Entry__c.fields.Reference_Account__c.isCreateable()&&
            Schema.sObjectType.Journal_Entry__c.fields.ReferenceAmount__c.isCreateable()&&
            Schema.sObjectType.Journal_Entry__c.fields.Foreign_Exchange__c.isCreateable() &&
            Schema.sObjectType.Journal_Entry__c.fields.Final_Amount__c.isCreateable())
            {
                insert childEntries;
            }
        }
        return parentEntry.Id;
    }

    @AuraEnabled(cacheable=true)
    public static List<DocumentWrapper> getJournalEntryAttachments(List<Id> journalEntryIds) {
        List<DocumentWrapper> wrappers = new List<DocumentWrapper>();
        if (journalEntryIds == null || journalEntryIds.isEmpty()) {
            return wrappers;
        }

        // Query Journal Entries with their ContentDocumentLinks and ContentDocuments
        List<Journal_Entry__c> journalEntries = [
            SELECT Id, Name, Entry_Date__c, Total_Amount__c, 
                (SELECT ContentDocumentId, ContentDocument.Title,
                ContentDocument.FileExtension, ContentDocument.FileType
                FROM ContentDocumentLinks)
            FROM Journal_Entry__c
            WHERE Id IN :journalEntryIds
            WITH SECURITY_ENFORCED
        ];

        for (Journal_Entry__c je : journalEntries) {
            for (ContentDocumentLink cdl : je.ContentDocumentLinks) {
                wrappers.add(new DocumentWrapper(
                    cdl.ContentDocumentId,
                    cdl.ContentDocument.Title,
                    je.Entry_Date__c,
                    je.Total_Amount__c,
                    je.Name,
                    cdl.ContentDocument.FileExtension, // Add file extension
                    cdl.ContentDocument.FileType       // Add file type
                ));
            }
        }
        return wrappers;
    }

}