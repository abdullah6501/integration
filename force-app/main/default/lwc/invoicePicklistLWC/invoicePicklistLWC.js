import { LightningElement, wire, track } from 'lwc';
import getDependentPicklistValues from '@salesforce/apex/InvoicePicklistController.getDependentPicklistValues';

export default class InvoicePicklistLWC extends LightningElement {
    taxCategoryOptions = [];
    taxExemptionOptions = [];
    picklistMap = {};
    selectedTaxCategory;
    selectedTaxExemption;

    @wire(getDependentPicklistValues)
    wiredPicklists({ data, error }) {
        if (data) {
            this.picklistMap = data;
            this.taxCategoryOptions = Object.keys(data).map(key => ({
                label: key,
                value: key
            }));
        } else if (error) {
            console.error(error);
        }
    }

    handleTaxCategoryChange(event) {
        this.selectedTaxCategory = event.detail.value;
        const exemptions = this.picklistMap[this.selectedTaxCategory] || [];
        this.taxExemptionOptions = exemptions.map(item => ({
            label: item,
            value: item
        }));
        this.selectedTaxExemption = null;
    }

    handleTaxExemptionChange(event) {
        this.selectedTaxExemption = event.detail.value;
    }
}
