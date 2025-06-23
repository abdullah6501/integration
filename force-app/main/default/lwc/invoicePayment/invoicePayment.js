import { LightningElement, api, track, wire } from 'lwc';
import getPicklistValue from '@salesforce/apex/NewPayment.getPicklistValue';
import getInvoiceDetails from '@salesforce/apex/NewPayment.getInvoiceDetails';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import saveInvoicePayment from '@salesforce/apex/NewPayment.saveInvoicePayment';
export default class InvoicePaymentModal extends LightningElement {
    @api recordId; 
    @api isModalOpen = false;
    
    // Track properties for form fields
    @track paymentCost;
    @track paymentMode;
    @track paymentDate;
    @track bankCharges;
    @track accountName;
    @track invoiceName;
    @track dueBalance;
    @track earlyPaidAmount;

    // Properties for dropdowns
    paymentOptions = [];

    @wire(getPicklistValue)
    wiredTaxPicklistValues({ error, data }) {
        if (data) {
            this.paymentOptions = data.paymentOptions.map(value => ({ label: value, value: value }));
        } else if (error) {
            console.error('Error loading picklists:', error);
        }
    }

    @wire(getInvoiceDetails, { invoiceId: '$recordId' })
    wiredInvoiceDetails({ error, data }) {
        if (data) {
            this.invoiceName = data.invoiceName;
            this.dueBalance = data.dueBalance;
            this.earlyPaidAmount = data.earlyPaidAmount;
            this.accountName = data.accountName;
        } else if (error) {
            console.error('Error loading invoice details:', error);
        }
    }
    handleChange(event) {
        const field = event.target.name;
        const value = event.target.value;
        
        switch(field) {
            case 'paymentCost':
                this.paymentCost = value;
                break;
            case 'paymentMode':
                this.paymentMode = value;
                break;
            case 'paymentDate':
                this.paymentDate = value;
                break;
            case 'bankCharges':
                this.bankCharges = value;
                break;
        }
    }

    closeModal() {
        this.isModalOpen = false;
    }

    handleSave() {
        if (!this.paymentCost || !this.paymentMode || !this.paymentDate) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Please fill all required fields',
                    variant: 'error'
                })
            );
            return;
        }
        if (this.paymentCost <= 0) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Payment amount must be greater than 0',
                    variant: 'error'
                })
            );
            return;
        }
            saveInvoicePayment({
                invoiceId: this.recordId,
                paymentAmount: this.paymentCost,
                paymentMode: this.paymentMode,
                paymentDate: this.paymentDate,
                tdsAmount: this.bankCharges
            })
            .then(result => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Payment saved successfully',
                        variant: 'success'
                    })
                );
                this.handleCancel();
            })
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: error.body.message,
                        variant: 'error'
                    })
                );
            });
     } 
     handleCancel() {
        window.history.back();
    }
}