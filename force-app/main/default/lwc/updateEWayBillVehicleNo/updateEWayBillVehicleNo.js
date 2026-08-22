import { LightningElement, api } from 'lwc';
import updateEWayBillVehicle from '@salesforce/apex/EWayBillService.updateEWayBillVehicle';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class UpdateEWayBillVehicleNo extends LightningElement {
    @api recordId;

    handleConfirm() {
        updateEWayBillVehicle({ invoiceId: this.recordId })
            .then(result => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Update E-Way Bill Vehicle Number successfully.',
                        variant: 'success'
                    })
                );
                this.dispatchEvent(new CloseActionScreenEvent());
            })
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: error.body?.message || 'Update Vehicle Number failed',
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
