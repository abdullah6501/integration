import { LightningElement, track } from 'lwc';
import getVATTaxDetails from '@salesforce/apex/VATReportHandler.getVATTaxDetails';

export default class VatReport extends LightningElement {
    @track outputVat = [];
    @track inputVat = [];
    @track reverseChargesVat = [];
    @track outputTotal = 0;
    @track outputTaxTotal = 0;
    @track inputTotal = 0;
    @track inputTaxTotal = 0;
    @track reverseTotal = 0;
    @track reverseTaxTotal = 0;
    @track getReport = false;
    startDate = '';
    endDate = '';
    @track reportType = 'VAT';
    handleStartDateChange(event) {
        this.startDate = event.target.value;
    }

    handleEndDateChange(event) {
        this.endDate = event.target.value;
    }
    reportModes = [
        { label: 'Detailed Report', value: 'Detailed' },
        { label: 'Summary Report', value: 'Summary' }
    ];
    handleReportModeChange(event) {
        this.reportMode = event.target.value;
        console.log('Report mode changed to:', this.reportMode);
    }
    get showReport(){
        console.log('Report mode:', this.reportMode, 'Get report:', this.getReport);
        return this.reportMode === 'Detailed' && this.getReport;
    }
    handleGetReport() {
        this.getReport = true;
        if (!this.startDate || !this.endDate) {
            alert('Please select both Start Date and End Date');
            return;
        }
        
        getVATTaxDetails({
            startDate: this.startDate,
            endDate: this.endDate
        })
        .then(data => {
            console.log('VAT data fetched:', JSON.stringify(data));
            // Reset all
            this.outputVat = [];
            this.inputVat = [];
            this.reverseChargesVat = [];
            this.outputTotal = this.outputTaxTotal = 0;
            this.inputTotal = this.inputTaxTotal = 0;
            this.reverseTotal = this.reverseTaxTotal = 0;

            data.forEach(row => {
                const enriched = {
                    ...row,
                    createdDate: row.createdDate ? new Date(row.createdDate).toLocaleDateString() : '',
                    invoiceUrl: row.invoiceId ? '/' + row.invoiceId : '',
                    billUrl: row.billId ? '/' + row.billId : '', 
                    taxUrl: row.taxId ? '/' + row.taxId : ''
                };

                if (row.type === 'Reverse Charge' ) {
                    // ➤ Reverse Charges: only based on isRCM true
                    this.reverseChargesVat.push(enriched);
                    this.reverseTotal += row.billtotal || 0;
                    this.reverseTaxTotal += row.amount || 0;
                } else if (row.type === 'Input Tax') {
                    // ➤ Input VAT: only if isRCM is false
                    this.inputVat.push(enriched);
                    this.inputTotal += row.billtotal || 0;
                    this.inputTaxTotal += row.amount || 0;
                } else if (row.type === 'Output Tax') {
                    // ➤ Output VAT: ignore isRCM
                    this.outputVat.push(enriched);
                    this.outputTotal += row.total || 0;
                    this.outputTaxTotal += row.amount || 0;
                }
            });

            // Round totals
            this.outputTotal = this.outputTotal.toFixed(2);
            this.outputTaxTotal = this.outputTaxTotal.toFixed(2);
            this.inputTotal = this.inputTotal.toFixed(2);
            this.inputTaxTotal = this.inputTaxTotal.toFixed(2);
            this.reverseTotal = this.reverseTotal.toFixed(2);
            this.reverseTaxTotal = this.reverseTaxTotal.toFixed(2);
        })
        .catch(error => {
            console.error('Error fetching VAT details:', error);
            this.outputVat = [];
            this.inputVat = [];
            this.reverseChargesVat = [];
        });
    }

    handleDownload() {
        console.log('Download clicked');
        // Optional CSV logic here
    }

}