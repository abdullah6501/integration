// <!--KA 29/05/2025 Estimation item Component-->
// AR 14/06/2025 Estimation Item component with discount type null and lead time and currency code changes
//  GV = 16-06-25 => Add customer PO Ref number
// AR 1/07/2025 Field visible and Read only control
// AB 10JUL25 Updated to use refreshApex instead of window.location.reload()


/*
   AR 18/07/2025 Tax detail records creation and calculation
   AAB 20/07/2025 UI Changes ,width control,,Account detail fetch 
*/
// Abdullah V S | 21-Aug-25 | Dynamically sets visibility, read-only, and required flags for fields
//AAB 5SEP25 Freeze form after status gets approved
import {LightningElement,track,api,wire} from 'lwc';
import getestimationItems from '@salesforce/apex/EstimationItemController.getestimationItems';
import syncCostRecords from '@salesforce/apex/EstimationItemController.syncCostRecords';
import getEstimation from '@salesforce/apex/EstimationItemController.getEstimation';
import searchProducts from '@salesforce/apex/EstimationItemController.searchProductsWrapper';
import deleteEstimationItem from '@salesforce/apex/EstimationItemController.deleteEstimationItem';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';
import getPicklistValue from '@salesforce/apex/EstimationItemController.getPicklistValue';
import saveEstimation from '@salesforce/apex/EstimationItemController.saveEstimation';
import saveEstimationItemsWithWrapper from '@salesforce/apex/EstimationItemController.saveEstimationItemsWithWrapper';
import getTableFieldMetadata from '@salesforce/apex/TableFieldConfigUtility.getTableFieldMetadata';
import { NavigationMixin } from 'lightning/navigation';
import getNslog from '@salesforce/apex/InvoiceFormController.getNslog';
import getAccountDetails from '@salesforce/apex/EstimationItemController.getAccountDetails';
import taxOptions from '@salesforce/apex/TaxUtility.getParentTaxes';
import createTaxDetailRecords from '@salesforce/apex/EstimationItemController.createTaxDetailRecords';
import Utility from 'c/utility';

export default class EstimationItems extends NavigationMixin(LightningElement) {
    @api recordId; // Parent Estimation record ID
    @track estimationitems = [];
    @track searchResults = [];
    @track isDiscountEnabled = false;
    @track hideDiscountFields = false;
    @track isButtonDisabled = false;
    @track isSyncButtonDisabled = false;
    @track discountType = [];
    @track discountModeValue = '';
    @track discountTypeValue = '';
    @api SyncEstimation = false;
    @api PaymentTerm = false;
    @api ShippingTerm = false;
    @api PoRefNum = false;
    @api PerferredCurrency = false;
    taxOptions = [];
    discOptions = [];
    statusOptions = [];
    @track componentName = 'estimationItem';
    //AR 22/08/2025 declared variables for default tax
    @track defaultTaxPercentage = '';
    @track visibilityFlags = {};
    @track readOnlyFlags = {};
    @track requiredFlags = {};
    @track width = {};
    
    // Store wire results for refreshApex - only for data that changes
    @track wiredEstimationResult;
    @track wiredEstimationItemsResult;
    @track currencyDisplay ='';//AP-05AUG25 Display the currencyCode

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
            this.requiredFlags = {};
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


    /// Tax Changes
    @track taxOptions = [];
    @track parentTaxOptions = [];
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
                //AR 22/08/2025 Set default tax percentage if available
                const defaultTax = data.find(option => option.isDefault);
                if (defaultTax) {
                    this.defaultTaxPercentage = defaultTax.parentTaxId;
                }
                console.log('Default Tax Percentage:', this.defaultTaxPercentage);
                this.taxOptionsLoaded = true; 
            } else if (error) {
                console.error('Error fetching tax options:', error);
                this.taxOptions = [];
            }
        }
        get showTaxDetailsSection() {
            return this.taxDetails && this.taxDetails.length > 0;
        }

    // Add these properties to the class
    @track taxDetails = [];
    @track taxOptionsLoaded = false;

    // Add the tax calculation method
    calculateAllTaxTotals() {
        const taxDetails = [];
    
        this.estimationitems.forEach((item, index) => {
            if (!item.tax) return;
    
            const selectedTax = this.taxOptions.find(option => option.value === item.tax);
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
            if (selectedTax.fullData.childTaxes && selectedTax.fullData.childTaxes.length > 0) {
                selectedTax.fullData.childTaxes.forEach(childTax => {
                    const taxAmount = (baseAmount * childTax.childTaxPercentage) / 100;
                    taxDetails.push({
                        taxName: childTax.childTaxName,
                        taxId: childTax.childTaxId,
                        taxAmount: parseFloat(taxAmount.toFixed(2)),
                        estimationItemId: `item${index + 1}`,
                        subtotal: baseAmount,
                        percentage: childTax.childTaxPercentage
                    });
                });
            } else {
                // Handle single tax
                const taxAmount = (baseAmount * selectedTax.percentage) / 100;
                taxDetails.push({
                    taxName: selectedTax.label,
                    taxId: selectedTax.value,
                    taxAmount: parseFloat(taxAmount.toFixed(2)),
                    estimationItemId: `item${index + 1}`,
                    subtotal: baseAmount,
                    percentage: selectedTax.percentage
                });
            }
        });
    
        // Handle lumpsum tax if applicable
        if (this.discountTypeValue === 'Lumpsum Discount' && this.lumpsumTaxPercentage) {
            const selectedTax = this.taxOptions.find(option => option.value === this.lumpsumTaxPercentage);
            if (selectedTax) {
                const baseAmount = parseFloat(this.calculatedSubTotal) || 0;
                
                if (selectedTax.fullData.childTaxes && selectedTax.fullData.childTaxes.length > 0) {
                    selectedTax.fullData.childTaxes.forEach(childTax => {
                        const taxAmount = (baseAmount * childTax.childTaxPercentage) / 100;
                        taxDetails.push({
                            taxName: childTax.childTaxName,
                            taxId: childTax.childTaxId,
                            taxAmount: parseFloat(taxAmount.toFixed(2)),
                            subtotal: baseAmount,
                            percentage: childTax.childTaxPercentage
                        });
                    });
                } else {
                    const taxAmount = (baseAmount * selectedTax.percentage) / 100;
                    taxDetails.push({
                        taxName: selectedTax.label,
                        taxId: selectedTax.value,
                        taxAmount: parseFloat(taxAmount.toFixed(2)),
                        subtotal: baseAmount,
                        percentage: selectedTax.percentage
                    });
                }
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
            acc[tax.taxName].details.push(tax);
            acc[tax.taxName].taxAmount += tax.taxAmount;
            return acc;
        }, {});
    
        this.taxDetails = Object.values(groupedTaxes).map(group => ({
            taxName: group.taxName,
            taxId: group.taxId,
            taxAmount: parseFloat(group.taxAmount.toFixed(2)),
            percentage: group.percentage,
            details: group.details
        }));
    }   
    calculateLumpsumTax(selectedTax) {
        const taxDetails = [];
        // Calculate base amount (total after discounts)
        const baseAmount = parseFloat(this.calculatedSubTotal) || 0;
    
        if (selectedTax.fullData.childTaxes && selectedTax.fullData.childTaxes.length > 0) {
            // Handle child taxes
            selectedTax.fullData.childTaxes.forEach(childTax => {
                const taxAmount = (baseAmount * childTax.childTaxPercentage) / 100;
                taxDetails.push({
                    taxName: childTax.childTaxName,
                    taxId: childTax.childTaxId,
                    taxAmount: parseFloat(taxAmount.toFixed(2)),
                    percentage: childTax.childTaxPercentage
                });
            });
        } else {
            // Handle single tax
            const taxAmount = (baseAmount * selectedTax.percentage) / 100;
            taxDetails.push({
                taxName: selectedTax.label,
                taxId: selectedTax.value,
                taxAmount: parseFloat(taxAmount.toFixed(2)),
                percentage: selectedTax.percentage
            });
        }
    
        // Update tax details
        this.taxDetails = taxDetails.map(tax => ({
            ...tax,
            taxAmount: parseFloat(tax.taxAmount.toFixed(2))
        }));
    }     
    ////Tax Ends

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

    get descriptionDisabled() {
        return this.isButtonDisabled ||
        this.isDescription.readOnly;
    }

    get stockDisabled() {
        return this.isButtonDisabled ||
        this.isStockAvailable.readOnly;
    }

    get productSKUDisabled() {
        return this.isButtonDisabled ||
        this.isProductSKU.readOnly;
    }

    get leadTimeDisabled() {
        return this.isButtonDisabled ||
        this.isLeadTime.readOnly;
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

    get isQuantityStyle() {
        return `width: ${this.isQuantity.width};`;
    }

    get isTaxStyle() {
        return `width: ${this.isTax.width};`;
    }

    get isLeadTimeStyle() {
        return `width: ${this.isLeadTime.width};`;
    }

    get isDescriptionStyle() {
        return `width: ${this.isDescription.width};`;
    }

    get showDiscountTypeField() {
        return this.discountModeValue && this.discountModeValue !== '' && this.discountModeValue !== 'None';
    }
    @wire(getPicklistValue)
    wiredTaxPicklistValues({error,data}) {
        if (data) {
            this.discOptions = [{
                    label: 'None',
                    value: ''
                },
                ...data.discOptions.map(value => ({
                    label: value,
                    value: value
                }))
            ];
            this.discountType = [{
                    label: 'None',
                    value: ''
                },
                ...data.discountType.map(value => ({
                    label: value,
                    value: value
                }))
            ];
            this.statusOptions = data.statusOptions.map(value => ({
                label: value,
                value: value
            }));
        } else if (error) {
            console.error('Error loading picklists:', error);
        }
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
    get noneTax() {
        return !this.discountTypeValue ||
            this.discountTypeValue === '' ||
            this.discountTypeValue === 'Line Item Discount';
    }
    get totalAmount() {
        return this.estimationitems.reduce((total, item) => {
            const amount = (item.unitPrice || 0) * (item.quantity || 0);
            return total + amount;
        }, 0).toFixed(2);
    }


    @track customerSelectedRecord = { id: null, name: null };
    @track shippingTerms;
    @track paymentTerms;
    @track currencyCode = '';

    accountobjectApiName = 'Account';
    accountadditionalFieldApiName = 'CustomerPriority__c'; 
    accountotherFieldApiName = 'Preferred_Currency_Code__c';
    accountlabel = 'Customer';

    handleValueSelectedOnCustomer(event) {
        if (!event.detail || !event.detail.id) {
            console.error('Invalid vendor selection event:', event);
            return;
        }
        const accId = event.detail.id;
        getAccountDetails({ accId: accId })
            .then(result => {
                console.log('Account Details:', result);
                this.shippingTerms = result.shippingTerm || '';
                this.paymentTerms = result.paymentTerm || '';
            })
            .catch(error => {
                console.error('Error fetching account details:', error);
            });
        this.customerSelectedRecord = {
            id: event.detail.id,
            name: event.detail.mainField
        };
       //AP-05AUG25 Store the selected full currency string
        this.currencyCode = event.detail.subField || '';
        this.preferredCurrency = event.detail.subField || '';
        // AP-04AUG25 | Extract only the currency code using Utility (e.g., 'INR' from 'INR - Rupee')
        this.currencyDisplay = Utility.extractCurrencyCode(this.currencyCode);
    }

    handleCustomerValRemoval() {
        this.customerSelectedRecord = { id: null, name: null };
        //this.currencyCode = '';
    }
    handleDiscountToggle(event) {
        this.isDiscountEnabled = event.target.checked;
        
        if (!this.isDiscountEnabled) {
            this.discountTypeValue = '';
            this.discountModeValue = '';
        }
    }
    
    get amountInWords() {
        // Abdullah V S | 25-Jul-25 | Convert total amount to words based on the selected currency using utility method.
        return Utility.convertToWords(this.grandTotal, this.preferredCurrency) + ' only';
    }
 
    @track lumpsumAmount = 0;
    @track lumpsumPercentage = 0;
    get totalDiscount() {
        const total = parseFloat(this.totalAmount) || 0;
        if (this.discountTypeValue === 'Line Item Discount') {
            if (this.discountModeValue === 'Percentage') {
                return this.estimationitems.reduce((total, item) => {
                    const amount = (item.unitPrice || 0) * (item.quantity || 0);
                    const discount = amount * ((item.discountPercentage || 0) / 100);
                    return total + discount;
                }, 0).toFixed(2);
            } else if (this.discountModeValue === 'Amount') {
                return this.estimationitems.reduce((total, item) => {
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
    lumpsumTaxPercentage;

    handleLumpsumTax(event) {
        this.isButtonDisabled = false;
        const selectedTaxId = event.detail.value;
        const selectedTax = this.taxOptions.find(option => option.value === selectedTaxId);
        
        if (selectedTax) {
            this.lumpsumTaxPercentage = selectedTaxId;
            console.log('Selected Tax:', JSON.stringify(selectedTax.percentage));
            this.taxPercent = selectedTax.percentage;
            this.calculateLumpsumTax(selectedTax);
        }
    }
    handleDiscountTypeChange(event) {
        this.isButtonDisabled = false;
        this.discountTypeValue = event.detail.value;
        
        if (this.discountTypeValue === 'Line Item Discount') {
            // Clear lumpsum values when switching to Line Item
            this.lumpsumAmount = 0;
            this.lumpsumPercentage = 0;
            this.lumpsumTaxPercentage = '';
            //AR 22/08/2025 Set default tax percentage for line items
            this.estimationitems = this.estimationitems.map(item => ({
                ...item,
                tax: this.defaultTaxPercentage || '',
                taxPercent: this.taxOptions.find(option => option.value === this.defaultTaxPercentage)?.percentage || 0,
            }));
            // Keep existing line item values
            this.calculateAllTaxTotals();
            
        } else if (this.discountTypeValue === 'Lumpsum Discount') {
            // Clear line item values when switching to Lumpsum
            this.estimationitems = this.estimationitems.map(item => ({
                ...item,
                tax: '',
                taxPercentage: 0,
                discountAmount: 0,
                discountPercentage: 0
            }));
            //AR 22/08/2025 Set default tax percentage for lumpsum
            this.lumpsumTaxPercentage = this.defaultTaxPercentage || '';
            this.taxPercent = this.taxOptions.find(option => option.value === this.lumpsumTaxPercentage)?.percentage || 0;
            // Keep existing lumpsum values
            this.calculateAllTaxTotals();
            
        } else {
            // Clear all values when selecting none or empty
            this.lumpsumAmount = 0;
            this.lumpsumPercentage = 0;
            this.lumpsumTaxPercentage = '';
            
            this.estimationitems = this.estimationitems.map(item => ({
                ...item,
                discountAmount: 0,
                discountPercentage: 0
            }));
        }
        
        // Recalculate tax totals after changes
        this.calculateAllTaxTotals();
    }
    handleDiscountModeChange(event) {
        this.isButtonDisabled = false;
        this.discountModeValue = event.detail.value;
        if (this.discountModeValue === '' || this.discountModeValue === 'None') {
            this.discountTypeValue = '';
        }
        this.estimationitems = this.estimationitems.map(item => ({
            ...item,
            discountMode: this.discountModeValue
        }));
    }
    handleLumpsumChange(event) {
        this.isButtonDisabled = false;
        const fieldName = event.target.name;
        const value = event.target.value;
        
        if (fieldName === 'lumpsumAmount') {
            this.lumpsumAmount = parseFloat(value) || 0;
            this.lumpsumPercentage = 0; 
        } else if (fieldName === 'lumpsumPercentage') {
            this.lumpsumPercentage = parseFloat(value) || 0;
            this.lumpsumAmount = 0; 
        }
        if (this.lumpsumTaxPercentage) {
            const selectedTax = this.taxOptions.find(option => option.value === this.lumpsumTaxPercentage);
            if (selectedTax) {
                this.calculateLumpsumTax(selectedTax);
            }
        }
        this.calculateAllTaxTotals();
    }
    connectedCallback() {
        this.loadestimationitems();
    }
    @track EstimationDetails = [];
    async loadestimationitems() {
        if (!this.recordId) {
            console.error('recordId is undefined');
            return;
        }
    
        try {
            // Load header data
            const headerData = await getEstimation({
                EstimationId: this.recordId
            });
            console.log('headerData', JSON.stringify(headerData));
            if (headerData) {
                // Map header fields
                this.name = headerData.name;
                this.quoteDate = headerData.quoteDate;
                this.status = headerData.status;
                this.shippingTerms = headerData.shippingTerms;
                this.paymentTerms = headerData.paymentTerms;
                this.porefnum = headerData.porefnum;
                this.discountTypeValue = headerData.discountType;
                this.discountModeValue = headerData.discountMode;
                this.lumpsumAmount = headerData.lumpsumDiscountAmount;
                this.lumpsumPercentage = headerData.lumpsumDiscountPercentage;
                this.lumpsumTaxPercentage = headerData.taxPercentage;
                this.taxPercent = headerData.taxPercent || 0;
                this.preferredCurrency = headerData.preferredCurrency;
                // Set customer details
                this.customerSelectedRecord = {
                    id: headerData.customerId,
                    name: headerData.supplierName
                };
                this.isDiscountEnabled = headerData.discountType ? true : false;
                //AR 21/07/2025 Added currency code field
                //this.currencyCode = event.detail.subField || '';
                this.currencyCode = headerData.currencyCode || '';
                this.preferredCurrency = headerData.preferredCurrency || '';
                //AP-05AUG25 Extract only the currency code part (e.g., "INR") for display
                this.currencyDisplay = Utility.extractCurrencyCode(headerData.currencyCode || headerData.preferredCurrency || '');

                if(this.status == 'Approved'){
                    this.isButtonDisabled = true;
                    console.log('flag',this.isButtonDisabled);
                }
            }
    
            // Load line items
            const itemsData = await getestimationItems({
                EstimationId: this.recordId
            });
            console.log('itemsData', JSON.stringify(itemsData));
            if (itemsData) {
                // Map the line items with all required properties
                this.estimationitems = itemsData.map(item => ({
                    id: item.id,
                    keyField: item.keyField,
                    productId: item.productId,
                    productName: item.productName || '',
                    productSku: item.productSku || '',
                    productQuantity: item.productQuantity || 0,
                    stockAvailable: item.stockAvailable || 0,
                    leadTime: item.leadTime || '',
                    unitPrice: item.unitPrice,
                    quantity: item.quantity,
                    description: item.description,
                    tax: item.tax,
                    taxPercent: item.taxPercent,
                    discountAmount: item.discountAmount || 0,
                    discountPercentage: item.discountPercentage || 0,
                    discountMode: item.discountMode,
                    searchResults: [],
                    disableAmount: item.discountMode !== 'Amount',
                    disablePercentage: item.discountMode !== 'Percentage'
                }));
            }
            this.calculateAllTaxTotals(); // Calculate initial tax totals
        } catch (error) {
            console.error('Error loading estimation data:', error);
            this.showToast('Error', 'Failed to load Estimation data', 'error');
        }
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
        this.isButtonDisabled = false;
        const fromIndex = this.fromIndex;
        const toIndex = this.targetIndex;
        const element = this.estimationitems.splice(fromIndex, 1)[0];
        this.estimationitems.splice(toIndex, 0, element);
        this.estimationitems = this.estimationitems.map((item, index) => ({
            ...item,
            keyField: index + 1
        }));
    }

    // Abdullah V S | 14-Aug-25 | Handle cancel logic
    handleCancel() {
        this.name = '';
        this.quoteDate = null;
        this.status = '';
        this.shippingTerms = '';
        this.paymentTerms = '';
        this.porefnum = '';
        this.discountTypeValue = '';
        this.discountModeValue = '';
        this.lumpsumAmount = '';
        this.lumpsumPercentage = null;
        this.lumpsumTaxPercentage = null;
        this.taxPercent = 0;
        this.preferredCurrency = null;
        this.isDiscountEnabled = false;
        this.currencyCode = '';
        this.currencyDisplay = '';
        this.handleCustomerValRemoval();
        this.estimationitems = [];
        this.loadestimationitems();
    }
    handleProductSearch(event) {
        this.isButtonDisabled = false;
        const searchKey = event.target.value;
        const index = event.target.dataset.index;

        if (searchKey.length > 2) {
            searchProducts({
                    searchKey
                })
                .then(data => {
                    this.estimationitems = this.estimationitems.map((item, i) => ({
                        ...item,
                        searchResults: i === parseInt(index) ? data : []
                    }));
                })
                .catch(error => {
                    console.error('Error searching products', error);
                });
        } else {
            this.clearSearchResults(index);
        }
    }

    selectProduct(event) {
        const index = event.target.dataset.index;
        const productId = event.currentTarget.dataset.id;
        const selectedProduct = this.estimationitems[index].searchResults.find(p => p.id === productId);
        if (selectedProduct) {
            this.estimationitems[index] = {
                ...this.estimationitems[index],
                productSku: selectedProduct.sku,
                productQuantity: selectedProduct.productQuantity,
                stockAvailable: selectedProduct.stockAvailable,
                unitPrice: selectedProduct.listingPrice,
                productName: selectedProduct.name,
                productId: selectedProduct.id,
                leadTime: selectedProduct.leadTime,

                searchResults: []
            };
        }
        //AR 22/08/2025 Calling calculateAllTaxTotals after selecting product
        this.calculateAllTaxTotals();
    }

    clearSearchResults(index) {
        this.estimationitems = this.estimationitems.map((item, i) => ({
            ...item,
            searchResults: i === parseInt(index) ? [] : item.searchResults
        }));
    }

    handleInputChange(event) {
        this.isButtonDisabled = false;
        const field = event.target.dataset.id;
        const value = event.detail.value;
    
        // Handle header fields
        if (field) {
            switch(field) {
                case 'name':
                    this.name = value;
                    break;
                case 'quoteDate':
                    this.quoteDate = value;
                    break;
                case 'status':
                    this.status = value;
                    break;
                case 'shippingTerms':
                    this.shippingTerms = value;
                    break;
                case 'paymentTerms':
                    this.paymentTerms = value;
                    break;
                case 'porefnum':
                    this.porefnum = value;
                    break;
                case 'estimationVersion':
                    this.estimationVersion = value;
                    break;
                case 'preferredCurrency':
                    this.preferredCurrency = value;
                    break;   
            }
        } 
        // Handle line item fields
        else {
            const index = event.target.dataset.index;
            const field = event.target.name;
            
            if (index !== undefined && field) {
                if (field === 'taxPercentage') {
                    const selectedTaxOption = this.taxOptions.find(option => option.value === value);
                    if (selectedTaxOption) {
                        this.estimationitems[index].tax = value;
                        this.estimationitems[index].taxPercent = selectedTaxOption.percentage;
                    }
                } else {
                    this.estimationitems[index][field] = value;
                }
    
                if (field === 'discountMode') {
                    const isAmount = value === 'Amount';
                    const isPercentage = value === 'Percentage';
                    
                    this.estimationitems[index] = {
                        ...this.estimationitems[index],
                        disableAmount: !isAmount,
                        disablePercentage: !isPercentage,
                        discountAmount: isAmount ? this.estimationitems[index].discountAmount : null,
                        discountPercentage: isPercentage ? this.estimationitems[index].discountPercentage : null
                    };
                }
                if (['quantity', 'unitPrice', 'discountAmount', 'discountPercentage', 'taxPercentage'].includes(field)) {
                    this.calculateAllTaxTotals();
                }
            }
        }
    }

    addRow() {
        this.isButtonDisabled = false;
        //AR 22/08/2025 Set default tax percentage for new rows
        const defaultTaxOption = this.taxOptions.find(option => 
            option.value === this.defaultTaxPercentage
        );
        this.estimationitems = [...this.estimationitems, {
            productId: '',
            productName: '',
            productSku: '',
            productQuantity: '',
            stockAvailable: '',
            unitPrice: '',
            leadTime: '',
            quantity: 1,
            //AR 22/08/2025 Set default tax percentage for new rows
            tax: this.defaultTaxPercentage ||'',
            taxPercent: defaultTaxOption ? defaultTaxOption.percentage : '',
            taxPercentage:'',
            discountMode: this.discountModeValue || '',
            searchResults: []
        }];
    }
    async saveRecords() {
        if (this.isButtonDisabled) return;
        this.isButtonDisabled = true;
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
            console.log('isValid:', isValid);
            this.showToast('Error', 'Please fill all required fields.', 'warning');
            this.isButtonDisabled = false;
            return;
        }
        try {
            const wrapper = {
                id: this.recordId || null,
                name: this.name,
                quoteDate: this.quoteDate,
                status: this.status,
                customerId: this.customerSelectedRecord?.id || null,
                shippingTerms: this.shippingTerms,
                paymentTerms: this.paymentTerms,
                preferredCurrency: this.preferredCurrency,
                porefnum: this.porefnum,
                discountType: this.discountTypeValue,
                discountMode: this.discountModeValue,
                lumpsumDiscountAmount: Number(this.lumpsumAmount) || 0,
                lumpsumDiscountPercentage: Number(this.lumpsumPercentage) || 0,
                taxPercentage: this.lumpsumTaxPercentage,
                taxPercent: this.discountTypeValue === 'Lumpsum Discount' ? 
                (this.taxPercent || 0) : 0,
                ESItems: this.estimationitems
                    .filter(item =>
                        item.productId && item.productName && item.unitPrice && item.quantity
                    )
                    .map((item, index) => ({
                        ...item,
                        keyField: index + 1,
                        taxPercent: (!this.discountTypeValue || 
                            this.discountTypeValue === 'Line Item Discount') ? 
                            (item.taxPercent || 0) : 0
                    }))
            };
            console.log('Wrapper data:', JSON.stringify(wrapper));
            const result = await saveEstimation({ wrapper: wrapper });
            console.log('this.taxDetails ', JSON.stringify(this.taxDetails));
            if (this.taxDetails && this.taxDetails.length > 0) {
                await createTaxDetailRecords({
                    taxDetailsList: this.taxDetails,
                    estimationId: result
                });
            }
            await this.loadestimationitems();
            this.showToast('Success', 'Estimation saved successfully', 'success');
            setTimeout(() => {
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: result,
                        objectApiName: this.ns+'Estimation__c',
                        actionName: 'view'
                    }
                });
            }, 1000);
    
        } catch (error) {
            console.error('Error saving estimation:', error);
            this.showToast('Error', error.body?.message || 'Error saving Estimation', 'error');
        } finally {
            this.isButtonDisabled = false;
        }
    }

    deleteRow(event) {
        this.isButtonDisabled = false
        let index = event.target.dataset.index;
        let itemId = this.estimationitems[index].id;
        console.log('index ' + index);
        this.showConfirmationDialog("Are you sure you want to delete this item?")
            .then((confirmation) => {
                if (!confirmation) return;

                if (itemId) {
                    console.log('Item has Id, proceeding with deletion');
                    deleteEstimationItem({
                            itemId
                        })
                        .then(() => {
                            this.showToast('Success', 'Item deleted successfully', 'success');
                            this.estimationitems = this.estimationitems.filter((_, i) => i != index);
                        })
                        .catch((error) => {
                            this.showToast('Error', 'This Estimation cannot be Update/deleted because it has related to PurchaseOrder Or Invoice records.', 'error');
                            console.error('Error deleting record:', error);
                        });
                } else {
                    console.log('Item has no Id, removing from UI only');
                    this.estimationitems = this.estimationitems.filter((_, i) => i != index);
                }
            });
    }
    
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
    }
    
    showConfirmationDialog(message) {
        return new Promise((resolve) => {
            const confirmed = window.confirm(message);
            resolve(confirmed);
        });
    }

    handleSync() {
        this.isSyncButtonDisabled = true;
        syncCostRecords({
                estimationId: this.recordId
            })
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Cost records synced successfully.',
                        variant: 'success'
                    })
                );
                // Refresh the estimation items data
                this.loadestimationitems();
            })
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error syncing',
                        message: error.body.message,
                        variant: 'error'
                    })
                );
            });
    }
}