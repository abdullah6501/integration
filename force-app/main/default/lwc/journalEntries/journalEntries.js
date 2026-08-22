import { LightningElement, track, api } from 'lwc';
import saveJournalEntries from '@salesforce/apex/JournalEntryController.saveJournalEntries';
import getJournalEntryRecords from '@salesforce/apex/JournalEntryController.getJournalEntryRecords';
export default class JournalEntries extends LightningElement {
    @track rows = [];
    @api recordId; // Record ID passed from the parent record
    parentAccountSelectedRecord=[];
    groupCounter = 1;
    rowCounter = 1;
    sharedDate = null;
    journlentryflag = true;
    newrecord=true;
    @api freezeFlag;
    @api disable;
    Accountname=''; //set label to empty for COA Lookup
    @api clearJournalEntries() {
            this.rows = [
                {
                    id: `row-${this.rowCounter++}`,
                    group: `Group ${this.groupCounter}`,
                    accountId: '',
                    debit: null,
                    credit: null,
                    debitDisabled: true,
                    creditDisabled: false,
                    selectedid: null
                },
                {
                    id: `row-${this.rowCounter++}`,
                    group: `Group ${this.groupCounter + 1}`,
                    accountId: '',
                    debit: null,
                    credit: null,
                    debitDisabled: false,
                    creditDisabled: true,
                    selectedid: null
                }
            ];
        this.parentAccountSelectedRecord = [];
        this.sharedDate = null;
        this.notifyParent();
    }
    connectedCallback() {
        if(this.recordId)
        {
            getJournalEntryRecords({ recordId: this.recordId })
            .then((result) => {
                this.records = result; 
                this.records.forEach((record, index) => {                    
                        // Debit row logic
                        // Handle records without children 
                        if (record.RFAB__Has_Debit_Child__c === false && record.RFAB__Debit_Chart_of_Accounts__c) {
                            this.rows.push({
                                id: `row-${index + 1}-debit`,
                                group: `Group 1`,
                                accountId: record.RFAB__Debit_Chart_of_Accounts__c,
                                debit: record.RFAB__Debit_Amount__c,
                                credit: null,
                                debitDisabled: true,
                                creditDisabled: false,
                                selectedid: record.RFAB__Debit_Chart_of_Accounts__c,
                                recid: record.Id,
                                description:record.RFAB__Debit_Description__c
                            });
                        }
                        // Handle records with children in Journal_Entries__r 
                        if(record.RFAB__Has_Debit_Child__c === true){
                            if( record.RFAB__Journal_Entries__r.length > 0 && (record.RFAB__Has_Debit_Child__c === true)) {           
                                record.RFAB__Journal_Entries__r.forEach((child, childIndex) => {           
                                    if (child.RFAB__Debit_Chart_of_Accounts__c && record.RFAB__Has_Debit_Child__c === true) {
                                        this.rows.push({
                                            id: `row-${index + 1}-${childIndex + 1}-debit`,
                                            group: `Group ${index + 1}`,
                                            accountId: child.RFAB__Debit_Chart_of_Accounts__c,
                                            debit: child.RFAB__Debit_Amount__c,
                                            credit: null,
                                            debitDisabled: true,
                                            creditDisabled: false,
                                            selectedid: child.RFAB__Debit_Chart_of_Accounts__c,
                                            recid: child.Id,
                                            description:child.RFAB__Debit_Description__c
                                        });
                                    }
                                }
                                );
                            }
                        }   
                        // Credit row logic
                         // Handle records without children 
                        if (record.RFAB__Has_Credit_Child__c === false && record.RFAB__Credit_Chart_of_Accounts__c) {
                            this.rows.push({
                                id: `row-${index + 1}-credit`,
                                group: `Group 2`,
                                accountId: record.RFAB__Credit_Chart_of_Accounts__c,
                                debit: null,
                                credit: record.RFAB__Credit_Amount__c,
                                debitDisabled: false,
                                creditDisabled: true,
                                selectedid: record.RFAB__Credit_Chart_of_Accounts__c,
                                recid: record.Id,
                                description:record.RFAB__Credit_Description__c
                            });
                        }
                        if(record.RFAB__Has_Credit_Child__c === true){
                            if( record.RFAB__Journal_Entries__r.length > 0 && (record.RFAB__Has_Credit_Child__c === true)) {
                                // Handle records with children in Journal_Entries__r            
                                record.RFAB__Journal_Entries__r.forEach((child, childIndex) => {
                                    if (child.RFAB__Credit_Chart_of_Accounts__c && record.RFAB__Has_Credit_Child__c === true) {
                                        this.rows.push({
                                            id: `row-${index + 1}-${childIndex + 1}-credit`,
                                            group: `Group ${index + 1}`,
                                            accountId: child.RFAB__Credit_Chart_of_Accounts__c,
                                            debit: null,
                                            credit: child.RFAB__Credit_Amount__c,
                                            debitDisabled: false,
                                            creditDisabled: true,
                                            selectedid: child.RFAB__Credit_Chart_of_Accounts__c,
                                            recid: child.Id,
                                            description:child.RFAB__Credit_Description__c
                                        });
                                    }
                                });
                            }
                        }
                });
            })
            .catch((error) => {
                console.error('Error fetching records:', error);
            });
            this.notifyParent();
        }
        else if(!this.recordId){
            this.clearJournalEntries();
        }
        
    }
    
    @api
    handleAddDebit() {
        this.addRow('Debit');
    }
 
    @api
    handleAddCredit() {
        this.addRow('Credit');
    }
 
    addRow(type) {
        const group = type === 'Debit' ? `Group ${this.groupCounter}` : `Group ${this.groupCounter + 1}`;
        const newRow = {
            id: `row-${this.rowCounter++}`,
            group: group,
            accountId: '',
            debit: null,
            credit: null,
            debitDisabled: type === 'Debit',
            creditDisabled: type === 'Credit',
            description:'',
            selectedid:null
        };
        this.parentAccountSelectedRecord=[];
        //this.rows = [...this.rows, newRow];
         // Add the new row and then sort by group
        this.rows = [...this.rows, newRow].sort((a, b) => {
            const groupA = parseInt(a.group.replace('Group ', ''), 10);
            const groupB = parseInt(b.group.replace('Group ', ''), 10);
            return groupA - groupB;
        });
        this.notifyParent();
    }

    // handleDateChange(event) {
    //     this.sharedDate = event.target.value;
    //     // Update the shared date in each row
    //     this.rows = this.rows.map(row => {
    //         row.date = this.sharedDate;
    //         return row;
    //     });
    //     this.notifyParent();
    // }

    get totalDebit() {
        return this.rows.reduce((sum, row) => sum + (parseFloat(row.debit) || 0), 0);
    }

    get totalCredit() {
        return this.rows.reduce((sum, row) => sum + (parseFloat(row.credit) || 0), 0);
    }
    
    handleInputChange(event) {
        const rowId = event.target.dataset.id;
        const field = event.target.dataset.field;
        const value = event.target.value;
 
        this.rows = this.rows.map(row => {
            if (row.id === rowId) {
                return { ...row, [field]: value };
            }
            return row;
        });
        this.rows = [...this.rows];
        this.notifyParent();
    }

    handleValueSelectedOnAccount(event) {
       
        const selectedItem = event.detail;
        const rowId = event.target.dataset.id;
        if (selectedItem) {
            this.rows = this.rows.map(row => {
                if (row.id === rowId) {
                    row.accountId = selectedItem.id;
                    row.Name = selectedItem.mainField;
                }
                return row;
            });
            this.notifyParent();
        }
    }
 
    handleDeleteRow(event) {
        const rowId = event.target.dataset.id;
        this.rows = this.rows.filter(row => row.id !== rowId);
        this.notifyParent();
    }
 
    notifyParent() {
        const event = new CustomEvent('journalrecordsupdate', {
            detail: this.rows // Pass rows as detail
        });
        this.dispatchEvent(event);
    }
    async handleSave() {
        if (!this.sharedDate) {
            alert('Please set a date for all rows.');
            return;
        }
 
        try {
            const jsonRows = JSON.stringify(this.rows); // Serialize rows into JSON
            await saveJournalEntries({ jsonRows: jsonRows, recordId: this.recordId });
            alert('Journal entries saved successfully!');
        } catch (error) {
            console.error('Error saving journal entries:', error);
            alert('Failed to save journal entries.');
        }
    }
}