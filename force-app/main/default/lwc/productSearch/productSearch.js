import { LightningElement, track } from 'lwc';
import getProductAvailability from '@salesforce/apex/ProductSearchController.getProductAvailability';

export default class ProductSearch extends LightningElement {
    @track selectedProductId;
    @track selectedProductName;
    @track productAvailabilityData;
    @track isProductSelected = false;
    @track totalProduct;

    handleValueSelected(event) {
        this.selectedProductId = event.detail.id;
        this.selectedProductName = event.detail.mainField;
        this.isProductSelected = true;
        this.handleSearch();
    }

    handleValueRemoval() {
        this.isProductSelected = false;
        this.selectedProductId = null;
        this.selectedProductName = null;
        this.productAvailabilityData = null;
    }

    handleSearch() {
        getProductAvailability({ productId: this.selectedProductId })
            .then(result => {
                // this.productAvailabilityData = result;
                this.productAvailabilityData = result.map((item, index) => ({
                    ...item,
                    sno: index+1
                    
                }));
                this.totalProduct= result[0].productQuantity;
                console.log('this.productAvailabilityData:', this.totalProduct, this.productAvailabilityData.quantityField);
            })
            .catch(error => {
                console.error('Error in getProductAvailability:', error);
            });
    }

    handleProductRemove() {
        this.isProductSelected = false;
        this.selectedProductId = null;
        this.selectedProductName = null;
        this.productAvailabilityData = null;
        this.totalProduct = null;
    }

}