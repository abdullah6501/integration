import { LightningElement, wire, track } from 'lwc';
import getIntegrationLogs from '@salesforce/apex/IntegrationLogService.getIntegrationLogs';

export default class IntegrationLogViewer extends LightningElement {
    @track logs = [];
    @track error;
    columns = [
        { label: 'Integration ID', fieldName: 'Integration_Id__c' },
        { label: 'Status', fieldName: 'Status__c' },
        { label: 'Date', fieldName: 'Integration_Date__c', type: 'date' },
        { label: 'Name', fieldName: 'Integration_Name__c' },
        { label: 'Endpoint', fieldName: 'Endpoint__c' },
        { label: 'Request Payload', fieldName: 'Request_Payload__c' },
        { label: 'Response Payload', fieldName: 'Response_Payload__c' }
    ];
    

    @wire(getIntegrationLogs)
    wiredLogs({ data, error }) {
        if (data) {
            this.logs = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.logs = [];
        }
    }

    get hasData() {
        return this.logs && this.logs.length > 0;
    }
}