import { LightningElement, api, track, wire } from 'lwc';
import fetchRecords from '@salesforce/apex/ReusableLookupController.fetchRecords';
import journalentryfetchRecords from '@salesforce/apex/journalentrylookuphandler.fetchRecords';
import fetchRecordTypes from '@salesforce/apex/journalentrylookuphandler.getRecordTypes';
import ACCOUNT_NAME_FIELD from '@salesforce/schema/Account.Name';
import { getRecord } from 'lightning/uiRecordApi';
import searchProducts from '@salesforce/apex/ProductSearchController.searchProducts';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
/** The delay used when debouncing event handlers before invoking Apex. */
const DELAY = 500;
 
export default class ReusableLookup extends LightningElement {
    @api helpText = "custom search lookup";
    @api label = "Parent Account";
    @api required;
    @api selectedIconName = "standard:account";
    @api objectLabel = "Account";
    recordsList = [];
    selectedRecordName;
    showNewRecords = false;
    @api objectApiName = "Account";
    @api fieldApiName = "Name";
    @api otherFieldApiName = "";
    @api additionalFieldApiName = "";
    @api searchString = "";
    @api selectedRecordId = "";
    @api rowId = "";
    @api parentRecordId;
    @api subF;
    @api parentFieldApiName = "";
    @api disableFlag;
    @api searchFieldApiName;
    @api journlentryflag;
    @api newrecord;
    @track isRecordTypeModalOpen = false; // Record Type Selection Modal
    @track isNewRecordModalOpen = false; // New Record Modal
    @track recordTypeOptions = [];
    @track selectedRecordType;
    @api productsearchflag;
    @api relatedParentField;
 
    preventClosingOfSerachPanel = false;
    get methodInput() {
        //console.log('Inside the methodInput');
        return {
            objectApiName: this.objectApiName,
            fieldApiName: this.fieldApiName,
            otherFieldApiName: this.otherFieldApiName,
            additionalFieldApiName: this.additionalFieldApiName,
            searchString: this.searchString,
            selectedRecordId: this.selectedRecordId,
            parentRecordId: this.parentRecordId,
            parentFieldApiName: this.parentFieldApiName,
            searchFieldApiName: this.searchFieldApiName,
            relatedParentField: this.relatedParentField

        };
    }
 
    get showRecentRecords() {
        if (!this.recordsList) {
            return false;
        }
        return this.recordsList.length > 0;
    }
 
    //getting the default selected record
    connectedCallback() {
        if(this.newrecord){
            fetchRecordTypes({ objectApiName: this.objectApiName })
            .then(result => {
                this.recordTypeOptions = result.map(rt => ({
                    label: rt.Name,
                    value: rt.Id
                }));
            })
            .catch(error => {
                // this.showToast('Error', 'Error fetching record types', 'error');
            });
        }
        
        //console.log('Inside the connectedCallBack');
        //console.log("this.selectedRecordId = "+this.selectedRecordId);
        if (this.selectedRecordId) {
            //console.log('Inside the if cond');
            this.fetchSobjectRecords(true,this.journlentryflag);
        }
    }

    openRecordTypeModal() {
        this.isRecordTypeModalOpen = true;
    }

    handleRecordTypeChange(event) {
        this.selectedRecordType = event.detail.value;
    }

    handleNext() {
        if (!this.selectedRecordType) {
            this.showToast('Error', 'Please select a record type', 'error');
            return;
        }
        this.isRecordTypeModalOpen = false;
        this.isNewRecordModalOpen = true;
    }
    handleCloseModal() {
        this.isRecordTypeModalOpen = false;
        this.isNewRecordModalOpen = false;
    }
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    @wire(getRecord, { recordId: '$selectedRecordId', fields: [ACCOUNT_NAME_FIELD] })
    wiredRecord({ error, data }) {
        if (data) {
            this.selectedRecordName = data.fields.Name.value;
        } else if (error) {
            console.error('Error fetching record:', error);
        }
    }

    handleRecordCreated(event) {
        // Capture the newly created record ID
        this.selectedRecordId = event.detail.id;
        let selectedRecord = {
            mainField: event.detail.mainfield,
            id: event.detail.id,
            rowId :this.rowId
        };
        this.selectedRecordId = selectedRecord.id;
        this.selectedRecordName = selectedRecord.mainField;
        this.recordsList = [];
        this.showNewRecords = false;
        // Creates the event
        const selectedEvent = new CustomEvent('valueselected', {
            detail: selectedRecord
        });
        //dispatching the custom event
        this.dispatchEvent(selectedEvent); 
        this.isNewRecordModalOpen = false;
    }

    handleSave() {
        // Manually trigger form submission (not needed if using lightning-record-form)
        const form = this.template.querySelector('lightning-record-form');
        if (form) {
            form.submit();
        }
    }
    
    handleNewAccount() {
        if(this.recordTypeOptions.length > 0){
            this.isRecordTypeModalOpen = true;
            this.showNewRecords = false;
        }
        else{
            this.isNewRecordModalOpen = true;
            this.showNewRecords = false;
        }
    }
 
    // //call the apex method
    fetchSobjectRecords(loadEvent) {
        if(this.journlentryflag){
            journalentryfetchRecords({searchString: this.searchString,recordid: this.selectedRecordId}).then(result => {
                if (loadEvent && result) {
                    this.showNewRecords = false;
                    this.selectedRecordName = result[0]?.mainField || '';
                    this.subF = result[0].subField || '';
                    this.parentFieldApiName = result[0].parentField || '';
                    if(this.searchString==''&& !this.selectedRecordId){
                        this.recordsList = JSON.parse(JSON.stringify(result));
                    }
                } else if (result) {
                    this.showNewRecords = false;
                    this.recordsList = JSON.parse(JSON.stringify(result));
                    if(this.recordsList.length == 0 && this.newrecord==true){
                        this.showNewRecords =true;
                    }
                } else {
                    //console.log("Inside else cond");
                    this.recordsList = [];
                }
            }).catch(error => {
                //console.log(error);
            })
        }
        else if(this.productsearchflag){
            searchProducts({
                searchKey:this.searchString
            }).then(result => {
                 if (result) {
                    this.recordsList = JSON.parse(JSON.stringify(result));
                } else {
                    this.recordsList = [];
                }
            }).catch(error => {
                //console.log(error);
            })
        }
        else{
            console.log('inside kiso if--->');
            console.log('methodinput--->',this.methodInput);
            fetchRecords({
                inputJSON:JSON.stringify(this.methodInput)
            }).then(result => {
                this.showNewRecords = false;
                console.log('inside kumar--->',result);
                console.log('result = '+JSON.stringify(result));
                if (loadEvent && result) {
                    console.log("Inside if cond");
                    this.showNewRecords = false;
                    this.selectedRecordName = result[0].mainField;
                    this.subF = result[0].subField;
                    // console.log('subField = '+JSON.stringify(this.subF));
                    // console.log("this.selectedRecordName = "+JSON.stringify(this.selectedRecordName));
                } else if (result) {
                    console.log("Inside else if cond");
                    this.recordsList = JSON.parse(JSON.stringify(result));
                    if(this.recordsList.length == 0 && this.newrecord==true){
                        this.showNewRecords =true;
                    }
                    console.log('hello--->',this.recordsList);
                } else {
                    console.log("Inside else cond");
                    this.recordsList = [];
                }
            }).catch(error => {
                //console.log(error);
            })
        }
    }
 
    get isValueSelected() {
        return this.selectedRecordId;
    }
 
    handlefetchrecordlist(event){
        //console.log('handlefetchrecordlist')
        if(this.journlentryflag){
            this.fetchSobjectRecords(true,this.journlentryflag);
        }  
    }
 
    //handler for calling apex when user change the value in lookup
    handleChange(event) {
        this.searchString = event.target.value;
        this.fetchSobjectRecords(false);
    }
 
    //handler for clicking outside the selection panel
    handleBlur() {
        this.recordsList = [];
        this.preventClosingOfSerachPanel = false;
        this.showNewRecords = false;
    }
 
    //handle the click inside the search panel to prevent it getting closed
    handleDivClick() {
        this.preventClosingOfSerachPanel = true;
        this.showNewRecords = false;
    }
 
    //handler for deselection of the selected item
    handleCommit(event) {
        this.showNewRecords = false;
        this.selectedRecordId = null;
        this.selectedRecordName = null;
        const selectedEvent = new CustomEvent('valueremoval', {
            detail: null
        });
        this.dispatchEvent(selectedEvent);
        /*let selectedRecord = {
            mainField: null,
            subField: null,
            id: null
        };
        this.selectedRecordId = selectedRecord.id;
        this.selectedRecordName = selectedRecord.mainField;
        this.recordsList = [];
        // Creates the event
        const selectedEvent = new CustomEvent('valueremoval', {
            detail: selectedRecord
        });
        //dispatching the custom event
        this.dispatchEvent(selectedEvent);*/
    }
 
    //handler for selection of records from lookup result list
    handleSelect(event) {
        let selectedRecord = {
            mainField: event.currentTarget.dataset.mainfield,
            subField: event.currentTarget.dataset.subfield,
            additionalField: event.currentTarget.dataset.additionalfield,
            id: event.currentTarget.dataset.id,
            rowId :this.rowId
        };
        this.selectedRecordId = selectedRecord.id;
        this.selectedRecordName = selectedRecord.mainField;
        this.recordsList = [];
        this.showNewRecords = false;
        // Creates the event
        const selectedEvent = new CustomEvent('valueselected', {
            detail: selectedRecord
        });
        //dispatching the custom event
        this.dispatchEvent(selectedEvent);
    }
   
    //to close the search panel when clicked outside of search input
    handleInputBlur(event) {
        // Debouncing this method: Do not actually invoke the Apex call as long as this function is
        // being called within a delay of DELAY. This is to avoid a very large number of Apex method calls.
        window.clearTimeout(this.delayTimeout);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.delayTimeout = setTimeout(() => {
            if (!this.preventClosingOfSerachPanel) {
                this.recordsList = [];
            }
            this.preventClosingOfSerachPanel = false;
        }, DELAY);
    }
 
}