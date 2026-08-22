import { LightningElement, track } from 'lwc';
// import generateEWayBillAuth from '@salesforce/apex/EWayBillService.generateEWayBillAuth';

export default class InvoiceComponent extends LightningElement {
    @track request = {
        Username: '',
        Password: '',
        clientId: '',
        clientSecret: '',
        gstIn: ''
    };

    @track response;
    @track error;

    handleChange(event) {
        this.request[event.target.name] = event.target.value;
    }

    handleSubmit() {
        generateEWayBillAuth({ reqWrapper: this.request })
            .then(result => {
                try {
                    this.response = JSON.parse(result); 
                    this.error = undefined;
                } catch (err) {
                    this.error = 'Failed to parse response: ' + err.message;
                    this.response = undefined;
                }
            })
            .catch(error => {
                this.error = error.body.message;
                this.response = undefined;
            });
    }
}
