import { LightningElement, api } from 'lwc';
import clearanceInvoice from '@salesforce/apex/ZatcaJsonController.clearanceInvoice';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class ZatcaClearance extends LightningElement {
    @api recordId;

    handleConfirm() {
        clearanceInvoice({ invoiceId: this.recordId })
            .then(result => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Invoice Cleared successfully.',
                        variant: 'success'
                    })
                );
                this.dispatchEvent(new CloseActionScreenEvent());
            })
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: error.body?.message || 'Clearance failed',
                        variant: 'error'
                    })
                );
                this.dispatchEvent(new CloseActionScreenEvent());
            });
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}
