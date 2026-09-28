// <!--AR 29/05/2025 Multiple invoice paymentComponent  -->
import { LightningElement, wire, api, track } from 'lwc';
import getInvoiceList from '@salesforce/apex/PaymentMultipleInvoice.getInvoiceList';
import updateInvoices from '@salesforce/apex/PaymentMultipleInvoice.updateInvoices';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

export default class PaymentMultipleInvoice extends LightningElement {
    @api recordId;
    @track invoiceList = [];
    @track sumPayment = 0;
    @track payment;
    @track isSaveDisabled = false;
    @track fullyInvoiced = false;
    originalInvoiceList;
    wiredInvoiceResult;

    @wire(getInvoiceList, { payId: '$recordId' })
    // wiredInvoices({ error, data }) {
    wiredInvoices(value) {
        this.wiredInvoiceResult = value;
        const { error, data } = value;
        if (data) {
            this.payment = data.payment;
            const total = parseFloat(data.payment.totalAmount) || 0;
            const invoiced = parseFloat(data.payment.invoicedAmount) || 0;
            this.availableAmount = total - invoiced;

            if (total === invoiced) {
                this.fullyInvoiced = true;
                this.invoiceList = []; 
                return;
            }
            this.invoiceList = data.invoices.map(invoice => ({
                id: invoice.invoiceId,
                invoiceNumber: invoice.invoiceNumber,
                totalCost: invoice.totalCost,
                paidCost: invoice.paidCost,
                dueBalance: invoice.dueBalance,
                lastPaidDate: invoice.lastPaidDate,
                paymentAmount: invoice.paymentAmount || 0
            }));

            this.originalInvoiceList = JSON.parse(JSON.stringify(this.invoiceList));
        }
        else if (error) {
            console.error('Error fetching invoices: ', error);
            this.showToast('Error', 'Failed to load invoice data', 'error');
        }
    }
    get formattedPaymentAmount() {
        return this.payment?.paymentAmount1 || 0;
    }
    handleEditIconClick(event) {
        event.stopPropagation(); // Prevent event bubbling
        const index = event.currentTarget.dataset.index;
        
        // Update only the clicked row
        this.invoiceList = this.invoiceList.map((invoice, i) => {
            return {
                ...invoice,
                isNotEditing: i !== parseInt(index)
            };
        });
    }
    handleSave() {
        this.isSaveDisabled = true;
        this.sumPayment = 0;


        for (const invoice of this.invoiceList) {
            const paymentAmount = parseFloat(invoice.paymentAmount) || 0;
            const dueBalance = parseFloat(invoice.dueBalance) || 0;
            
            if (paymentAmount > dueBalance) {
                this.showToast(
                    'Error',
                    `Payment amount (${paymentAmount}) cannot exceed due balance (${dueBalance}) for invoice ${invoice.invoiceNumber}`,
                    'error'
                );
                this.isSaveDisabled = false;
                return;
            }
            this.sumPayment += paymentAmount;
        }
        const totalAllowed = parseFloat(this.payment.paymentAmount1) || 0;
        if (this.sumPayment !== totalAllowed) {
            this.showToast(
                'Error',
                `Total payment amount (${this.sumPayment}) must equal the payment total (${totalAllowed}).`,
                'error'
            );
            this.isSaveDisabled = false;
            return;
        }
        const invoicesToUpdate = this.invoiceList
        .filter(invoice => (parseFloat(invoice.paymentAmount) || 0) > 0)
        .map(invoice => ({
            invoiceId: invoice.id,
            invoiceNumber: invoice.invoiceNumber,
            totalCost: invoice.totalCost,
            paidCost: invoice.paidCost,
            dueBalance: invoice.dueBalance,
            lastPaidDate: invoice.lastPaidDate,
            paymentAmount: parseFloat(invoice.paymentAmount)
        }));

    if (invoicesToUpdate.length === 0) {
        this.showToast('Error', 'No valid payment amounts entered', 'error');
        this.isSaveDisabled = false;
        return;
    }
        if (this.sumPayment > totalAllowed) {
            this.showToast(
                'Error',
                `Total payment amount (${this.sumPayment}) cannot exceed available amount (${totalAllowed}).`,
                'error'
            );
            this.isSaveDisabled = false;
            return;
        }
        updateInvoices({ 
            invoiceWrappers: invoicesToUpdate, 
            paymentId: this.recordId, 
            sumPayment: this.sumPayment 
        })
        .then(result => {
            this.showToast('Success', 'Invoices updated successfully', 'success');
            refreshApex(this.wiredInvoiceResult);
            // setTimeout(() => {
            //     window.location.reload();
            // }, 1000);
        })
        .catch(error => {
            console.error('Error updating invoices:', error);
            this.showToast('Error', error.body?.message || 'Error updating invoices', 'error');
        })
        .finally(() => {
            this.isSaveDisabled = false;
        });
    }
    extractInvoiceNumber(htmlString) {
        const div = document.createElement('div');
        div.innerHTML = htmlString;
        return div.textContent;
    }

    handlePaymentChange(event) {
        const index = parseInt(event.target.dataset.index);
        const paymentAmount = parseFloat(event.target.value) || 0;
    
        if (!isNaN(index)) {
            this.invoiceList = this.invoiceList.map((invoice, i) => {
                if (i === index) {
                    return {
                        ...invoice,
                        paymentAmount: paymentAmount
                    };
                }
                return invoice;
            });
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}