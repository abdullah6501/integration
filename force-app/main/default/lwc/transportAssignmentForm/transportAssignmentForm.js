import { LightningElement, track } from 'lwc';
import saveTransAssign from '@salesforce/apex/TransportAssignment.saveTransAssign';
import getTransAssignById from '@salesforce/apex/TransportAssignment.getTransAssignById';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class TransportAssignmentForm extends LightningElement {
    @track assignment = {
        recordId: null,
        productId: '',
        productName: '',
        quantity: '',
        driverId: '',
        driverName: '',
        driverNumber: '',
        vendorId: '',
        vendorName: '',
        gstin: '',
        vehicleNumber: ''
    };

    @track savedAssignment;

    // ---------- Lookup Handlers ----------
    handleProductSelect(event) {
        const selected = event.detail;
        this.assignment.productId = selected.id;
        this.assignment.productName = selected.title;
    }

    handleDriverSelect(event) {
        const selected = event.detail;
        this.assignment.driverId = selected.id;
        this.assignment.driverName = selected.title;
        this.assignment.driverNumber = selected.subField; // phone
    }

    handleVendorSelect(event) {
        const selected = event.detail;
        this.assignment.vendorId = selected.id;
        this.assignment.vendorName = selected.title;
        this.assignment.gstin = selected.subField; // GSTIN
    }

    // Handle text/number input
    handleChange(event) {
        const field = event.target.dataset.field;
        this.assignment[field] = event.target.value;
    }

    // ---------- Save ----------
    handleSave() {
        saveTransAssign({ wrapperData: this.assignment })
            .then((recordId) => {
                this.assignment.recordId = recordId;
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: 'Transport Assignment saved successfully',
                    variant: 'success'
                }));
                return getTransAssignById({ recordId });
            })
            .then(result => {
                this.savedAssignment = result;
            })
            .catch(error => {
                console.error(error);
            });
    }

    editRecord() {
        this.assignment = { ...this.savedAssignment };
    }
}
