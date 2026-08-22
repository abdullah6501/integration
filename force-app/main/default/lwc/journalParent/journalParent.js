import { LightningElement, track, api, wire } from 'lwc';
import saveJournalEntries from '@salesforce/apex/JournalEntryController.saveJournalEntries';
import getJournalEntryRecords from '@salesforce/apex/JournalEntryController.getJournalEntryRecords';
import createGeneralLedger from '@salesforce/apex/GeneralLedgerCreator.createGeneralLedgerRecords';
import getLedgerRecord from '@salesforce/apex/GeneralLedgerCreator.getLedgerRecord';
import getdocuments from '@salesforce/apex/JournalEntryController.getdocuments';
import getCurrencyPicklistValues from '@salesforce/apex/JournalEntryController.getCurrencyPicklistValues';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import deleteFileFromJE from '@salesforce/apex/JournalEntryController.deleteFileFromJE';
import getNslog from '@salesforce/apex/InvoiceFormController.getNslog';
 
export default class JournalParent extends NavigationMixin(LightningElement) {
    ns;
    @api billId;
    @api recordId;
    @track documents = [];
    @track records = [];
    @track files = [];
    @track header = {
        name: '',
        date: '',
        currency:'',
        exchangerate: 1,
        billId: '',
        isforeignexchange: false,
        amount:0,
        status: 'Draft'
    };
    @track journalRecords = [];
    @track currencyOptions = [];
    @track isSaving = false;
    wiredJournalEntries;
    post =false;
    isClearDisabled=true;
    // @track selectedCurrency = '';
    @track disableFlag = false;
    @track reverseflag = false;
    @track showForeignExchangeFields = false;
    @track isReverseDisabled = false;
    @track freezeFlag = false;
    @track showReverseModal = false;
    @track reverseComment = '';
    @track isReverseCreateDisabled = true;
 
    @wire(getCurrencyPicklistValues)
    wiredCurrencyOptions({ error, data }) {
        if (data) {
            this.currencyOptions = data;
        } else if (error) {
            console.error('Error loading currency options:', error);
            this.ShowToast('Error', 'Error loading currency options', 'error');
        }
    }

    @wire(getNslog)
    handleNamespace({ error, data }) {
        if (data) {
            this.ns = data.nameSpace != 'null' ? data.nameSpace : '';
        }else if (error) {
            console.error('Error loading namespace:', error);
        }
    }
    connectedCallback() {
        // if (this.recordId) {
        // Compare with snippet from c:)
        // if (this.recordId) {
        //     this.loadJournalEntryData();
        // }
        if(!this.recordId){
            let today = new Date().toISOString().slice(0, 10);
            this.header.date = today;
            this.isClearDisabled=false;
        }
    }
    @wire(getLedgerRecord, { recordId: '$recordId' })
    wiredLedger({ error, data }) {
        if (data === 'Found') {
            this.disableFlag = true;
            this.isReverseDisabled = false; // disableFlag reverse button if ledger exists
        } else if (error) {
            console.error('Error fetching ledger:', error);
        }
    }
 
@wire(getJournalEntryRecords, { recordId: '$recordId' })
 wiredRecords(result) {
      this.wiredJournalEntries = result; // Store the wired result for refreshApex
      if (result.data) {
            this.records = result.data;
            if (this.records.length > 0) {
                 this.parentRecordId = this.ns ? this.records[0][this.ns + 'Parent_Journal_Entry__c'] : this.records[0].Parent_Journal_Entry__c;
                 // disableFlag reverse button if Status__c is 'reversed'
                 const status = this.ns ? this.records[0][this.ns + 'Status__c'] : this.records[0].Status__c;
                 if (status === 'Reversed') {
                      this.isReverseDisabled = true; 
                      this.freezeFlag = true; // Freeze the form if reversed
                 }
                 if(this.parentRecordId){
                      this.navigateToRecord(this.parentRecordId);
                      // this.navigateToRecord(this.records[0].Parent_Journal_Entry__c);
                      return;
                 }
                 this.header.name = this.records[0].Name;
                 console.log('ns-------->'+this.ns);
                 console.log('Name----->'+this.header.name);
                 this.header.date = this.ns ? this.records[0][this.ns + 'Entry_Date__c']:this.records[0].Entry_Date__c; 
                    console.log('date----->'+this.header.date);
                 this.header.currency = this.ns ? this.records[0][this.ns + 'Currency__c']:this.records[0].Currency__c;
                    console.log('currency----->'+this.header.currency);
                 this.header.exchangerate = this.ns ? this.records[0][this.ns + 'Exchange_rate__c']:this.records[0].Exchange_rate__c;
                    console.log('exchangerate----->'+this.header.exchangerate);
                 this.header.isforeignexchange = this.ns ? this.records[0][this.ns + 'Foreign_Exchange__c']:this.records[0].Foreign_Exchange__c;
                    console.log('isforeignexchange----->'+this.header.isforeignexchange);
                 this.header.amount = this.ns ? this.records[0][this.ns + 'Foreign_Amount__c']:this.records[0].Foreign_Amount__c;
                 if(this.header.isforeignexchange){
                    this.showForeignExchangeFields = true;
                    this.header.amount = this.ns ? this.records[0][this.ns + 'Foreign_Amount__c']:this.records[0].Foreign_Amount__c;
                    console.log('header.amount: ' + this.header.amount);

                 }
                 console.log('isforeignexchange: ' + this.header.isforeignexchange);
                 if(!this.billId){
                      this.header.billId = this.records[0].Bill__c || '';
                 }
            }
      } else if (result.error) {
            console.error(result.error);
      }
 }
 
    navigateToRecord(recordId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: this.ns ? this.ns + 'Journal_Entry__c' : 'Journal_Entry__c',
                actionName: 'view'
            }
        });
    }
 
    
    
    @wire(getdocuments, { recordId: '$recordId' })
    wiredFiles(result) {
        if (result.data) {
            console.log('###result: ' + JSON.stringify(result.data));
            this.documents = result.data;
            console.log('###documents: ' + this.documents);
        } else if (result.error) {
            console.error('Error fetching files:', result.error);
        }
    }
    previewFile(event) {
        const contentDocumentId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: { pageName: 'filePreview' },
            state: { selectedRecordId: contentDocumentId }
        });
    }

    // handleCurrencyChange(event) {
    //     this.selectedCurrency = event.detail.value;
    // }
 
    handleHeaderChange(event) {
        const field = event.target.dataset.field;
        this.header = { ...this.header, [field]: event.target.value };

        console.log('fghj----->'+ this.header[field]);
        console.log('header: ' + JSON.stringify(this.header));
        if(field == 'isforeignexchange' ){
            this.header.isforeignexchange = event.target.checked;
            
            // if(!this.header.isforeignexchange){
            //     this.finalAmount = 0; // Reset finalAmount when foreign exchange is enabled
            // }
            console.log('isforeignexchange>>>>>>: ' + this.header.isforeignexchange);
        }
        if(this.header.isforeignexchange){
            console.log('isforeignexchange---: ' + this.header.isforeignexchange);
            this.showForeignExchangeFields = true;
            console.log('isforeignexchange---->>>>: ' + this.header.isforeignexchange);
            // Calculate finalAmount if amount or exchangerate changes
            if (field === 'amount' || field === 'exchangerate') {
                const amount = parseFloat(this.header.amount) || 0;
                const exchangerate = parseFloat(this.header.exchangerate) || 1;
                // this.finalAmount = amount * exchangerate;
            }
        }
        else{
            this.showForeignExchangeFields = false;
        }
    }
 
    handleJournalRecordsUpdate(event) {
        this.journalRecords = event.detail;
        console.log('journalRecords: ' + this.journalRecords);
    }

    openReverseModal() {
        this.showReverseModal = true;
        this.reverseComment = '';
        this.isReverseCreateDisabled = true;
    }

    closeReverseModal() {
        this.showReverseModal = false;
        this.reverseComment = '';
    }

    handleReverseCommentChange(event) {
        this.reverseComment = event.target.value;
        this.isReverseCreateDisabled = !this.reverseComment || this.reverseComment.trim() === '';
    }

    submitReverse() {
        if (!this.reverseComment || this.reverseComment.trim() === '') {
            this.isReverseCreateDisabled = true;
            return;
        }
        this.showReverseModal = false;
        this.handlereversepost(this.reverseComment);
    }

    handlereversepost(comment) {
        // Add comment to header for Apex
        this.header.Comments__c = comment;
        this.header.status = 'Reversed'; // Set status to Reversed
        this.reverseflag = false; // Reset reverse flag
        console.log('revese flag------>'+ this.reverseflag);
        this.handleSave()
        .then((result) => {  
                   
        });
        this.reverseflag = true;
        this.recordId =null;
        console.log('recordId--->'+this.recordId);
        this.handleSave()
        .then((result) => {
            createGeneralLedger({ journalEntryId: result });
        });
    }

  handlesavepost(){
    this.disableFlag = true;
    
    if(this.recordId == null){
        this.post = true; // Set post flag to true
        this.handleSave()
        .then((result) => {
            // Use the result from handleSave (which is the parentEntry.Id)
            return createGeneralLedger({ journalEntryId: result });
        })
        .then(() => {                      
            this.ShowToast('Success', 'General Ledger records created successfully!', 'success');
            window.location.reload();
        })
        .catch(error => {
            console.error('Error in handlesavepost:', error);
            this.ShowToast('Error', error.body?.message || 'Failed to save journal entries.', 'error');
        })
        .finally(() => {
            this.disableFlag = false;
        });
    }
    else if (this.recordId) {
        // For existing records, also set post to true and call handleSave first
        this.post = true;
        this.handleSave()
        .then((result) => {
            return createGeneralLedger({ journalEntryId: this.recordId });
        })
        .then(() => {
            this.ShowToast('Success', 'General Ledger records created successfully!', 'success');
            window.location.reload();
        })
        .catch(error => {
            this.ShowToast('Error', error.body?.message || 'Failed to create general ledger.', 'error');
        })
        .finally(() => {
            this.disableFlag = false;
            this.post = false; // Reset post flag
        });
    }
}
    
    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        this.files = [...this.files, ...uploadedFiles.map(file => ({
            documentId: file.documentId,
            fileName: file.name
        }))];
        console.log('Files uploaded:', JSON.stringify(this.files));
        // toast
        this.ShowToast('Success', 'File(s) uploaded successfully!', 'success');
    }

    // Remove a single file from the list
    handleRemove(event) {
        const documentId = event.target.dataset.id;
        this.files = this.files.filter(file => file.documentId !== documentId);
    }
    // KK 11/06/25 - Delete a file from the Journal Entry
    handleDelete(event) {
        const contentDocumentId = event.currentTarget.dataset.id;

        // Show confirmation before deleting
        if (confirm('Are you sure you want to delete this file?')) {
            deleteFileFromJE({ 
                contentDocumentId: contentDocumentId, 
                journalEntryId: this.recordId 
            })
            .then(() => {
                this.ShowToast('Success', 'File deleted successfully', 'success');

                // Optionally: Wait a moment then reload
                setTimeout(() => {
                    window.location.reload();
                }, 500);
            })
            .catch(error => {
                console.error('Error deleting file:', error);
                this.ShowToast('Error', 'Failed to delete file', 'error');
            });
        }
    }

    handleSave() {
    this.freezeFlag = true; // Disable Save button immediately
    try {
        const jsonRows = JSON.stringify(this.journalRecords);
        console.log('###jsonRows: ' + JSON.stringify(jsonRows));
        console.log('#journalRecords: ' + JSON.stringify(this.journalRecords));
        let debitTotal = 0;
        let creditTotal = 0;
        let hasDebit = false;
        let hasCredit = false;

        this.journalRecords.forEach(record => {
            const debit = parseFloat(record.debit);
            const credit = parseFloat(record.credit);
            if (record.debit > 0) {
                debitTotal += debit;
                hasDebit = true;
            }
            if (record.credit > 0) {
                creditTotal += credit;
                hasCredit = true;
            }
        });
        debitTotal = parseFloat(debitTotal.toFixed(2));
        creditTotal = parseFloat(creditTotal.toFixed(2));
        
        if(this.billId){
            this.header.billId = this.billId;
        }
        console.log('###header: ' + JSON.stringify(this.header));
        
        const header1 = JSON.stringify(this.header);
        console.log('###header1: ' + header1);
        
        if (!hasDebit && hasCredit) {
            this.freezeFlag = false; // Enable Save button on error
            this.ShowToast('Failure!', 'Missing Debit.', 'error');
            return Promise.reject('Missing Debit');
        }
        if (!hasCredit && hasDebit) {
            this.freezeFlag = false; // Enable Save button on error
            this.ShowToast('Failure!', 'Missing Credit.', 'error');
            return Promise.reject('Missing Credit');
        }
        if (debitTotal !== creditTotal) {
            this.freezeFlag = false; // Enable Save button on error
            this.ShowToast('Failure!', 'Debit and Credit amount not Equal.', 'error');
            return Promise.reject('Debit and Credit amount not Equal');
        }
        
        console.log('###header1: ' + header1);
        
        if (debitTotal === creditTotal) {
            return saveJournalEntries({  // Add 'return' here
                jsonRows: jsonRows,
                recordId: this.recordId,
                header: header1,
                post: this.post,
                files: this.files,
                reverseflag: this.reverseflag
            })
            .then((result) => {
                // if(this.recordId && this.reverseflag){
                //     this.ShowToast('Success!', 'Record Reversed', 'success');
                //}
                if (this.recordId) {
                    this.ShowToast('Success!', 'Record Updated', 'success');
                    this.files = [];
                    window.location.reload();

                    setTimeout(() => {
                        this.navigateToListView();
                    }, 500);
                    refreshApex(this.wiredJournalEntries);
                } else {
                    this.ShowToast('Success!', 'Record Created', 'success');
                    this.files = [];
                    setTimeout(() => {
                        //this.resetComponent();
                        window.location.reload();
                    }, 500);
                    this.disableFlag = false;
                }
                return result; // Return the result to the calling method
            })
            .catch((error) => {
                this.freezeFlag = false; // Enable Save button on error
                console.error("###Error in handle save:  " + error.body.message);
                this.ShowToast('Failure!', 'Error saving record.', 'error');
                throw error; // Re-throw the error
            });
        } else {
            this.freezeFlag = false; // Enable Save button on error
            this.ShowToast('Failure!', 'Total Amount and Entry Amount must be Equal.', 'error');
            return Promise.reject('Total Amount and Entry Amount must be Equal');
        }
    } catch (error) {
        this.freezeFlag = false; // Enable Save button on error
        console.error('Error saving journal entries:', error);
        this.ShowToast('Failure!', 'Failed to save journal entries.', 'error');
        return Promise.reject(error);
    }
}
    handleclear() {
        this.resetComponent();
    }
 
    resetComponent() {
    this.recordId = null;
    this.header = { name: '', date: new Date().toISOString().slice(0, 10), currency:'',exchangerate:'' };
    this.journalRecords = [];
 
    const childComponent = this.template.querySelector('c-journal-entries');
    if (childComponent) {
        childComponent.clearJournalEntries();
    }
}
   
    
    navigateToListView() {
        if (!billId) {
            Promise.resolve().then(() => {
            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: {
                    objectApiName: this.ns ? this.ns + 'Journal_Entry__c' : 'Journal_Entry__c',
                    actionName: 'list'
                }
            });
        });    
        } 
    }
 
    ShowToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }

    handleAddDebit() {
        const journalEntries = this.template.querySelector('c-journal-entries');
        if (journalEntries) {
            journalEntries.handleAddDebit();
        }
    }

    handleAddCredit() {
        const journalEntries = this.template.querySelector('c-journal-entries');
        if (journalEntries) {
            journalEntries.handleAddCredit();
        }
    }
}