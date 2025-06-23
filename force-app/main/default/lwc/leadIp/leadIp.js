import { LightningElement, track } from 'lwc';
import getContactsByAccount from '@salesforce/apex/LeadController.getContactsByAccount';
import saveBusinessProcess from '@salesforce/apex/LeadController.saveBusinessProcess';
import {NavigationMixin} from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'

export default class LeadIp extends NavigationMixin(LightningElement)  {
    @track accountId;
    @track contactId;
    @track MobilePhone = '';
    @track email = '';
    @track status = '';
    @track projectReference = '';
    @track endUser = '';
    @track remarks = '';
    journlentryflag = true;
    contactentryflag = true;
    newrecord=true;
   // Error Handling for Required Fields
    @track accountError = false;
    @track contactError = false;

    // Status Picklist Options
    get statusOptions() {
        return [
            { label: 'Contacted', value: 'Contacted' },
            { label: 'Open', value: 'Open' },
            { label: 'Qualified', value: 'Qualified' },
            { label: 'UnQualified', value: 'UnQualified' },
            { label: 'Closed', value: 'Closed' }
        ];
    }


    handleValueSelectedOnAccount(event) {
        const selectedItem = event.detail;
        console.log('selectedItem--->'+JSON.stringify(selectedItem));
        if (selectedItem && event.detail.id) {
            this.accountId=selectedItem.id;
            this.accountError = false; // Clear error
        }
        else{
            this.accountId='';
            this.accountError = !this.accountId; // Set error if Account is not selected
        }
    }

    handleValueSelectedOnContact(event) {
        const selectedItem = event.detail;
        console.log('selectedItem--->'+JSON.stringify(selectedItem));
        if (selectedItem && selectedItem.id) {
            console.log('selectedItem--->'+selectedItem.id);
            this.contactId = selectedItem.id;
            console.log('contactId--->'+this.contactId);
            this.contactError = false; // Clear error
    
            // Fetch contact details based on selected Contact ID
            getContactsByAccount({ accountId: this.accountId })
                .then((data) => {
                    console.log('data--->'+JSON.stringify(data));
                    const contactDetails = data.find(contact => contact.Id === this.contactId);
                    console.log('contactDetails--->'+JSON.stringify(contactDetails));
                    if (contactDetails) {
                        this.contactId = contactDetails.Id ||'';
                        this.MobilePhone = contactDetails.MobilePhone || ''; // Autofill MobilePhone
                        this.email = contactDetails.Email || ''; // Autofill Email
                    }
                })
                .catch(error => {
                    console.error('Error fetching contact details:', error);
                });
    
        } else {
            this.contactId = '';
            this.MobilePhone = ''; // Reset MobilePhone if no Contact is selected
            this.email = ''; // Reset Email if no Contact is selected
            this.contactError = true; // Show error
        }
    }

    handleInputChange(event) {
        this[event.target.name] = event.target.value;
    }

    handleReset() {
        this.accountId = '';
        this.contactId = '';
        this.status = '';
        this.MobilePhone = '';
        this.email = '';
        this.projectReference = '';
        this.endUser = '';
        this.remarks = '';
        this.accountError = false;
        this.contactError = false;
    }

    handleSave() {
       // Validate Required Fields
        this.accountError = !this.accountId;
        this.contactError = !this.contactId;

        if (this.accountError || this.contactError) {
            this.showToast('Error', 'Please fill in all required fields.', 'error');
            return;
        }

        const businessProcessData = {
            IP_Account__c: this.accountId,
            ContactId: this.contactId,
            IP_Phone__c: this.MobilePhone,
            IP_Email__c: this.email,
            RFAB__Division__c : this.status,
            Project_Reference__c: this.projectReference,
            End_User__c: this.endUser,
            Remarks__c: this.remarks
        };
        console.log('businessProcessData-->'+JSON.stringify(businessProcessData));
        saveBusinessProcess({ businessProcessData })
        .then((result) => {
            let parsedResultant = JSON.parse(result);
            console.log('Business Process created with ID:', parsedResultant.leadId);
            if(!parsedResultant.successFlag){
                this.errorMessage = parsedResultant.errorMessage;
                var tempMsg = this.errorMessage;
                const toastEvent = new ShowToastEvent({
                    title:'Failure!',
                    message:tempMsg,
                    variant:'error'
                });

                this.dispatchEvent(toastEvent);


            }else if(parsedResultant.successFlag && parsedResultant.leadId){
                //console.log('Record created successfully:', JSON.stringify(parsedResultant.invoiceId));
                var tempMsg = 'Record created successfully';
                const toastEvent = new ShowToastEvent({
                    title:'Success!',
                    message:tempMsg,
                    variant:'success'
                });
                console.log('Before  Dispatch');
                this.dispatchEvent(toastEvent);

                console.log('Start Navigation');
                //Start Navigation
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId:  parsedResultant.leadId,
                        objectApiName: 'RFAB__Business_Process__c',
                        actionName: 'view'
                    },
                });
                //End Navigation
            }
        })
        .catch((error) => {
            console.error('Error saving Business Process:', error);
        });
    }
}