//<!--AR 21/05/2025 So item Component with Discount and tax -->
// GV - 26-06-25 --> wrapper changes
// <!-- AR 2/07/2025 Field Visible and read only control, Change Actual coast to listing price, Discount type corrected value-->
//<!--RT 18/07/2025 Wrapper 
//    AAB 18/07/2025 Control width ,allignment changes , Auto fetch account details
 //   AR 18/07/2025 Tax details record creation and Calculation
// -->
// Abdullah V S | 21-Aug-25 | Dynamically sets visibility, read-only, and required flags for fields
//AAB 5SEP25 Freeze form after status gets approved
import { LightningElement, track, wire, api } from 'lwc';
import getAccountDetails from '@salesforce/apex/CreateSalesOrderItems.getAccountDetails';
import LightningConfirm from 'lightning/confirm';
import { refreshApex } from '@salesforce/apex';
import searchProducts from '@salesforce/apex/CreateSalesOrderItems.searchProducts';
import getsalesOrderItems from '@salesforce/apex/CreateSalesOrderItems.getsalesOrderItems';
import savesalesOrderItems from '@salesforce/apex/CreateSalesOrderItems.savesalesOrderItems';
import deleteEstimationItem from '@salesforce/apex/CreateSalesOrderItems.deleteEstimationItem';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import savesalesOrder from '@salesforce/apex/CreateSalesOrderItems.savesalesOrder';
import getsalesOrder from '@salesforce/apex/CreateSalesOrderItems.getsalesOrder';
import getTableFieldMetadata from '@salesforce/apex/TableFieldConfigUtility.getTableFieldMetadata';
import getPicklistValue from '@salesforce/apex/CreateSalesOrderItems.getPicklistValue';

import SoWrapper from './soWrapper';
import ItemWrapper from './soItemWrapper';
import taxOptions from '@salesforce/apex/TaxUtility.getParentTaxes';
import createTaxDetailRecords from '@salesforce/apex/CreateSalesOrderItems.createTaxDetailRecords';
import getNslog from '@salesforce/apex/InvoiceFormController.getNslog';
import { NavigationMixin } from 'lightning/navigation';
import Utility from 'c/utility';

export default class SoItems extends NavigationMixin(LightningElement) {
    @api recordId; // Parent Estimation record ID
    @track salesOrderItems = [];
    @track salesOrderDetails = new SoWrapper();
    @track searchResults = [];
    @track hideDiscountFields = false;
    @track isButtonDisabled = false;
    @track discountType =[];
    @track showSpinner = false;
    @track isDiscountEnabled = false;
    statusOptions = [];

    accountobjectApiName = 'Account';
    accountadditionalFieldApiName = 'CustomerPriority__c'; 
    accountotherFieldApiName = 'Preferred_Currency_Code__c';
    accountlabel = 'Account';
    discountTypeValue;
    discountModeValue;
    taxOptions=[];
    discOptions=[];
    ns;
    @api SoRefNum =false;
    @track componentName = 'soItem';
    @track visibilityFlags = {};
    @track readOnlyFlags = {};
    @track requiredFlags = {};
    @track amountInWordsValue = '';
    @track currencyDisplay = '';//AP-05AUG25 Display the currencyCode
    
    // Wire properties for refreshApex
    wiredSalesOrderResult;
    wiredSalesOrderItemsResult;
   ////Tax Changes
    @wire(taxOptions)
    wiredTaxOptions({error, data}) {
        if (data) {
            console.log('Tax options loaded:', JSON.stringify(data));
            this.taxOptions = data.map(option => ({
                label: option.parentTaxName,
                value: option.parentTaxId,
                parentTaxId: option.parentTaxId,
                percentage: option.parentTaxPercentage,
                fullData: option
            }));
            // AR 22/08/2025 Set default tax percentage if available
            const defaultTax = data.find(option => option.isDefault);
            if (defaultTax) {
                this.defaultTaxPercentage = defaultTax.parentTaxId;
            }
            this.taxOptionsLoaded = true; 
        } else if (error) {
            console.error('Error fetching tax options:', error);
            this.taxOptions = [];
        }
    }

    @wire(getTableFieldMetadata, {
        componentName: '$componentName'
    })
    wiredTableConfig({
        error,
        data
    }) {
        if (data) {
            console.log('data', JSON.stringify(data));
            this.visibilityFlags = {};
            this.readOnlyFlags = {};
            this.width = {};
            data.forEach(row => {
                const {
                    fieldAPI,
                    visiblityMode,
                    width
                } = row;
                this.visibilityFlags[fieldAPI] = visiblityMode === 'Visible' || visiblityMode === 'Read Only'|| visiblityMode === 'Required';
				this.readOnlyFlags[fieldAPI] = visiblityMode === 'Read Only';
				this.requiredFlags[fieldAPI] = visiblityMode === 'Required';
                this.width[fieldAPI] = width;

            });
            console.log('this.width',data);

        } else if (error) {
            console.error('Error loading table configuration:', error);
        }
    }
    @wire(getNslog)
        handleNamespace({ error, data }) {
            if (data) {
                this.ns = data.nameSpace != 'null' ? data.nameSpace : '';
                } else if (error) {
            console.error('Error loading namespace:', error);
                }
        } 
    //AR 21/07/2025 picklist values are fetched from Apex
    @wire(getPicklistValue)
    wiredPicklistValues({ error, data }) {
        if (data) {
            console.log('Picklist data:', JSON.stringify(data));
            this.soTypes = data.soTypeOptions.map(option => ({
                label: option,
                value: option
            }));
            
            this.discountModeOptions = data.discOptions.map(option => ({
                label: option,
                value: option
            }));
            
            this.discountTypeOptions = data.discountType.map(option => ({
                label: option,
                value: option
            }));
            
            this.statusOptions = data.statusOptions.map(option => ({
                label: option,
                value: option
            }));
        } else if (error) {
            console.error('Error loading picklist values:', error);
            this.showToast('Error', 'Error loading picklist values', 'error');
        }
    }  
    // AP 06082025: Returns the currency to display
    get displayCurrency() {
        return this.salesOrderDetails?.currencyDisplay || this.currencyDisplay;
    }  
    // Wire method for Sales Order
    @wire(getsalesOrder, { salesOrderId: '$recordId' })
    wiredSalesOrder(result) {
        this.wiredSalesOrderResult = result;
        console.log("Wired Sales Order Result:", JSON.stringify(result));
        if (result.data) {
            this.salesOrderDetails = result.data;
            //AP-06AUG25 Extract and display currency code
            this.currencyDisplay = Utility.extractCurrencyCode(this.salesOrderDetails.currencyCode);
            console.log('Sales Order Details:', JSON.stringify(this.salesOrderDetails));
            // Set the discount values first
            this.discountTypeValue = result.data.discountType;
            this.discountModeValue = result.data.discountMode;
            this.lumpsumDiscountAmount = result.data.lumpsumDiscountAmount;
            this.lumpsumDiscountPercentage = result.data.lumpsumDiscountPercentage;
            this.lumpsumTaxPercentage = result.data.taxPercentage;
            this.lumpsumPercentage = result.data.lumpsumDiscountPercentage || 0;
            this.lumpsumAmount = result.data.lumpsumDiscountAmount || 0;
            this.isDiscountEnabled = Boolean(this.discountTypeValue && this.discountTypeValue !== '');
            this.calculateAllTaxTotals();
        } else if (result.error) {
            console.error('Error fetching sales order:', result.error);
        }

        if(this.salesOrderDetails.status == 'Approved'){
            this.isButtonDisabled = true;
        }
    }
    

    // Wire method for Sales Order Items
    @wire(getsalesOrderItems, { salesOrderId: '$recordId' })
    wiredSalesOrderItems(result) {
        this.wiredSalesOrderItemsResult = result;
        if (result.data) {
            console.log('Items:', JSON.stringify(result.data));
            if (Array.isArray(result.data)) {
                this.salesOrderItems = result.data.map(item => 
                    new ItemWrapper(item)
                );
            } else {
                console.error('Sales Order Items returned non-array:', result.data);
            }
            this.calculateAllTaxTotals(); // Calculate taxes after items are loaded
        } else if (result && result.error) {
            console.error('Error fetching sales order items:', result.error);
        } else {
            console.error('Unknown error or result is undefined in wiredSalesOrderItems:', result);
        }
    }
    @track taxDetails = [];
    @track taxOptionsLoaded = false;

    get showTaxDetailsSection() {
        return this.taxDetails && this.taxDetails.length > 0;
    }
    calculateAllTaxTotals() {
        const taxDetails = [];
    
        // Handle line item taxes
        if (this.discountTypeValue === 'Line Item Discount' || !this.discountTypeValue || this.discountTypeValue === '') {
            this.salesOrderItems.forEach((item) => {
                if (!item.taxPercentage) return;
    
                const selectedTax = this.taxOptions.find(option => option.value === item.taxPercentage);
                if (!selectedTax) return;
    
                // Calculate base amount (total after discounts)
                let baseAmount = (item.unitPrice || 0) * (item.quantity || 0);
                
                // Apply line item discounts if applicable
                if (this.discountTypeValue === 'Line Item Discount') {
                    if (this.discountModeValue === 'Percentage') {
                        baseAmount -= baseAmount * (item.discountPercentage || 0) / 100;
                    } else if (this.discountModeValue === 'Amount') {
                        baseAmount -= (item.discountAmount || 0);
                    }
                }
    
                // Process child taxes
                if (selectedTax.fullData?.childTaxes?.length > 0) {
                    selectedTax.fullData.childTaxes.forEach(childTax => {
                        const taxAmount = (baseAmount * childTax.childTaxPercentage) / 100;
                        taxDetails.push({
                            taxName: childTax.childTaxName,
                            taxId: childTax.childTaxId,
                            taxAmount: parseFloat(taxAmount.toFixed(2)),
                            percentage: childTax.childTaxPercentage,
                            soItemId: item.id,
                            details: [{
                                soItemId: item.id,
                                taxAmount: taxAmount,
                                baseAmount: baseAmount
                            }]
                        });
                    });
                } else {
                    const taxAmount = (baseAmount * selectedTax.percentage) / 100;
                    taxDetails.push({
                        taxName: selectedTax.label,
                        taxId: selectedTax.value,
                        taxAmount: parseFloat(taxAmount.toFixed(2)),
                        percentage: selectedTax.percentage,
                        soItemId: item.id,
                        details: [{
                            soItemId: item.id,
                            taxAmount: taxAmount,
                            baseAmount: baseAmount
                        }]
                    });
                }
            });
        }
    
        // Handle lumpsum tax
        if (this.discountTypeValue === 'Lumpsum Discount' && this.lumpsumTaxPercentage) {
            const selectedTax = this.taxOptions.find(option => option.value === this.lumpsumTaxPercentage);
            if (selectedTax) {
                this.calculateLumpsumTax(selectedTax);
                return;
            }
        }
    
        // Group and update tax details
        const groupedTaxes = taxDetails.reduce((acc, tax) => {
            if (!acc[tax.taxName]) {
                acc[tax.taxName] = {
                    taxName: tax.taxName,
                    taxId: tax.taxId,
                    taxAmount: 0,
                    percentage: tax.percentage,
                    details: []
                };
            }
            acc[tax.taxName].details.push(...tax.details);
            acc[tax.taxName].taxAmount += tax.taxAmount;
            return acc;
        }, {});
    
        this.taxDetails = Object.values(groupedTaxes);
    }
    
    calculateLumpsumTax(selectedTax) {
        const taxDetails = [];
        const baseAmount = parseFloat(this.calculatedSubTotal) || 0;
    
        if (selectedTax.fullData.childTaxes && selectedTax.fullData.childTaxes.length > 0) {
            // Handle child taxes
            selectedTax.fullData.childTaxes.forEach(childTax => {
                const taxAmount = (baseAmount * childTax.childTaxPercentage) / 100;
                taxDetails.push({
                    taxName: childTax.childTaxName,
                    taxId: childTax.childTaxId,
                    taxAmount: parseFloat(taxAmount.toFixed(2)),
                    percentage: childTax.childTaxPercentage,
                    isLumpsum: true
                });
            });
        } else {
            // Handle single tax
            const taxAmount = (baseAmount * selectedTax.percentage) / 100;
            taxDetails.push({
                taxName: selectedTax.label,
                taxId: selectedTax.value,
                taxAmount: parseFloat(taxAmount.toFixed(2)),
                percentage: selectedTax.percentage,
                isLumpsum: true
            });
        }
    
        // Update tax details
        this.taxDetails = taxDetails.map(tax => ({
            ...tax,
            taxAmount: parseFloat(tax.taxAmount.toFixed(2))
        }));
    }

    // AR 11 sep 2025 Not showing the zero tax
    get taxDetailSummary(){
        if (!this.taxDetails || !Array.isArray(this.taxDetails)) {
            return [];
        }
    
        return this.taxDetails
            .filter(tax => parseFloat(tax.taxAmount) !== 0)
            .map(tax => ({
                taxName: tax.taxName,
                taxId: tax.taxId,
                taxAmount: tax.taxAmount,
                percentage: tax.percentage
            }));
    }

    getFieldConfig(fieldAPI) {
        return {
            label: this.labelList?.[fieldAPI] || fieldAPI,
            visible: this.visibilityFlags?.[fieldAPI] ?? false,
            readOnly: this.readOnlyFlags?.[fieldAPI] ?? false,
			required : this.requiredFlags?.[fieldAPI] ?? false,
			requiredClass : this.requiredFlags?.[fieldAPI] ? 'validate' : '',
            width: this.width?.[fieldAPI] || ''
        }
    }

    get stockDisabled() {
        return this.isButtonDisabled || 
        this.isStockAvailable.readOnly; 
    }

    get descriptionDisabled() {
        return this.isButtonDisabled || 
        this.isDescription.readOnly; 
    }

    get productSKUDisabled() {
        return this.isButtonDisabled || 
        this.isProductSKU.readOnly; 
    }

    get salesCostDisabled() {
        return this.isButtonDisabled || 
        this.isSalesCost.readOnly; 
    }

    get quantityDisabled() {
        return this.isButtonDisabled || 
        this.isQuantity.readOnly; 
    }

    get discountAmountDisabled() {
        return this.isButtonDisabled ||
        this.isSDiscountAmount.readOnly;
    }

    get discountPercentageDisabled() {
        return this.isButtonDisabled || 
        this.isDiscountPercentage.readOnly; 
    }
    
    get taxDisabled() {
        return this.isButtonDisabled ||
        this.isTax.readOnly;
	}

    get isStockAvailable() {
        return this.getFieldConfig('stockAvailable');
    }

    get isSDiscountAmount() {
        return this.getFieldConfig('discountAmount');
    }

    get isDiscountPercentage() {
        return this.getFieldConfig('discountPercentage');
    }

    get isProductSKU() {
        return this.getFieldConfig('productSKU');
    }

    get isQuantity() {
        return this.getFieldConfig('quantity');
    }

    get isSalesCost() {
        return this.getFieldConfig('salesCost');
    }

    get isTax() {
        return this.getFieldConfig('tax');
    }

    get isLeadTime() {
        return this.getFieldConfig('leadTime');
    }
   //<!-- AR 5 Sep 2025 Added description -->
    get isDescription() {
        return this.getFieldConfig('description');
    }

    get isSalesCostStyle() {
        return `width: ${this.isSalesCost.width};`;
    }

    get isProductSKUStyle() {
        return `width: ${this.isProductSKU.width};`;
    }

    get isDiscountPercentageStyle() {
        return `width: ${this.isDiscountPercentage.width};`;
    }

    get isSDiscountAmountStyle() {
        return `width: ${this.isSDiscountAmount.width};`;
    }

    get isStockStyle() {
        return `width: ${this.isStockAvailable.width};`;
    }
    //<!-- AR 5 Sep 2025 Added description -->
    get isDescriptionStyle(){
        return `width : ${this.isDescription.width}`;
    }
    get isQuantityStyle() {
        return `width: ${this.isQuantity.width};`;
    }

    get isTaxStyle() {
        return `width: ${this.isTax.width};`;
    }

    get showDiscountTypeField() {
        return this.discountModeValue && this.discountModeValue !== '' && this.discountModeValue !== 'None';
    }

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
        console.log('Calculating total amount for sales order items:', JSON.stringify(this.salesOrderItems));
        return this.salesOrderItems.reduce((total, item) => {
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
                return this.salesOrderItems.reduce((total, item) => {
                    const amount = (item.unitPrice || 0) * (item.quantity || 0);
                    const discount = amount * ((item.discountPercentage || 0) / 100);
                    return total + discount;
                }, 0).toFixed(2);
            } else if (this.discountModeValue === 'Amount') {
                return this.salesOrderItems.reduce((total, item) => {
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
        return this.taxDetails.reduce((total, tax) => total + tax.taxAmount, 0).toFixed(2);
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

    get amountInWords() {
        // Abdullah V S | 25-Jul-25 | Convert total amount to words based on the selected currency using utility method.
        return Utility.convertToWords(this.grandTotal, this.salesOrderDetails.currencyCode) + ' only';
    }

    lumpsumTaxPercentage;
    handleLumpsumTax(event) {
        this.isButtonDisabled = false;
        const selectedTaxId = event.detail.value;
        const selectedTax = this.taxOptions.find(option => option.value === selectedTaxId);
        
        if (selectedTax) {
            this.lumpsumTaxPercentage = selectedTaxId;
            let updatedDetails = { ...this.salesOrderDetails };
            updatedDetails.taxPercentage = selectedTaxId;
            updatedDetails.taxPercent = selectedTax.percentage || 0;
            this.salesOrderDetails = updatedDetails;
            this.calculateLumpsumTax(selectedTax);
        }
    }
    handleDiscountTypeChange(event) {
        this.isButtonDisabled = false;
        this.discountTypeValue = event.detail.value;
        let updatedDetails = { ...this.salesOrderDetails };
        updatedDetails.discountType = event.detail.value;
        this.salesOrderDetails = updatedDetails;
        if (this.discountTypeValue === 'Line Item Discount') {
            // Clear lumpsum values
            this.lumpsumAmount = 0;
            this.lumpsumPercentage = 0;
            this.lumpsumTaxPercentage = '';
            //AR 22/08/2025 Set default tax percentage for line items
            this.salesOrderItems = this.salesOrderItems.map(item => {
                const newItem = {
                    ...item,
                    taxPercentage: this.defaultTaxPercentage || ''
                };
                if (this.defaultTaxPercentage) {
                    const selectedTax = this.taxOptions.find(option => 
                        option.value === this.defaultTaxPercentage
                    );
                    if (selectedTax) {
                        newItem.taxPercent = selectedTax.percentage;
                    }
                }
                
                return newItem;
            });
        } else if (this.discountTypeValue === 'Lumpsum Discount') {
            // Clear line item values
            this.salesOrderItems = this.salesOrderItems.map(item => ({
                ...item,
                tax: '',
                taxPercentage: '',
                discountAmount: 0,
                discountPercentage: 0
            }));
            //AR 22/08/2025 Set default tax percentage for lumpsum
            this.lumpsumTaxPercentage = this.defaultTaxPercentage || '';
            
        }
        
        // Recalculate tax totals
        this.calculateAllTaxTotals();
    }

    handleDiscountModeChange(event) {
        let updatedDetails = { ...this.salesOrderDetails };
        updatedDetails.discountMode = event.detail.value;
        this.salesOrderDetails = updatedDetails;
        this.discountModeValue = event.detail.value;
        this.salesOrderItems = this.salesOrderItems.map(item => ({
            ...item,
            discountType: this.discountTypeValue
        }));
    }
    
    handleValueSelectedOnVendor(event) {
        if (!event.detail || !event.detail.id) {
            console.error('Invalid vendor selection event:', event);
            return;
        }
        const accountId = event.detail.id;
        // Always use a plain object for salesOrderDetails to ensure reactivity
        let updatedDetails = { ...this.salesOrderDetails };
        updatedDetails.customerId = accountId;
        this.salesOrderDetails = updatedDetails;
        // Fetch account details from Apex
        getAccountDetails({ accountId })
            .then(result => {
                if (result) {
                    let details = { ...this.salesOrderDetails };
                    details.paymentTerms = result.paymentTerms || '';
                    details.shippingTerms = result.shippingTerms || '';
                    details.currencyCode = result.currencyCode || '';
                    details.preferredCurrency = result.currencyCode || '';
                    
                    //AP-04AUG25 | Extract only the currency code using Utility (e.g., "INR" from "INR - Indian Rupee")
                    details.currencyDisplay = Utility.extractCurrencyCode(details.preferredCurrency);

                    this.salesOrderDetails = details;
                }
            })
            .catch(error => {
                console.error('Error fetching account details:', error);
            });
        //this.salesOrderDetails.preferredCurrency = event.detail.subField || '';
        console.log('vendor' + JSON.stringify(event.detail));
    }

    handleLumpsumChange(event) {
        const fieldName = event.target.name;
        const value = event.target.value;
        let updatedDetails = { ...this.salesOrderDetails };
        
        if (fieldName === 'lumpsumDiscountAmount') {
            updatedDetails.lumpsumDiscountAmount = value;
            this.salesOrderDetails = updatedDetails;
            this.lumpsumAmount = value;
        } else if (fieldName === 'lumpsumDiscountPercentage') {
            updatedDetails.lumpsumDiscountPercentage = value;
            this.salesOrderDetails = updatedDetails;
            this.lumpsumPercentage = value;
        }
        this.calculateAllTaxTotals();
    }

    // Removed the old loadsalesOrderItems method since we're using @wire now
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
        const element = this.salesOrderItems.splice(fromIndex, 1)[0];
        this.salesOrderItems.splice(toIndex, 0, element);

        this.salesOrderItems = this.salesOrderItems.map((item, index) => ({
            ...item,
            key: index + 1
        }));
    }

    handleProductSearch(event) {
        const searchKey = event.target.value;
        const index = event.target.dataset.index;
    
        if (searchKey.length > 2) {
            searchProducts({ searchKey })
                .then(data => {
                    console.log('Search Results:', JSON.stringify(data));
                    // Ensure data is always an array
                    if (!Array.isArray(data)) {
                        data = [];
                    }
                    this.salesOrderItems = this.salesOrderItems.map((item, i) => ({
                        ...item,
                        searchResults: i === parseInt(index) ? data : [] 
                    }));
                    console.log('Updated Sales Order Items:', this.salesOrderItems);
                })
                .catch(error => {
                    console.error('Error searching products', error);
                });
        } else {
            this.clearSearchResults(index);
        }
    }

    handleDiscountToggle(event) {
        this.isDiscountEnabled = event.target.checked;
        
        if (!this.isDiscountEnabled) {
            this.discountTypeValue = '';
            this.discountModeValue = '';
            // Abdullah V S | 14-Aug-25 | Disable Discount bug fix
            this.lumpsumTaxPercentage = null;
            this.calculateAllTaxTotals();
        }
    }
    
    selectProduct(event) {
        const index = event.target.dataset.index;
        const productId = event.currentTarget.dataset.id;

        // Try both 'id' and 'Id' for compatibility with searchProducts result
        const selectedProduct = this.salesOrderItems[index].searchResults.find(
            p => p.id === productId || p.Id === productId
        );
        console.log('Selected Product:', selectedProduct);
        if (selectedProduct) {
            this.salesOrderItems[index] = {
                ...this.salesOrderItems[index],
                productSku: selectedProduct.sku,
                productQuantity: selectedProduct.productQuantity,
                stockAvailable: selectedProduct.stockAvailable,  // GV - 26-06-25 fixed stockAvailable
                unitPrice: selectedProduct.listingPrice,
                productName: selectedProduct.name,
                productId: selectedProduct.id || selectedProduct.Id,
                searchResults: []
            };
        }
        //AR 22/08/2025 Set default tax percentage for selected product
        this.calculateAllTaxTotals();
    }
    
    clearSearchResults(index) {
        this.salesOrderItems = this.salesOrderItems.map((item, i) => ({
            ...item,
            searchResults: i === parseInt(index) ? [] : item.searchResults
        }));
    }

    handleInputChange(event) {
        console.log('Input change event--->', JSON.stringify(event.detail));
        console.log('sales order items--->', JSON.stringify(this.salesOrderItems));
        const index = event.target.dataset.index;
        const field = event.target.name;
        const value = event.detail && event.detail.value !== undefined ? event.detail.value : event.target.value;

        if (!field) {
            console.error('handleInputChange: Missing field', { field, event });
            return;
        }
        if (index !== undefined && index !== null) {
            // Row-level change
            if (!this.salesOrderItems[index]) {
                console.error('handleInputChange: salesOrderItems missing for index', index);
                return;
            }
            this.salesOrderItems[index][field] = value;
            if (field === 'discountType') {
                const isAmount = value === 'Amount';
                const isPercentage = value === 'Percentage';
                this.salesOrderItems[index].disableAmount = !isAmount;
                this.salesOrderItems[index].disablePercentage = !isPercentage;
            }
            console.log("after item-->", JSON.stringify(this.salesOrderItems));
        } 
        if (field === 'taxPercentage') {
            const selectedTax = this.taxOptions.find(option => option.value === value);
            if (selectedTax) {
                this.salesOrderItems[index].taxPercent = selectedTax.percentage;
            }
        }
        if (field === 'taxPercentage' || field === 'quantity' || field === 'unitPrice' || 
            field === 'discountAmount' || field === 'discountPercentage') {
                console.log('Calculating tax totals after input change');
            this.calculateAllTaxTotals();
        }
    }

    handleParent(event) {
        console.log('handleParent triggered');
        const field = event.target.name;
        const value = event.detail?.value ?? event.target.value;
        console.log('Field:', field, 'Value:', value);
        let updatedDetails = { ...this.salesOrderDetails };
        updatedDetails[field] = value;
        this.salesOrderDetails = updatedDetails;
    }

    addRow() {
        this.salesOrderItems = [...this.salesOrderItems, { 
            key: this.salesOrderItems.length + 1,
            productId: '', 
            productName: '',
            productSku: '', 
            stockAvailable: '', 
            description: '',
            unitPrice: '', 
            leadTime:'',
            quantity: 1, 
            //AR 22/08/2025 Set default tax percentage for new items
            taxPercentage: this.defaultTaxPercentage || '',
            searchResults: [] 
        }];
    }

    @track saveSalesOrderId;
    saveRecords() {
        // Abdullah V S | 18-Aug-25 | Client-side validation for required input fields
        const inputs = this.template.querySelectorAll('.validate');
        let isValid = true;
        inputs.forEach(input => {
            console.log('Validating inputs:', input.checkValidity(), input.reportValidity());
            if (!input.checkValidity()) {
                input.reportValidity();
                isValid = false;
            }
        });
        if(!isValid){
            this.showToast('Error', 'Please fill all required fields.', 'warning');
            return;
        }
        this.showSpinner = true; // Show spinner while saving
        //this.salesOrderDetails.customerId = this.customerSelectedRecord .id;
        console.log('Saving records with discountTypeValue:', JSON.stringify(this.salesOrderDetails));
        this.isButtonDisabled = true;

        if (this.discountTypeValue === 'Lumpsum Discount' && this.lumpsumTaxPercentage) {
            const selectedTax = this.taxOptions.find(option => 
                option.value === this.lumpsumTaxPercentage
            );
            if (selectedTax) {
                this.salesOrderDetails.taxPercentage = this.lumpsumTaxPercentage;
                this.salesOrderDetails.taxPercent = selectedTax.percentage || 0;
            }
        }
        // Abdullah V S | 14-Aug-25 | Disable Discount bug fix
        if(!this.isDiscountEnabled) {
            let updatedDetails = { ...this.salesOrderDetails };
            updatedDetails.discountType = '';
            updatedDetails.discountMode = '';
            updatedDetails.taxPercentage = null;
            updatedDetails.taxPercent = 0;
            this.salesOrderDetails = updatedDetails;
        }
        
        savesalesOrder({
            salesOrderWrapper: this.salesOrderDetails
        })
        .then((result) => {
            this.saveSalesOrderId = result; 
            console.log('Sales Order saved successfully:', result);
            console.log('Sales Order ID:', result.Id);
            if (this.taxDetails && this.taxDetails.length > 0) {
                createTaxDetailRecords({
                    taxDetailsList: this.taxDetails,
                    salesOrderId: result
                });
            }
                
            this.salesOrderDetails.id = result; 
            this.recordId = result; 
            this.salesOrderItems = this.salesOrderItems.map((item, index) => ({
                ...item,
                discountType: this.discountModeValue,
                key: index + 1
            }));
            console.log('salesOrderItems:', JSON.stringify(this.salesOrderItems));
            console.log('salesOrderItems.length:', this.salesOrderItems.length);            
            // const jsonString = JSON.stringify((this.salesOrderItems));
            const validItems = this.salesOrderItems.filter(item =>
                item.productId && item.productName && item.unitPrice && item.quantity
            );
            const jsonString = JSON.stringify(validItems);
            console.log('jsonString:', JSON.stringify(jsonString));
            return savesalesOrderItems({ 
                wrappersJson: jsonString, 
                salesOrderId: this.recordId 
            });
        })
        .then((result) => {
            this.showToast('Success', 'SO Item Saved Successfully', 'success');
            this.dispatchEvent(new CustomEvent('success', { detail: 'Records saved successfully!' }));
            this.isButtonDisabled = false;
            this.showSpinner = false; // Hide spinner after saving
            
            return Promise.all([
                refreshApex(this.wiredSalesOrderResult),
                refreshApex(this.wiredSalesOrderItemsResult)
            ]).then(() => {
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: this.saveSalesOrderId,
                        objectApiName: this.ns + 'Sales_Order__c',
                        actionName: 'view'
                    }
                });
            });
        })
        .catch(error => {
            this.showToast('Error', 'Error saving records: ' + error.body.message, 'error');
            console.error('Error saving records', error);
            this.isButtonDisabled = false;
            this.showSpinner = false; // Hide spinner on error
        });
    }
     // Delete row based on index
    deleteRow(event) {
        let index = event.target.dataset.index;
        //AR 6/08/25 changed 'ID' to 'id' according to the new SOItemWrapper
        let itemId = this.salesOrderItems[index].id;
        this.showConfirmationDialog("Are you sure you want to delete this item?")
        .then((confirmation) => {
            if (!confirmation) return;
       
            if (itemId) {
                // Call Apex method to delete from Salesforce
                deleteEstimationItem({ itemId })
                    .then(() => {
                        this.showToast('Success', 'Item deleted successfully', 'success');
                        this.salesOrderItems = this.salesOrderItems.filter((_, i) => i != index);
                        // Refresh data after deletion
                        return Promise.all([
                            refreshApex(this.wiredSalesOrderResult),
                            refreshApex(this.wiredSalesOrderItemsResult)
                        ]);
                    })
                    .catch(error => {
                        this.showToast('Error', 'This SalesOrder cannot be Update/deleted because it has related to PurchaseOrder Or Invoice records.', 'error');
                        console.error('Error deleting record:', error);
                        setTimeout(() => {
                            window.location.reload(); // Refresh the page
                        }, 2000);
                    });
            } else {
                // Just remove from UI if it has no Id
                this.salesOrderItems = this.salesOrderItems.filter((_, i) => i != index);
            }
        });
    }

    async cancelRecords() {
        this.showSpinner = true;
        
        try {
            const result = await LightningConfirm.open({
                message: 'Are you sure you want to cancel?',
                variant: 'headerless',
                label: 'Confirm Cancellation',
                theme: 'default'
            });

            console.log('Cancellation result:', result);
            
            if (result) {
                // Method 1: Force refresh by clearing data first, then refreshing
                this.salesOrderItems = [];
                this.salesOrderDetails = new SoWrapper();
                await this.manualDataReload();
            }
        } catch (error) {
            console.error('Error in cancelRecords:', error);
        } finally {
            this.showSpinner = false;
        }
    }

    // Fallback method for manual data reload
    async manualDataReload() {
        try {
            // Manually call the Apex methods to get fresh data
            const [salesOrderData, salesOrderItemsData] = await Promise.all([
                getsalesOrder({ salesOrderId: this.recordId }),
                getsalesOrderItems({ salesOrderId: this.recordId })
            ]);
            
            // Update the data manually
            if (salesOrderData) {
                this.salesOrderDetails = salesOrderData;
                this.discountTypeValue = salesOrderData.discountType;
                this.discountModeValue = salesOrderData.discountMode;
                this.lumpsumDiscountAmount = salesOrderData.lumpsumDiscountAmount;
                this.lumpsumDiscountPercentage = salesOrderData.lumpsumDiscountPercentage;
                this.lumpsumTaxPercentage = salesOrderData.taxPercentage;
                this.isDiscountEnabled = !!(this.discountTypeValue || this.discountTypeValue !== '');
                //AP06AUG25 Extract currency code (e.g., 'INR' from 'INR - Indian Rupee')
                this.currencyDisplay = Utility.extractCurrencyCode(salesOrderData.preferredCurrency);
            }
            console.log('Sales Order Details reloaded:', salesOrderItemsData);
            if (salesOrderItemsData && Array.isArray(salesOrderItemsData)) {
                this.salesOrderItems = salesOrderItemsData.map(item => new ItemWrapper(item));
                console.log('Sales Order Items reloaded:', this.salesOrderItems);
            }
            if (this.taxOptionsLoaded) {
                this.calculateAllTaxTotals();
            }
            console.log('Manual data reload completed');
        } catch (error) {
            console.error('Manual data reload failed:', error);
            throw error;
        }
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