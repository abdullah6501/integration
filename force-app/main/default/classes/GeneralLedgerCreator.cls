public with sharing class GeneralLedgerCreator {

    @AuraEnabled(cacheable=true)
    public static String getUserCurrency() {
        System.debug('currency-->'+UserInfo.getDefaultCurrency());
        return UserInfo.getDefaultCurrency();  
    }

    @AuraEnabled(cacheable=true)
    public static String getLedgerRecord(String recordId) {
        if (String.isNotBlank(recordId)) {
            List<General_Ledger__c> ledgerRecords = [
                SELECT Id
                FROM General_Ledger__c 
                WHERE Journal_Entry__c = :recordId 
                WITH SECURITY_ENFORCED 
                LIMIT 1
            ];
            System.debug('Hello----------->'+recordId);

            if (!ledgerRecords.isEmpty()) {
                System.debug('Ledger Record Found: ' + ledgerRecords[0].Id);
                return 'Found';
            }
        }
        return '';
    }

    @AuraEnabled
    public static List<Map<String,Object>> getChartAccChild(String chartOfAccount){
        try {
            List<Map<String,Object>> getChartAccChild=new List<Map<String,Object>>();
            List<Chart_of_Accounts__c> ChartAcc =[SELECT Id, NAME, Opening_Balance__c, Balance_Amount__c, Parent_Account__c 
                                                 FROM Chart_of_Accounts__c WHERE Parent_Account__c=:chartOfAccount WITH SECURITY_ENFORCED];
            
            if(ChartAcc.size()>0){
                for(Chart_of_Accounts__c cc : ChartAcc){
                    Map<String,Object> records =new Map<String,Object>();
                    records.put('Id', cc.Id);
                    records.put('AccountName',cc.Name);
                    records.put('OpeningBalance',cc.Opening_Balance__c);
                    records.put('BalanceAmount',cc.Balance_Amount__c);
                    records.put('ParentAccount',cc.Parent_Account__c);
                    getChartAccChild.add(records);
                }
            }
            return getChartAccChild;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    @AuraEnabled
    public static List<Map<String,Object>> getGeneralLedger(String chartOfAccount, Date startdate, Date enddate){
        try {
            List<Map<String,Object>> generalrecords=new List<Map<String,Object>>();
            List<General_Ledger__c> ledger= [SELECT ID, Name, CreatedDate, Chart_of_Accounts__c, Entry_Date__c,
            Amount__c, Opening_Balance__c, Closing_Balance__c, Chart_of_Accounts__r.Balance_Amount__c,
            ChildJournal__c, ChildJournal__r.Reference_Account__c, ChildJournal__r.Final_Amount__c,
            ChildJournal__r.ReferenceAmount__c,ChildJournal__r.Reference_Account__r.Name,
            ChildJournal__r.Debit_Amount__c, ChildJournal__r.Credit_Amount__c,
            ChildJournal__r.Debit_Chart_of_Accounts__c, ChildJournal__r.Credit_Chart_of_Accounts__c,
            ChildJournal__r.Debit_Chart_of_Accounts__r.Name, ChildJournal__r.Credit_Chart_of_Accounts__r.Name, 
            Journal_Entry__c, Journal_Entry__r.Entry_Date__c,
            Journal_Entry__r.Name, Journal_Entry__r.Has_Credit_Child__c,Journal_Entry__r.Has_Debit_Child__c, 
            Journal_Entry__r.Debit_Amount__c, Journal_Entry__r.Credit_Amount__c, Journal_Entry__r.Final_Amount__c,
            Journal_Entry__r.Debit_Chart_of_Accounts__c,  Journal_Entry__r.Credit_Chart_of_Accounts__c,
            Journal_Entry__r.Debit_Chart_of_Accounts__r.Name,  Journal_Entry__r.Credit_Chart_of_Accounts__r.Name
            FROM General_Ledger__c 
            WHERE Chart_of_Accounts__c=:chartOfAccount AND Entry_Date__c >=:startdate AND Entry_Date__c <=:enddate WITH SECURITY_ENFORCED 
            ORDER BY CreatedDate ASC];

            Set<Id> Journalids=new Set<Id>();

            if(ledger.size()>0){
                for (General_Ledger__c gl : ledger){
                    if(gl.Journal_Entry__r.Has_Credit_Child__c==false && gl.Journal_Entry__r.Has_Debit_Child__c==false){
                        System.debug('Hello------------->1');
                        Map<String,Object> records=new Map<String,Object>();
                    records.put('Id', gl.Id);
                    records.put('GeneralLedgerName', gl.Name);
                    records.put('chart Of account',gl.Chart_of_Accounts__c);
                    records.put('Amount', gl.Amount__c);
                    records.put('GeneralLedgerEntrydate', gl.Entry_Date__c);
                    records.put('OpeningBalance', gl.Opening_Balance__c);
                    records.put('ClosingBalance', gl.Closing_Balance__c);
                    records.put('JournalEntryId', gl.Journal_Entry__c != null ? gl.Journal_Entry__c : null);
                    records.put('JournalEntryName', gl.Journal_Entry__c != null ? gl.Journal_Entry__r.Name : null);
                    records.put('DebitChartAccountName', gl.Journal_Entry__r.Debit_Chart_of_Accounts__r.Name!=null ? gl.Journal_Entry__r.Debit_Chart_of_Accounts__r.Name : null);
                    records.put('DebitCOA', gl.Journal_Entry__r.Debit_Chart_of_Accounts__c);
                    records.put('DebitAmount', gl.Journal_Entry__r.Final_Amount__c);
                    records.put('CreditChartAccountName', gl.Journal_Entry__r.Credit_Chart_of_Accounts__r.Name!=null? gl.Journal_Entry__r.Credit_Chart_of_Accounts__r.Name : null);
                    records.put('CreditCOA', gl.Journal_Entry__r.Credit_Chart_of_Accounts__c);
                    records.put('creditAmount', gl.Journal_Entry__r.Final_Amount__c);
                    records.put('ChartOfAccountsBalance', gl.Chart_of_Accounts__r.Balance_Amount__c);

                    generalrecords.add(records);
                    }
                    else if(gl.ChildJournal__c!=null && gl.Journal_Entry__r.Has_Debit_Child__c==true){
                        System.debug('Hello------------->1');
                        Map<String,Object> records=new Map<String,Object>();
                        records.put('Id', gl.Id);
                        records.put('GeneralLedgerName', gl.Name);
                        records.put('chart Of account',gl.Chart_of_Accounts__c);
                        records.put('Amount', gl.Amount__c);
                        records.put('GeneralLedgerEntrydate', gl.Entry_Date__c);
                        records.put('OpeningBalance', gl.Opening_Balance__c);
                        records.put('ClosingBalance', gl.Closing_Balance__c);
                        records.put('JournalEntryId', gl.Journal_Entry__c != null ? gl.Journal_Entry__c : null);
                        records.put('JournalEntryName', gl.Journal_Entry__c != null ? gl.Journal_Entry__r.Name : null);
                        records.put('DebitChartAccountName', gl.ChildJournal__r.Debit_Chart_of_Accounts__r.Name!=null ? gl.ChildJournal__r.Debit_Chart_of_Accounts__r.Name : null);
                        records.put('DebitCOA', gl.ChildJournal__r.Debit_Chart_of_Accounts__c);
                        records.put('DebitAmount', gl.ChildJournal__r.Final_Amount__c);
                        records.put('CreditChartAccountName', gl.ChildJournal__r.Reference_Account__r.Name!=null? gl.ChildJournal__r.Reference_Account__r.Name : null);
                        records.put('CreditCOA', gl.ChildJournal__r.Reference_Account__c);
                        records.put('creditAmount', gl.ChildJournal__r.ReferenceAmount__c);
                        records.put('ChartOfAccountsBalance', gl.Chart_of_Accounts__r.Balance_Amount__c);
    
                        generalrecords.add(records);
                    }
                    else if(gl.ChildJournal__c!=null && gl.Journal_Entry__r.Has_Credit_Child__c==true){
                        System.debug('Hello------------->1');
                        Map<String,Object> records=new Map<String,Object>();
                        records.put('Id', gl.Id);
                        records.put('GeneralLedgerName', gl.Name);
                        records.put('chart Of account',gl.Chart_of_Accounts__c);
                        records.put('Amount', gl.Amount__c);
                        records.put('GeneralLedgerEntrydate', gl.Entry_Date__c);
                        records.put('OpeningBalance', gl.Opening_Balance__c);
                        records.put('ClosingBalance', gl.Closing_Balance__c);
                        records.put('JournalEntryId', gl.Journal_Entry__c != null ? gl.Journal_Entry__c : null);
                        records.put('JournalEntryName', gl.Journal_Entry__c != null ? gl.Journal_Entry__r.Name : null);
                        records.put('DebitChartAccountName', gl.ChildJournal__r.Reference_Account__r.Name!=null ? gl.ChildJournal__r.Reference_Account__r.Name : null);
                        records.put('DebitCOA', gl.ChildJournal__r.Reference_Account__c);
                        records.put('DebitAmount', gl.ChildJournal__r.ReferenceAmount__c);
                        records.put('CreditChartAccountName', gl.ChildJournal__r.Credit_Chart_of_Accounts__r.Name!=null? gl.ChildJournal__r.Credit_Chart_of_Accounts__r.Name : null);
                        records.put('CreditCOA', gl.ChildJournal__r.Credit_Chart_of_Accounts__c);
                        records.put('creditAmount', gl.ChildJournal__r.Final_Amount__c);
                        records.put('ChartOfAccountsBalance', gl.Chart_of_Accounts__r.Balance_Amount__c);
    
                        generalrecords.add(records);
                    }
                    else if(gl.ChildJournal__c==null && gl.Journal_Entry__r.Has_Debit_Child__c==true || gl.Journal_Entry__r.Has_Credit_Child__c==true){
                        Journalids.add(gl.Journal_Entry__c);
                    }  
            }

            List<General_Ledger__c> generalchild= [SELECT ID, Name, CreatedDate, Chart_of_Accounts__c, Entry_Date__c,
            Amount__c, Opening_Balance__c, Closing_Balance__c, ParentOB__c, ParentCB__c,
            Chart_of_Accounts__r.Balance_Amount__c,ChildJournal__r.Final_Amount__c,
            ChildJournal__c, ChildJournal__r.Reference_Account__c, 
            ChildJournal__r.ReferenceAmount__c,ChildJournal__r.Reference_Account__r.Name,
            ChildJournal__r.Debit_Amount__c, ChildJournal__r.Credit_Amount__c,
            ChildJournal__r.Debit_Chart_of_Accounts__c, ChildJournal__r.Credit_Chart_of_Accounts__c,
            ChildJournal__r.Debit_Chart_of_Accounts__r.Name, ChildJournal__r.Credit_Chart_of_Accounts__r.Name, 
            Journal_Entry__c,Journal_Entry__r.Name, Journal_Entry__r.Has_Credit_Child__c,Journal_Entry__r.Has_Debit_Child__c         
            FROM General_Ledger__c 
            WHERE Journal_Entry__c IN :Journalids
            WITH SECURITY_ENFORCED 
            ORDER BY CreatedDate ASC] ;

            for(General_Ledger__c grChild : generalchild){
                if(grchild.ChildJournal__c!=null && grchild.Journal_Entry__r.Has_Debit_Child__c==true){
                    System.debug('Hello------------->2');
                    Map<String,Object> records=new Map<String,Object>();
                    records.put('Id', grChild.Id);
                    records.put('GeneralLedgerName', grChild.Name);
                    records.put('chart Of account',grChild.Chart_of_Accounts__c);
                    records.put('Amount', grChild.Amount__c);
                    records.put('GeneralLedgerEntrydate', grChild.Entry_Date__c);
                    records.put('OpeningBalance', grChild.ParentOB__c);
                    records.put('ClosingBalance', grChild.ParentCB__c);
                    records.put('JournalEntryId', grChild.Journal_Entry__c != null ? grChild.Journal_Entry__c : null);
                    records.put('JournalEntryName', grChild.Journal_Entry__c != null ? grChild.Journal_Entry__r.Name : null);
                    records.put('DebitChartAccountName', grChild.ChildJournal__r.Debit_Chart_of_Accounts__r.Name!=null ? grChild.ChildJournal__r.Debit_Chart_of_Accounts__r.Name : null);
                    records.put('DebitCOA', grChild.ChildJournal__r.Debit_Chart_of_Accounts__c);
                    records.put('DebitAmount', grChild.ChildJournal__r.Final_Amount__c);
                    records.put('CreditChartAccountName', grChild.ChildJournal__r.Reference_Account__r.Name!=null? grChild.ChildJournal__r.Reference_Account__r.Name : null);
                    records.put('CreditCOA', grChild.ChildJournal__r.Reference_Account__c);
                    records.put('creditAmount', grChild.ChildJournal__r.ReferenceAmount__c);
                    records.put('ChartOfAccountsBalance', grChild.ParentCB__c);
    
                        generalrecords.add(records);
                }
                else if(grchild.ChildJournal__c!=null && grchild.Journal_Entry__r.Has_Credit_Child__c==true){
                    System.debug('Hello------------->2');
                    Map<String,Object> records=new Map<String,Object>();
                        records.put('Id', grChild.Id);
                        records.put('GeneralLedgerName', grChild.Name);
                        records.put('chart Of account',grChild.Chart_of_Accounts__c);
                        records.put('Amount', grChild.Amount__c);
                        records.put('GeneralLedgerEntrydate', grChild.Entry_Date__c);
                        records.put('OpeningBalance', grChild.ParentOB__c);
                        records.put('ClosingBalance', grChild.ParentCB__c);
                        records.put('JournalEntryId', grChild.Journal_Entry__c != null ? grChild.Journal_Entry__c : null);
                        records.put('JournalEntryName', grChild.Journal_Entry__c != null ? grChild.Journal_Entry__r.Name : null);
                        records.put('DebitChartAccountName', grChild.ChildJournal__r.Reference_Account__r.Name!=null ? grChild.ChildJournal__r.Reference_Account__r.Name : null);
                        records.put('DebitCOA', grChild.ChildJournal__r.Reference_Account__c);
                        records.put('DebitAmount', grChild.ChildJournal__r.ReferenceAmount__c);
                        records.put('CreditChartAccountName', grChild.ChildJournal__r.Credit_Chart_of_Accounts__r.Name!=null? grChild.ChildJournal__r.Credit_Chart_of_Accounts__r.Name : null);
                        records.put('CreditCOA', grChild.ChildJournal__r.Credit_Chart_of_Accounts__c);
                        records.put('creditAmount', grChild.ChildJournal__r.Final_Amount__c);
                        records.put('ChartOfAccountsBalance', grChild.ParentCB__c);
    
                        generalrecords.add(records);
                }
            }

            return generalrecords;
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        return null;
    }
    public static Map<Id, Decimal> accountBalanceMap = new Map<Id, Decimal>();
    @AuraEnabled
    public static void createGeneralLedgerRecords(String journalEntryId) {
        try {
            // Fetch the Journal Entry and its child records
            Journal_Entry__c journalEntry = [
                SELECT Id, Name, Credit_Chart_of_Accounts__c, Credit_Amount__c, Status__c,
                       Debit_Chart_of_Accounts__c, Debit_Amount__c, Entry_Date__c,
                       Has_Debit_Child__c, Has_Credit_Child__c,
                       Debit_Chart_of_Accounts__r.Name,
                       Debit_Chart_of_Accounts__r.Balance_Amount__c,
                       Debit_Chart_of_Accounts__r.Id,
                       Debit_Cart_Record_Type__c,Credit_Cart_Record_Type__c,
                       Credit_Chart_of_Accounts__r.Balance_Amount__c,
                       Credit_Chart_of_Accounts__r.Id,
                       Credit_Chart_of_Accounts__r.Name,
                       Final_Amount__c,
                       (SELECT Id,Name, Debit_Chart_of_Accounts__c, Debit_Amount__c,
                                Debit_Chart_of_Accounts__r.Name,
                                Debit_Chart_of_Accounts__r.Id,
                                Debit_Chart_of_Accounts__r.Balance_Amount__c,
                                Debit_Cart_Record_Type__c,Credit_Cart_Record_Type__c,
                                Credit_Chart_of_Accounts__r.Name,
                                Credit_Chart_of_Accounts__r.Id,
                                Credit_Chart_of_Accounts__r.Balance_Amount__c, 
                                Credit_Chart_of_Accounts__c, Credit_Amount__c,Final_Amount__c
                        FROM Journal_Entries__r)
                FROM Journal_Entry__c
                WHERE Id = :journalEntryId
                WITH SECURITY_ENFORCED LIMIT 1
            ];
            //if two debit and two credit :
            //take JE and update refacc refamt to both childs
            List<General_Ledger__c> ledgerRecords = new List<General_Ledger__c>();
            Map<Id, Chart_of_Accounts__c> chartOfAccountsList = new Map<Id, Chart_of_Accounts__c>();
            //List<Chart_of_Accounts__c> chartOfAccountsList = new List<Chart_of_Accounts__c>();
            // Map<Id, Decimal> accountBalanceMap = new Map<Id, Decimal>();
            // Handle Has_Debit_Child__c logic
            if (journalEntry.Has_Debit_Child__c) {
                Decimal parentOpeningBalance = journalEntry.Credit_Chart_of_Accounts__r.Balance_Amount__c;
                Decimal parentClosingBalance = parentOpeningBalance;
                // Decimal chartbalance=child.Debit_Chart_of_Accounts__r.Balance_Amount__c;  
                        
                for (Journal_Entry__c child : journalEntry.Journal_Entries__r) {
                    if (child.Debit_Amount__c != null) {
                        accountBalanceMap.put(child.Debit_Chart_of_Accounts__r.Id, child.Debit_Chart_of_Accounts__r.Balance_Amount__c);
                        General_Ledger__c general = new General_Ledger__c();
                        general.Name = child.Name + '_' + child.Debit_Chart_of_Accounts__r.Name;
                        general.Chart_of_Accounts__c = child.Debit_Chart_of_Accounts__c;
                        general.Amount__c = child.Final_Amount__c;
                        general.Entry_Date__c = journalEntry.Entry_Date__c;
                           // Type__c = 'Debit',
                        general.Journal_Entry__c = journalEntry.Id;
                        general.ChildJournal__c= child.Id;
                        general.ParentOB__c = parentClosingBalance;
                        general.Last_Transaction_Type__c = 'Debit';
                            if(child.Debit_Cart_Record_Type__c =='Assets' || child.Debit_Cart_Record_Type__c =='Expenses'){
                                general.Opening_Balance__c = child.Debit_Chart_of_Accounts__r.Balance_Amount__c;
                                general.Closing_Balance__c =child.Debit_Chart_of_Accounts__r.Balance_Amount__c + child.Final_Amount__c;                            
                            }
                            else if(child.Debit_Cart_Record_Type__c =='Liabilities' || child.Debit_Cart_Record_Type__c=='Revenue' || child.Debit_Cart_Record_Type__c =='Equity' ){
                                general.Opening_Balance__c = child.Debit_Chart_of_Accounts__r.Balance_Amount__c;
                                general.Closing_Balance__c =child.Debit_Chart_of_Accounts__r.Balance_Amount__c - child.Final_Amount__c;
                            }
                            if(journalEntry.Credit_Cart_Record_Type__c=='Assets' || journalEntry.Credit_Cart_Record_Type__c=='Expenses'){
                                parentClosingBalance -= child.Final_Amount__c;
                                general.ParentCB__c = parentClosingBalance;
                            }
                            else if(journalEntry.Credit_Cart_Record_Type__c=='Liabilities' || journalEntry.Credit_Cart_Record_Type__c=='Revenue' || journalEntry.Credit_Cart_Record_Type__c=='Equity'){
                                parentClosingBalance += child.Final_Amount__c;
                                general.ParentCB__c = parentClosingBalance;
                            }
                           

                            ledgerRecords.add(general);
                            changeBalanceAmount(child.Debit_Chart_of_Accounts__r.Id,general.Closing_Balance__c,chartOfAccountsList);
                    }
                }
            } else if (journalEntry.Debit_Amount__c != null) {
                // Decimal chartbalance=journalEntry.Debit_Chart_of_Accounts__r.Balance_Amount__c;
                accountBalanceMap.put(journalEntry.Debit_Chart_of_Accounts__r.Id, journalEntry.Debit_Chart_of_Accounts__r.Balance_Amount__c);
                    General_Ledger__c general = new General_Ledger__c();
                    general.Name = journalEntry.Name + '_' + journalEntry.Debit_Chart_of_Accounts__r.Name;
                    general.Chart_of_Accounts__c = journalEntry.Debit_Chart_of_Accounts__c;
                    general.Amount__c = journalEntry.Final_Amount__c;
                    general.Entry_Date__c = journalEntry.Entry_Date__c;
                    general.Journal_Entry__c = journalEntry.Id;
                    general.Last_Transaction_Type__c = 'Debit';
                    // Check if the record type is Assets or Expenses
                    if(journalEntry.Debit_Cart_Record_Type__c =='Assets' || journalEntry.Debit_Cart_Record_Type__c =='Expenses'){
                     general.Opening_Balance__c = journalEntry.Debit_Chart_of_Accounts__r.Balance_Amount__c;
                     general.Closing_Balance__c =journalEntry.Debit_Chart_of_Accounts__r.Balance_Amount__c + journalEntry.Final_Amount__c;
                    }
                    //Type__c = 'Debit'
                   // Check if the record type is liabilities or revenue
                   else if(journalEntry.Debit_Cart_Record_Type__c =='Liabilities' ||  journalEntry.Debit_Cart_Record_Type__c =='Revenue' || journalEntry.Debit_Cart_Record_Type__c =='Equity'){
                     general.Opening_Balance__c = journalEntry.Debit_Chart_of_Accounts__r.Balance_Amount__c;
                     general.Closing_Balance__c =journalEntry.Debit_Chart_of_Accounts__r.Balance_Amount__c - journalEntry.Final_Amount__c;
                     //Type__c = 'Debit',
                  }
                    ledgerRecords.add(general);
                    changeBalanceAmount(journalEntry.Debit_Chart_of_Accounts__r.Id,general.Closing_Balance__c,chartOfAccountsList);
                    
            }

            // Handle Has_Credit_Child__c logic
            if (journalEntry.Has_Credit_Child__c) {
                Decimal parentOpeningBalance = journalEntry.Debit_Chart_of_Accounts__r.Balance_Amount__c;
                Decimal parentClosingBalance = parentOpeningBalance;
                // Decimal chartbalance=child.Credit_Chart_of_Accounts__r.Balance_Amount__c;
                
                for (Journal_Entry__c child : journalEntry.Journal_Entries__r) {
                    if (child.Credit_Amount__c != null) {
                        accountBalanceMap.put(child.Credit_Chart_of_Accounts__r.Id, child.Credit_Chart_of_Accounts__r.Balance_Amount__c);
                        General_Ledger__c general = new General_Ledger__c();
                        general.Name = child.Name + '_' + child.Credit_Chart_of_Accounts__r.Name;
                        general.Chart_of_Accounts__c = child.Credit_Chart_of_Accounts__c;
                        general.Amount__c = child.Final_Amount__c;
                        general.Entry_Date__c = journalEntry.Entry_Date__c;
                           // Type__c = 'Credit',
                        general.Journal_Entry__c = journalEntry.Id;  
                        general.ChildJournal__c= child.Id;
                        general.ParentOB__c = parentClosingBalance;
                        general.Last_Transaction_Type__c = 'Credit';
                        if(child.Credit_Cart_Record_Type__c =='Assets' 
                               ||  child.Credit_Cart_Record_Type__c =='Expenses'){
                                
                                general.Opening_Balance__c = child.Credit_Chart_of_Accounts__r.Balance_Amount__c;
                                general.Closing_Balance__c =child.Credit_Chart_of_Accounts__r.Balance_Amount__c - child.Final_Amount__c;
                          }
                          else if(child.Credit_Cart_Record_Type__c =='Liabilities' 
                                   ||  child.Credit_Cart_Record_Type__c =='Revenue' || child.Credit_Cart_Record_Type__c =='Equity'){
                                    general.Opening_Balance__c = child.Credit_Chart_of_Accounts__r.Balance_Amount__c;
                                    general.Closing_Balance__c =child.Credit_Chart_of_Accounts__r.Balance_Amount__c + child.Final_Amount__c;
                          }
                          if(journalEntry.Debit_Cart_Record_Type__c=='Assets' || journalEntry.Debit_Cart_Record_Type__c=='Expenses' || journalEntry.Debit_Cart_Record_Type__c=='Equity'){
                            parentClosingBalance += child.Final_Amount__c;
                            general.ParentCB__c = parentClosingBalance;
                        }
                        else if(journalEntry.Debit_Cart_Record_Type__c=='Liabilities' || journalEntry.Debit_Cart_Record_Type__c=='Revenue'){
                            parentClosingBalance -= child.Final_Amount__c;
                            general.ParentCB__c = parentClosingBalance;
                        }
                          ledgerRecords.add(general);
                          changeBalanceAmount(child.Credit_Chart_of_Accounts__r.Id,general.Closing_Balance__c,chartOfAccountsList);
                    }
                }
            } else if (journalEntry.Credit_Amount__c != null) {
                // Decimal chartbalance=journalEntry.Credit_Chart_of_Accounts__r.Balance_Amount__c;
                accountBalanceMap.put(journalEntry.Credit_Chart_of_Accounts__r.Id, journalEntry.Credit_Chart_of_Accounts__r.Balance_Amount__c);
                General_Ledger__c general = new General_Ledger__c();
                    general.Name = journalEntry.Name + '_' + journalEntry.Credit_Chart_of_Accounts__r.Name;
                    general.Chart_of_Accounts__c = journalEntry.Credit_Chart_of_Accounts__c;
                    general.Amount__c = journalEntry.Final_Amount__c;
                    general.Entry_Date__c = journalEntry.Entry_Date__c;
                    general.Journal_Entry__c = journalEntry.Id;
                    general.Last_Transaction_Type__c = 'Credit';
                    //  Type__c = 'Credit',
                   // Check if the record type is Assets or Expenses
                   if(journalEntry.Credit_Cart_Record_Type__c =='Assets' 
                               ||  journalEntry.Credit_Cart_Record_Type__c =='Expenses'){
                     general.Opening_Balance__c = journalEntry.Credit_Chart_of_Accounts__r.Balance_Amount__c;
                     general.Closing_Balance__c =journalEntry.Credit_Chart_of_Accounts__r.Balance_Amount__c - journalEntry.Final_Amount__c;
                    }
                   // Check if the record type is Liabilities or revenue
                   else if(journalEntry.Credit_Cart_Record_Type__c =='Liabilities' 
                          || journalEntry.Credit_Cart_Record_Type__c =='Revenue' || journalEntry.Credit_Cart_Record_Type__c =='Equity'){ 
                        general.Opening_Balance__c = journalEntry.Credit_Chart_of_Accounts__r.Balance_Amount__c;
                        general.Closing_Balance__c =journalEntry.Credit_Chart_of_Accounts__r.Balance_Amount__c + journalEntry.Final_Amount__c;
                    }    
                    ledgerRecords.add(general);
                   changeBalanceAmount(journalEntry.Credit_Chart_of_Accounts__r.Id,general.Closing_Balance__c,chartOfAccountsList);
                }
            // Insert General Ledger records
            if (!ledgerRecords.isEmpty() && !chartOfAccountsList.isEmpty()) {
                if (General_Ledger__c.SObjectType.getDescribe().isCreateable() &&
                   Schema.sObjectType.General_Ledger__c.fields.Name.isCreateable() &&
                   Schema.sObjectType.General_Ledger__c.fields.Chart_of_Accounts__c.isCreateable() &&
                   Schema.sObjectType.General_Ledger__c.fields.Amount__c.isCreateable() &&
                   Schema.sObjectType.General_Ledger__c.fields.Entry_Date__c.isCreateable() &&
                   Schema.sObjectType.General_Ledger__c.fields.Journal_Entry__c.isCreateable() &&
                   Schema.sObjectType.General_Ledger__c.fields.Opening_Balance__c.isCreateable() &&
                   Schema.sObjectType.General_Ledger__c.fields.Closing_Balance__c.isCreateable()&&
                   Schema.sObjectType.General_Ledger__c.fields.ParentCB__c.isCreateable()&&
                   Schema.sObjectType.General_Ledger__c.fields.ParentOB__c.isCreateable()&&
                   Schema.sObjectType.General_Ledger__c.fields.ChildJournal__c.isCreateable() ) {
                    insert ledgerRecords;
                }
                if (Chart_of_Accounts__c.SObjectType.getDescribe().isUpdateable() &&
                   Schema.sObjectType.Chart_of_Accounts__c.fields.Balance_Amount__c.isUpdateable()) {
                  update chartOfAccountsList.values();
                  //Call changeBalanceAmount1 for each updated account
                    for (Chart_of_Accounts__c updatedAccount : chartOfAccountsList.values()) {
                        changeBalanceAmount1(updatedAccount.Id, updatedAccount.Balance_Amount__c);
                    }
                }
            }
            
         }
        catch (Exception e) {
            throw new AuraHandledException('Error creating General Ledger records: ' + e.getMessage());
        }
    }
    //Update the Balance Amount in Chart of Accounts 
    public static void changeBalanceAmount(String Id, Decimal amount,Map<Id,Chart_of_Accounts__c> chartOfAccountsList) {
        List <Chart_of_Accounts__c> chartOfAccount = [SELECT Balance_Amount__c FROM Chart_of_Accounts__c WHERE Id = :Id];
        chartOfAccount[0].Balance_Amount__c =amount;
        if (!chartOfAccount.isEmpty()) {
            chartOfAccountsList.put(chartOfAccount[0].Id,chartOfAccount[0]);
        }
    }

    public static void changeBalanceAmount1(String accountId, Decimal amount) {
        String operation='';
        Decimal atu = 0;
        if(accountBalanceMap.containsKey(accountId)){
           Decimal mapedamount = accountBalanceMap.get(accountId);
           if(amount>mapedamount){
            atu = amount-mapedamount;
           }
           else if(amount<mapedamount){
            atu = mapedamount-amount;
           }
           if(mapedamount<amount){
               operation='Increases';
           }
           else if(mapedamount>amount){
               operation='Decreases' ;
           }
        }
        //Collect all parent account IDs
        Set<Id> parentIds = new Set<Id>();
        Id currentId = accountId;
        
        while (currentId != null) {
            parentIds.add(currentId);
            currentId = [SELECT Parent_Account__c FROM Chart_of_Accounts__c WHERE Id = :currentId].Parent_Account__c;
        }
        
        //Query all parent accounts in one SOQL query
        Map<Id, Chart_of_Accounts__c> parentAccounts = new Map<Id, Chart_of_Accounts__c>(
            [SELECT Id, Balance_Amount__c, Parent_Account__c FROM Chart_of_Accounts__c WHERE Id IN :parentIds]
        );
        //Update balance amounts for each parent
        currentId = accountId;
        while (currentId != null && parentAccounts.containsKey(currentId)) {
            if (currentId == accountId) {
                currentId = parentAccounts.get(currentId).Parent_Account__c; // Move to next parent
                continue;
            }
            Chart_of_Accounts__c account = parentAccounts.get(currentId);
            if(operation=='Increases'){
                account.Balance_Amount__c += atu;
            }
            else if(operation=='Decreases'){
                account.Balance_Amount__c -= atu;
            }
            // account.Balance_Amount__c += amount; // Apply incremental balance change
            currentId = account.Parent_Account__c; // Move to the next parent
        }
        
        // Step 4: Perform update to database
        if (!parentAccounts.isEmpty()) {
            if (Chart_of_Accounts__c.SObjectType.getDescribe().isUpdateable() &&
                Schema.sObjectType.Chart_of_Accounts__c.fields.Balance_Amount__c.isUpdateable()){
                    update parentAccounts.values();
                   }           
        }
    }
       
}