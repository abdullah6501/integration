import { LightningElement, api } from 'lwc';
import validateInvoiceRecord from '@salesforce/apex/ZatcaJsonController.validateInvoiceRecord';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class ZatcaRecordId extends LightningElement {
    @api recordId;
    

    handleConfirm() {
        validateInvoiceRecord({ invoiceId: this.recordId })
            .then(result => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Invoice validated successfully.',
                        variant: 'success'
                    })
                );
                this.dispatchEvent(new CloseActionScreenEvent());
            })
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: error.body?.message || 'Validation failed',
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
