// <!-- AR 17/05/2025 DIscount Logic , Tax amount , Place of supply from metadata,Terms from invoice picklist, default first currency picklist  -->
// <!-- KK 17/05/2025 Invoice Item product lookup , Stock Serial Number tag in line item-->
import { LightningElement, track, wire, api } from 'lwc';
//import getRecordTypeId from '@salesforce/apex/InvoiceFormController.getRecordTypeId';
import getProductList from '@salesforce/apex/InvoiceFormController.getProductList';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'
// import { getPicklistValues } from 'lightning/uiObjectInfoApi';
//import BillingCountryCode from '@salesforce/schema/Account.BillingCountryCode';
// import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import ACCOUNT_OBJECT from '@salesforce/schema/Account';
import getAccBankInfo from "@salesforce/apex/InvoiceFormController.getAccBankInfo";
//import getCurrencyInWords from "@salesforce/apex/InvoiceFormController.getCurrencyInWords";
import getInvoiceFormData from "@salesforce/apex/InvoiceFormController.getInvoiceFormData";
import getMainTaxOptions from "@salesforce/apex/InvoiceFormController.getMainTaxOptions";
import getChildTaxOptions from '@salesforce/apex/InvoiceFormController.getChildTaxOptions';
import getAllChildTaxOptions from '@salesforce/apex/InvoiceFormController.getAllChildTaxOptions';
import saveInvoiceRecord from "@salesforce/apex/InvoiceFormController.saveInvoiceRecord";
import emailViewCount from "@salesforce/apex/InvoiceFormController.emailViewCount";
import getAuthList from '@salesforce/apex/InvoiceFormController.getAuthList';
//import {LightningPrompt} from 'lightning/prompt';
import {NavigationMixin} from 'lightning/navigation';
//import base64PDF from './example.js';
//import FILE_PREVIEW_RESOURCE from '@salesforce/resourceUrl/lightningFilePreview';
import LightningModal from 'lightning/modal';
import SystemModstamp from '@salesforce/schema/Account.SystemModstamp';
import getPicklistValue from '@salesforce/apex/InvoiceFormController.getPicklistValue';
import getProductDetails from '@salesforce/apex/InvoiceFormController.getProductDetails';
import searchStocks from '@salesforce/apex/InvoiceFormController.searchStocks';
import getStockByInvoiceItemIds from '@salesforce/apex/InvoiceFormController.getStockByInvoiceItemIds';
import validateInvoiceRecord from "@salesforce/apex/InvoiceFormController.validateInvoiceRecord";
import clearanceInvoice from "@salesforce/apex/InvoiceFormController.clearanceInvoice";
// import getInvoiceType from '@salesforce/apex/InvoiceFormController.getInvoiceType';
// import getInvoiceNameType from '@salesforce/apex/InvoiceFormController.getInvoiceNameType';
// import getPaymentType from '@salesforce/apex/InvoiceFormController.getPaymentType';
import getPicklistValues from '@salesforce/apex/InvoiceFormController.getPicklistValues';
// import getDependentPicklistValues from '@salesforce/apex/InvoiceFormController.getDependentPicklistValues';
// import updateInvoiceValidation from "@salesforce/apex/InvoiceFormController.updateInvoiceValidation";
// import updateInvoiceClearance from "@salesforce/apex/InvoiceFormController.updateInvoiceClearance";
import { getRecord } from 'lightning/uiRecordApi';

const ZERO_RATE_EXEMPTIONS = [
    {label: "The international transport of goods", value: "The international transport of goods"},
    {label: "International transport of passengers", value: "International transport of passengers"},
    {label: "Services directly connected and incidental to a supply of international passenger transport", 
     value: "Services directly connected and incidental to a supply of international passenger transport"},
    {label: "Supply of a qualifying means of transport", value: "Supply of a qualifying means of transport"},
    {label: "Any services relating to goods or passenger transportation", 
     value: "Any services relating to goods or passenger transportation"},
    {label: "Medicines and medical equipment", value: "Medicines and medical equipment"},
    {label: "Qualifying metals", value: "Qualifying metals"},
    {label: "Private education to citizen", value: "Private education to citizen"},
    {label: "Private healthcare to citizen", value: "Private healthcare to citizen"},
    {label: "Supply of qualified military goods", value: "Supply of qualified military goods"}
];

const EXEMPTED_TAX_EXEMPTIONS = [
    {label: "Financial services", value: "Financial services"},
    {label: "Life insurance", value: "Life insurance"},
    {label: "Real estate transactions", value: "Real estate transactions"}
];

export default class InvoiceForm extends NavigationMixin(LightningElement) {

    @track showPopup = false;
    // @track serialNumber = '';
    @track searchKey = '';
    // @track searchResults = [];
    // @track selectedStockId = null;
    // @track selectedStockName = '';
    @track selectedSerialNumbers = []; // stores selected stocks
    @track searchResults = [];
    @track activeRowIndex;
    @track activeProductId;
    handleProductSelected(event) {
        this.showpdtcolmnfn=true;
        const selectedItem = event.detail;
        console.log('pppppppp---->'+selectedItem.id);
        const rowIndex = selectedItem.rowId;
        console.log('Hello--->'+rowIndex);
        if (selectedItem && rowIndex !== undefined) {
            const productId = selectedItem.id;
            getProductDetails({ productId: productId })
            .then(result => {
                const invoiceItems = [...this.invoiceItemList];
                this.invoiceItemList[rowIndex].pdtId = result.Id;
                this.invoiceItemList[rowIndex].selectedSerialNumbers = [];
                this.invoiceItemList[rowIndex].tempSelectedSerials = [];
                this.invoiceItemList[rowIndex].isSerialProduct=false;
                if(result.Is_Serial_Number__c){
                     this.showpdtcolmnfn=true;
                     this.invoiceItemList[rowIndex].isSerialProduct = result.Is_Serial_Number__c;
                } 
                else{

                }  
                // trigger reactivity if needed
                this.invoiceItemList = [...this.invoiceItemList];
            })
            .catch(error => {
                console.error('Error fetching product details: ', error);
            });
        }
    }
   handleSerialInput(event) {
    this.searchKey = event.target.value;

    if (this.searchKey.length > 2) {
        searchStocks({ searchKey: this.searchKey, productId: this.activeProductId })
            .then(data => {
                    const committedGlobally = [];

                    // Collect all selected serial numbers from other rows (same product)
                    this.invoiceItemList.forEach((item, idx) => {
                        if (item.pdtId === this.activeProductId && idx !== this.activeRowIndex) {
                            (item.selectedSerialNumbers || []).forEach(serial => {
                                committedGlobally.push(serial.value);
                            });
                        }
                    });

                    const alreadyChosenIds = new Set([
                        ...committedGlobally,
                        ...(this.invoiceItemList[this.activeRowIndex]?.selectedSerialNumbers || []).map(s => s.value),
                    ]);

                this.searchResults = (data || []).filter(
                    stock => !alreadyChosenIds.has(stock.Id)
                );

            })
            .catch(error => {
                console.error('Error searching products', error);
            });
    } else {
        this.searchResults = [];
    }
}


    handleSelect(event) {
    const stockId = event.target.dataset.id;
    const stockSNO = event.target.label;
    const index = this.activeRowIndex;

    if (!this.invoiceItemList[index].tempSelectedSerials) {
        this.invoiceItemList[index].tempSelectedSerials = [];
    }

    const existingList = this.invoiceItemList[index].tempSelectedSerials;
    const alreadySelected = existingList.some(item => item.value === stockId);

    if (!alreadySelected) {
        existingList.push({ value: stockId, label: stockSNO });
    } else {
        this.invoiceItemList[index].tempSelectedSerials = existingList.filter(item => item.value !== stockId);
    }

    // Trigger reactivity
    this.invoiceItemList = [...this.invoiceItemList];
}

    togglePopup(event) {
        this.activeRowIndex = parseInt(event.currentTarget.dataset.index, 10);
        this.activeProductId = this.invoiceItemList[this.activeRowIndex]?.pdtId;
        this.showPopup = true;
        this.searchKey = ''; // reset search input
        this.searchResults = []; // clear old search results
    }

    closePopup() {
        this.showPopup = false;
    }

    saveSerialNumber() {
        const index = this.activeRowIndex;

        this.invoiceItemList[index].selectedSerialNumbers = [...(this.invoiceItemList[index].tempSelectedSerials || [])];
        this.invoiceItemList = [...this.invoiceItemList];
        this.closePopup();
    } 
    deselectSerialNumber(event) {
        const index = parseInt(event.target.dataset.index, 10);
        const value = event.target.dataset.value;

        this.invoiceItemList[index].selectedSerialNumbers = this.invoiceItemList[index].selectedSerialNumbers.filter(
            item => item.value !== value
        );
        this.invoiceItemList[index].tempSelectedSerials =
        (this.invoiceItemList[index].tempSelectedSerials || []).filter(
            item => item.value !== value
        );

        this.invoiceItemList = [...this.invoiceItemList];
    }
    newrecord=true;
    empty='';
    @track checkboxjournalflag = false;
    @track invoicerecordId;
    @api recordId;
    @track invWrapObj;
    sendEmailFlag = false;
    popupDivStyle;
    journalEntryDebit;
    //@api ParentinvoiceId = '';
    @track dragStart;
    @track spinnerFlag = false;
    @track isGreyedOut = false;
    @track ready = false;
    formDisableFlag;
    //invoiceId = 'a0tDn000001hWtjIAE';
    @api invoiceId = '';
    @track isExecutedOnce = false;
    @track invoiceItemList = [];
    errorMessage;
    sendEmailFlag = false;
    serviceDate = null;
    pdtId = null;
    pdtDraftName = null;
    isKnownPdt = false;
    // hsn = null;
    // description = null;
    taxExemption = null;
    taxCategory = null;
    discountReason = null;
    qty = null;
    rate = null;
    amt = null;
    tax = null;
    taxId = null;
    primaryContactEmail;
    ccEmailAddressesStr;
    tempCcEmailAddressesStr;
    bccEmailAddressesStr;
    tempBccEmailAddressesStr;
    calculatedSubTotal = 0.00;
    //@track grandTotal = 0.00;
    //showSubTotalSection = false;
    chosenParentTaxOption = 'Inclusive of Tax';
    accMdtInfo = null;
    msgOnInv = null;
    companyName = null;
    termsAndCond = null;
    invNumber = null;
    currencyInWords = null
    msgOnStmt = null;
    //showGrandTotalSection = false;
    hideSubTaxesSection = false;
    showCcBccSec = false;
    @track resultantSubTaxArray = [{"Id" : null,  "Label" : null, "value": null}];
    taxPercentageOptions = [];
    currentSelectedTaxLabel;
    @track finalSubTaxesInfoJson = [];
    @track finalSubTaxesInfoMap = new Map();
    @track subTaxLabelMap = new Map();
    @track subTaxWholeMap = new Map();
    discountoptions = [];
    discountTypeOptions = [];
    currencyoptions = [];
    // @track selectedCurrency = 'INR - Indian Rupee';
    @track selectedCurrency;
    @track exchangeRate = '1';
    @track supplyOption=[];
    @track termsOptions = [];
    currencyField = 'Currency__c';
    @wire(getPicklistValue, { fieldApiName: '$currencyField' })
    wiredCurrencies({ error, data }) {
        if (data) {
            this.currencyoptions = data.map(label => ({ label, value: label }));
            if (this.currencyoptions.length > 0) {
                this.selectedCurrency = this.currencyoptions[0].value;
                const myArray = this.selectedCurrency.split("-");
                this.currencyCode = myArray[0];
                this.currencyCodeName = myArray[1];
            }
        } else if (error) {
            console.error('Error fetching picklist values:', error);
        }
    }
    termField= 'Term__c';
    @wire(getPicklistValue, { fieldApiName: '$termField' })
    wiredTerms({ error, data }) {
        if (data) {
            // this.termsOptions = data.map(label => ({ label, value: label }));
            this.termsOptions = data.map(label => {
                const match = label.match(/\d+/); // Extract number like 15
                return {
                    label: label,
                    value: match ? match[0] : ''
                };
            });
        } else if (error) {
            console.error('Error fetching picklist values:', error);
        }
    }
    discountModeField = 'Discount_Mode__c';
    @wire(getPicklistValue, { fieldApiName: '$discountModeField' })
    wiredDiscountMode({ error, data }) {
        if (data) {
            this.discountoptions = data.map(label => ({ label, value: label }));
        } else if (error) {
            console.error('Error fetching picklist values:', error);
        }
    }
    discountTypeField= 'Discount_Type__c';
    @wire(getPicklistValue, { fieldApiName: '$discountTypeField' })
    wiredDiscounttype({ error, data }) {
        if (data) {
            this.discountTypeoptions = data.map(label => ({ label, value: label }));
        } else if (error) {
            console.error('Error fetching picklist values:', error);
        }
    }
    @track selectedDiscountMode = '';
    @track selectedDiscountType = '';

    // Add computed property to control column visibility
    get showDiscountPercentage() {
        return this.selectedDiscountMode === 'Line Item Discount' && 
            this.selectedDiscountType === 'Percentage';
    }

    get showDiscountAmount() {
        return this.selectedDiscountMode === 'Line Item Discount' && 
            this.selectedDiscountType === 'Amount';
    }

    // Add computed property for showing/hiding discount reason column
    get showDiscountReason() {
        return this.selectedDiscountMode === 'Line Item Discount';
    }

    get showDeliveryDate() {
        return this.invoiceNameType === 'Simplified' && this.invoiceIndicator === 'Summary';
    }

    // get showTaxExemption() {
    //     return this.taxCategory === 'Zero Rate' || this.taxCategory === 'Exempted From Tax';
    // }

    // get showTaxExemptionOutsideScope() {
    //     return this.taxCategory === 'Outside Scope of Tax';
    // }

    @track lumpsumDiscountPercentage = 0;
    @track lumpsumDiscountAmount = 0;

    // Computed properties for showing/hiding lumpsum discount fields
    get showLumpsumPercentage() {
        return this.selectedDiscountMode === 'Lumpsum Discount' && 
            this.selectedDiscountType === 'Percentage';
    }

    get showLumpsumAmount() {
        return this.selectedDiscountMode === 'Lumpsum Discount' && 
            this.selectedDiscountType === 'Amount';
    }

    handleLumpsumDiscountPercentageChange(event) {
        this.lumpsumDiscountPercentage = event.target.value;
        if (this.invoiceItemList) {
            this.invoiceItemList.forEach(item => {
                item.taxAmount = this.calculateLineItemTaxAmount(item);
            });
        }
        this.calculateSubTotal(false);
    }

    handleLumpsumDiscountAmountChange(event) {
        this.lumpsumDiscountAmount = event.target.value;
        if (this.invoiceItemList) {
            this.invoiceItemList.forEach(item => {
                item.taxAmount = this.calculateLineItemTaxAmount(item);
            });
        }
        this.calculateSubTotal(false);
    }
    discountPercentage;
    discountAmount;
    taxAmount=null;
    handleDiscountPercentageChange(event) {
        const index = event.target.dataset.index;
        const value = event.target.value;
        this.invoiceItemList[index].discountPercentage = value;
        this.invoiceItemList[index].taxAmount = this.calculateLineItemTaxAmount(this.invoiceItemList[index]);
        this.taxAmount = this.invoiceItemList[index].taxAmount;
        // this.calculateLineItemTotal(index);
    }
    
    handleDiscountAmountChange(event) {
        const index = event.target.dataset.index;
        const value = event.target.value;
        this.invoiceItemList[index].discountAmount = value;
        this.invoiceItemList[index].taxAmount = this.calculateLineItemTaxAmount(this.invoiceItemList[index]);
        this.taxAmount = this.invoiceItemList[index].taxAmount;
        // this.calculateLineItemTotal(index);
    }
    handleDiscountMode(event) {
        this.selectedDiscountMode = event.detail.value;
        // Handle Line Item Discount mode
        if (this.selectedDiscountMode !== 'Line Item Discount') {
            this.resetDiscountValues();
        }
        // Handle Lumpsum Discount mode
        if (this.selectedDiscountMode !== 'Lumpsum Discount') {
            this.lumpsumDiscountPercentage = 0;
            this.lumpsumDiscountAmount = 0;
        }
        this.calculateSubTotal(false);
    }
    
    handleDiscountType(event) {
        this.selectedDiscountType = event.detail.value;
        // Reset line item discounts
        this.resetDiscountValues();
        // Reset lumpsum discounts
        this.lumpsumDiscountPercentage = 0;
        this.lumpsumDiscountAmount = 0;
        this.validateTaxesForLumpsumDiscount();
        this.calculateSubTotal(false);
    }
   
    
    resetDiscountValues() {
        if (this.invoiceItemList) {
            this.invoiceItemList.forEach(item => {
                item.discountAmount = 0;
                item.discountPercentage = 0;
            });
        }
    }
    
    handleCurrencyChange(event) {
        this.selectedCurrency = event.detail.value;
        const myArray = this.selectedCurrency.split("-");
        this.currencyCode = myArray[0];
        this.currencyCodeName = myArray[1];
    }

    handleExchangeRateChange(event) {
        this.exchangeRate = event.detail.value;
        console.log('Exchange Rate:', this.exchangeRate);
    }
    validateTaxesForLumpsumDiscount() {
        // Only validate if Lumpsum Discount is selected
        if (this.selectedDiscountMode === 'Lumpsum Discount' && this.invoiceItemList && this.invoiceItemList.length > 0) {
            const firstTax = this.invoiceItemList[0].tax;
            const hasDifferentTax = this.invoiceItemList.some(item => item.tax !== firstTax);

            if (hasDifferentTax) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'When using Lumpsum Discount, all items must have the same tax rate.',
                        variant: 'error'
                    })
                );
                return false;
            }
        }
        return true;
    }
    
    @wire(getAllChildTaxOptions) allChildTaxInfoResp;
    @wire(getMainTaxOptions,{countryName:'India'}) handleGetTaxOptionsResult(result){
        // ////console.log("Inside the handleGetTaxOptionsResult");
        // ////console.log(result);
        // ////console.log(result.data);
        ////console.log(typeof result.data);
        if(result.data) {   
            this.taxPercentageOptions = result.data;
            // ////console.log("taxPercentageOptions.length = "+this.taxPercentageOptions.length);
            // ////console.log('this.taxPercentageOptions = ',this.taxPercentageOptions);
        }
    };
    @track parentAccountSelectedRecord = [];
    @track parentContactSelectedRecord = [];
    chosenTerm = '15';
    chosenTermLabel = 'Net 15';
    @track invoiceDate = new Date().toISOString().substring(0, 10);
    @track dueDate = new Date(new Date().setDate(new Date().getDate() + 15)).toISOString().substring(0, 10);
    selectedCountry;
    ccListLength = 0;
    bccListLength = 0;
    //previewPdfFlag = false;
    vfPageURLToPreview;
    hideInputForPdtSerCurrentRow = true;
    //@track pdtList;
    @track pdtComboBoxList = [];
    
    pdtListRenderingFlag = false;
    @wire(getProductList) handleGetProductList(result){
        
        if(result.data){
            ////console.log('result.data.length'+result.data.length);
            for(let i=0; i<result.data.length; i++){
                ////console.log('Name = '+result.data[i].Name);
                this.pdtComboBoxList.push({label:result.data[i].Name, value:result.data[i].Id});
            }
            this.pdtComboBoxList.push({label:'+ Add New', value:'_new_'});
            this.pdtListRenderingFlag = true;
        }
    };
    @track autComboBoxList = [];
    @track authroizedSignature;

    @wire(getAuthList)
    wiredMetadata({ error, data }) {
        if (data) {
            this.autComboBoxList = data.map((record) => ({
                label: record.MasterLabel,
                value: record.MasterLabel
            }));
        } else if (error) {
            ////console.error('Error fetching custom metadata:', error);
        }
    }

    // taxCategoryOptions = [];
    // taxExemptionOptions = [];
    // // picklistMap = {};
    // selectedTaxCategory; // taxCategory
    // selectedTaxExemption; // taxExemption

    // @wire(getDependentPicklistValues)
    // wiredPicklists({ data, error }) {
    //     if (data) {
    //         this.picklistMap = data;
    //         this.taxCategoryOptions = Object.keys(data).map(key => ({
    //             label: key,
    //             value: key
    //         }));
    //     } else if (error) {
    //         console.error(error);
    //     }
    // }

    // handleTaxCategoryChange(event) {
    //     this.selectedTaxCategory = event.detail.value;
    //     const exemptions = this.picklistMap[this.selectedTaxCategory] || [];
    //     this.taxExemptionOptions = exemptions.map(item => ({
    //         label: item,
    //         value: item
    //     }));
    //     this.selectedTaxExemption = null;
    // }

    handleTaxExemptionChange(event) {
        let i = event.target.dataset.index;
        this.invoiceItemList[i].taxExemption = event.detail.value;
        console.log('Selected Tax Exemption:', this.invoiceItemList[i].taxExemption);
        
    }

    handleTaxCategoryChange(event) {
        let i = event.target.dataset.index;
        // this.invoiceItemList[i].taxCategory = event.detail.value;
        // console.log('Selected Tax Category:', this.invoiceItemList[i].taxCategory);
        const selectedCategory = event.detail.value;
        this.invoiceItemList[i].taxCategory = selectedCategory;
        this.invoiceItemList[i].taxExemption = null; // Reset exemption when category changes
        
        // Update exemption options based on selected category
        if (selectedCategory === 'Zero Rate') {
            this.taxExemptionOptions = ZERO_RATE_EXEMPTIONS;
        } else if (selectedCategory === 'Exempted From Tax') {
            this.taxExemptionOptions = EXEMPTED_TAX_EXEMPTIONS;
        } else {
            this.taxExemptionOptions = []; // Clear options for other categories
        }

        // Force reactivity
        this.invoiceItemList = [...this.invoiceItemList];

    }

    @wire(getPicklistValues)
    wiredPicklists({ error, data }) {
        if (data) {
            this.invoicetypeList = data.invoiceType.map(value => ({ label: value, value: value }));
            this.invoiceNametypeList = data.invoiceNameType.map(value => ({ label: value, value: value }));
            this.paymentList = data.paymentType.map(value => ({ label: value, value: value }));
            this.discountReasonOptions = data.discountReason.map(value => ({ label: value, value: value }));
            this.invoiceIndicatorOptions = data.invoiceIndicator.map(value => ({ label: value, value: value }));
            this.taxCategoryOptions = data.taxId.map(value => ({ label: value, value: value }));
            console.log('@track taxCategoryOptions = [];', JSON.stringify(this.taxCategoryOptions));
            this.taxExemptionOptions = data.taxExemptionReason.map(value => ({ label: value, value: value }));
            console.log('@track taxExemptionOptions = [];', JSON.stringify(this.taxExemptionOptions));
            
            // this.taxExemptionMap = data.taxExemptionReason || {};

            // // Optionally set default options
            // if (this.taxCategoryOptions.length > 0) {
            //     this.taxCategory = this.taxCategoryOptions[0].value;
            //     this.updateTaxExemptionOptions(this.taxCategory);
            // }
            // this.taxExemptionMap = data.taxExemptionReason || {};
            // this.taxCategoryOptions = data.taxId.map(val => ({ label: val, value: val }));

            // // initialize options for each row
            // this.invoiceItems = this.invoiceItems.map(item => ({
            //     ...item,
            //     taxExemptionOptions: [] // initialize with empty
            // }));

            
            
            // Store tax exemptions with their category relationships
            // this.taxExemptionOptions = data.taxExemptionReason.map(item => ({
            //     label: item.label,
            //     value: item.value,
            //     categoryId: item.validForId // Assuming this comes from your backend
            // }));
        } else if (error) {
            console.error('Error loading picklists:', error);
        }
    }

    @track discountReasonOptions = [];
    @track invoicetypeList = [];
    @track invoiceType;
    @track taxCategoryOptions = [];
    // taxCategory = null;
    @track taxExemptionOptions = [];
    // taxExemption = null;
    // taxExemptionMap = {};

    // onExistingTaxCategoryChange(event) {
    //     this.taxCategory = event.target.value;
    //     console.log('Selected Tax Category:', this.taxCategory);
    //     // Update tax exemption options based on selected category
    //     this.updateTaxExemptionOptions(this.taxCategory);
    //     this.taxExemption = '';
    // }
    // onExistingTaxCategoryChange(event) {
    //     const rowIndex = event.target.dataset.index;
    //     const selectedTaxCategory = event.target.value;
    
    //     this.invoiceItems[rowIndex].taxCategory = selectedTaxCategory;
    
    //     // Create and assign exemption options for this row
    //     const exemptionList = this.taxExemptionMap[selectedTaxCategory] || [];
    //     this.invoiceItems[rowIndex].taxExemptionOptions = exemptionList.map(value => ({
    //         label: value,
    //         value: value
    //     }));
    
    //     // Clear previous selection
    //     this.invoiceItems[rowIndex].taxExemption = '';
    // }
    

    // onExistingTaxExemptionChange(event) {
    //     this.taxExemption = event.target.value;
    //     console.log('Selected Tax Exemption:', this.taxExemption);
    // }
    // onExistingTaxExemptionChange(event) {
    //     const rowIndex = event.target.dataset.index;
    //     const selectedValue = event.target.value;
    
    //     // Update the taxExemption value in the invoiceItems list for the selected row
    //     this.invoiceItems[rowIndex].taxExemption = selectedValue;
    
    //     console.log(`Row ${rowIndex} selected Tax Exemption:`, selectedValue);
    // }

    // updateTaxExemptionOptions(taxCategory) {
    //     const values = this.taxExemptionMap[taxCategory] || [];
    //     this.taxExemptionOptions = values.map(value => ({ label: value, value: value }));
    // }

    // @wire(getInvoiceType)
    // wiredInvTypeData({ error, data }) {
    //     if (data) {
    //         this.invoicetypeList = data;
    //     } else if (error) {
    //         // console.error('Error fetching custom metadata:', error);
    //     }
    // }

    handleInvTypeChange(event){
        this.invoiceType = event.target.value;
        console.log('invoiceType = '+this.invoiceType);
    }

    @track invoiceNametypeList = [];
    @track invoiceNameType;

    // @wire(getInvoiceNameType)
    // wiredInvNameTypeData({ error, data }) {
    //     if (data) {
    //         this.invoiceNametypeList = data;
    //     } else if (error) {
    //         // console.error('Error fetching custom metadata:', error);
    //     }
    // }

    handleInvNameTypeChange(event){
        this.invoiceNameType = event.target.value;
        console.log('invoiceNameType = '+this.invoiceNameType);
    }
    @track paymentList = [];
    @track paymentType;
    // @wire(getPaymentType)
    // wiredPaymentTypeData({ error, data }) {
    //     if (data) {
    //         this.paymentList = data;
    //     } else if (error) {
    //         // console.error('Error fetching custom metadata:', error);
    //     }
    // }
    handlePaymentListChange(event) {
        this.paymentType = event.target.value;
        console.log('paymentType = ' + this.paymentType);
    }

    @track invoiceIndicator;
    @track invoiceIndicatorOptions = [];
    handleIndicatorChange(event) {
        this.invoiceIndicator = event.target.value;
        // Update the radio button selection
        // const allRadios = this.template.querySelectorAll('input[name="indicator"]');
        // allRadios.forEach(radio => {
        //     radio.checked = (radio.value === this.invoiceIndicator);
        // });
    }

    handleCheckboxChange(event) {         
        this.checkboxjournalflag = event.target.checked; 
        ////console.log('this.isChecked = '+this.checkboxjournalflag);
    }
    @track latestDeliveryDate;
    latestDeliveryDateChange(event) {
        this.latestDeliveryDate = event.target.value;
        ////console.log('latestDeliveryDate = ' + this.latestDeliveryDate);
    }
    

    closeAction() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Invoice__c',
                actionName: 'list'
            },
        });
    }
    constructor() {
        ////console.log('Inside the constructor');
        super();
        ////console.log(this.recordId);
        //this.recordId = 'a0tDn000001hWtjIAE';
    }

    /*get fetchPdtComboList(){
        ////console.log("fetchPdtComboList");
        ////console.log("pdtList.length = "+this.pdtList.length);
        let pdtComboList = [];
        let i = 0;
        this.pdtList.forEach(ele =>{
                ////console.log("Inside the for loop = Name: "+ele.Name+" Id: "+ele.Id);
                pdtComboList.push({label:ele.Name, value:ele.Id});
                i++;
            });
        
        return pdtComboList;
    }*/

    /*get currencyInWords(){
        if(!this.grandTotal || this.grandTotal <= 0) return 'Zero Only';
        getCurrencyInWords(
                {totalInvAmt: this.grandTotal}
            )
            .then((result) => {
                //console.log("Inside the getCurrencyInWords");
                //console.log(result);
                let currencyInWordsVal = result + ' Only';
                //console.log(' currencyInWordsVal = '+currencyInWordsVal);
                return currencyInWordsVal;
            })
            .catch((error) => {
                //console.log("###Error : " + error.body.message);
                return 'Zero Only';
            });
    }*/

    get fetchTaxOptions(){
        ////console.log("fetchTaxOptions");
        ////console.log("this.grandTotal "+this.grandTotal);
        ////console.log("taxPercentageOptions.length = "+this.taxPercentageOptions.length);
        let mainPercentageOptions = [];
        let i = 0;
        this.taxPercentageOptions.forEach(ele =>{
                ////console.log("Inside the for loop = Name: "+ele.Name+" Tax_Percentage__c: "+ele.Tax_Percentage__c);
                mainPercentageOptions.push({label:ele.Name, value:ele.Tax_Percentage__c+"%"});
                //this.subTaxLabelMap.set(ele.Tax_Percentage__c+"%",ele.Name);
                this.subTaxLabelMap.set(ele.Tax_Percentage__c+"%",ele);
                this.subTaxWholeMap.set(ele.Name,ele.Id);
                ////console.log("Inside the for loop = Name: "+ele.Name+" Id: "+ele.Id);
                /*////console.log("Inside the for loop = Name: "+mainPercentageOptions[i].label+
                " Tax_Percentage__c: "+mainPercentageOptions[i].value);*/
                i++;
            });
        
        ////console.log('this.subTaxLabelMap.size = ',this.subTaxLabelMap.size);
        ////console.log('this.subTaxWholeMap.size = ',this.subTaxWholeMap.size);
        
        ////console.log("this.recordId = "+this.recordId);
        ////console.log('this.invoiceItemList.length = '+this.invoiceItemList.length);
        if(this.recordId && !this.isExecutedOnce && this.invoiceItemList.length > 0){
            ////console.log('Invoice id not null cond in fetchTaxOptions');
            //this.isExecutedOnce = true;
            this.reCalculateSubTaxInfoMap(true);
        }

        ////console.log('mainPercentageOptions = ',mainPercentageOptions);

        return mainPercentageOptions;
    }

    get disableFlagForPdtNameSec(){
        return (this.hideInputForPdtSerCurrentRow || this.formDisableFlag)
    }

    /*get hideBalanceDueSecOnTop(){
        if(this.recordId && this.isExecutedOnce){
            return false;
        }else if(!this.recordId){
            return false;
        }
        return true;
    }*/
       
        get totalRate() {
            let total = 0;
            if (this.invoiceItemList) {
                this.invoiceItemList.forEach(item => {
                    if (item.rate && item.qty) {
                        // Calculate line total using rate * quantity 
                        const lineTotal = parseFloat(item.rate) * parseFloat(item.qty);
                        total += lineTotal;
                    }
                });
            }
            return total > 0 ? total.toFixed(2) : null;
        }
        calculateLineItemTaxAmount(item) {
            if (item.rate && item.qty && item.tax) {
                const baseAmount = parseFloat(item.rate) * parseFloat(item.qty);
                let discountedAmount = baseAmount;
                if (this.selectedDiscountMode === 'Line Item Discount') {
                    if (this.selectedDiscountType === 'Percentage' && item.discountPercentage) {
                        const discountAmount = baseAmount * (parseFloat(item.discountPercentage) / 100);
                        discountedAmount = baseAmount - discountAmount;
                    } else if (this.selectedDiscountType === 'Amount' && item.discountAmount) {
                        discountedAmount = baseAmount - parseFloat(item.discountAmount);
                    }
                }
                else if (this.selectedDiscountMode === 'Lumpsum Discount') {
                    if (this.selectedDiscountType === 'Percentage' && this.lumpsumDiscountPercentage) {
                        // const discountPerItem = this.lumpsumDiscountPercentage / this.invoiceItemList.length;
                        const discountAmount = baseAmount * (this.lumpsumDiscountPercentage / 100);
                        discountedAmount = baseAmount - discountAmount;
                    } else if (this.selectedDiscountType === 'Amount' && this.lumpsumDiscountAmount) {
                        // For amount lumpsum, distribute discount proportionally based on item amount
                        const totalInvoiceAmount = this.invoiceItemList.reduce((sum, invItem) => {
                            return sum + (parseFloat(invItem.rate || 0) * parseFloat(invItem.qty || 0));
                        }, 0);
                        
                        if (totalInvoiceAmount > 0) {
                            const itemRatio = baseAmount / totalInvoiceAmount;
                            const itemDiscount = this.lumpsumDiscountAmount * itemRatio;
                            discountedAmount = baseAmount - itemDiscount;
                        }
                    }
                }
                
                // Calculate tax on discounted amount
                const taxPercentage = parseFloat(item.tax.replace('%', ''));
                const taxAmount = discountedAmount * (taxPercentage / 100);
                
                return taxAmount.toFixed(2);
            }
            return '0.00';
        }
        get calculatedTaxAmount() {
            let total = 0;
            if (this.invoiceItemList) {
                this.invoiceItemList.forEach(item => {
                    if (item.taxAmount) {
                        total += parseFloat(item.taxAmount);
                    }
                });
            }
            return total > 0 ? total.toFixed(2) : '0.00';
        }
        
        totalDiscountAmount;
        get totalDiscount() {
            let totalDiscount = 0;
            
            // Calculate line item discounts
            if (this.selectedDiscountMode === 'Line Item Discount') {
                this.invoiceItemList.forEach(item => {
                    if (item.rate && item.qty) {
                        let lineAmount = parseFloat(item.rate) * parseFloat(item.qty);
                        if (this.selectedDiscountType === 'Percentage' && item.discountPercentage) {
                            const discountAmount = lineAmount * (parseFloat(item.discountPercentage) / 100);
                            totalDiscount += discountAmount;
                        } else if (this.selectedDiscountType === 'Amount' && item.discountAmount) {
                            totalDiscount += parseFloat(item.discountAmount);
                        }
                    }
                });
            }
            
            // Calculate lumpsum discount
            else if (this.selectedDiscountMode === 'Lumpsum Discount') {
                let baseAmount = 0;
                this.invoiceItemList.forEach(item => {
                    if (item.amt) {
                        baseAmount += parseFloat(item.amt);
                    }
                });
                
                if (this.selectedDiscountType === 'Percentage' && this.lumpsumDiscountPercentage) {
                    totalDiscount = baseAmount * (parseFloat(this.lumpsumDiscountPercentage) / 100);
                } else if (this.selectedDiscountType === 'Amount' && this.lumpsumDiscountAmount) {
                    totalDiscount = parseFloat(this.lumpsumDiscountAmount);
                }
            }
            
            return totalDiscount > 0 ? totalDiscount.toFixed(2) : null;
        }
        @wire(getAccBankInfo)
        wiredAccBankInfo({ error, data }) {
            if (data && data.length > 0) {
                const placeOfSupply = data[0].Place_of_Supply__c;
                if (placeOfSupply) {
                    this.supplyOption = placeOfSupply
                        .split(',')
                        .map(item => item.trim())
                        .filter(item => item)
                        .map(val => ({
                            label: val,
                            value: val
                        }));
                }
            } else if (error) {
                console.error('Error loading picklist values', error);
            }
        }
        

        @track showpdtcolmnfn=false;
        @track lumpsumDiscountReason;

    // Add computed property for showing/hiding lumpsum discount reason
    get showLumpsumDiscountReason() {
        return this.selectedDiscountMode === 'Lumpsum Discount';
    }

    handleLumpsumDiscountReasonChange(event) {
        this.lumpsumDiscountReason = event.target.value;
    }

        connectedCallback() {
        ////console.log(this.heckboxjournalflag);
        //this.recordId = 'a0tDn000001hWtjIAE';
        ////console.log('Inside connected callback');
        ////console.log("this.recordId = "+this.recordId);
        if(!this.recordId){
            getAccBankInfo(
                //RP - 02May2023 - Commanded since we will be having only one row in this table here after
                //{accName: "Ranger Technologies Private Limited"}
            )
            .then((result) => {
                // //console.log("Inside the getAccBankInfo");
                // //console.log(result);
                if(result.length > 0 ){
                    this.accMdtInfo = result[0];
                    // this.msgOnInv = "Bank Information:";
                    // this.msgOnInv += "\nAccount Number: "+this.accMdtInfo.Account_Number__c;
                    // this.msgOnInv += "\nAccount Type: "+this.accMdtInfo.Account_Type__c;
                    // this.msgOnInv += "\nIFSC Code: "+this.accMdtInfo.IFSC_Code__c;
                    // this.msgOnInv += "\nBranch: "+this.accMdtInfo.Branch__c;
                    this.termsAndCond = this.accMdtInfo.Terms_And_Condition__c;
                    this.companyName = this.accMdtInfo.Name__c;
                }
                ////console.log(this.msgOnInv);
                this.spinnerFlag = true;
            })
            .catch((error) => {
                ////console.log("###Error : " + error.body.message);
            });


            var tempInvItem = {
                serviceDate : null,
                pdtId : null,
                isKnownPdt : true,
                pdtDraftName: null,
                // hsn : null,
                // description : null,
                discountReason : null,
                qty : null,
                rate : null,
                amt : null,
                tax : null,
                taxCategory : null,
                taxExemption : null,
                taxLabel : null,
                taxId : null,
                key: 1,
                taxAmt: null,
                discountPercentage: null,
                discountAmount: null,
                taxAmount: null,
                amtWithTax: null
            }
            this.invoiceItemList.push(JSON.parse(JSON.stringify(tempInvItem)));
            tempInvItem.key = 2;
            this.invoiceItemList.push(JSON.parse(JSON.stringify(tempInvItem)));
            ////console.log('invoiceItemList.length = '+this.invoiceItemList.length);
            
            this.ready = true;
        }else{
                emailViewCount({invId: this.recordId}).then((result) => {
                    this.emailViewData = result;
                    ////console.log(result);
                }).catch((error) => {
                    ////console.log("###Error : " + error.body.message);
                });
                ////console.log('Inside the else');
                let invoiceItemIds = []; 
                getInvoiceFormData(
                        {invId: this.recordId}
                    )
                    .then((result) => {
                        // //console.log("Inside the getInvoiceFormData");
                        // //console.log(result);
                        let parsedResultant = JSON.parse(result);
                        ////console.log("parsedResultant.invWrapObj ",parsedResultant.invWrapObj);
                        this.invNumber = parsedResultant.invWrapObj.name;
                        this.parentAccountSelectedRecord.id = parsedResultant.invWrapObj.accId;
                        this.parentContactSelectedRecord.id = parsedResultant.invWrapObj.conId;
                        //this.parentContactSelectedRecord.mainField = parsedResultant.invWrapObj.conName;
                        this.primaryContactEmail = parsedResultant.invWrapObj.primaryConEmailAddresses;
                        this.ccEmailAddressesStr = parsedResultant.invWrapObj.ccEmailAddresses;
                        this.bccEmailAddressesStr = parsedResultant.invWrapObj.bccEmailAddresses;

                        ////console.log('1.this.invoiceItemList.length = '+this.invoiceItemList.length);
                        let tempCCStr = this.ccEmailAddressesStr ? this.ccEmailAddressesStr.replace(' ','') : this.ccEmailAddressesStr;
                        this.ccListLength = tempCCStr ? JSON.parse(JSON.stringify(tempCCStr.split(','))).length : 0;


                        let tempBCCStr = this.bccEmailAddressesStr ? this.bccEmailAddressesStr.replace(' ','') : this.bccEmailAddressesStr;
                        this.bccListLength = tempBCCStr ? JSON.parse(JSON.stringify(tempBCCStr.split(','))).length : 0;

                        ////console.log('2.this.invoiceItemList.length = '+this.invoiceItemList.length);
                        this.billingAddress = parsedResultant.invWrapObj.billingAddress;
                        this.chosenTerm = parsedResultant.invWrapObj.term;
                        this.chosenTermLabel = parsedResultant.invWrapObj.termLabel;
                        this.invoiceDate = parsedResultant.invWrapObj.invoiceDate;
                        this.dueDate = parsedResultant.invWrapObj.dueDate;
                        this.selectedCountry = parsedResultant.invWrapObj.placeOfSupply;
                        this.selectedDiscountMode = parsedResultant.invWrapObj.selectedDiscountMode;
                        this.selectedDiscountType = parsedResultant.invWrapObj.selectedDiscountType;
                        this.lumpsumDiscountPercentage = parsedResultant.invWrapObj.lumpsumDiscountPercentage;
                        this.lumpsumDiscountAmount = parsedResultant.invWrapObj.lumpsumDiscountAmount;
                        this.lumpsumDiscountReason = parsedResultant.invWrapObj.lumpsumDiscountReason;
                        this.authroizedSignature = parsedResultant.invWrapObj.authSign;
                        this.invoiceType = parsedResultant.invWrapObj.invoiceType;
                        this.invoiceNameType = parsedResultant.invWrapObj.invoiceNameType;
                        this.invoiceIndicator = parsedResultant.invWrapObj.invoiceIndicator;
                        // if (this.invoiceIndicator) {
                        //     // Set timeout to let the DOM render first
                        //     setTimeout(() => {
                        //         const radioButton = this.template.querySelector(`input[value="${this.invoiceIndicator}"]`);
                        //         if (radioButton) {
                        //             radioButton.checked = true;
                        //         }
                        //     }, 0);
                        // }
                        this.paymentType = parsedResultant.invWrapObj.paymentType;
                        this.latestDeliveryDate = parsedResultant.invWrapObj.latestDeliveryDate;
                        this.selectedCurrency=parsedResultant.invWrapObj.selectedCurrency;
                        this.exchangeRate=parsedResultant.invWrapObj.exchangeRate;
                        ////console.log('3.this.invoiceItemList.length = '+this.invoiceItemList.length);
                        this.chosenParentTaxOption = parsedResultant.invWrapObj.parentTaxSelectedOption;
                        ////console.log('4.this.invoiceItemList.length = '+this.invoiceItemList.length);
                        this.invoiceItemList = parsedResultant.invWrapObj.invoiceItemList;
                        invoiceItemIds = this.invoiceItemList.map(item => item.invItemId);
                        ////console.log('5.this.invoiceItemList.length = '+this.invoiceItemList.length);
                        this.msgOnInv = parsedResultant.invWrapObj.msgOnInv;
                        this.termsAndCond = parsedResultant.invWrapObj.termsAndCond;
                        //this.currencyInWords = parsedResultant.invWrapObj.amtInWords;
                        ////console.log('currencyInWords = '+this.currencyInWords);
                        this.msgOnStmt = parsedResultant.invWrapObj.msgOnStmt;
                        this.paidAmount = parsedResultant.invWrapObj.paidAmount;

                        //this.currencyCode = parsedResultant.invWrapObj.currencyCode;
                        if(parsedResultant.invWrapObj.selectedCurrency){
                            const myArray = parsedResultant.invWrapObj.selectedCurrency.split("-");
                            this.currencyCode = myArray[0];
                            this.currencyCodeName = myArray[1];
                        }
                        
                        this.companyName = parsedResultant.invWrapObj.companyName;

                        this.formDisableFlag = parsedResultant.invWrapObj.invStatus == 'Draft' ? false : true;
                        if(!this.formDisableFlag){
                            this.showpdtcolmnfn=true;
                        }
                        ////console.log('this.msgOnStmt = '+this.msgOnStmt);
                        /*this.taxVal = parsedResultant.invWrapObj.totalTaxAmt;
                        this.calculatedSubTotal = parsedResultant.invWrapObj.subTotal;
                        this.grandTotal = parsedResultant.invWrapObj.total;
                        this.grandTotal = parsedResultant.invWrapObj.balanceDue;*/

                        //this.fetchTaxOptions();
                        //this.reCalculateSubTaxInfoMap(false);
                        this.spinnerFlag = true;
                        if(this.chosenParentTaxOption === 'Out of scope of Tax') {
                            this.hideSubTaxesSection = true;
                            if(this.recordId && !this.isExecutedOnce && this.invoiceItemList.length > 0){
                                ////console.log('Invoice id not null cond in fetchTaxOptions');
                                //this.isExecutedOnce = true;
                                this.reCalculateSubTaxInfoMap(true);
                            }
                        }
                        
                        // Call Apex to get stock data
                        getStockByInvoiceItemIds({ invoiceItemIds:invoiceItemIds })
                            .then(originalStockMap => {
                                console.log('data--->' + JSON.stringify(originalStockMap));
                                 // Deep clone the stock map so we can safely mutate it
                                const stockMap = JSON.parse(JSON.stringify(originalStockMap));

                                this.invoiceItemList = this.invoiceItemList.map(item => {
                                    let stocks = stockMap[item.invItemId] || [];
                                console.log('Initial Stocks for item ' + item.invItemId + ' → ' + JSON.stringify(stocks));

                                const assignedStockIds = new Set();

                                // Assign serials to this row
                                const selectedSerialNumbers = stocks.map(stock => {
                                    assignedStockIds.add(stock.Id);
                                    return {
                                                            label: stock.Serial_Number__c,
                                                            value: stock.Id
                                    };
                                });

                                // Remove assigned stocks from other invoice items
                                Object.keys(stockMap).forEach(key => {
                                    if (key !== item.invItemId) {
                                        stockMap[key] = stockMap[key].filter(stock => !assignedStockIds.has(stock.Id));
                                    }
                                });

                                console.log('Assigned serials → ' + JSON.stringify(selectedSerialNumbers));

                                    return {
                                        ...item,
                                        isSerialProduct: selectedSerialNumbers.length > 0,
                                        selectedSerialNumbers: selectedSerialNumbers,
                                        tempSelectedSerials: [...selectedSerialNumbers]
                                    };
                                });

                                // Optional: trigger UI refresh or re-render
                            })
                            .catch(error => {
                                console.error('Error fetching stock records:', error);
                            });

                    })
                    .catch((error) => {
                        ////console.log("###Error : " + error.body.message);
                    });
        }
       
        // if (this.recordId) {
        //     // Get the current record's field values
        //     getRecord({
        //         recordId: this.recordId,
        //         fields: ['Invoice__c.Validate__c', 'Invoice__c.Clearance__c']
        //     })
        //     .then(result => {
        //         this.validateChecked = result.fields.Validate__c?.value || false;
        //         this.clearanceChecked = result.fields.Clearance__c?.value || false;
        //     })
        //     .catch(error => {
        //         console.error('Error fetching record data:', error);
        //     });
            
        // }
        /*setTimeout(() => {
            this.ready = true;
        }, 5000);*/

    }

    renderedCallback()    {  
      ////console.log('This is From child component rendered callback'); 
      if(this.isExecutedOnce) this.ready = true;
      ////console.log('this.ready = '+this.ready);
   }

    
    @track index = 0;

    @track row;
    @track targetIndex;
    @track fromIndex;
    start(event){
        ////console.log('Inside the start');
        ////console.log(event);
        this.row = event.target; 
        ////console.log('this.row = ',this.row);
    }
    over(event){
        ////console.log('Inside the over');
        event.preventDefault();
        var children = Array.from(event.target.parentNode.parentNode.children);
        ////console.log('children ',children);
        
        this.targetIndex = children.indexOf(event.target.parentNode);
        this.fromIndex = children.indexOf(this.row);
        ////console.log('this.targetIndex ',this.targetIndex);
        ////console.log('this.fromIndex ',this.fromIndex);
        /*if(children.indexOf(event.target.parentNode)>children.indexOf(this.row)){
            ////console.log('Inside the if cond');
            ////console.log(event.target.parentNode);
            //event.target.parentNode.after(this.row);
        } else{
            ////console.log('Inside the else cond');
            ////console.log(event.target.parentNode);
            //event.target.parentNode.before(this.row);
        }*/
    }

    newDrop(event){
        ////console.log('Inside the newDrop');
        ////console.log('this.targetIndex ',this.targetIndex);
        ////console.log('this.fromIndex ',this.fromIndex);
        /*var tempVar = this.invoiceItemList[this.fromIndex];
        this.invoiceItemList[this.fromIndex] = this.invoiceItemList[this.targetIndex];
        this.invoiceItemList[this.targetIndex] = tempVar;
        ////console.log('this.invoiceItemList['+this.fromIndex+'] ',this.invoiceItemList[this.fromIndex]);
        ////console.log('this.invoiceItemList['+this.targetIndex+'] ',this.invoiceItemList[this.targetIndex]);*/


        /*if(this.targetIndex>this.fromIndex){
            ////console.log('Inside the if cond');
            ////console.log(event.target.parentNode);
            //event.target.parentNode.insertAfter(this.row);
            event.target.parentNode.after(this.row);
        } else{
            ////console.log('Inside the else cond');
            ////console.log(event.target.parentNode);
            //event.target.parentNode.insertBefore(this.row);
            event.target.parentNode.before(this.row);
        }*/
        //['css', 'js', 'ts']
        const fromIndex = this.fromIndex;
        const toIndex = this.targetIndex;
        const element = this.invoiceItemList.splice(fromIndex, 1)[0];
        ////console.log(element); // ['css']
        this.invoiceItemList.splice(toIndex, 0, element);
        ////console.log(this.invoiceItemList); // 👉️ ['js', 'ts', 'css']
        var tempKey = 1;
        for(let i = 0; i < this.invoiceItemList.length; i++) {
            this.invoiceItemList[i].key = tempKey;
            tempKey++;
        }
    }

    DragStart(event) {
        ////console.log("On DragStart");
        this.dragStart = event.target.title;
        event.target.classList.add("drag");
    }

    DragOver(event) {
        ////console.log("On DragOver");
        ////console.log(event);
        event.preventDefault();
        //return false;
    }

    Drop(event) {
        ////console.log("On Drop");
        ////console.log(event);
        event.stopPropagation();
        const DragValName = this.dragStart;
        const DropValName = event.target.title;
        if (DragValName === DropValName) {
        return false;
        }
        const index = DropValName;
        const currentIndex = DragValName;
        const newIndex = DropValName;
        Array.prototype.move = function (from, to) {
        this.splice(to, 0, this.splice(from, 1)[0]);
        };
        this.invoiceItemList.move(currentIndex, newIndex);
    }

    handleServiceDateChange(event){
        this.serviceDate = event.target.value;
    }


    handlePdtChange(event){
        ////console.log("Inside the handlePdtChange");
        ////console.log(event);
        this.pdtId = event.target.value;
        this.pdtDraftName = null;
        if(this.pdtId == '_new_'){
            ////console.log("Inside the if cond");
            this.hideInputForPdtSerCurrentRow = false;
            this.isKnownPdt = false;
        }else{
            this.hideInputForPdtSerCurrentRow = true;
            this.isKnownPdt = true;
        }
        ////console.log("this.isKnownPdt = "+this.isKnownPdt);
    }
    handlePdtDraftChange(event){
        ////console.log("Inside the handlePdtChange");
        this.pdtDraftName = event.target.value;
    }
    /*currentPdtChangeOnBlur(){
        ////console.log("Inside the currentPdtChangeOnBlur");
        ////console.log(event);
    }*/
    // handleHsnChange(event){
    //     this.hsn = event.target.value;
    // }
    // handleDescChange(event){
    //     this.description = event.target.value;
    // }
    // handleDiscountReasonChange(event){
    //     this.discountReason = event.target.value;
    //     ////console.log("discountReason = "+this.discountReason);
    // }
    handleQtyChange(event){
        this.qty = event.target.value;
        if(this.rate) this.amt = (this.qty * this.rate).toFixed(2);
    }
    handleRateChange(event){
        this.rate = event.target.value;
        if(this.qty) this.amt = (this.qty * this.rate).toFixed(2);
    }
    handleAmtChange(event){
        this.amt = event.target.value;
    }
    handleTaxChange(event){
        ////console.log("Inside the handleTaxChange");
        ////console.log(event);
        this.tax = event.target.value;
        ////console.log("tax = "+this.tax);
        this.currentSelectedTaxLabel = event.target.options.find(opt => opt.value === event.detail.value).label;
        ////console.log("selectedLabel = "+this.currentSelectedTaxLabel);
        ////console.log("subTaxWholeMap.size = "+this.subTaxWholeMap.size);
        this.taxId = this.subTaxWholeMap.get(this.currentSelectedTaxLabel);
        ////console.log("taxId = "+this.taxId);
        //this.resetChildTaxMap();
    }
    

    updateExistingChildTaxInfoMap(event){
        // ////console.log("Inside the updateExistingChildTaxInfoMap");
        // ////console.log("event ",event);
        ////console.log(this.fetchTaxOptions);
        ////console.log("event ",event);
        ////console.log("event.index",event.target.dataset.index);
        ////console.log("label ",event.target.dataset.label);
        var previousRowTaxLabel = null;
        var currentRowTaxLabel = event.target.options.find(opt => opt.value === event.detail.value).label;
        ////console.log("currentRowTaxLabel = "+currentRowTaxLabel);


        let i = event.target.dataset.index;
        if(this.invoiceItemList[i].tax){
            //previous tax info NA cond
            previousRowTaxLabel = (this.invoiceItemList[i].tax).replace('%','');
            ////console.log("previousRowTaxLabel = "+previousRowTaxLabel);
        }
        this.invoiceItemList[i].tax = event.detail.value;
        this.invoiceItemList[i].taxLabel = currentRowTaxLabel;
        this.invoiceItemList[i].taxId = this.subTaxWholeMap.get(currentRowTaxLabel);
        this.invoiceItemList[i].taxAmount = this.calculateLineItemTaxAmount(this.invoiceItemList[i]);
        if(this.invoiceItemList[i].tax){ //this.invoiceItemList[i].amt &&
            var taxFloat = 0;
            var calTaxVal = 0;
            var amtWithTaxVal = 0;
            if(this.chosenParentTaxOption === 'Out of scope of Tax'){
                calTaxVal = 0;
                amtWithTaxVal = parseFloat(this.invoiceItemList[i].amt);
            }else{
                ////console.log(this.invoiceItemList[i].tax.replace('%',''));
                taxFloat = parseFloat(this.invoiceItemList[i].tax.replace('%',''));
                calTaxVal = this.invoiceItemList[i].amt * (taxFloat / 100);
                calTaxVal = (Math.round(calTaxVal * 100) / 100).toFixed(2);
                amtWithTaxVal = parseFloat(calTaxVal) + parseFloat(this.invoiceItemList[i].amt);
                if(this.chosenParentTaxOption === 'Inclusive of Tax') amtWithTaxVal = parseFloat(this.invoiceItemList[i].amt);
            }
            ////console.log("calTaxVal ==> "+calTaxVal);
            ////console.log("amtWithTaxVal ==> "+amtWithTaxVal);
            this.invoiceItemList[i].taxAmt = calTaxVal;
            this.invoiceItemList[i].amtWithTax = amtWithTaxVal;
        }
       // ////console.log('Changed tax value = '+this.invoiceItemList[i].tax);

        this.reCalculateSubTaxInfoMap(false);
    }

    onExistingPdtOptionChange(event){
        ////console.log("Inside the onExistingPdtOptionChange");
        ////console.log("event ",event);
        ////console.log("event.index",event.target.dataset.index);
        ////console.log("event.value ",event.target.value);

        let i = event.target.dataset.index;
        if(event.target.value == '_new_'){
            ////console.log("Inside the if cond");
            this.invoiceItemList[i].isKnownPdt = false;
        }else{
            this.invoiceItemList[i].isKnownPdt = true;
            this.invoiceItemList[i].pdtDraftName = null;
        }
        this.invoiceItemList[i].pdtId = event.target.value;
    }

    onExistingPdtNameChange(event){
        ////console.log("Inside the onExistingPdtNameChange");
        ////console.log("event ",event);
        ////console.log("event.index",event.target.dataset.index);
        ////console.log("event.value ",event.target.value);

        let i = event.target.dataset.index;
        this.invoiceItemList[i].pdtDraftName = event.target.value;
    }
 
    onExistingPdtQtyChange(event){
        ////console.log("Inside the onExistingPdtQtyChange");
        ////console.log(JSON.stringify(this.invoiceItemList));
        ////console.log("this.invoiceItemList.length "+ this.invoiceItemList.length);
        ////console.log("event ",event);
        ////console.log("event.index",event.target.dataset.index);
        ////console.log("event.value ",event.target.value);
        ////console.log("event.index New = ",event.currentTarget.dataset.index);
        ////console.log("event.value New = ",event.currentTarget.value);

        let i = event.target.dataset.index;
        this.invoiceItemList[i].qty = event.target.value == '' ? null : event.target.value;
        var tempRate = this.invoiceItemList[i].rate ? this.invoiceItemList[i].rate : 0;
        if(tempRate) { 
            var tempQty = this.invoiceItemList[i].qty ? this.invoiceItemList[i].qty : 0;
            this.invoiceItemList[i].amt = (tempQty * tempRate).toFixed(2);
            ////console.log('amt: ',this.invoiceItemList[i].amt);

            var taxFloat = 0;
            var calTaxVal = 0;
            var amtWithTaxVal = 0;
            if(this.chosenParentTaxOption === 'Out of scope of Tax'  || !this.invoiceItemList[i].tax || this.invoiceItemList[i].tax == ''){
                calTaxVal = 0;
                amtWithTaxVal = parseFloat(this.invoiceItemList[i].amt);
            }else{
                ////console.log(this.invoiceItemList[i].tax.replace('%',''));
                taxFloat = parseFloat(this.invoiceItemList[i].tax.replace('%',''));
                calTaxVal = this.invoiceItemList[i].amt * (taxFloat / 100);
                calTaxVal = (Math.round(calTaxVal * 100) / 100).toFixed(2);
                amtWithTaxVal = parseFloat(calTaxVal) + parseFloat(this.invoiceItemList[i].amt);
                if(this.chosenParentTaxOption === 'Inclusive of Tax') amtWithTaxVal = parseFloat(this.invoiceItemList[i].amt);
            }
            ////console.log("calTaxVal ==> "+calTaxVal);
            ////console.log("amtWithTaxVal ==> "+amtWithTaxVal);
            this.invoiceItemList[i].taxAmt = calTaxVal;
            this.invoiceItemList[i].amtWithTax = amtWithTaxVal;
            this.invoiceItemList[i].taxAmount = this.calculateLineItemTaxAmount(this.invoiceItemList[i]);
            this.taxAmount = this.invoiceItemList[i].taxAmount;
            this.reCalculateSubTaxInfoMap(false);
        }
    }

    onExistingPdtRateChange(event){
        ////console.log("Inside the onExistingPdtRateChange");
        ////console.log("this.invoiceItemList.length = "+this.invoiceItemList.length);
        ////console.log("event ",event);
        ////console.log("event.index",event.target.dataset.index);
        ////console.log("event.value ",event.target.value);

        let i = event.target.dataset.index;
        ////console.log('Inside the IF cond');
        this.invoiceItemList[i].rate = event.target.value == '' ? null : event.target.value;

        //this.invoiceItemList[i].qty = this.invoiceItemList[i].qty ? this.invoiceItemList[i].qty : 0;
        var tempQty = this.invoiceItemList[i].qty ? this.invoiceItemList[i].qty : 0;
        ////console.log('tax: ',this.invoiceItemList[i].tax);
        if(tempQty) { // && this.invoiceItemList[i].tax
            var tempRate = this.invoiceItemList[i].rate ? this.invoiceItemList[i].rate : 0;
            ////console.log('Inside the 2nd IF cond');
            this.invoiceItemList[i].amt = (tempQty * tempRate).toFixed(2);
            ////console.log('amt: ',this.invoiceItemList[i].amt);
            var taxFloat = 0;
            var calTaxVal = 0;
            var amtWithTaxVal = 0;
            if(this.chosenParentTaxOption === 'Out of scope of Tax' || !this.invoiceItemList[i].tax || this.invoiceItemList[i].tax == ''){
                calTaxVal = 0;
                amtWithTaxVal = parseFloat(this.invoiceItemList[i].amt);
            }else{
                ////console.log(this.invoiceItemList[i].tax.replace('%',''));
                taxFloat = parseFloat(this.invoiceItemList[i].tax.replace('%',''));
                calTaxVal = this.invoiceItemList[i].amt * (taxFloat / 100);
                calTaxVal = (Math.round(calTaxVal * 100) / 100).toFixed(2);
                amtWithTaxVal = parseFloat(calTaxVal) + parseFloat(this.invoiceItemList[i].amt);
                if(this.chosenParentTaxOption === 'Inclusive of Tax') amtWithTaxVal = parseFloat(this.invoiceItemList[i].amt);
            }
            ////console.log("calTaxVal ==> "+calTaxVal);
            ////console.log("amtWithTaxVal ==> "+amtWithTaxVal);
            this.invoiceItemList[i].taxAmt = calTaxVal;
            this.invoiceItemList[i].amtWithTax = amtWithTaxVal;
            this.invoiceItemList[i].taxAmount = this.calculateLineItemTaxAmount(this.invoiceItemList[i]);
            this.taxAmount = this.invoiceItemList[i].taxAmount;
            this.reCalculateSubTaxInfoMap(false);
        }
    }



    // onExistingHsnChange(event){
    //     ////console.log("Inside the onExistingHsnChange");
    //     ////console.log("event ",event);
    //     ////console.log("event.index",event.target.dataset.index);
    //     ////console.log("event.value ",event.target.value);

    //     let i = event.target.dataset.index;
    //     ////console.log("Before: ==> hsn:"+this.invoiceItemList[i].hsn+'index = '+i);
    //     this.invoiceItemList[i].hsn = event.target.value;
    //     ////console.log("After: ==> hsn:"+this.invoiceItemList[i].hsn);
    // }
    handleDiscountReasonChange(event){
        ////console.log("Inside the handleDiscountReasonChange");
        ////console.log("event ",event);
        ////console.log("event.index",event.target.dataset.index);
        ////console.log("event.value ",event.target.value);
        let i = event.target.dataset.index;
        ////console.log("Before: ==> discountReason:"+this.invoiceItemList[i].discountReason+'index = '+i);
        this.invoiceItemList[i].discountReason = event.target.value;
        ////console.log("After: ==> discountReason:"+this.invoiceItemList[i].discountReason);
    }

    onExistingServiceDateChange(event){
        ////console.log("Inside the onExistingServiceDateChange");
        ////console.log("event ",event);
        ////console.log("event.index",event.target.dataset.index);
        ////console.log("event.value ",event.target.value);

        let i = event.target.dataset.index;
        ////console.log("Before: ==> serviceDate:"+this.invoiceItemList[i].serviceDate+'index = '+i);
        this.invoiceItemList[i].serviceDate = event.target.value;
        ////console.log("After: ==> serviceDate:"+this.invoiceItemList[i].serviceDate);
    }


    // onExistingDescChange(event){
    //     ////console.log("Inside the onExistingDescChange");
    //     ////console.log("event ",event);
    //     ////console.log("event.index",event.target.dataset.index);
    //     ////console.log("event.value ",event.target.value);

    //     let i = event.target.dataset.index;
    //     ////console.log("Before: ==> description:"+this.invoiceItemList[i].description+'index = '+i);
    //     this.invoiceItemList[i].description = event.target.value;
    //     ////console.log("After: ==> description:"+this.invoiceItemList[i].description);
    // }


    reCalculateSubTaxInfoMap(isFirstExecution){
        ////console.log("Inside the reCalculateSubTaxInfoMap");
        ////console.log('isFirstExecution = '+isFirstExecution);
        ////console.log('this.invoiceItemList.length = ',this.invoiceItemList.length);
        ////console.log('this.subTaxLabelMap.size = ',this.subTaxLabelMap.size);
        let invMap = new Map();
        this.finalSubTaxesInfoMap = new Map();
        this.invoiceItemList.forEach(element => {
            ////console.log("element.tax = "+element.tax);
            if(element.tax){
                var mapRes = this.subTaxLabelMap.get(element.tax);
                var tempTaxNameVal = mapRes ? mapRes.Name : null;
                ////console.log("tempTaxNameVal = ",tempTaxNameVal);
                let tempAmt = parseFloat(invMap.get(tempTaxNameVal));
                if (!tempAmt) tempAmt = 0;
                invMap.set(tempTaxNameVal,tempAmt+ (element.amt ? parseFloat(element.amt) : 0));
            }
        });
        ////console.log("map size = "+invMap.size);

        if(invMap.size <= 0){
            this.finalSubTaxesInfoJson = [];
        }
        const tempMap = new Map(Object.entries(this.allChildTaxInfoResp.data));
        invMap.forEach((invValues,invKeys) => {
            ////console.log("tempMap.keys = "+invKeys);
            var totalAmt = invMap.get(invKeys);
            ////console.log('totalAmt = '+totalAmt);
            let tempSubTotalInt = 0;
        
        // Calculate subtotal with discounts
        for (let i = 0; i < this.invoiceItemList.length; i++) {
            let lineItem = this.invoiceItemList[i];
            let lineAmount = lineItem.amt ? parseFloat(lineItem.amt) : 0;
            
            // Apply discounts if Line Item Discount mode is selected
            if (this.selectedDiscountMode === 'Line Item Discount') {
                if (this.selectedDiscountType === 'Percentage' && lineItem.discountPercentage) {
                    // Calculate discount amount using percentage
                    const discountAmount = lineAmount * (parseFloat(lineItem.discountPercentage) / 100);
                    lineAmount = lineAmount - discountAmount;
                } else if (this.selectedDiscountType === 'Amount' && lineItem.discountAmount) {
                    // Subtract direct discount amount
                    lineAmount = lineAmount - parseFloat(lineItem.discountAmount);
                }
            }
            
            // Add the final line amount (after discount) to subtotal
            tempSubTotalInt += lineAmount;
        }
        if (this.selectedDiscountMode === 'Lumpsum Discount') {
            if (this.selectedDiscountType === 'Percentage' && this.lumpsumDiscountPercentage) {
                const discountAmount = tempSubTotalInt * (parseFloat(this.lumpsumDiscountPercentage) / 100);
                tempSubTotalInt = tempSubTotalInt - discountAmount;
            } else if (this.selectedDiscountType === 'Amount' && this.lumpsumDiscountAmount) {
                tempSubTotalInt = tempSubTotalInt - parseFloat(this.lumpsumDiscountAmount);
            }
        }
        this.calculatedSubTotal1 = tempSubTotalInt.toFixed(2);
            tempMap.forEach((values,keys) => {
                ////console.log("tempMap.keys = "+keys);
                if(invKeys === keys){
                    ////console.log("MATCH FOUND = "+keys);
                    for (let i=0; i < values.length; i++){
                        var label = values[i].Name+' @ '+values[i].Tax_Percentage__c+'% on '+ totalAmt;
                        ////console.log("label ==> "+label);
                        ////console.log("values[i].Tax_Percentage__c = "+values[i].Tax_Percentage__c);
                        var calculatedVal = parseFloat(totalAmt) * (values[i].Tax_Percentage__c / 100);
                        calculatedVal = (Math.round(calculatedVal * 100) / 100).toFixed(2);
                        ////console.log("calculatedVal ==> "+calculatedVal);
                        var tempList = [];
                        let subTaxMapKey = values[i].Name+' @ '+values[i].Tax_Percentage__c+'%';
                        ////console.log("subTaxMapKey ==> "+subTaxMapKey);
                        const subTaxItem = {"Id":label ,"Label":label, "Value":calculatedVal};
                        tempList.push(subTaxItem);
                        this.finalSubTaxesInfoMap.set(subTaxMapKey, tempList);
                    }
                    ////console.log('this.finalSubTaxesInfoMap = '+this.finalSubTaxesInfoMap.size);
                    var newInt=0;
                    this.finalSubTaxesInfoJson = [];
                    this.finalSubTaxesInfoMap.forEach((newValues,newKeys) => {
                        this.finalSubTaxesInfoJson.push(newValues[newInt]);
                    });
                    // ////console.log('this.finalSubTaxesInfoJson = '+this.finalSubTaxesInfoJson.length);
                    // ////console.log('this.finalSubTaxesInfoJson = '+this.finalSubTaxesInfoJson);
                }
            });
        });
        this.calculateSubTotal(isFirstExecution);
    }

    updateRecentChildTaxInfoMap(){
        ////console.log("Inside the updateRecentChildTaxInfoMap");
        ////console.log("selectedLabel = "+this.currentSelectedTaxLabel);
        if(this.invoiceItemList.length <= 0 ){
            return;
        }
        
        // this.prepareInvLabelMap();
        let invMap = new Map();
        this.invoiceItemList.forEach(element => {
            ////console.log("element.tax = "+element.tax);
            ////console.log("Inside the for loop");
            if(element.tax){
                var tempTaxNameVal = this.subTaxLabelMap.get(element.tax).Name;
                ////console.log("tempTaxNameVal = ",tempTaxNameVal);
                let tempAmt = parseFloat(invMap.get(tempTaxNameVal));
                if (!tempAmt) tempAmt = 0;
                invMap.set(tempTaxNameVal,tempAmt+parseFloat(element.amt));
            }
        });
        this.reCalculateSubTaxInfoMap(false);
    }

    

    fetchChildTaxOptions(parentTaxVar){
        ////console.log("Inside the result of fetchChildTaxOptions");
        getChildTaxOptions({
        parentTaxName: parentTaxVar
        })
        .then((result) => {
            ////console.log("Inside the result of getChildTaxOptions");
            ////console.log(result.data);
        })
        .catch((error) => {
            ////console.log("###Error : " + error.body.message);
        });
    }


    get disableAddRowButton(){
        // let disableCondVal = !(this.serviceDate && this.hsn && this.description && this.discountAmount && this.discountPercentage && this.taxAmount && this.qty && (this.qty > 0)
        let disableCondVal = !(this.serviceDate && this.discountReason && this.discountAmount && this.discountPercentage && this.taxAmount && this.qty && (this.qty > 0)
         && this.rate && (this.rate > 0) && this.amt && this.taxCategory && this.taxExemption
         && (this.pdtId && (this.isKnownPdt == true || (this.isKnownPdt == false && this.pdtDraftName)))
         && (this.tax || this.hideSubTaxesSection));
        ////console.log("Inside the disableAddRowButton");
        ////console.log(disableCondVal);
        return disableCondVal;
    }

    get disableCalculateSubTotalButton(){
        return (!(this.invoiceItemList.length > 0) || this.formDisableFlag);
    }

    clearAllRows(){
        this.invoiceItemList = [];
        //this.showSubTotalSection = false;
        this.reCalculateSubTaxInfoMap(false);
        //this.showGrandTotalSection = false;
    }

    get showSubTotalSecConditionally(){
        ////console.log('Inside the showSubTotalSecConditionally');
        ////console.log('this.recordId = '+this.recordId);
        ////console.log('this.isExecutedOnce = '+this.isExecutedOnce);
        if(this.recordId && this.isExecutedOnce){
            ////console.log('In IF');
           return true;
        }else if(!this.recordId){
            ////console.log('In ELSE IF');
            return true;
        }else{
            ////console.log('In ELSE');
            return false;
        }
    }

    calculateSubTotal(isFirstExecution){  
        ////console.log('Inside the calculateSubTotal');
        ////console.log('isFirstExecution = '+isFirstExecution);
        ////console.log(this.invoiceItemList.length);
        let tempSubTotalInt = 0;
        for (let i = 0; i < this.invoiceItemList.length; i++) {
            let lineItem = this.invoiceItemList[i];
            // old let lineAmount = lineItem.amt ? parseFloat(lineItem.amt) : 0;
            let lineAmount = 0;
            if (lineItem.rate && lineItem.qty) {
                lineAmount = parseFloat(lineItem.rate) * parseFloat(lineItem.qty);
            }
            // Apply line item discounts if that mode is selected
            if (this.selectedDiscountMode === 'Line Item Discount') {
                if (this.selectedDiscountType === 'Percentage' && lineItem.discountPercentage) {
                    const discountAmount = lineAmount * (parseFloat(lineItem.discountPercentage) / 100);
                    lineAmount = lineAmount - discountAmount;
                } else if (this.selectedDiscountType === 'Amount' && lineItem.discountAmount) {
                    lineAmount = lineAmount - parseFloat(lineItem.discountAmount);
                }
            }
            
            tempSubTotalInt += lineAmount;
        }
    
        // Apply lumpsum discount if that mode is selected
        if (this.selectedDiscountMode === 'Lumpsum Discount') {
            if (this.selectedDiscountType === 'Percentage' && this.lumpsumDiscountPercentage) {
                const discountAmount = tempSubTotalInt * (parseFloat(this.lumpsumDiscountPercentage) / 100);
                tempSubTotalInt = tempSubTotalInt - discountAmount;
            } else if (this.selectedDiscountType === 'Amount' && this.lumpsumDiscountAmount) {
                tempSubTotalInt = tempSubTotalInt - parseFloat(this.lumpsumDiscountAmount);
            }
        }
        
        // Format the final subtotal to 2 decimal places
        this.calculatedSubTotal = tempSubTotalInt.toFixed(2);
        ////console.log(this.calculatedSubTotal);
        //this.showSubTotalSection = true;
        //this.calculateGrandTotal();
        ////console.log('isFirstExecution = ',isFirstExecution);
        if(isFirstExecution) {
            ////console.log('Inside the necessary if cond');
            this.isExecutedOnce = true;
        }
    }

    deleteCurrentRow(){
        ////console.log('Inside the deleteCurrentRow');
        this.serviceDate = null;
        this.pdtId = null;
        this.isKnownPdt = false;
        this.pdtDraftName = null;
        // this.hsn = null;
        // this.description = null;
        this.discountReason = null;
        this.qty = null;
        this.rate = null;
        this.amt = null;
        this.tax = null;
        this.taxCategory = null;
        this.taxExemption = null;
        this.taxId = null;
        this.currentSelectedTaxLabel = null;
        this.hideInputForPdtSerCurrentRow = true;
        this.discountAmount = null;
        this.taxAmount = null;
        this.discountPercentage = null;
    }

    addNewRow(){
        ////console.log("Inside the addRow");
        ////console.log("Before push length = "+this.invoiceItemList.length);
        //var tempKey = this.invoiceItemList.length > 0 ? (this.invoiceItemList.length - 1) : 0;
        ////console.log('tempKey = '+tempKey);

        var tempInvItem = {
            serviceDate : null,
            pdtId : null,
            isKnownPdt : true,
            pdtDraftName: null,
            // hsn : null,
            // description : null,
            discountReason : null,
            qty : null,
            rate : null,
            amt : null,
            tax : null,
            taxCategory : null,
            taxExemption : null,
            taxLabel : null,
            taxId : null,
            taxAmt: null,
            key:null,
            discountAmount: null,   
            discountPercentage: null,
            taxAmount : null,
            amtWithTax: null
        }


        if(this.invoiceItemList.length > 0) {
            tempInvItem.key = this.invoiceItemList[this.invoiceItemList.length - 1].key + 1;
        } else {
            tempInvItem.key = 1;
        }

        this.invoiceItemList.push(JSON.parse(JSON.stringify(tempInvItem)));
        ////console.log("After push length = "+this.invoiceItemList.length);

    }

    addRow(){
        ////console.log("Inside the addRow");
        ////console.log("Before push length = "+this.invoiceItemList.length);
        ////console.log("isKnownPdt = "+this.isKnownPdt);
        ////console.log("showSubTotalSection = "+this.showSubTotalSection);


        var taxFloat = 0;
        var calTaxVal = 0;
        var amtWithTaxVal = 0;

        if(this.chosenParentTaxOption === 'Out of scope of Tax'){
            calTaxVal = 0;
            amtWithTaxVal = parseFloat(this.amt);
        }else{
            ////console.log(this.tax.replace('%',''));
            taxFloat = this.tax ? parseFloat(this.tax.replace('%','')) : 0;
            calTaxVal = this.amt ? this.amt * (taxFloat / 100) : 0;
            calTaxVal = (Math.round(calTaxVal * 100) / 100).toFixed(2);
            amtWithTaxVal = parseFloat(calTaxVal) + parseFloat(this.amt);
            if(this.chosenParentTaxOption === 'Inclusive of Tax') amtWithTaxVal = this.amt ? parseFloat(this.amt) : 0;
        }

        ////console.log("calTaxVal ==> "+calTaxVal);
        ////console.log("amtWithTaxVal ==> "+amtWithTaxVal);

        var i = this.index;
        this.invItem = {
            serviceDate : this.serviceDate,
            pdtId : this.pdtId,
            isKnownPdt : this.isKnownPdt,
            pdtDraftName: this.pdtDraftName,
            // hsn : this.hsn,
            // description : this.description,
            discountReason : this.discountReason,
            qty : this.qty,
            rate : this.rate,
            amt : this.amt,
            tax : this.tax,
            taxCategory : this.taxCategory,
            taxExemption : this.taxExemption,
            taxLabel : this.currentSelectedTaxLabel,
            taxId : this.taxId,
            taxAmt: calTaxVal,
            key:i,
            discountAmount: this.discountAmount,
            discountPercentage: this.discountPercentage,
            taxAmount : this.taxAmount,
            amtWithTax: amtWithTaxVal
        }
        
        ////console.log('this.serviceDate = '+this.serviceDate+' this.invItem.isKnownPdt = '+this.invItem.isKnownPdt);
        this.invoiceItemList.push(JSON.parse(JSON.stringify(this.invItem)));
        ////console.log("After push length = "+this.invoiceItemList.length);
        ////console.log('1st ',this.invoiceItemList[0].isKnownPdt);
        ////console.log('Last ',this.invoiceItemList[(this.invoiceItemList.length-1)].serviceDate);

        /*if(this.showSubTotalSection){
            ////console.log("Inside the expected if cond");
            this.calculateSubTotal(false);
        }*/
        this.calculateSubTotal(false);

        ////console.log("before calling updateRecentChildTaxInfoMap");
        if(this.chosenParentTaxOption !== 'Out of scope of Tax') this.updateRecentChildTaxInfoMap();

        this.serviceDate = null;
        this.pdtId = null;
        this.isKnownPdt = false;
        this.pdtDraftName = null;
        // this.hsn = null;
        // this.description = null;
        this.discountReason = null;
        this.qty = null;
        this.rate = null;
        this.amt = null;
        this.tax = null;
        this.taxId = null;
        this.taxCategory = null;
        this.taxExemption = null;
        this.currentSelectedTaxLabel = null;
        this.hideInputForPdtSerCurrentRow = true;
        this.discountAmount = null;
        this.discountPercentage = null;
        this.taxAmount = null;
        this.index++;
    }

    removeRow(event){
        ////console.log("Inside removeRow");
        ////console.log("Before this.invoiceItemList.length = "+this.invoiceItemList.length);
        ////console.log("dataset.id = "+event.target.dataset.id);
        ////console.log("dataset.label = "+event.target.dataset.label);
        ////console.log("dataset.index = "+event.target.dataset.index);
        /*var tempIndex = parseInt(event.target.dataset.index)+1;
        ////console.log("tempIndex = "+tempIndex);*/
        if(this.invoiceItemList.length>1) {
            this.invoiceItemList.splice(event.target.dataset.index, 1);
            ////console.log("After this.invoiceItemList.length = "+this.invoiceItemList.length);
            /*if(this.showSubTotalSection){
                this.calculateSubTotal(false);
            }*/
            this.calculateSubTotal(false);
        }
        else if(this.invoiceItemList.length==1) {
            this.invoiceItemList=[];
            //this.showSubTotalSection = false;
        }
        
        this.reCalculateSubTaxInfoMap(false);
    } 

    removeRowNew(event) {
        ////console.log('Inside the removeRowNew');
        ////console.log(event);
        let toBeDeletedRowKey = event.target.dataset.key;
        console.log('Before invoiceItemList length = '+this.invoiceItemList.length);
        console.log('Before invoiceItemList length = '+this.invoiceItemList);

        let invoiceItemListTemp = [];
        for(let i = 0; i < this.invoiceItemList.length; i++) {
            let tempRecord = Object.assign({}, this.invoiceItemList[i]); //cloning object
            ////console.log(tempRecord);
            ////console.log('tempRecord.key = ',tempRecord.key+' & toBeDeletedRowKey = ',toBeDeletedRowKey);
            ////console.log('typeof tempRecord.key',typeof tempRecord.key);
            ////console.log('typeof toBeDeletedRowKey',typeof toBeDeletedRowKey);
            if(tempRecord.key != toBeDeletedRowKey) {
                ////console.log('Inside the push logic ');
                invoiceItemListTemp.push(tempRecord);
            }else{
                ////console.log('Inside the else logic ');
            }
        }
        ////console.log('invoiceItemListTemp length = '+invoiceItemListTemp.length);
        for(let i = 0; i < invoiceItemListTemp.length; i++) {
            invoiceItemListTemp[i].key = i + 1;
        }

        this.invoiceItemList = invoiceItemListTemp;
        this.reCalculateSubTaxInfoMap(false);
        ////console.log('After invoiceItemList length = '+this.invoiceItemList.length);
        ////console.log('End of Method');
    }
    


    // @wire(getObjectInfo, { objectApiName: ACCOUNT_OBJECT })
    // accountInfo;

    // @wire(getPicklistValues,
    //     {
    //         recordTypeId: '$accountInfo.data.defaultRecordTypeId',
    //         fieldApiName: BillingCountryCode
    //     }
    // )
    // listOfCountries;

    
    handleCountryChange(event){
        ////console.log(this.listOfCountries.data);
        ////console.log(event);
        ////console.log('Inside the handleCountryChange');
        this.selectedCountry = event.target.value;
        ////console.log('selectedCountry = '+this.selectedCountry);
    }

    handleAuthChange(event){
        ////console.log(this.listOfCountries.data);
        ////console.log(event);
        ////console.log('Inside the handleCountryChange');
        this.authroizedSignature = event.target.value;
       // //console.log('authroizedSignature = '+this.authroizedSignature);
    }
    

    handleValueSelectedOnAccount(event) {
        // //console.log("Inside the handleValueSelectedOnAccount");
        // //console.log(event);
        ////console.log(JSON.parse(JSON.stringify(event.detail)));
        this.parentAccountSelectedRecord = event.detail;
        this.billingAddress = this.parentAccountSelectedRecord.subField;
        //this.currencyCode = this.parentAccountSelectedRecord.additionalField;
        if(this.parentAccountSelectedRecord.additionalField){
            const myArray = this.parentAccountSelectedRecord.additionalField.split("-");
            this.currencyCode = myArray[0];
            this.currencyCodeName = myArray[1];
        }
        ////console.log(this.parentAccountSelectedRecord);
        ////console.log("this.parentAccountSelectedRecord.id = "+this.parentAccountSelectedRecord.id);
        ////console.log(this.parentAccountSelectedRecord.mainField);
        ////console.log(this.parentAccountSelectedRecord.subField);
    }
    handleAccValRemoval(event){
        ////console.log("Inside the handleAccValRemoval");
        ////console.log(event);
        ////console.log(event.detail);
        //this.parentAccountSelectedRecord = event.detail;
        this.parentAccountSelectedRecord.mainField = null;
        this.parentAccountSelectedRecord.subField = null;
        this.parentAccountSelectedRecord.id = null;
        this.parentAccountSelectedRecord.additionalField = null;
        ////console.log("this.parentContactSelectedRecord",JSON.parse(JSON.stringify(this.parentContactSelectedRecord)));
        //this.parentContactSelectedRecord = null;
        this.parentContactSelectedRecord.mainField = null;
        this.parentContactSelectedRecord.subField = null;
        this.parentContactSelectedRecord.id = null;
        // this.primaryContactEmail = null;
        this.currencyCode = null;
    }

    handleValueSelectedOnContact(event) {
        ////console.log("Inside the handleValueSelectedOnContact");
        ////console.log(event);
        this.parentContactSelectedRecord = event.detail;
        ////console.log("this.parentContactSelectedRecord",JSON.parse(JSON.stringify(this.parentContactSelectedRecord)));
        ////console.log(this.parentContactSelectedRecord.id);
        ////console.log(this.parentContactSelectedRecord.mainField);
        ////console.log("this.parentContactSelectedRecord.subField = "+this.parentContactSelectedRecord.subField);
        this.primaryContactEmail = this.parentContactSelectedRecord.subField;
    }
    handleConValRemoval(){
        ////console.log("Inside the handleConValRemoval");
        ////console.log(event);
        //this.parentContactSelectedRecord = event.detail;
        this.parentContactSelectedRecord.mainField = null;
        this.parentContactSelectedRecord.subField = null;
        this.parentContactSelectedRecord.id = null;
        this.primaryContactEmail = null;
    }

    get parentTaxOptions(){
        return [
            { label:"Exclusive of Tax", value:"Exclusive of Tax" },
            { label:"Inclusive of Tax", value:"Inclusive of Tax" },
            { label:"Out of scope of Tax", value:"Out of scope of Tax" }
        ];
    }

    ccBccSecOnClose(){
        ////console.log("Inside the ccBccSecOnClose");
        ////console.log("this.ccEmailAddressesStr = ",this.ccEmailAddressesStr);
        ////console.log("this.bccEmailAddressesStr = ",this.bccEmailAddressesStr);
        this.showCcBccSec = !this.showCcBccSec;
    }

    ccBccSecCancel(){
        ////console.log("Inside the ccBccSecCancel");
        this.showCcBccSec = !this.showCcBccSec;
    }

    ccBccSecDone(){
        ////console.log("Inside the ccBccSecDone");
        ////console.log("this.ccEmailAddressesStr = ",this.ccEmailAddressesStr);
        ////console.log("this.bccEmailAddressesStr = ",this.bccEmailAddressesStr);
        if(this.isInputValid()) {
            ////console.log('Inside the isInputValid cond');
            this.ccEmailAddressesStr = this.tempCcEmailAddressesStr;
            this.bccEmailAddressesStr = this.tempBccEmailAddressesStr;
            let tempCCListStr = this.ccEmailAddressesStr ? this.ccEmailAddressesStr.replace(' ','') : null;
            this.ccListLength = tempCCListStr ? JSON.parse(JSON.stringify(tempCCListStr.split(','))).length : 0;
            ////console.log("tempCCListStr = ",tempCCListStr);
            ////console.log("this.ccListLength = ",this.ccListLength);
            let tempBCCListStr = this.bccEmailAddressesStr ? this.bccEmailAddressesStr.replace(' ','') : null;
            this.bccListLength = tempBCCListStr ? JSON.parse(JSON.stringify(tempBCCListStr.split(','))).length : 0;
            ////console.log("tempBCCListStr = ",tempBCCListStr);
            ////console.log("this.bccListLength = ",this.bccListLength);
            ////console.log("ALL THE INPUTS ARE VALID");
            this.showCcBccSec = !this.showCcBccSec;
        }
        
    }

    isInputValid() {
        ////console.log("Inside the isInputValid method");
        let isValid = true;
        ////console.log(this.template);
        let inputFields = this.template.querySelectorAll('.ccBccInputSec');
        ////console.log(inputFields);
        inputFields.forEach(inputField => {
            ////console.log('Inside the foreach ',inputField);
            ////console.log('inputField.checkValidity() = ',inputField.checkValidity());
            if(!inputField.checkValidity()) {
                inputField.reportValidity();
                isValid = false;
            }
        });
        return isValid;
    }

    updateContactEmailList(event){
        ////console.log("Inside the updateContactEmailList");
        this.primaryContactEmail = event.target.value;
        ////console.log("this.primaryContactEmail = ",this.primaryContactEmail);
    }
    updateBillingAddress(event){
        ////console.log("Inside the updateBillingAddress");
        ////console.log(event);
        ////console.log(event.target);
        ////console.log(event.target.value);
        //this.parentAccountSelectedRecord.subField = event.target.value;
        this.billingAddress = event.target.value;
    }

    get disableSaveButton(){
        ////console.log("Inside the disableSaveButton");
        let disableFlag = false;
        ////console.log("this.parentAccountSelectedRecord.id = ",this.parentAccountSelectedRecord.id);
        ////console.log("this.parentContactSelectedRecord.id = ",this.parentContactSelectedRecord.id);
        ////console.log("this.primaryContactEmail = ",this.primaryContactEmail);
        ////console.log("this.ccEmailAddressesStr = ",this.ccEmailAddressesStr);
        ////console.log("this.bccEmailAddressesStr = ",this.bccEmailAddressesStr);
        ////console.log("this.parentAccountSelectedRecord.subField = ",this.parentAccountSelectedRecord.subField);
        ////console.log("this.chosenTerm = ",this.chosenTerm); 
        ////console.log("this.invoiceDate = ",this.invoiceDate); 
        ////console.log("this.dueDate = ",this.dueDate); 
        ////console.log("this.selectedCountry = ",this.selectedCountry); 
        ////console.log("this.chosenParentTaxOption = ",this.chosenParentTaxOption); 
        ////console.log("this.invoiceItemList.length = ",this.invoiceItemList.length); 
        ////console.log("this.msgOnInv = ",this.msgOnInv); 
        ////console.log("this.msgOnStmt = ",this.msgOnStmt);
        disableFlag = !(
            (this.parentAccountSelectedRecord.id != null && this.parentAccountSelectedRecord.id != undefined  && this.parentAccountSelectedRecord.id != '') &&
            (this.parentContactSelectedRecord.id != null && this.parentContactSelectedRecord.id != undefined  && this.parentContactSelectedRecord.id != '') &&
            (this.primaryContactEmail != null && this.primaryContactEmail != undefined && this.primaryContactEmail != '') &&
            (this.billingAddress != null && this.billingAddress != undefined && this.billingAddress != '') &&
            (this.chosenTerm != null && this.chosenTerm != undefined && this.chosenTerm != '') &&
            (this.invoiceDate != null && this.invoiceDate != undefined && this.invoiceDate != '') &&
            (this.dueDate != null && this.dueDate != undefined && this.dueDate != '') &&
            (this.selectedCountry != null && this.selectedCountry != undefined && this.selectedCountry != '') &&
            (this.authroizedSignature != null && this.authroizedSignature != undefined && this.authroizedSignature != '') &&
            (this.chosenParentTaxOption != null && this.chosenParentTaxOption != undefined && this.chosenParentTaxOption != '') &&
            (this.invoiceItemList.length != null && this.invoiceItemList.length != undefined && this.invoiceItemList.length > 0) &&
            (this.msgOnInv != null && this.msgOnInv != undefined && this.msgOnInv != '') &&
            (this.termsAndCond != null && this.termsAndCond != undefined && this.termsAndCond != '') &&
            (this.msgOnStmt != null && this.msgOnStmt != undefined && this.msgOnStmt != '')       
            );

        ////console.log(" Before forloop disableFlag = ",disableFlag);

        if(disableFlag) return disableFlag;

        ////console.log("this.invoiceItemList.length = ",this.invoiceItemList.length);
        for (let i = 0; i < this.invoiceItemList.length; i++) {
            ////console.log('this.invoiceItemList[i].serviceDate = '+this.invoiceItemList[i].serviceDate);
            let serviceCond = (this.invoiceItemList[i].serviceDate != null 
                    && this.invoiceItemList[i].serviceDate != undefined && this.invoiceItemList[i].serviceDate != '');
            let pdtIdCond = (this.invoiceItemList[i].pdtId != null 
                    && this.invoiceItemList[i].pdtId != undefined && this.invoiceItemList[i].pdtId != '');
            /*let isKnownPdtCond = (this.invoiceItemList[i].isKnownPdt != null 
                    && this.invoiceItemList[i].isKnownPdt != undefined && this.invoiceItemList[i].isKnownPdt != '');*/
            let pdtDraftNameCond = (this.invoiceItemList[i].isKnownPdt == true ||
                (this.invoiceItemList[i].isKnownPdt == false && 
                    this.invoiceItemList[i].pdtDraftName != null && this.invoiceItemList[i].pdtDraftName != undefined 
                    && this.invoiceItemList[i].pdtDraftName != ''));
            // let hsnCond = (this.invoiceItemList[i].hsn != null 
            //         && this.invoiceItemList[i].hsn != undefined && this.invoiceItemList[i].hsn != '');
            // let descriptionCond = (this.invoiceItemList[i].description != null 
            //         && this.invoiceItemList[i].description != undefined && this.invoiceItemList[i].description != '');
            let discountReasonCond = (this.invoiceItemList[i].discountReason != null
                    && this.invoiceItemList[i].discountReason != undefined && this.invoiceItemList[i].discountReason != '');
            let discountAmtCond = (this.invoiceItemList[i].discountAmount != null
                    && this.invoiceItemList[i].discountAmount != undefined && this.invoiceItemList[i].discountAmount != '');
            let discountPercCond = (this.invoiceItemList[i].discountPercentage != null
                    && this.invoiceItemList[i].discountPercentage != undefined && this.invoiceItemList[i].discountPercentage != '');
            let taxAmtCond = (this.invoiceItemList[i].taxAmount != null
                    && this.invoiceItemList[i].taxAmount != undefined && this.invoiceItemList[i].taxAmount != '');
            let qtyCond = (this.invoiceItemList[i].qty != null 
                    && this.invoiceItemList[i].qty != undefined && this.invoiceItemList[i].qty != '' 
                    && this.invoiceItemList[i].qty > 0);
            let rateCond = (this.invoiceItemList[i].rate != null 
                    && this.invoiceItemList[i].rate != undefined && this.invoiceItemList[i].rate != '' 
                    && this.invoiceItemList[i].rate > 0);
            let amtCond = (this.invoiceItemList[i].amt != null 
                    && this.invoiceItemList[i].amt != undefined && this.invoiceItemList[i].amt != '' 
                    && this.invoiceItemList[i].amt > 0);
            let taxCond = (this.invoiceItemList[i].tax != null 
                    && this.invoiceItemList[i].tax != undefined && this.invoiceItemList[i].tax != '');
            let taxCategoryCond = (this.invoiceItemList[i].taxCategory != null
                    && this.invoiceItemList[i].taxCategory != undefined && this.invoiceItemList[i].taxCategory != '');
            let taxExemptionCond = (this.invoiceItemList[i].taxExemption != null
                    && this.invoiceItemList[i].taxExemption != undefined && this.invoiceItemList[i].taxExemption != '');
            let taxLabelCond = (this.invoiceItemList[i].taxLabel != null 
                    && this.invoiceItemList[i].taxLabel != undefined && this.invoiceItemList[i].taxLabel != '');
            let taxIdCond = (this.invoiceItemList[i].taxId != null 
                    && this.invoiceItemList[i].taxId != undefined && this.invoiceItemList[i].taxId != '');
            let wholeTaxCond = (this.chosenParentTaxOption === 'Out of scope of Tax' || 
                (this.chosenParentTaxOption !== 'Out of scope of Tax' && taxCond && taxLabelCond && taxIdCond));

            if(disableFlag == false){
                ////console.log("Inside the disableFlag false cond");
                ////console.log('1.serviceDate = '+this.invoiceItemList[i].serviceDate +' cond:'+serviceCond);
                ////console.log('2.pdtId = '+this.invoiceItemList[i].pdtId +' cond:'+pdtIdCond);
                ////console.log('3.isKnownPdt = '+this.invoiceItemList[i].isKnownPdt +' cond:'+isKnownPdtCond);
                ////console.log('3.pdtDraftName = '+this.invoiceItemList[i].pdtDraftName +' cond:'+pdtDraftNameCond);
                ////console.log('4.hsn = '+this.invoiceItemList[i].hsn +' cond:'+hsnCond);
                ////console.log('5.description = '+this.invoiceItemList[i].description +' cond:'+descriptionCond);
                ////console.log('6.qty = '+this.invoiceItemList[i].qty +' cond:'+qtyCond);
                ////console.log('7.rate = '+this.invoiceItemList[i].rate+' cond:'+rateCond);
                ////console.log('8.amt = '+this.invoiceItemList[i].amt+' cond:'+amtCond);
                ////console.log('9.tax = '+this.invoiceItemList[i].tax +' cond:'+taxCond);
                ////console.log('10.taxLabel = '+this.invoiceItemList[i].taxLabel +' cond:'+taxLabelCond);
                ////console.log('11.taxId = '+this.invoiceItemList[i].taxId +' cond:'+taxIdCond);
                ////console.log('12.wholeTaxCond = '+this.invoiceItemList[i].chosenParentTaxOption +' cond:'+wholeTaxCond);

                // disableFlag = !(serviceCond && pdtIdCond && pdtDraftNameCond && hsnCond && descriptionCond
                disableFlag = !(serviceCond && pdtIdCond && pdtDraftNameCond && discountReasonCond && taxCategoryCond && taxExemptionCond
                    && qtyCond && rateCond && amtCond && wholeTaxCond && discountAmtCond && discountPercCond && taxAmtCond);

            }else{
                ////console.log("Inside the disableFlag true cond");
                return disableFlag
            }
            ////console.log("Inside forloop  disableFlag = ",disableFlag);
        }
        
        ////console.log("OutSide of forloop disableFlag = ",disableFlag);
        return disableFlag;
    }

    saveAndSendAction() {
        if (!this.validateTaxesForLumpsumDiscount()) {
            return;
        }
        this.sendEmailFlag = true;
        //console.log('Inside the saveAndSendAction');
        this.checkboxjournalflag;
        this.saveAction()
            .then(() => {
                //console.log('Inside the saveAndSendAction');
                //return this.createJournalEntry();
            })
            .catch(error => {
                //console.error('Error in saveAction:', error);
                // Handle error (e.g., show a toast message)
            });
    }

    saveAction() {
        if (!this.validateTaxesForLumpsumDiscount()) {
            return;
        }
      //  //console.log("Inside the saveAction");
        return new Promise((resolve, reject) => {
        var taxVal = 0;
            if (this.chosenParentTaxOption === "Inclusive of Tax" || this.chosenParentTaxOption === "Exclusive of Tax") {
            ////console.log('Inside the if cond');
                for (let i = 0; i < this.finalSubTaxesInfoJson.length; i++) {
                ////console.log('Inside the for cond');
                taxVal = taxVal + parseFloat(this.finalSubTaxesInfoJson[i].Value);
                ////console.log("taxVal ===> "+taxVal);
            }
        } 
        ////console.log("Before objWrap preparation step");  

        let finalInvItemList = [];
        ////console.log("Before this.invoiceItemList.length = ",this.invoiceItemList.length);
        for (let i = 0; i < this.invoiceItemList.length; i++) {
            var serviceDateCond = (this.invoiceItemList[i].serviceDate != null 
                    && this.invoiceItemList[i].serviceDate != undefined && this.invoiceItemList[i].serviceDate != '');
            var pdtIdCond = (this.invoiceItemList[i].pdtId != null 
                    && this.invoiceItemList[i].pdtId != undefined && this.invoiceItemList[i].pdtId != '');
            var pdtDraftNameCond = (this.invoiceItemList[i].pdtDraftName != null && this.invoiceItemList[i].pdtDraftName != undefined 
                    && this.invoiceItemList[i].pdtDraftName != '');
            // var hsnCond = (this.invoiceItemList[i].hsn != null 
            //         && this.invoiceItemList[i].hsn != undefined && this.invoiceItemList[i].hsn != '');
            // var descriptionCond = (this.invoiceItemList[i].description != null 
            //         && this.invoiceItemList[i].description != undefined && this.invoiceItemList[i].description != '');
            var discountReasonCond = (this.invoiceItemList[i].discountReason != null
                    && this.invoiceItemList[i].discountReason != undefined && this.invoiceItemList[i].discountReason != '');
            var discountAmtCond = (this.invoiceItemList[i].discountAmount != null
                    && this.invoiceItemList[i].discountAmount != undefined && this.invoiceItemList[i].discountAmount != '');
            var discountPercCond = (this.invoiceItemList[i].discountPercentage != null
                    && this.invoiceItemList[i].discountPercentage != undefined && this.invoiceItemList[i].discountPercentage != '');
            var taxAmtCond = (this.invoiceItemList[i].taxAmount != null
                    && this.invoiceItemList[i].taxAmount != undefined && this.invoiceItemList[i].taxAmount != '');
            var qtyCond = (this.invoiceItemList[i].qty != null 
                    && this.invoiceItemList[i].qty != undefined && this.invoiceItemList[i].qty != '' 
                    && this.invoiceItemList[i].qty > 0);
            var rateCond = (this.invoiceItemList[i].rate != null 
                    && this.invoiceItemList[i].rate != undefined && this.invoiceItemList[i].rate != '' 
                    && this.invoiceItemList[i].rate > 0);
            var taxCond = (this.invoiceItemList[i].tax != null 
                    && this.invoiceItemList[i].tax != undefined && this.invoiceItemList[i].tax != '');
            var taxCategoryCond = (this.invoiceItemList[i].taxCategory != null
                    && this.invoiceItemList[i].taxCategory != undefined && this.invoiceItemList[i].taxCategory != '');
            var taxExemptionCond = (this.invoiceItemList[i].taxExemption != null
                    && this.invoiceItemList[i].taxExemption != undefined && this.invoiceItemList[i].taxExemption != '');

            // if(
            //     (this.chosenParentTaxOption !== "Out of scope of Tax" 
            //         && (serviceDateCond || pdtIdCond || pdtDraftNameCond || hsnCond || descriptionCond || qtyCond 
            //             || rateCond || taxCond || discountAmtCond || discountPercCond || taxAmtCond))
            //     || (this.chosenParentTaxOption === "Out of scope of Tax" 
            //         && (serviceDateCond || pdtIdCond || pdtDraftNameCond || hsnCond || descriptionCond || qtyCond 
            //             || rateCond || discountAmtCond || discountPercCond  || taxAmtCond))){
            //             //Having any one of the field value, so have to be saved
            //             ////console.log('Inside the if cond - i '+i);
            //             finalInvItemList.push(this.invoiceItemList[i]);
            //         }
            if(
                (this.chosenParentTaxOption !== "Out of scope of Tax" 
                    && (serviceDateCond || pdtIdCond || pdtDraftNameCond || discountReasonCond || qtyCond || taxCategoryCond
                        || taxExemptionCond || rateCond || taxCond || discountAmtCond || discountPercCond || taxAmtCond))
                || (this.chosenParentTaxOption === "Out of scope of Tax" 
                    && (serviceDateCond || pdtIdCond || pdtDraftNameCond || discountReasonCond || qtyCond || taxCategoryCond
                        || taxExemptionCond || rateCond || discountAmtCond || discountPercCond  || taxAmtCond))){
                        //Having any one of the field value, so have to be saved
                        ////console.log('Inside the if cond - i '+i);
                        finalInvItemList.push(this.invoiceItemList[i]);
                    }
            else{
                ////console.log('Inside the else cond - i '+i);
                //Not having any one of the field value, so have to be removed from invoiceItemList
                //this.invoiceItemList.splice(i, 1);
            }
        }
        ////console.log("After this.invoiceItemList.length = ",this.invoiceItemList.length);
        //  console.log('Finalitems--------->'+JSON.stringify(finalInvItemList));
        let productSerialMapList = [];
        console.log('product making--->'+JSON.stringify(this.invoiceItemList));
        for (let item of this.invoiceItemList) {
        if (
            item.isSerialProduct &&
            item.pdtId &&
            item.selectedSerialNumbers &&
            item.selectedSerialNumbers.length > 0
        ) {
            let stockIds = item.selectedSerialNumbers.map(s => s.value);

                    productSerialMapList.push({
                key: item.key, // <-- include the row's unique key
                        stockIds: stockIds
                    });
                }
            }

            var invStatusVar = null;
            if(!this.recordId){
                invStatusVar = 'Draft';
            }
        
        // //console.log("this.accMdtInfo = "+this.accMdtInfo);
        // //console.log('mdt Name = '+this.accMdtInfo.Name__c);
        console.log('Finallist-------------->'+JSON.stringify(finalInvItemList));
        ////console.log("this.msgOnStmt = "+this.msgOnStmt);
        var invWrapObj = {
            invId:this.recordId,
            invNumber: this.invNumber,
            accId: this.parentAccountSelectedRecord.id,
            conId: this.parentContactSelectedRecord.id,
            primaryConEmailAddresses: this.primaryContactEmail,
            ccEmailAddresses: this.ccEmailAddressesStr,
            bccEmailAddresses: this.bccEmailAddressesStr,
            billingAddress: this.billingAddress,
            term: this.chosenTerm,
            termLabel: this.chosenTermLabel,
            invoiceDate: this.invoiceDate,
            dueDate: this.dueDate,
            placeOfSupply: this.selectedCountry,
            authSign: this.authroizedSignature,
            invoiceType: this.invoiceType,
            invoiceIndicator: this.invoiceIndicator,
            latestDeliveryDate: this.latestDeliveryDate,
            invoiceNameType: this.invoiceNameType,
            paymentType: this.paymentType,
            selectedCurrency:this.selectedCurrency,
            exchangeRate:this.exchangeRate,
            parentTaxSelectedOption: this.chosenParentTaxOption,
            invoiceItemList: finalInvItemList, //this.invoiceItemList,
            msgOnInv: this.msgOnInv,
            termsAndCond: this.termsAndCond,
            msgOnStmt: this.msgOnStmt,
            subTotal: this.calculatedSubTotal,
            total: this.grandTotal,
            balanceDue: this.paidAmount,
            totalTaxAmt: taxVal,
            selectedDiscountMode: this.selectedDiscountMode,
            selectedDiscountType: this.selectedDiscountType,
            //name: 'SampleInv - '+ this.invoiceDate,
            lumpsumDiscountPercentage: this.lumpsumDiscountPercentage,
            lumpsumDiscountAmount: this.lumpsumDiscountAmount,
            lumpsumDiscountReason: this.lumpsumDiscountReason,
            invStatus: invStatusVar,
            companyName: this.companyName,
            currencyCode: this.currencyCode,
            currencyCodeName: this.currencyCodeName
        }

        ////console.log('invWrapObj = ',JSON.stringify(invWrapObj));
        // Validate serial number count for serial-tracked products
        for (let item of finalInvItemList) {
            if (item.isSerialProduct) {
                const qty = parseFloat(item.qty) || 0;
                const selectedSerials = item.selectedSerialNumbers || [];

                if (selectedSerials.length === 0) {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Missing Serial Numbers',
                            message: `Product requires serial numbers, but none are selected.`,
                            variant: 'error'
                        })
                    );
                    reject('No serial numbers selected for serial-tracked product');
                    return;
                }

                if (selectedSerials.length !== qty) {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Serial Number Mismatch',
                            message: `The quantity for product is ${qty}, but ${selectedSerials.length} serial number(s) selected.`,
                            variant: 'error'
                        })
                    );
                    reject('Serial number mismatch');
                    return;
                }
            }
        }


      saveInvoiceRecord({
            invWrap: JSON.stringify(invWrapObj),
             sendEmailFlag: this.sendEmailFlag,
            checkboxjournalflag: this.checkboxjournalflag,
            productSerialMapList: productSerialMapList
        })
        .then((result) => {
            ////console.log("Inside the result of saveInvoiceRecord");
            ////console.log(result);
            let parsedResultant = JSON.parse(result);
            //console.log("parsedResultant ",parsedResultant);
            ////console.log(typeof parsedResultant.successFlag);
            //console.log(typeof parsedResultant.invoiceId);
            //console.log(parsedResultant.invoiceId);
            this.invoicerecordId =parsedResultant.invoiceId;
            //console.log('invoicerecordId---->',this.invoicerecordId);
            if(!parsedResultant.successFlag){
                this.errorMessage = parsedResultant.errorMessage;
                /*LightningPrompt.open({
                    message: this.errorMessage,
                    label: 'Please fill the missing required info',
                }).then((result) => {
                    ////console.log('Result: '+ result);
                });*/

                var tempMsg = this.errorMessage;
                const toastEvent = new ShowToastEvent({
                    title:'Failure!',
                    message:tempMsg,
                    variant:'error'
                    //mode:'sticky'
                });

                this.dispatchEvent(toastEvent);


            }else if(parsedResultant.successFlag && parsedResultant.invoiceId){
                //console.log('Record created successfully:', JSON.stringify(parsedResultant.invoiceId));
                var tempMsg = this.recordId ? 'Record updated successfully' : 'Record created successfully';
                const toastEvent = new ShowToastEvent({
                    title:'Success!',
                    message:tempMsg,
                    variant:'success'
                });
                this.dispatchEvent(toastEvent);

                ////console.log('Inside the elseIf cond');
                //Start Navigation
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: parsedResultant.invoiceId,
                        objectApiName: 'Invoice__c',
                        actionName: 'view'
                    },
                });
                resolve(parsedResultant.invoiceId);
                //End Navigation
            }
        })
        .catch((error) => {
            ////console.log("###Error : " + error.body.message);
        });
        this.sendEmailFlag = false;


            // saveInvoiceRecord({ invWrap: JSON.stringify(this.invWrapObj), sendEmailFlag: this.sendEmailFlag })
            //     .then(result => {
            //         //console.log('Invoice saved successfully:', result);
            //         resolve();
            //     })
            //     .catch(error => {
            //         //console.error('Error saving invoice:', error);
            //         reject(error);
            //     });
        });
    }

    validateInvoice() {
        console.log('Inside the validateInvoice');
        console.log('this.invoicerecordId = ',this.invoicerecordId);   
        // this.invoicerecordIdValid = this.invoicerecordId;
        
        validateInvoiceRecord({ invoiceId: String(this.invoicerecordId) })
            .then(response => {
                console.log('Validation Successful:', response);
                
                this.showToast('Validation Successful!', 'Invoice data validated successfully.', 'success');
            })
            .catch(error => {
                this.showToast('Validation Failed!', error.body.message, 'error');
            });
    }

    validateAndSave() {
        console.log('Inside the validateAndSave');
        
        this.saveAction()
            .then((invoiceId) => {
                console.log('abdullah');
                console.log('Result:', invoiceId);
                // this.invoiceIdNew = invoiceId;
                this.validateInvoice();
            })
            .catch(error => {
                this.showToast('Error', error.body.message, 'error');
            });
    }

    clearance() {
        console.log('Inside the clearance');
        console.log('invoicerecordId = ',this.recordId);
        
        clearanceInvoice({ invoiceId: this.recordId })
            .then(response => {
                console.log('Clearance Successful:', response);
                this.showToast('Clearance Successful!', 'Invoice cleared successfully.', 'success');
                location.reload();
            })
            .catch(error => {
                this.showToast('Clearance Failed!', error.body.message, 'error');
            });
    }

    showToast(title, message, variant) {
        const toastEvent = new ShowToastEvent({
            title,
            message,
            variant
        });
        this.dispatchEvent(toastEvent);
    }

    msgOnStmtOnChange(event){
        ////console.log("Inside the msgOnStmtOnChange");
        ////console.log(event);
        ////console.log("event.target.value = "+event.target.value);
        this.msgOnStmt = event.target.value;
        ////console.log("this.msgOnStmt = ",this.msgOnStmt);
    }


    msgOnInvOnChange(event){
        ////console.log("Inside the msgOnInvOnChange");
        ////console.log(event);
        ////console.log("event.target.value = "+event.target.value);
        this.msgOnInv = event.target.value;
        ////console.log("this.msgOnInv = ",this.msgOnInv);
    }


    termsAndCondOnChange(event){
      //  //console.log("Inside the termsAndCondOnChange");
      //  //console.log(event);
        ////console.log("event.target.value = "+event.target.value);
        this.termsAndCond = event.target.value;
      //  //console.log("this.termsAndCond = ",this.termsAndCond);
    }
  

    emailViewCnt(event){
        
          this.EmailViewCount = event.target.value;
        //  //console.log("this.termsAndCond = ",this.termsAndCond);
      }

    ccOnChange(event){
        ////console.log("Inside the ccOnChange");
        ////console.log(event);
        ////console.log("event.target.value = "+event.target.value);
        this.tempCcEmailAddressesStr = event.target.value;
        ////console.log("this.tempCcEmailAddressesStr = ",this.tempCcEmailAddressesStr);
    }

    bccOnChange(event){
        ////console.log("Inside the bccOnChange");
        ////console.log(event);
        ////console.log("event.target.value = "+event.target.value);
        this.tempBccEmailAddressesStr = event.target.value;
        ////console.log("this.tempBccEmailAddressesStr = ",this.tempBccEmailAddressesStr);
    }

    ccBccSecOnClick(){
        ////console.log("Inside the ccBccSecOnClick");
        this.showCcBccSec = !this.showCcBccSec;
    }

    insertBefore(newNode, existingNode) {
        ////console.log("Inside the insertBefore");
        existingNode.parentNode.insertBefore(newNode, existingNode.nextSibling);
    }

    handleParentTaxChange(event){
        ////console.log("Inside the handleParentTaxChange method");
        ////console.log("Previous this.chosenParentTaxOption = "+this.chosenParentTaxOption);
        /*if(this.chosenParentTaxOption === "Out of scope of Tax"){ //"Out of scope of Tax" to another tax option change
            this.clearAllRows();
            this.chosenParentTaxOption = event.detail.value;
            return;
        }*/
        this.chosenParentTaxOption = event.detail.value;
        ////console.log("After this.chosenParentTaxOption = "+this.chosenParentTaxOption);
        ////console.log("this.chosenParentTaxOption = "+this.chosenParentTaxOption);
        if(this.chosenParentTaxOption){
            ////console.log("First if cond");
            //this.showGrandTotalSection = true;
            if(this.chosenParentTaxOption === 'Out of scope of Tax'){
                ////console.log("First if cond");
                this.hideSubTaxesSection = true;
                for (let i = 0; i < this.invoiceItemList.length; i++) {
                    this.invoiceItemList[i].taxAmt = 0;
                    this.invoiceItemList[i].amtWithTax = parseFloat(this.invoiceItemList[i].amt);
                }
            }else{
                ////console.log("else cond");
                this.hideSubTaxesSection = false;
                for (let i = 0; i < this.invoiceItemList.length; i++) {
                    this.invoiceItemList[i].taxAmt = 0;
                    this.invoiceItemList[i].amtWithTax = this.invoiceItemList[i].amt;
                    if(this.invoiceItemList[i].amt && this.invoiceItemList[i].tax){
                        var taxFloat = 0;
                        var calTaxVal = 0;
                        var amtWithTaxVal = 0;
                        ////console.log(this.invoiceItemList[i].tax.replace('%',''));
                        taxFloat = parseFloat(this.invoiceItemList[i].tax.replace('%',''));
                        calTaxVal = this.invoiceItemList[i].amt * (taxFloat / 100);
                        calTaxVal = (Math.round(calTaxVal * 100) / 100).toFixed(2);
                        amtWithTaxVal = parseFloat(calTaxVal) + parseFloat(this.invoiceItemList[i].amt);
                        if(this.chosenParentTaxOption === 'Inclusive of Tax') amtWithTaxVal = parseFloat(this.invoiceItemList[i].amt);
                        ////console.log("calTaxVal ==> "+calTaxVal);
                        ////console.log("amtWithTaxVal ==> "+amtWithTaxVal);
                        this.invoiceItemList[i].taxAmt = calTaxVal;
                        this.invoiceItemList[i].amtWithTax = amtWithTaxVal;
                    }
                }
            }
        }
        this.calculateSubTotal(false);
        //this.calculateGrandTotal();
    }

    /*calculateGrandTotal(){
        ////console.log("Inside the calculateGrandTotal method");
        this.grandTotal = 0.00;
        if(this.chosenParentTaxOption === "Inclusive of Tax" || this.chosenParentTaxOption === "Out of scope of Tax"){
            this.grandTotal = this.calculatedSubTotal;
        }else if(this.chosenParentTaxOption === "Exclusive of Tax"){
            for(let i=0; i<this.finalSubTaxesInfoJson.length; i++){
                ////console.log("Value ===> "+this.finalSubTaxesInfoJson[i].Value);
                this.grandTotal = this.grandTotal + (this.finalSubTaxesInfoJson[i].Value ? parseFloat(this.finalSubTaxesInfoJson[i].Value) : 0);
            }
            this.grandTotal = parseFloat(this.calculatedSubTotal) + this.grandTotal;
            this.grandTotal = (Math.round(this.grandTotal * 100) / 100).toFixed(2);
            ////console.log("this.grandTotal ===> "+this.grandTotal);
        }else{
            //this.showGrandTotalSection = false;
        }
    }*/

    get grandTotal(){
        ////console.log("Inside the grandTotal");
        let gt = 0.00;
        if(this.chosenParentTaxOption === "Inclusive of Tax" || this.chosenParentTaxOption === "Out of scope of Tax"){
            gt = this.calculatedSubTotal;
        }else if(this.chosenParentTaxOption === "Exclusive of Tax"){
            
            gt = parseFloat(this.calculatedSubTotal) + parseFloat(this.calculatedTaxAmount || 0);

            gt = (Math.round(gt * 100) / 100).toFixed(2);
            ////console.log("gt ===> "+gt);
        }else{
           gt = null;
        }
        return gt;
    }
    get balanceDue(){
        ////console.log("Inside the grandTotal");
        let gt = 0.00;
        if(this.chosenParentTaxOption === "Inclusive of Tax" || this.chosenParentTaxOption === "Out of scope of Tax"){
            gt = this.calculatedSubTotal;
            ////console.log('this.paidAmount'+this.paidAmount);
            
            gt = gt-(this.paidAmount==undefined ||this.paidAmount==''? 0:this.paidAmount);
            gt = (gt >0 ? gt:0.00);
            gt = (Math.round(gt * 100) / 100).toFixed(2);
        }else if(this.chosenParentTaxOption === "Exclusive of Tax"){
            
            gt = parseFloat(this.calculatedSubTotal) + parseFloat(this.calculatedTaxAmount || 0);
            gt = (Math.round(gt * 100) / 100).toFixed(2);
            
           // //console.log("gt ===> "+gt);
        }else{
           gt = null;
        }
        return gt;
    }

   

    handleTermsChange(event){
            ////console.log("Inside the handleTermsChange method");
            this.chosenTerm = event.detail.value;
            this.chosenTermLabel = event.target.options.find(opt => opt.value === event.detail.value).label;
            
            if (this.invoiceDate !== null) {
                var data_out = new Date(this.invoiceDate);
                let dateInMS = data_out.setDate(data_out.getDate() + parseInt(this.chosenTerm));
                var data_out_02 = new Date(dateInMS);
                this.dueDate = data_out_02.toISOString().substring(0, 10); //NEW
                //OLD: this.dueDate = data_out_02.toLocaleDateString('en-us', { year:"numeric", month:"short", day:"numeric"});
                //ERRORED: this.dueDate = new Date(new Date().setDate(data_out.getDate() + parseInt(this.chosenTerm))).toISOString().substring(0, 10);
            }


        }

    invoiceDateChange(event){
        ////console.log("Inside the invoiceDateChange method");
        this.invoiceDate = event.target.value;

        if (this.chosenTerm !== null) {
            var data_out = new Date(this.invoiceDate);
            let dateInMS = data_out.setDate(data_out.getDate() + parseInt(this.chosenTerm));
            var data_out_02 = new Date(dateInMS);

            //Sol #1 - with WeekDay value - Fri, Jul 2, 2021
            //this.dueDate = data_out_02.toDateString();

            // Sol #2 - with WeekDay long value - "Friday, Jul 2, 2021"
            ////console.log(data_out_02.toLocaleDateString('en-us', { weekday:"long", year:"numeric", month:"short", day:"numeric"}));

             // Sol #3 - Expected sol - Jul 2, 2021 - 'MMM D, YYYY' format - But onSave throwing error due to invalid format
            ////console.log(data_out_02.toLocaleDateString('en-us', { year:"numeric", month:"short", day:"numeric"}));
            //this.dueDate = data_out_02.toLocaleDateString('en-us', { year:"numeric", month:"short", day:"numeric"});

            // Sol #4 - Expected sol - Jul 2, 2021 - 'MMM D, YYYY' format - errored onSave
            //this.dueDate = new Date(new Date().setDate(data_out.getDate() + parseInt(this.chosenTerm))).toISOString().substring(0, 10);

            // Sol #5 - Expected sol - Jul 2, 2021 - 'MMM D, YYYY' format - success onSave
            this.dueDate = data_out_02.toISOString().substring(0, 10); //NEW

        }

    }

    //Call this method from your .html file
    openVisualForcePage(event) 
    {
        //this.previewPdfFlag = true;
        this.vfPageURLToPreview = '/apex/InvoicePdf?id='+this.recordId;
       // this.vfPageURLToPreview = '/apex/InvoicePdf?id='+this.recordId;
        this.isGreyedOut = true;
        this.popupDivStyle = "position:absolute;height:50%;width:50%;margin-top:-"+window.innerHeight+"px;margin-left:"+(window.innerWidth / 4)+"px;";
        /*const urlWithParameters = '/apex/InvoicePdf?id='+this.recordId;
        ////console.log('urlWithParameters...'+urlWithParameters);
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: urlWithParameters
            }
        }, false); //if you set true this will opens the new url in same window*/

    }

    get mainFrameClass(){
        var classText = this.isGreyedOut ? 'slds-m-around_medium greyed-out': 'slds-m-around_medium';
        return classText;
    }

    hideModalBox() {  
        this.isGreyedOut = false;
        this.vfPageURLToPreview = null;
    }

    // @track validateChecked = false;
    // @track clearanceChecked = false;

    // // Computed property for Validate button disabled state
    // get isValidateDisabled() {
    //     return this.validateChecked || this.formDisableFlag;
    // }

    // // Computed property for Clearance button disabled state
    // get isClearanceDisabled() {
    //     return !this.validateChecked || this.clearanceChecked || this.formDisableFlag;
    // }

    // validateInvoice() {
    //     console.log('Inside the validateInvoice');
    //     console.log('this.invoicerecordId = ',this.invoicerecordId);   
        
    //     validateInvoiceRecord({ invoiceId: String(this.invoicerecordId) })
    //         .then(response => {
    //             console.log('Validation Response:', response);
    //             console.log('Response Status Code:', response.statusCode);
                
    //             if (response) {
    //                 // Update validate checkbox
    //                 updateInvoiceValidation({ 
    //                     invoiceId: this.invoicerecordId, 
    //                     isValidated: true 
    //                 })
    //                 .then(() => {
    //                     this.validateChecked = true;
    //                     this.showToast('Validation Successful!', 'Invoice data validated successfully.', 'success');
    //                     // automatic refresh after 1 second
    //                     setTimeout(() => {
    //                         location.reload();
    //                     }, 1000);
    //                 })
    //                 .catch(error => {
    //                     console.error('Error updating validation status:', error);
    //                     this.showToast('Error', 'Failed to update validation status', 'error');
    //                 });
    //             }
    //         })
    //         .catch(error => {
    //             this.showToast('Validation Failed!', error.body.message, 'error');
    //         });
    // }

    // clearance() {
    //     console.log('Inside the clearance');
    //     console.log('invoicerecordId = ',this.recordId);
        
    //     clearanceInvoice({ invoiceId: this.recordId })
    //         .then(response => {
    //             console.log('Clearance Response:', response);
                
    //             if (response && response.statusCode === 200) {
    //                 // Update clearance checkbox
    //                 updateInvoiceClearance({ 
    //                     invoiceId: this.recordId, 
    //                     isCleared: true 
    //                 })
    //                 .then(() => {
    //                     this.clearanceChecked = true;
    //                     this.showToast('Clearance Successful!', 'Invoice cleared successfully.', 'success');
    //                     // location.reload();
    //                     setTimeout(() => {
    //                         location.reload();
    //                     }, 1000);
    //                 })
    //                 .catch(error => {
    //                     console.error('Error updating clearance status:', error);
    //                     this.showToast('Error', 'Failed to update clearance status', 'error');
    //                 });
    //             }
    //         })
    //         .catch(error => {
    //             this.showToast('Clearance Failed!', error.body.message, 'error');
    //         });
    // }

    // @wire(getRecord, { recordId: '$invoicerecordId', fields: ['Invoice__c.Validate__c', 'Invoice__c.Clearance__c'] })
    // wiredInvoice({ error, data }) {
    //     if (data) {
    //         this.validateChecked = data.fields.Validate__c.value;
    //         this.clearanceChecked = data.fields.Clearance__c.value;
    //     } else if (error) {
    //         console.error('Error loading invoice:', error);
    //     }
    // }

    // // Update computed properties to also check wired data
    // get isValidateDisabled() {
    //     return this.validateChecked || this.formDisableFlag;
    // }

    // get isClearanceDisabled() {
    //     return !this.validateChecked || this.clearanceChecked || this.formDisableFlag;
    // }
}