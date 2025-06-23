import { LightningElement, api } from 'lwc';
// import fetchAndStorePDF from '@salesforce/apex/PdfService.fetchAndStorePDF';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class PdfButton extends LightningElement {
    @api recordId; 

    handleClick() {
        fetchAndStorePDF({ json: {}, relatedRecordId: this.recordId })
            .then(() => {
                this.showToast('Success', 'PDF stored successfully!', 'success');
            })
            .catch(error => {
                this.showToast('Error', error.body.message, 'error');
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
