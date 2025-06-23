import { LightningElement, track, wire } from 'lwc';
import getWhatsAppNumber from '@salesforce/apex/WhatsAppTemplateController.getWhatsAppNumber';
import sendTemplateMessage from '@salesforce/apex/WhatsAppTemplateController.sendTemplateMessage';
import getTemplateNames from '@salesforce/apex/WhatsAppTemplateController.getTemplateNames';
import getTemplateParameters from '@salesforce/apex/WhatsAppTemplateController.getTemplateParameters';
import getTemplates from '@salesforce/apex/WhatsAppTemplateController.getTemplates';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class WhatsAppTemplateSender extends LightningElement {
    @track phoneOptions = []; 
    @track selectedPhoneNumbers = []; 
    @track templateName = '';
    @track parameters = [];
    @track responseMessage = '';
    @track templateOptions = [];
    @track language = '';
    @track maxParameters = 0; 

    @wire(getWhatsAppNumber)
    wiredWhatsAppNumbers({ error, data }) {
        if (data) {
            this.phoneOptions = data.map(record => ({
                label: record.Name,
                value: record.MobilePhone,
            }));
        } else if (error) {
            console.error('Error fetching WhatsApp numbers:', error);
        }
    }

    @wire(getTemplateNames)
    wiredTemplateNames({ error, data }) {
        if (data) {
            console.log(JSON.stringify(data));
            this.templateOptions = data.map(record => ({
                label: record.name,
                value: record.name,
                language: record.language
            }));
        } else if (error) {
            console.error('Error fetching template names:', error);
        }
    }

    handlePhoneSelection(event) {
        const selectedValue = event.target.value;
        const selectedOption = this.phoneOptions.find(option => option.value === selectedValue);
    
        if (selectedOption && !this.selectedPhoneNumbers.some(number => number.value === selectedValue)) {
            this.selectedPhoneNumbers = [...this.selectedPhoneNumbers, selectedOption];
        }
    }
    
    deselectPhoneNumber(event) {
        const numberToRemove = event.target.label;
        this.selectedPhoneNumbers = this.selectedPhoneNumbers.filter(number => number.label !== numberToRemove);
    }

    // handleInputChange(event) {
    //     const field = event.target.dataset.id;
    //     this[field] = event.target.value;
    // }

    async handleTemplateSelection(event) {
        this.templateName = event.target.value;
        const selectedOption = this.templateOptions.find(option => option.value === this.templateName);
        this.language = selectedOption ? selectedOption.language : null;
        
        try {
            const paramString = await getTemplateParameters({ templateName: this.templateName });

            if (paramString) {
                const paramArray = paramString.split(','); 
                this.maxParameters = paramArray.length;
                this.parameters = paramArray.map((param, index) => ({ index, value: '', name: param.trim() }));
            } else {
                this.maxParameters = 0;
                this.parameters = [];
            }
        } catch (error) {
            console.error('Error fetching template parameters:', error);
            this.maxParameters = 0;
            this.parameters = [];
        }
    }

    handleParameterChange(event) {
        const index = event.target.dataset.index;
        this.parameters[index].value = event.target.value;
    }

    async sendMessage() {
        const paramValues = this.parameters.map(param => param.value);

        for (const number of this.selectedPhoneNumbers) {
            try {
                const result = await sendTemplateMessage({
                    phoneNumber: number.value,
                    templateName: this.templateName,
                    language: this.language,
                    parameters: paramValues            
                });
                this.responseMessage = `Message sent to ${number.label}: ${result}`;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: this.responseMessage,
                        variant: 'success'
                    })
                );
                this.templateName = '';
                this.selectedPhoneNumbers = [];
                this.parameters = [];
                this.phoneOptions = [];
                console.log(this.responseMessage);
            } catch (error) {
                console.error(error);
                this.responseMessage = `Error sending message to ${number.label}.`;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: this.responseMessage,
                        variant: 'error'
                    })
                );
            }
        }
    }

    async fetchTemplates() {
        try {
            await getTemplates();
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Templates fetched successfully!',
                    variant: 'success'
                })
            );
            location.reload();
        } catch (error) {
            console.error('Error fetching templates:', error);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to fetch templates',
                    variant: 'error'
                })
            );
        }
    }
}