import { LightningElement, track, api } from 'lwc';
import cancelInvoice from '@salesforce/apex/CancelEInvoice.cancelInvoice';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CancelInvoice extends LightningElement {
    @api recordId;
    @track wrapper = {
        invoiceId: '',
        cnlRsn: '',
        cnlRem: ''
    };

    connectedCallback() {
        this.wrapper.invoiceId = this.recordId;
    }

    handleChange(event) {
        const field = event.target.dataset.field;
        this.wrapper[field] = event.target.value;
    }

    handleCancel() {
        cancelInvoice({ wrapReq: this.wrapper })
            .then(result => {
                this.showToast('Success', result, 'success');
            })
            .catch(error => {
                this.showToast('Error', error.body.message, 'error');
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
