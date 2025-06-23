import { LightningElement, track, api, wire } from 'lwc';
import getpurchaseOrderItems from '@salesforce/apex/CreatePurchaseOrderItems.getpurchaseOrderItems';
import getPurchaseOrder from '@salesforce/apex/CreatePurchaseOrderItems.getPurchaseOrder';
import searchProducts from '@salesforce/apex/CreatePurchaseOrderItems.searchProductsWrapper';
import deleteEstimationItem from '@salesforce/apex/CreatePurchaseOrderItems.deletePoItem';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPicklistValue from '@salesforce/apex/CreatePurchaseOrderItems.getPicklistValue';
import savesPurchaseOrder from '@salesforce/apex/CreatePurchaseOrderItems.savesPurchaseOrder';
import savePurchaseOrderItemsWithWrapper from '@salesforce/apex/CreatePurchaseOrderItems.savePurchaseOrderItemsWithWrapper';
export default class PoItems extends LightningElement {
   @api recordId; // Parent Estimation record ID
       @track poItems = [];
       @track searchResults = [];
       @track hideDiscountFields = false;
       @track isButtonDisabled = false;
       @track discountType =[];
       discountTypeValue;
       discountModeValue;
       taxOptions=[];
       discOptions=[];
       @wire(getPicklistValue)
       wiredTaxPicklistValues({ error, data }) {
            if (data) {
                this.taxOptions = data.taxOptions.map(value => ({ label: value, value: value }));
                console.log("Tax Options: ", JSON.stringify(this.taxOptions));
                
                this.discOptions = data.discOptions.map(value => ({ label: value, value: value }));
                console.log("Discount Mode Options: ", JSON.stringify(this.discOptions));
                this.discountType = data.discountType.map(value => ({ label: value, value: value }));
                console.log("Discount Type Options: ", JSON.stringify(this.discountType));
            } else if (error) {
                console.error('Error loading picklists:', error);
            }
        }
    //    @wire(getPicklistValue, { 
    //        objectApiName: 'Purchase_Order__c', 
    //        fieldApiName: 'Tax_Percentage__c' 
    //    })
    //    wiredTaxPicklistValues({ error, data }) {
    //        if (data) {
    //            this.taxOptions = data.map(label => ({ label, value: label }));
    //        } else if (error) {
    //            console.error('Error fetching tax picklist values:', error);
    //        }
    //    }
       
    //    @wire(getPicklistValue, { 
    //        objectApiName: 'Purchase_Order__c', 
    //        fieldApiName: 'Discount_Mode__c' 
    //    })
    //    wiredDiscountModePicklistValues({ error, data }) {
    //        if (data) {
    //            this.discOptions = data.map(label => ({ label, value: label }));
    //        } else if (error) {
    //            console.error('Error fetching discount mode picklist values:', error);
    //        }
    //    }
       
    //    @wire(getPicklistValue, { 
    //        objectApiName: 'Purchase_Order__c', 
    //        fieldApiName: 'Discount_Type__c' 
    //    })
    //    wiredDiscountTypePicklistValues({ error, data }) {
    //        if (data) {
    //            this.discountType = data.map(label => ({ label, value: label }));
    //        } else if (error) {
    //            console.error('Error fetching discount type picklist values:', error);
    //        }
    //    }
       get showDiscountAmount() {
           return this.discountTypeValue == 'Line Item Discount' && 
                  this.discountModeValue == 'Amount';
       }
   
       get showDiscountPercentage() {
           return this.discountTypeValue == 'Line Item Discount' && 
                  this.discountModeValue == 'Percentage';
       }
       get showLumpsumAmount() {
           return this.discountTypeValue === 'Lumpsum Discount' && 
                  this.discountModeValue === 'Amount';
       }
       
       get showLumpsumPercentage() {
           return this.discountTypeValue === 'Lumpsum Discount' && 
                  this.discountModeValue === 'Percentage';
       }
       get showLumpsumTax() {
           return this.discountTypeValue === 'Lumpsum Discount' 
       }
       get noneTax(){
           return !this.discountTypeValue || 
              this.discountTypeValue === '' || 
              this.discountTypeValue === 'Line Item Discount';
       }
       get totalAmount() {
           return this.poItems.reduce((total, item) => {
               const amount = (item.unitPrice || 0) * (item.quantity || 0);
               return total + amount;
           }, 0).toFixed(2);
       }
       @track lumpsumAmount = 0;
       @track lumpsumPercentage = 0;
       get totalDiscount() {
           const total = parseFloat(this.totalAmount) || 0;
           if (this.discountTypeValue === 'Line Item Discount') {
               if (this.discountModeValue === 'Percentage') {
                   return this.poItems.reduce((total, item) => {
                       const amount = (item.unitPrice || 0) * (item.quantity || 0);
                       const discount = amount * ((item.discountPercentage || 0) / 100);
                       return total + discount;
                   }, 0).toFixed(2);
               } else if (this.discountModeValue === 'Amount') {
                   return this.poItems.reduce((total, item) => {
                       const discount = Number(item.discountAmount || 0);
                       return total + discount;
                   }, 0).toFixed(2);
               }
           } else if (this.discountTypeValue === 'Lumpsum Discount') {
               if (this.discountModeValue === 'Percentage') {
                   const discountPercentage = parseFloat(this.lumpsumPercentage) || 0;
                   return (total * (discountPercentage / 100)).toFixed(2);
               } else if (this.discountModeValue === 'Amount') {
                   const discountAmount = parseFloat(this.lumpsumAmount) || 0;
                   return discountAmount.toFixed(2);
               }
           }
           
           return '0.00';
       }
       get calculatedTaxAmount() {
           if (!this.discountTypeValue || this.discountTypeValue === '') {
               return this.poItems.reduce((total, item) => {
                   const baseAmount = (item.unitPrice || 0) * (item.quantity || 0);
                   const taxAmount = baseAmount * (parseFloat(item.taxPercentage || 0) / 100);
                   return total + taxAmount;
               }, 0).toFixed(2);
           }
           if (this.discountTypeValue === 'Line Item Discount' || this.discountTypeValue === '' || !this.discountTypeValue) {
               
               if (this.discountModeValue === 'Percentage') {
                   
                   return this.poItems.reduce((total, item) => {
                       const baseAmount = (item.unitPrice || 0) * (item.quantity || 0);
                       const discountedAmount = baseAmount - (baseAmount * (item.discountPercentage || 0) / 100);
                       const taxAmount = discountedAmount * (parseFloat(item.taxPercentage || 0) / 100);
                       return total + taxAmount;
                   }, 0).toFixed(2);
               } else if (this.discountModeValue === 'Amount') {
                   
                   return this.poItems.reduce((total, item) => {
                       const baseAmount = (item.unitPrice || 0) * (item.quantity || 0);
                       const discountedAmount = baseAmount - (item.discountAmount || 0);
                       const taxAmount = discountedAmount * (parseFloat(item.taxPercentage || 0) / 100);
                       return total + taxAmount;
                   }, 0).toFixed(2);
               }
           } 
   
           if (this.discountTypeValue === 'Lumpsum Discount') {
               const subtotal = parseFloat(this.calculatedSubTotal) || 0;
               const taxPercentage = parseFloat(this.lumpsumTaxPercentage || 0) / 100;
               return (subtotal * taxPercentage).toFixed(2);
           }
           
           return '0.00';
       }
       get calculatedSubTotal() {
           const total = parseFloat(this.totalAmount) || 0;
           const discount = parseFloat(this.totalDiscount) || 0;
           return (total - discount).toFixed(2);
       }
       get grandTotal() {
           const subtotal = parseFloat(this.calculatedSubTotal) || 0;
           const taxAmount = parseFloat(this.calculatedTaxAmount) || 0;
           return (subtotal + taxAmount).toFixed(2);
       }
       lumpsumTaxPercentage;
       handleLumpsumTax(event) {
           this.lumpsumTaxPercentage = event.detail.value;
       }
       handleDiscountTypeChange(event) {
           this.discountTypeValue = event.detail.value;
       }
       handleDiscountModeChange(event) {
           this.discountModeValue = event.detail.value;
           this.poItems = this.poItems.map(item => ({
               ...item,
               discountMode: this.discountModeValue
           }));
       }
       handleLumpsumChange(event) {
           const fieldName = event.target.name;
           const value = event.target.value;
           
           if (fieldName === 'lumpsumAmount') {
               this.lumpsumAmount = value;
           } else if (fieldName === 'lumpsumPercentage') {
               this.lumpsumPercentage = value;
           }
           
       }
       connectedCallback() {
           this.loadpoItems();
       }
         @track purchaseOrderDetails=[];
       loadpoItems() {
        getPurchaseOrder({
            purchaseOrderId: this.recordId
           })
               .then(data => {
                    console.log("Purchase order data: ", JSON.stringify(data));
                   if (data) {
                    this.purchaseOrderDetails = [{
                        Id: data.id,
                        supplierNameField: data.supplierNameField,
                        paymentTerms: data.paymentTerms,
                        shippingTerms: data.shippingTerms
                    }];

                    console.log("Purchase order details: ", JSON.stringify(this.purchaseOrderDetails));
                       this.discountTypeValue = data.discountType;
                       this.discountModeValue = data.discountMode;
                       this.lumpsumAmount = data.lumpsumDiscountAmount;
                       this.lumpsumPercentage = data.lumpsumDiscountPercentage;
                       this.lumpsumTaxPercentage = data.taxPercentage;
                   }
               });
            getpurchaseOrderItems({ purchaseOrderId: this.recordId })
               .then(data => {
                   this.poItems = data.map(item => {
                       const discountType = item.purchaseOrderDiscountType || '';
                       const enableAmount = discountType === 'Amount';
                       const enablePercentage = discountType === 'Percentage';
                       
                       return {
                       ...item,
                       id : item.id,
                       keyField: item.keyField,
                       productName: item.productName || '',
                       description: item.description,
                       productSku: item.productSku || '',
                       productQuantity: item.productQuantity || '',
                       unitPrice: item.unitPrice,
                       quantity: item.quantity,
                       taxPercentage: item.taxPercentage,
                       discountAmount: item.discountAmount ?? '',
                       discountPercentage: item.discountPercentage ?? '',
                       discountMode: item.discountMode,
                       productId: item.productId,
                       enableAmount,
                       enablePercentage,
                       disableAmount: !enableAmount,
                       disablePercentage: !enablePercentage,
                       searchResults: []
                       }
                   });
               })
               .catch(error => {
                   console.error('Error fetching PO items', error);
               });
       }
       @track row;
       @track targetIndex;
       @track fromIndex;
   
       start(event) {
           this.row = event.target; 
       }
       
       over(event) {
           event.preventDefault();
           var children = Array.from(event.target.parentNode.parentNode.children);
           this.targetIndex = children.indexOf(event.target.parentNode);
           this.fromIndex = children.indexOf(this.row);
       }
       newDrop(event) {
           const fromIndex = this.fromIndex;
           const toIndex = this.targetIndex;
           const element = this.poItems.splice(fromIndex, 1)[0];
           this.poItems.splice(toIndex, 0, element);
           
         
           this.poItems = this.poItems.map((item, index) => ({
               ...item,
               keyField: index + 1
           }));
       }
       handleProductSearch(event) {
           const searchKey = event.target.value;
           const index = event.target.dataset.index;
       
           if (searchKey.length > 2) { 
               searchProducts({ searchKey })
                   .then(data => {
                    console.log("Search results: ", JSON.stringify(data));
                       this.poItems = this.poItems.map((item, i) => ({
                           ...item,
                           searchResults: i === parseInt(index) ? data : [] 
                       }));

                       console.log("Search results for index " , JSON.stringify(this.poItems[index].searchResults));
                   })
                   .catch(error => {
                       console.error('Error searching products', error);
                   });
           } else {
               this.clearSearchResults(index);
           }
       }
       
    //    selectProduct(event) {
    //        const index = event.target.dataset.index;
    //        const productId = event.currentTarget.dataset.id;
       
    //        const selectedProduct = this.poItems[index].searchResults.find(p => p.id === productId);
    //        console.log("Selected product: ", JSON.stringify(selectedProduct));
    //        if (selectedProduct) {
    //            this.poItems[index] = {
    //                ...this.poItems[index],
    //                productId: selectedProduct.id,
    //             //    productSku: selectedProduct.productSku,
    //                productQuantity: selectedProduct.productQuantity,
    //                unitPrice: selectedProduct.actualCost,
    //                productName: selectedProduct.name,
    //                searchResults: [] 
    //            };
    //            console.log("Updated PO item: ", JSON.stringify(this.poItems[index]));
    //        }
    //    }
    selectProduct(event) {
        const index = event.target.dataset.index;
        const productId = event.currentTarget.dataset.id;
         console.log("event.target.dataset.index  "+ JSON.stringify(event.target.dataset));
            console.log("event.currentTarget.dataset.  "+ JSON.stringify(event.currentTarget.dataset));
          console.log("this.poItems[index].searchResults  "+ JSON.stringify(this.poItems[index].searchResults));
        const selectedProduct = this.poItems[index].searchResults.find(p => p.id === productId);
        console.log("Selected product: ", JSON.stringify(selectedProduct));
        if (selectedProduct) {
            this.poItems[index] = {
                ...this.poItems[index],
                //id: selectedProduct.id,
                productSku: selectedProduct.sku,
                productQuantity: selectedProduct.productQuantity,
                unitPrice: selectedProduct.actualCost,
                productName: selectedProduct.name,
                // productName: selectedProduct.name,
                 productId: selectedProduct.id,
                // productSku: selectedProduct.sku,
                // productQuantity: selectedProduct.productQuantity,
                // unitPrice: selectedProduct.actualCost,
                // name: selectedProduct.name,
                // productName: selectedProduct.name,
                searchResults: []
            };
            console.log("Updated PO item: ", JSON.stringify(this.poItems[index]));
        }
    }
       
       clearSearchResults(index) {
           this.poItems = this.poItems.map((item, i) => ({
               ...item,
               searchResults: i === parseInt(index) ? [] : item.searchResults
           }));
       }
   
       handleInputChange(event) {
           const index = event.target.dataset.index;
           const field = event.target.name;
           const value = event.detail.value;
           this.poItems[index][field] = value;
           if (field === 'discountMode') {
               const isAmount = value === 'Amount';
               const isPercentage = value === 'Percentage';
       
               this.poItems[index].disableAmount = !isAmount;
               this.poItems[index].disablePercentage = !isPercentage;
           }
       }
   
       addRow() {
           this.poItems = [...this.poItems, { 
               productId: '', 
               productName: '', 
               productSku: '', 
               productQuantity: '', 
               unitPrice: '', 
               quantity: '', 
               taxPercentage: '',
               searchResults: [] 
           }];
       }
       async saveRecords() {
        console.log('Saving records with discountTypeValue:', this.discountTypeValue);
        
           this.isButtonDisabled = true;
           savesPurchaseOrder({
               discountTypeValue: this.discountTypeValue, 
               discountModeValue: this.discountModeValue,
               lumpsumAmount: this.lumpsumAmount,
               lumpsumPercentage: this.lumpsumPercentage,
               lumpsumTaxPercentage: this.lumpsumTaxPercentage,
               purchaseOrderId: this.recordId 
           })
           
    //        .then(() => {
    //             console.log('this.recordId'+ this.recordId);

    //             this.showToast('Success', 'Purchase Order Saved Successfully', 'success');
    //             console.log('Poitems'+ JSON.stringify(this.poItems));
    //             console.log('this.discountModeValue'+ this.discountModeValue);
    //            this.poItems = this.poItems.map((item, index) => ({
    //                ...item,
    //                discountMode: this.discountModeValue,
    //                keyField: index + 1
    //            }));
    //            console.log('Return ;;Poitems'+ JSON.stringify(this.poItems));
    //             savePurchaseOrderItemsWithWrapper({ 
    //                itemWrappers: this.poItems, 
    //                purchaseOrderId: this.recordId 
    //            });
    //        })
    //        .then((result) => {
    //                this.showToast('Success', 'PO Item Saved Successfully', 'success');
    //                this.dispatchEvent(new CustomEvent('success', { detail: 'Records saved successfully!' }));
    //                this.loadpoItems();
    //             //    setTimeout(() => {
    //             //        window.location.reload(); 
    //             //    }, 2000);
    //            })
    //            .catch(error => {
    //                console.error('Error saving records', error);
    //             //    setTimeout(() => {
    //             //        window.location.reload(); 
    //             //    }, 2000);
    //            });
    //    }
     
        try {
            console.log('this.recordId: ' + this.recordId);
            
            savesPurchaseOrder({
                discountTypeValue: this.discountTypeValue, 
                discountModeValue: this.discountModeValue,
                lumpsumAmount: this.lumpsumAmount,
                lumpsumPercentage: this.lumpsumPercentage,
                lumpsumTaxPercentage: this.lumpsumTaxPercentage,
                purchaseOrderId: this.recordId 
            });
            
            // this.showToast('Success', 'Purchase Order Saved Successfully', 'success');
    
            this.poItems = this.poItems.map((item, index) => ({
                ...item,
                id: item.id,
                discountMode: this.discountModeValue,
                keyField: index + 1
            }));
    
            console.log('Mapped poItems:', JSON.stringify(this.poItems));
            const cleanItems = this.poItems.map(item => ({
                id: item.id,
                keyField: item.keyField,
                productName: item.productName || '',
                productSku: item.productSku || '',
                productQuantity: parseFloat(item.productQuantity) || 0,
                unitPrice: item.unitPrice,
                quantity: item.quantity,
                taxPercentage: item.taxPercentage,
                discountAmount: parseFloat(item.discountAmount) ?? 0,
                discountPercentage: parseFloat(item.discountPercentage) ?? 0,
                discountMode: item.discountMode,
                productId: item.productId
            }));
            console.log('cleanItems:', JSON.stringify(cleanItems));
            const result = await savePurchaseOrderItemsWithWrapper({ 
                itemWrappers: cleanItems, 
                purchaseOrderId: this.recordId 
            });
            this.showToast('Success', 'PO Item Saved Successfully', 'success');
            this.dispatchEvent(new CustomEvent('success', { detail: 'Records saved successfully!' }));
            this.loadpoItems();
            setTimeout(() => {
                window.location.reload(); 
            }, 2000);
        } catch (error) {
            console.error('Error saving records', error);
        }
    }
    
    
        // Delete row based on index
       deleteRow(event) {
           let index = event.target.dataset.index;
           let itemId = this.poItems[index].id;
           this.showConfirmationDialog("Are you sure you want to delete this item?")
           .then((confirmation) => {
               if (!confirmation) return;
          
               if (itemId) {
                   // Call Apex method to delete from Salesforce
                   deleteEstimationItem({ itemId })
                       .then(() => {
                           this.showToast('Success', 'Item deleted successfully', 'success');
                           this.poItems = this.poItems.filter((_, i) => i != index);
                       })
                       .catch(error => {
                           this.showToast('Error', 'This Purchase Order cannot be Update/deleted because it has related to PurchaseOrder Or Invoice records.', 'error');
                           console.error('Error deleting record:', error);
                           setTimeout(() => {
                               window.location.reload(); // Refresh the page
                           }, 2000);
                       });
               } else {
                   // Just remove from UI if it has no Id
                   this.poItems = this.poItems.filter((_, i) => i != index);
               }
           });
       }
       showToast(title, message, variant) {
           this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
       }
       showConfirmationDialog(message) {
           return new Promise((resolve) => {
               const confirmed = window.confirm(message);
               resolve(confirmed);
           });
       }

}