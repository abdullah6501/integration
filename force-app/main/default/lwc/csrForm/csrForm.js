import { LightningElement, track, wire } from 'lwc';
import getCountryPicklistValues from '@salesforce/apex/CSRController.getCountryPicklistValues';
import getInvoiceTypeValues from '@salesforce/apex/CSRController.getInvoiceTypeValues';
import saveCSRData from '@salesforce/apex/CSRController.saveCSRData';
import sendCSRData from '@salesforce/apex/CSRController.sendCSRData';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CsrForm extends LightningElement {
    @track csrData = {
        Company_Name__c: '',
        VAT_Number__c: '',
        Branch_Name__c: '',
        Country__c: '',
        Invoice_Type__c: '',
        Address__c: '',
        Industry__c: '',
        OTP: ''
    };

    @track countryOptions = [];
    @track invoiceTypeOptions = [];
    @track recId;

    @wire(getInvoiceTypeValues)
    wiredInvoiceType({ error, data }) {
        if (data) {
            this.invoiceTypeOptions = data;
        } else if (error) {
            console.error('Error fetching invoice type picklist:', error);
        }
    }

    @wire(getCountryPicklistValues)
    wiredCountries({ error, data }) {
        if (data) {
            this.countryOptions = data;
        } else if (error) {
            console.error('Error fetching country picklist:', error);
        }
    }

    handleInputChange(event) {
        this.csrData[event.target.name] = event.target.value;
    }

    handleSubmit() {
        saveCSRData({ csr: this.csrData })
            .then((recordId) => {
                console.log('result:', recordId);
                this.recId = recordId;
                let requestData = {
                    companyName: this.csrData.Company_Name__c,
                    vatNumber: this.csrData.VAT_Number__c,
                    branchName: this.csrData.Branch_Name__c,
                    country: this.csrData.Country__c,
                    invoiceType: this.csrData.Invoice_Type__c,
                    businessAddress: this.csrData.Address__c,
                    industryType: this.csrData.Industry__c,
                    otp: this.csrData.OTP
                };

                return sendCSRData({ requestData, recId: this.recId });
                // console.log('res:', JSON.stringify(res));
            })
            .then((res) => {  
                console.log('res:', JSON.stringify(JSON.parse(res)));              
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: 'CSR Data saved and sent successfully!',
                    variant: 'success'
                }));
                // this.resetForm();
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: error.body.message,
                    variant: 'error'
                }));
            });
    }

    // resetForm() {
    //     this.csrData = {
    //         Company_Name__c: '',
    //         VAT_Number__c: '',
    //         Branch_Name__c: '',
    //         Country__c: '',
    //         Invoice_Type__c: '',
    //         Address__c: '',
    //         Industry__c: '',
    //         OTP: ''
    //     };
    // }
}
