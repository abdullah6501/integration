public class GeneralLedgerHelper {
    
    /**
     * Creates a standardized map of General Ledger data
     * @param gl The General Ledger record
     * @param isChild Whether this is a child record
     * @param isDebitChild Whether this is a debit child
     * @param parentOB Optional parent opening balance
     * @param parentCB Optional parent closing balance
     * @return Standardized Map of General Ledger data
     */
    public static Map<String,Object> createGeneralLedgerMap(
        General_Ledger__c gl, 
        Boolean isChild, 
        Boolean isDebitChild,
        Decimal parentOB,
        Decimal parentCB
    ) {
        Map<String,Object> records = new Map<String,Object>();
        
        // Common fields for all record types
        records.put('Id', gl.Id);
        records.put('GeneralLedgerName', gl.Name);
        records.put('chart Of account', gl.Chart_of_Accounts__c);
        records.put('Amount', gl.Amount__c);
        records.put('GeneralLedgerEntrydate', gl.Entry_Date__c);
        records.put('JournalEntryName', gl.Journal_Entry__c != null ? gl.Journal_Entry__r.Name : null);
        
        // Set balance fields based on whether this is a child record
        if (isChild) {
            records.put('OpeningBalance', parentOB);
            records.put('ClosingBalance', parentCB);
            records.put('ChartOfAccountsBalance', parentCB);
        } else {
            records.put('OpeningBalance', gl.Opening_Balance__c);
            records.put('ClosingBalance', gl.Closing_Balance__c);
            records.put('ChartOfAccountsBalance', gl.Chart_of_Accounts__r.Balance_Amount__c);
        }
        
        // Set specific fields based on record type
        if (gl.ChildJournal__c == null && !gl.Journal_Entry__r.Has_Credit_Child__c && !gl.Journal_Entry__r.Has_Debit_Child__c) {
            // Simple journal entry
            records.put('DebitChartAccountName', gl.Journal_Entry__r.Debit_Chart_of_Accounts__r.Name != null ? 
                         gl.Journal_Entry__r.Debit_Chart_of_Accounts__r.Name : null);
            records.put('DebitCOA', gl.Journal_Entry__r.Debit_Chart_of_Accounts__c);
            records.put('DebitAmount', gl.Journal_Entry__r.Final_Amount__c);
            records.put('CreditChartAccountName', gl.Journal_Entry__r.Credit_Chart_of_Accounts__r.Name != null ? 
                         gl.Journal_Entry__r.Credit_Chart_of_Accounts__r.Name : null);
            records.put('CreditCOA', gl.Journal_Entry__r.Credit_Chart_of_Accounts__c);
            records.put('creditAmount', gl.Journal_Entry__r.Final_Amount__c);
        } 
        else if (gl.ChildJournal__c != null) {
            if (isDebitChild) {
                // Debit child journal
                records.put('DebitChartAccountName', gl.ChildJournal__r.Debit_Chart_of_Accounts__r.Name != null ? 
                             gl.ChildJournal__r.Debit_Chart_of_Accounts__r.Name : null);
                records.put('DebitCOA', gl.ChildJournal__r.Debit_Chart_of_Accounts__c);
                records.put('DebitAmount', gl.ChildJournal__r.Final_Amount__c);
                records.put('CreditChartAccountName', gl.ChildJournal__r.Reference_Account__r.Name != null ? 
                             gl.ChildJournal__r.Reference_Account__r.Name : null);
                records.put('CreditCOA', gl.ChildJournal__r.Reference_Account__c);
                records.put('creditAmount', gl.ChildJournal__r.ReferenceAmount__c);
            } else {
                // Credit child journal
                records.put('DebitChartAccountName', gl.ChildJournal__r.Reference_Account__r.Name != null ? 
                             gl.ChildJournal__r.Reference_Account__r.Name : null);
                records.put('DebitCOA', gl.ChildJournal__r.Reference_Account__c);
                records.put('DebitAmount', gl.ChildJournal__r.ReferenceAmount__c);
                records.put('CreditChartAccountName', gl.ChildJournal__r.Credit_Chart_of_Accounts__r.Name != null ? 
                             gl.ChildJournal__r.Credit_Chart_of_Accounts__r.Name : null);
                records.put('CreditCOA', gl.ChildJournal__r.Credit_Chart_of_Accounts__c);
                records.put('creditAmount', gl.ChildJournal__r.Final_Amount__c);
            }
        }
        
        return records;
    }
}