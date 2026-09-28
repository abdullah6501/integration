// AB 10JUL25 Updated to use refreshApex instead of window.location.reload()
import { LightningElement, api, track, wire } from 'lwc';
import getPicklistValue from '@salesforce/apex/BillPaymentHandler.getPicklistValue';
import getBillDetails from '@salesforce/apex/BillPaymentHandler.getBillDetails';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import saveBillPayment from '@salesforce/apex/BillPaymentHandler.saveBillPayment';
import {refreshApex} from '@salesforce/apex';

export default class BillPayment extends LightningElement {
    @api recordId; // The ID of the bill record
    @track isSaveDisabled = false;
    @track paymentCost;
    @track paymentMode;
    @track paymentDate;
    @track bankCharges;
    @api billName;
    @api accountName;
    @api dueBalance;
    @api earlyPaidAmount;
    @track wiredBillDetailsResult; // Store the result of the wire service

    @track paymentOptions = []; // Your payment options
   

    // Add this lifecycle method to remove unwanted close buttons
    renderedCallback() {
        // Use setTimeout to ensure DOM is fully rendered
        setTimeout(() => {
            this.removeFlowCloseButtons();
        }, 100);
    }

    connectedCallback() {
        // Also try removing close buttons when component connects
        setTimeout(() => {
            this.removeFlowCloseButtons();
        }, 500);
    }


    removeFlowCloseButtons() {
        try {
            // Find all close buttons in the document that are not our custom one
            const allCloseButtons = document.querySelectorAll(
                'lightning-button-icon[icon-name="utility:close"]:not(.custom-modal-close), ' +
                '.slds-button_icon:not(.custom-modal-close), ' +
                '.slds-modal__close:not(.custom-modal-close)'
            );

            allCloseButtons.forEach(button => {
                // Check if this button is outside our component (Flow-generated)
                if (!this.template.contains(button)) {
                    button.style.display = 'none';
                    button.style.visibility = 'hidden';
                    
                    // Also try to hide parent container
                    if (button.parentElement) {
                        button.parentElement.style.display = 'none';
                    }
                }
            });

            // Alternative approach - look for buttons in Flow runtime containers
            const flowContainers = document.querySelectorAll(
                '.runtime_sales_forceBaseScreenAction, ' +
                '.flowruntime-screen, ' +
                '.oneFlowRuntimeBaseScreenAction'
            );

            flowContainers.forEach(container => {
                const closeButtons = container.querySelectorAll(
                    'lightning-button-icon[icon-name="utility:close"], ' +
                    '.slds-button_icon'
                );
                closeButtons.forEach(btn => {
                    btn.style.display = 'none';
                });
            });

        } catch (error) {
            console.log('Error removing close buttons:', error);
        }
    }

    @wire(getPicklistValue)
        wiredTaxPicklistValues({ error, data }) {
            if (data) {
                this.paymentOptions = data.paymentOptions.map(value => ({ label: value, value: value }));
            } else if (error) {
                console.error('Error loading picklists:', error);
            }
        }

    @wire(getBillDetails, { billId: '$recordId' })
    wiredBillDetails(result) {
        const { data, error } = result;
        this.wiredBillDetailsResult = result; // Store the result for later use
        if (data) {
            this.billName = data.billName;
            this.dueBalance = data.dueBalance;
            this.earlyPaidAmount = data.earlyPaidAmount;
            this.accountName = data.accountName;
        } else if (error) {
            console.error('Error loading bill details:', error);
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
        }
        
    }

    updateSaveButtonState() {
        this.isSaveDisabled = !this.paymentCost || !this.paymentMode || !this.paymentDate;
    }

    handleCancel() {
        // Your cancel logic
        this.dispatchEvent(new CustomEvent('cancel'));
    }

     handleSave() {
        if (this.dueBalance <= 0) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'No due balance available for payment',
                    variant: 'error'
                })
            );
            return;
        }
        if (this.dueBalance < this.paymentCost) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Payment amount cannot exceed due balance',
                    variant: 'error'
                })
            );
            return;
        }
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
        this.isSaveDisabled = true;
            saveBillPayment({
                billId: this.recordId,
                paymentAmount: this.paymentCost,
                paymentMode: this.paymentMode,
                paymentDate: this.paymentDate
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
                return refreshApex(this.wiredBillDetailsResult); 
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