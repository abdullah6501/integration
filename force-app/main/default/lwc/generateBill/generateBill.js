import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin } from 'lightning/navigation';
import createBillFromPurchaseOrder from '@salesforce/apex/BillCreatorController.createBillFromPurchaseOrder';
import billExistsForPurchaseOrder from '@salesforce/apex/BillCreatorController.billExistsForPurchaseOrder';

export default class GenerateBill extends NavigationMixin(LightningElement) {
    @api recordId;
    @track isProcessing = false;
    @track billExists = false;
    @track isLoading = true;
    @track error;

    rendered = false;

    get billExistsMessage() {
        return this.billExists
            ? 'Bills already exist. Do you want to create a bill for this Purchase Order?'
            : 'Do you want to create a bill for this Purchase Order?';
    }

    @api invoke() {
        console.log('Invoke method called with recordId:', this.recordId);
        this.createBill();
    }

    async renderedCallback() {
        if (this.rendered) return;
        this.rendered = true;

        if (this.recordId) {
            await this.checkBillExists();
        } else {
            this.isLoading = false;
        }
    }

    async checkBillExists() {
        try {
            this.isLoading = true;
            const timeoutPromise = new Promise((_, reject) =>
                setTimeout(() => reject(new Error('Request timeout')), 10000)
            );
            const exists = await Promise.race([
                billExistsForPurchaseOrder({ purchaseOrderId: this.recordId }),
                timeoutPromise
            ]);
            console.log('Result from Apex:', exists);
            this.billExists = !!exists;
        } catch (e) {
            console.error('Error checking bill existence:', e);
            this.showErrorToast('Error checking existing bills: ' + (e.body?.message || e.message));
            this.billExists = false;
        } finally {
            this.isLoading = false;
        }
    }

    async handleCreateBill() {
        if (this.billExists) {
            const confirmed = confirm('A bill already exists. Are you sure you want to create another bill?');
            if (!confirmed) return;
        }
        await this.createBill();
    }

    async createBill() {
        if (this.isProcessing || !this.recordId) return;

        this.isProcessing = true;
        this.error = null;

        try {
            const billId = await createBillFromPurchaseOrder({ purchaseOrderId: this.recordId });

            this.showSuccessToast('Bill created successfully!');
            this.navigateToBill(billId);
            this.closeAction();

        } catch (error) {
            this.error = error.body?.message || error.message || 'An error occurred while creating the bill';
            this.showErrorToast(this.error);
        } finally {
            this.isProcessing = false;
        }
    }

    showSuccessToast(message) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: message,
            variant: 'success',
        }));
    }

    showErrorToast(message) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: message,
            variant: 'error',
        }));
    }

    navigateToBill(billId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: billId,
                objectApiName: 'RFAB__Bill__c',
                actionName: 'view'
            }
        });
    }

    closeAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleCancel() {
        window.history.back();
    }
}