// <!--AR 29/05/2025 Po item Component with Discount and tax -->
//<!-- AR 3/07/2025  Field visiblity and read only control -->
// AAB 11JUL25 PURCHASE ORDER FORM COMPONENT


//<!--
 //   AR 18/07/2025 Tax details record creation and Calculation
// -->
// Abdullah V S | 21-Aug-25 | Dynamically sets visibility, read-only, and required flags for fields
import { LightningElement, track, api, wire } from 'lwc';
import getpurchaseOrderItems from '@salesforce/apex/CreatePurchaseOrderItems.getpurchaseOrderItems';
import getPurchaseOrder from '@salesforce/apex/CreatePurchaseOrderItems.getPurchaseOrder';
import searchProducts from '@salesforce/apex/CreatePurchaseOrderItems.searchProductsWrapper';
import deleteEstimationItem from '@salesforce/apex/CreatePurchaseOrderItems.deletePoItem';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPicklistValue from '@salesforce/apex/CreatePurchaseOrderItems.getPicklistValue';
import savePurchaseOrder from '@salesforce/apex/CreatePurchaseOrderItems.savePurchaseOrder';
import savePurchaseOrderItemsWithWrapper from '@salesforce/apex/CreatePurchaseOrderItems.savePurchaseOrderItemsWithWrapper';
import getTableFieldMetadata from '@salesforce/apex/TableFieldConfigUtility.getTableFieldMetadata';
import { NavigationMixin } from 'lightning/navigation';
import getNslog from '@salesforce/apex/InvoiceFormController.getNslog';
import taxOptions from '@salesforce/apex/TaxUtility.getParentTaxes';
import createTaxDetailRecords from '@salesforce/apex/CreatePurchaseOrderItems.createTaxDetailRecords';
import getVendorDetails from '@salesforce/apex/CreatePurchaseOrderItems.getVendorDetails';
import Utility from 'c/utility';
import getPOItemIds from '@salesforce/apex/CreatePurchaseOrderItems.getPOItemIds';

export default class PoItems extends NavigationMixin(LightningElement) {
    @track isLoading = false;
    @api recordId; 
    ns;
    @track poItems = [];
    @track searchResults = [];
    @track hideDiscountFields = false;
    @track isButtonDisabled = false;
    @track discountType =[];
    @track isDiscountEnabled = false;
    @track discountTypeValue = '';
    @track discountModeValue = '';
    discOptions=[];
    statusOptions=[];
    poTypeOptions=[];
    @api paymentTerm=false;
    @api shippingTerm= false;
    @track componentName = 'poItem';
    @track visibilityFlags = {};
    @track readOnlyFlags = {};
    @track requiredFlags = {};
        // TAX CHANGES 
    @track taxOptions = [];
    @track parentTaxOptions = [];
    // AR 21/07/2025 Added currency code field
    @track paymentTerms = '';
    @track preferredCurrency;
    @track currencyDisplay = '';//AP-05AUG25 Display the currencyCode
    @wire(taxOptions)
        wiredTaxOptions({error, data}) {
            if (data) {
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
        get showTaxDetailsSection() {
            return this.taxDetails && this.taxDetails.length > 0;
        }
        @track taxDetails = [];
        calculateAllTaxTotals() {
            const taxDetails = [];
        
            this.poItems.forEach((item, index) => {
                if (!item.tax) return;
        
                const selectedTax = this.taxOptions.find(option => option.value === item.tax);
                if (!selectedTax) return;
        
                let baseAmount = (item.unitPrice || 0) * (item.quantity || 0);
                
                if (this.discountTypeValue === 'Line Item Discount') {
                    if (this.discountModeValue === 'Percentage') {
                        baseAmount -= baseAmount * (item.discountPercentage || 0) / 100;
                    } else if (this.discountModeValue === 'Amount') {
                        baseAmount -= (item.discountAmount || 0);
                    }
                }
                if (selectedTax.fullData.childTaxes && selectedTax.fullData.childTaxes.length > 0) {
                    selectedTax.fullData.childTaxes.forEach(childTax => {
                        const taxAmount = (baseAmount * childTax.childTaxPercentage) / 100;
                        taxDetails.push({
                            taxName: childTax.childTaxName,
                            taxId: childTax.childTaxId,
                            taxAmount: parseFloat(taxAmount.toFixed(2)),
                            poItemId:  `item${index + 1}`,//item.id ||
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
                        poItemId: `item${index + 1}`,//item.id || 
                        subtotal: baseAmount,
                        percentage: selectedTax.percentage
                    });
                }
            });
            // Handle lumpsum discount case
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
            // Group taxes by name
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

       @wire(getTableFieldMetadata, {
               componentName: '$componentName'
           })
           wiredTableConfig({
               error,
               data
           }) {
               if (data) {
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
                   console.log('this.width',data);
       
               } else if (error) {
                   console.error('Error loading table configuration:', error);
               }
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
        get isStockAvailabe() {
            return this.getFieldConfig('stockAvailable');
        }
        get isProductSKU() {
            return this.getFieldConfig('productSKU');
        }
        get isLeadTime() {
            return this.getFieldConfig('leadTime');
        }
        get isSalesCost() {
            return this.getFieldConfig('salesCost');
        }
        get isQuantity() {
            return this.getFieldConfig('quantity');
        }
        get isDiscountAmount() {
            return this.getFieldConfig('discountAmount');
        }
        get isDiscountPercentage() {
            return this.getFieldConfig('discountPercentage');
        }
        get isTax() {
            return this.getFieldConfig('tax');
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
            return `width: ${this.isDiscountAmount.width};`;
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


        @wire(getNslog)
        handleNamespace({ error, data }) {
            if (data) {
                this.ns = data.nameSpace != 'null' ? data.nameSpace : '';
             } else if (error) {
          console.error('Error loading namespace:', error);
             }
        } 

       @wire(getPicklistValue)
        wiredPicklistValues({ error, data }) {
            if (data) {
                //this.taxOptions = data.taxOptions?.map(value => ({ label: value, value: value })) || [];
                this.discOptions = data.discOptions?.map(value => ({ label: value, value: value })) || [];
                this.discountType = data.discountType?.map(value => ({ label: value, value: value })) || [];
                this.statusOptions = data.statusOptions?.map(value => ({ label: value, value: value })) || [];
                this.poTypeOptions = data.poType?.map(value => ({ label: value, value: value })) || [];
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

        @track vendorSelectedRecord = { id: null, name: null };
        @track currencyCode = '';

        accountobjectApiName = 'Vendor__c';
        accountadditionalFieldApiName = 'Shipping_Terms__c'; 
        accountotherFieldApiName = 'Preferred_Currency_Code__c';
        accountlabel = 'Vendor';

        handleValueSelectedOnVendor(event) {
            if (!event.detail || !event.detail.id) {
                console.error('Invalid vendor selection event:', event);
                return;
            }
            this.vendorSelectedRecord = {
                id: event.detail.id,
                name: event.detail.mainField
            };
            this.currencyCode = event.detail.subField || '';
            if (event.detail.additionalField) {
                this.shippingTerms = event.detail.additionalField;
            }
            // AR 21/07/2025 Added vendor details retrieval
            getVendorDetails({ vendorId: event.detail.id }) 
                .then(data => { 
                    if (data) {
                        this.paymentTerms = data.paymentTerms || '';
                    } else {
                        console.warn('No vendor details found for ID:', event.detail.id);
                    }
                })
                // AP-04AUG25 | Extract only the currency code using Utility (e.g., "INR" from "INR - Indian Rupee")
                // AP-05AUG25 Store the selected full currency string
                this.preferredCurrency = event.detail.subField || '';
                this.currencyCode = event.detail.subField || '';
                this.currencyDisplay = Utility.extractCurrencyCode(this.preferredCurrency);
                
        }

        handleVendorValRemoval() {
            this.vendorSelectedRecord = { id: null, name: null };
            this.currencyCode = '';
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
            return Utility.convertToWords(this.grandTotal, this.currencyCode) + ' only';
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
            const selectedTaxId = event.detail.value;
            const selectedTax = this.taxOptions.find(option => option.value === selectedTaxId);
            
            if (selectedTax) {
                this.lumpsumTaxPercentage = selectedTaxId;
                this.taxPercent = selectedTax.percentage; // Store the percentage
                this.calculateLumpsumTax(selectedTax);
            }
       }
       calculateLumpsumTax(selectedTax) {
        const taxDetails = [];
        const baseAmount = parseFloat(this.calculatedSubTotal) || 0;
    
        if (selectedTax.fullData.childTaxes && selectedTax.fullData.childTaxes.length > 0) {
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
            const taxAmount = (baseAmount * selectedTax.percentage) / 100;
            taxDetails.push({
                taxName: selectedTax.label,
                taxId: selectedTax.value,
                taxAmount: parseFloat(taxAmount.toFixed(2)),
                percentage: selectedTax.percentage
            });
        }
    
        this.taxDetails = taxDetails.map(tax => ({
            ...tax,
            taxAmount: parseFloat(tax.taxAmount.toFixed(2))
        }));
    }
    handleDiscountTypeChange(event) {
        this.discountTypeValue = event.detail.value;
        
        if (this.discountTypeValue === 'Line Item Discount') {
            this.lumpsumTaxPercentage = '';
            this.lumpsumAmount = 0;
            this.lumpsumPercentage = 0;
            //AR 22/08/2025 Set default tax percentage for line items
            this.poItems = this.poItems.map(item => ({
                ...item,
                tax: this.defaultTaxPercentage || '',   
                taxPercent: this.taxOptions.find(option => option.value === this.defaultTaxPercentage)?.percentage || 0,    
            }));
        } 
        else if (this.discountTypeValue === 'Lumpsum Discount') {
            this.poItems = this.poItems.map(item => ({
                ...item,
                tax: '',
                taxPercentage: 0,
                discountAmount: 0,
                discountPercentage: 0
            }));
            //AR 22/08/2025 Set default tax percentage for lumpsum
            this.lumpsumTaxPercentage = this.defaultTaxPercentage || '';
            this.taxPercent = this.taxOptions.find(option => option.value === this.lumpsumTaxPercentage)?.percentage || 0;
        }
        
        this.calculateAllTaxTotals();
    }
       handleDiscountModeChange(event) {
           this.discountModeValue = event.detail.value;
           this.poItems = this.poItems.map(item => ({
               ...item,
               discountMode: this.discountModeValue
           }));
           this.calculateAllTaxTotals(); 
       }
       handleLumpsumChange(event) {
           const fieldName = event.target.name;
           const value = event.target.value;
           
           if (fieldName === 'lumpsumAmount') {
               this.lumpsumAmount = value;
           } else if (fieldName === 'lumpsumPercentage') {
               this.lumpsumPercentage = value;
           }
           this.calculateAllTaxTotals();
       }

       connectedCallback() {
            if (this.recordId) {
                this.loadpoItems();
            } 
       }
         @track purchaseOrderDetails=[];

    async loadpoItems() {
        if (!this.recordId) {
            console.error('recordId is undefined');
            return;
        }
        this.isLoading = true;
        try {
            const headerData = await getPurchaseOrder({
                purchaseOrderId: this.recordId
            });
    
            if (headerData) {
                this.poName = headerData.poName;
                this.requiredDate = headerData.requiredDate;
                this.status = headerData.status;
                this.poType = headerData.poType;
                this.title = headerData.title || '';
                this.shippingTerms = headerData.shippingTerms;
                this.paymentTerms = headerData.paymentTerms;
                this.discountTypeValue = headerData.discountType;
                this.discountModeValue = headerData.discountMode;
                this.lumpsumAmount = headerData.lumpsumDiscountAmount;
                this.lumpsumPercentage = headerData.lumpsumDiscountPercentage;
                this.lumpsumTaxPercentage = headerData.taxPercentage;
                
                this.vendorSelectedRecord = {
                    id: headerData.vendorId,
                    name: headerData.supplierNameField
                };
                this.isDiscountEnabled = headerData.discountType ? true : false;
                this.currencyCode = headerData.currencyCode || '';
                // AR 21/07/2025 Added preferred currency
                this.preferredCurrency = headerData.preferredCurrency;
                this.currencyDisplay = Utility.extractCurrencyCode(headerData.preferredCurrency || '');
            }
    
            const itemsData = await getpurchaseOrderItems({
                purchaseOrderId: this.recordId
            });
    
            if (itemsData) {
                this.poItems = itemsData.map(item => ({
                    ...item,
                    id: item.id,
                    keyField: item.keyField,
                    productName: item.productName || '',
                    description: item.description,
                    productSku: item.productSku || '',
                    productQuantity: item.productQuantity || '',
                    unitPrice: item.unitPrice,
                    quantity: item.quantity,
                    tax: item.taxPercentage,
                    discountAmount: item.discountAmount ?? '',
                    discountPercentage: item.discountPercentage ?? '',
                    discountMode: item.discountMode,
                    productId: item.productId,
                    searchResults: []
                }));
                this.calculateAllTaxTotals(); 
            }
            // AP-30JUL25 - Extracting valid poItemIds from poItems array
            const poItemIds = this.poItems.map(item => item.id).filter(id => id);
            // AP-31JUL25 - Fetching poItemNames based on poItemIds for handling with and without productId tagged poItems
            await getPOItemIds({poItemIds: poItemIds})
                .then(data => {
                     // AP-30JUL25 - Adding Additional key and values in poItems with poItemName and isProductName based on productId
                    this.poItems = this.poItems.map(item => ({
                        ...item,
                        poItemName: data[item.id] || '',
                        isProductName: item.productId != null ? false : true,//AP-31JUL25 - If productId is not null, then it is a product, else it is a manual input
                    }));
                })
        } catch (error) {
            console.error('Error loading PO data:', error);
            this.showToast('Error', 'Failed to load Purchase Order data', 'error');
        } finally {
            this.isLoading = false;
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
        // AP-30JUL25 - Update productName with the user's search key input
        this.poItems[index].productName = searchKey;
        this.poItems[index].productId = null; 
    
        if (searchKey.length > 2) { 
            searchProducts({ searchKey })
                .then(data => {
                    this.poItems = this.poItems.map((item, i) => ({
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
        const selectedProduct = this.poItems[index].searchResults.find(p => p.id === productId);
        
        if (selectedProduct) {
            this.poItems[index] = {
                ...this.poItems[index],
                productSku: selectedProduct.sku,
                productQuantity: selectedProduct.productQuantity,
                unitPrice: selectedProduct.actualCost,
                productName: selectedProduct.name,
                productId: selectedProduct.id,
                //AR 22/08/2025 Set default tax percentage for selected product
                tax: this.defaultTaxPercentage || '',
                taxPercent: this.taxOptions.find(option => option.value === this.defaultTaxPercentage)?.percentage || 0,
                discountAmount: 0, 
                taxPercentage: 0, 
                searchResults: []
            };
        }
        //AR 22/08/2025 - calling calculation when a product is selected
        this.calculateAllTaxTotals();
    }
    clearSearchResults(index) {
        this.poItems = this.poItems.map((item, i) => ({
            ...item,
            searchResults: i === parseInt(index) ? [] : item.searchResults
        }));
    }


    handleInputChange(event) {
        const field = event.target.dataset.id;
        const value = event.detail.value;
    
        // Handle header fields
        if (field) {
            switch(field) {
                case 'poName':
                    this.poName = value;
                    break;
                case 'requiredDate':
                    this.requiredDate = value;
                    break;
                case 'status':
                    this.status = value;
                    break;
                case 'poType':
                    this.poType = value;
                    break;
                case 'title':
                    this.title = value;
                    break;
                case 'shippingTerms':
                    this.shippingTerms = value;
                    break;
                case 'paymentTerms':
                    this.paymentTerms = value;
                    break;
                    //AR 21/07/2025 Added preferred currency
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
                    console.log('Selected tax percentage:', value);
                    const selectedTaxOption = this.taxOptions.find(option => option.value === event.detail.value);
                    if (selectedTaxOption) {
                        this.poItems[index] = {
                            ...this.poItems[index],
                            tax: event.detail.value,
                            taxPercentage: selectedTaxOption.percentage || 0,
                            taxPercent: selectedTaxOption.percentage || 0
                        };
                        this.calculateAllTaxTotals();
                    }
                } else {
                    this.poItems[index][field] = value;
                    if (['quantity', 'unitPrice'].includes(field)) {
                        this.calculateAllTaxTotals();
                    }
                }

                if (field === 'discountMode') {
                    const isAmount = value === 'Amount';
                    const isPercentage = value === 'Percentage';
                    
                    this.poItems[index] = {
                        ...this.poItems[index],
                        disableAmount: !isAmount,
                        disablePercentage: !isPercentage,
                        discountAmount: isAmount ? this.poItems[index].discountAmount : null,
                        discountPercentage: isPercentage ? this.poItems[index].discountPercentage : null
                    };
                    this.calculateAllTaxTotals();
                }
                if (['discountAmount', 'discountPercentage'].includes(field)) {
                    this.calculateAllTaxTotals();
                }
            }
        }
    }
    
    handleCancel() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: this.ns ? this.ns + 'Purchase_Order__c' : 'Purchase_Order__c',
                actionName: 'list'
            }
          });
      }
   
       addRow() {
           this.poItems = [...this.poItems, { 
               productId: '', 
               productName: '', 
               productSku: '', 
               productQuantity: '', 
               unitPrice: '', 
               quantity: 1, 
               //AR 22/08/2025 Set default tax percentage for new items
               tax: this.defaultTaxPercentage || '',
               taxPercent: this.defaultTaxPercentage ? this.taxOptions.find(option => option.value === this.defaultTaxPercentage)?.percentage || 0 : 0,
               taxPercentage: '0',
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
                if (!input.checkValidity()) {
                    input.reportValidity();
                    isValid = false;
                }
            });
            if(!isValid){
                this.showToast('Error', 'Please fill all required fields.', 'warning');
                this.isButtonDisabled = false;
                return;
            }
            try {
                const updatedPoItems = this.poItems.map((item, index) => ({
                    id: item.id || null,
                    keyField: Number(index + 1),
                    productId: item.productId || null, // AP-30JUL25 - Use productId if available, else null
                    // AP-30JUL25 - If isProductName is true, use poItemName (manual input); else use productName or fallback to empty string
                    productName: item.isProductName ? item.poItemName : item.productName || '',
                    productSku: item.productSku,
                    productQuantity: Number(item.productQuantity) || 0,
                    unitPrice: Number(item.unitPrice) || 0,
                    quantity: Number(item.quantity) || 0,
                    taxPercentage: item.tax,
                    //taxPercent: item.taxPercent || 0 ,
                    taxPercent: (!this.discountTypeValue || this.discountTypeValue === 'Line Item Discount') ? 
                      (item.taxPercent || 0) : 0,
                    discountAmount: Number(item.discountAmount) || 0,
                    discountPercentage: Number(item.discountPercentage) || 0,
                    discountMode: item.discountMode || null
                }));
        
                const wrapper = {
                    id: this.recordId,
                    poName: this.poName || '',
                    requiredDate: this.requiredDate,
                    status: this.status || '',
                    poType: this.poType || '',
                    title: this.title || '',
                    vendorId: this.vendorSelectedRecord?.id,
                    shippingTerms: this.shippingTerms || '',
                    paymentTerms: this.paymentTerms || '',
                    discountType: this.discountTypeValue || '',
                    discountMode: this.discountModeValue || '',
                    lumpsumDiscountAmount: Number(this.lumpsumAmount) || 0,
                    lumpsumDiscountPercentage: Number(this.lumpsumPercentage) || 0,
                    taxPercentage: this.lumpsumTaxPercentage || '',
                    taxPercent: this.discountTypeValue === 'Lumpsum Discount' ?(this.taxPercent || 0) : 0,
                    // AR 21/07/2025 Added preferred currency
                    preferredCurrency: this.preferredCurrency,
                    poItems: updatedPoItems || []
                };
        
                const result=await savePurchaseOrder({ wrapper: wrapper });
                 // Create tax details after PO is saved
                if (this.taxDetails && this.taxDetails.length > 0) {
                    const taxDetailsForApex = this.taxDetails.map(tax => ({
                        taxId: tax.taxId,
                        taxName: tax.taxName,
                        percentage: tax.percentage,
                        taxAmount: tax.taxAmount
                    }));

                    await createTaxDetailRecords({ 
                        //taxDetailsList: [{ details: taxDetailsForApex }], 
                        taxDetailsList: this.taxDetails,
                        poId: result 
                    });
                }
                await this.loadpoItems(); 
                this.showToast('Success', 'Purchase Order saved successfully', 'success');
                setTimeout(() => {
                    this[NavigationMixin.Navigate]({
                        type: 'standard__recordPage',
                        attributes: {
                            recordId: result,
                            objectApiName: this.ns ? this.ns + 'Purchase_Order__c' : 'Purchase_Order__c',
                            actionName: 'view'
                        }
                    });
                }, 1000);
            } catch (error) {
                console.error('Error saving PO:', error);
                this.showToast('Error', error.body?.message || 'Error saving Purchase Order', 'error');
            } finally {
                this.isButtonDisabled = false;
            }
        }
        deleteRow(event) {
           let index = event.target.dataset.index;
           let itemId = this.poItems[index].id;
           this.showConfirmationDialog("Are you sure you want to delete this item?")
           .then((confirmation) => {
               if (!confirmation) return;
          
               if (itemId) {
                   deleteEstimationItem({ itemId })
                       .then(() => {
                           this.showToast('Success', 'Item deleted successfully', 'success');
                           this.poItems = this.poItems.filter((_, i) => i != index);
                           this.calculateAllTaxTotals(); 
                       })
                       .catch(error => {
                           this.showToast('Error', 'This Purchase Order cannot be Update/deleted because it has related to PurchaseOrder Or Invoice records.', 'error');
                           console.error('Error deleting record:', error);
                           setTimeout(() => {
                               window.location.reload(); // Refresh the page
                           }, 2000);
                       });
               } else {
                   this.poItems = this.poItems.filter((_, i) => i != index);
                   this.calculateAllTaxTotals(); 
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