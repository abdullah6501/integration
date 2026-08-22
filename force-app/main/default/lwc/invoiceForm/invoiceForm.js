/*
SNO     Date           createdBy                      LastModifiedBy            Description             
1       17/05/2025     Abdul Riyan                       -                      Invoice newly created
2       03/07/2025                                    Mohamed Abdul Kadher      Bug fix for invoice
*/

import { LightningElement, track, wire, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

import getAccBankInfo from "@salesforce/apex/InvoiceFormController.getAccBankInfo";
import getInvoiceFormData from "@salesforce/apex/InvoiceFormController.getInvoiceFormData";
import createTaxDetailRecords from '@salesforce/apex/InvoiceFormController.createTaxDetailRecords';
import getAllChildTax from '@salesforce/apex/InvoiceFormController.getAllChildTax';
import saveInvoiceRecord from "@salesforce/apex/InvoiceFormController.saveInvoiceRecord";
//import emailViewCount from "@salesforce/apex/InvoiceFormController.emailViewCount";
import getAuthList from '@salesforce/apex/InvoiceFormController.getAuthList';
import getPicklistValue from '@salesforce/apex/InvoiceFormController.getPicklistValue';
import getNslog from '@salesforce/apex/InvoiceFormController.getNslog';

//Added by mohamed abdul kadher for dynamic table starts 
import getTableFieldMetadata from '@salesforce/apex/TableFieldConfigUtility.getTableFieldMetadata';
import taxOptions from '@salesforce/apex/TaxUtility.getParentTaxes';
//Added by mohamed abdul kadher for dynamic table Ends 

import processBusinessEvent from '@salesforce/apex/JEEventService.processBusinessEvent';

export default class InvoiceForm extends NavigationMixin(LightningElement) {

    //Added by mohamed abdul kadher for dynamic table starts 
    @track tableFieldMetadata = [];
    @track taxOptions = [];
    @track isDataLoaded = false;
    @track itemList = [];
    @track lumpsumDiscountAmount = 0;
    @track lumpsumDiscountPercentage = 0;
    @api recordId;
    @api invoiceId;
    @track showPopup = false;
    // @track serialNumber = '';
    @track searchKey = '';
    @track selectedSerialNumbers = [];
    @track searchResults = [];
    @track activeRowIndex;
    @track activeProductId;
    // Discount related properties
    @track showCcBccPopup = false;
    @track ccEmailAddressesStr = '';
    @track bccEmailAddressesStr = '';
    @track tempCcEmailAddressesStr = '';
    @track tempBccEmailAddressesStr = '';
    @track ccListLength = 0;
    @track bccListLength = 0;
    @track isDiscountEnabled = false;
    @track selectedDiscountMode = '';
    @track selectedDiscountType = '';
    @track discountOptions = [];
    @track discountTypeOptions = [];
    @track checkboxjournalflag = false;
    // Store original metadata for field restoration
    @track originalTableFieldMetadata = [];
    @track autComboBoxList = [];
    @track selectedCurrency;
    @track exchangeRate = '1';
    @track currencyoptions = [];
    @track termsOptions = [];
    @track supplyOption = [];
    @track parentAccountSelectedRecord = [];
    @track parentContactSelectedRecord = [];
    @track ccListLength = 0;
    @track bccListLength = 0;
    @track showCcBccSec = false;
    @track invoiceDate;
    @track taxDetails = [];
    @track chosenTerm;
    @track chosenTermLabel;
    @track dueDate;
    @track invoiceDate = new Date().toISOString().substring(0, 10);
    @track dueDate = new Date(new Date().setDate(new Date().getDate() + 15)).toISOString().substring(0, 10);
    @track authroizedSignature;
    @track companyName = null;
    @track redirectToView = 'Invoice__c';
    @track accOtherFieldApi = 'Preferred_Currency_Code__c';
    @track conAdditionalField = 'Gender__c';
    // @track checkboxValue = false;
    @track invWrapObj = {};
    @track spinnerFlag = true;
    @track chosenParentTaxOption = 'Inclusive of Tax';
    @track totalwithTax = 0.00;
    currencyField = 'Currency__c';
    termField = 'Term__c';
    billingAddress;
    currencyCode;
    currencyCodeName;
    primaryContactEmail;
    tempCcEmailAddressesStr;
    tempBccEmailAddressesStr;
    selectedCountry;
    showCcBccSec = false;
    msgOnInv = null;
    msgOnStmt = null;
    termsAndCond = null;
    componentName = 'Invoice__c';
    taxOptionsLoaded = false;
    discountModeField = 'Discount_Mode__c';
    discountTypeField = 'Discount_Type__c';
    saveDisableFlag = false;
    sendEmailFlag = false;
    objectProduct = 'Product__c';
    formDisableFlag = false;

    @wire(taxOptions)
    wiredTaxOptions({ error, data }) {
        if (data) {
            this.taxOptions = data.map(option => ({
                label: option.parentTaxName,
                value: option.parentTaxName,
                percentage: option.parentTaxPercentage,
                fullData: option
            }));
            //this.checkDataReady();
            this.taxOptionsLoaded = true;
            this.getTableFieldMetadata();
        } else if (error) {
            console.error('Parent - Error fetching tax options:', error);
            this.taxOptions = [];
        }
    }

    getDropdownOptions() {
        return this.taxOptions.map(t => ({
            label: t.label,
            value: t.fullData.parentTaxId
        }));
    }


    getTableFieldMetadata() {
        return new Promise((resolve, reject) => {
            if (!this.taxOptionsLoaded) {
                return resolve(); // or reject if it's critical
            }

            getTableFieldMetadata({ componentName: this.componentName })
                .then(result => {
                    if (result) {
                        try {
                            const sortedData = [...result].sort((a, b) => parseInt(a.order) - parseInt(b.order));
                            const processedData = sortedData.map(field => {
                                const baseField = {
                                    ...field,
                                    style: field.width ? `width:${field.width}` : 'width:100px',
                                    fieldType: this.getFieldType(field.dataType),
                                    value: '',
                                    isDropdown: field.dataType === 'Dropdown',
                                    isText: field.dataType === 'Text',
                                    isLookup: field.dataType === 'Lookup',
                                    isNumber: field.dataType === 'Number',
                                    isDate: field.dataType === 'Date',
                                    isProduct: field.dataType === 'Product',
                                    options: field.dataType === 'Dropdown' ? this.getDropdownOptions() : [],
                                    isSerialProduct: false,
                                    selectedSerialNumbers: [],
                                    tempSelectedSerials: [],
                                    showSerialSearch: false,
                                    productDetails: null
                                };

                                if (field.dataType === 'Product') {
                                    return {
                                        ...baseField,
                                        additionFieldApiName: '',
                                        iconName: 'standard:product',
                                        objectApiName: this.objectProduct,
                                        objectLabel: 'Product',
                                        otherFieldApiName: ''
                                    };
                                }

                                return baseField;
                            });

                            this.tableFieldMetadata = processedData;

                            if (this.originalTableFieldMetadata.length === 0) {
                                this.originalTableFieldMetadata = JSON.parse(JSON.stringify(processedData));
                            }

                            this.applyDiscountFieldFiltering();
                            this.notifyChildOfMetadataChange();
                            this.isDataLoaded = true;
                            resolve();
                        } catch (e) {
                            console.error('Parent - Error processing table metadata:', e);
                            this.tableFieldMetadata = [];
                            reject(e);
                        }
                    } else {
                        this.tableFieldMetadata = [];
                        resolve();
                    }
                })
                .catch(error => {
                    console.error('Parent - Error loading table metadata:', error);
                    this.tableFieldMetadata = [];
                    reject(error);
                });
        });
    }

    async transformInvoiceRows(rawDataRows) {
        await this.getTableFieldMetadata();

        return rawDataRows.map((row, rowIndex) => {
            const newRow = {
                invItemId: row.invItemId || this.generateTempId(),
                rowNumber: rowIndex + 1,
                fields: this.tableFieldMetadata
                    .filter(metaField => {
                        if ((metaField.fieldAPI === 'Tax__c' || metaField.fieldAPI === 'Tax_Amount__c') &&
                            this.chosenParentTaxOption === 'Out of scope of Tax') {
                            return false;
                        }
                        return true;
                    })
                    .map(metaField => {
                        const inputField = row.fields.find(f => f.fieldAPI === metaField.fieldAPI);
                        const value = inputField?.value || '';

                        let mergedField = { ...metaField, value };

                        if (metaField.dataType === 'Product') {
                            mergedField.productDetails = inputField?.productDetails || null;
                            mergedField.isSerialProduct = inputField?.isSerialProduct ||
                                inputField?.productDetails?.serialNumberFlag ||
                                false;

                            // Handle serial numbers
                            mergedField.selectedSerialNumbers = inputField?.selectedSerialNumbers || [];
                            mergedField.tempSelectedSerials = inputField?.tempSelectedSerials || [];
                            mergedField.showSerialSearch = inputField?.showSerialSearch || false;

                            // Ensure serial numbers have both label and value
                            if (mergedField.selectedSerialNumbers.length > 0) {
                                mergedField.selectedSerialNumbers = mergedField.selectedSerialNumbers.map(serial => ({
                                    label: serial.label || serial.value || '',
                                    value: serial.value || serial.label || ''
                                }));
                            }
                        }

                        return mergedField;
                    })
            };
            return newRow;
        });
    }

    getFieldType(dataType) {
        switch (dataType) {
            case 'Date':
                return 'date';
            case 'Number':
                return 'number';
            case 'Email':
                return 'email';
            case 'Phone':
                return 'tel';
            case 'Dropdown':
                return 'combobox';
            case 'Url':
                return 'url';
            default:
                return 'text';
        }
    }

    handleTableDataUpdate(event) {
        // Handle data updates from child component
        const tableData = event.detail.tableData;
        //console.log('abdul',JSON.stringify(tableData))
        const tableevent = new CustomEvent('parenttabledataupdate', {
            detail: { tableData }
        });
        this.dispatchEvent(tableevent);
        this.childHandler(tableevent);
    }
    //Added by mohamed abdul kadher for dynamic table Ends 

    // Apply discount field filtering based on current selection
    applyDiscountFieldFiltering() {

        if (!this.originalTableFieldMetadata || this.originalTableFieldMetadata.length === 0) {
            return;
        }

        // Clone original metadata
        let filteredMetadata = JSON.parse(JSON.stringify(this.originalTableFieldMetadata));

        // Filter discount fields based on current selection
        filteredMetadata = filteredMetadata.filter(field => {

            if (field.fieldAPI === 'Tax__c' || field.fieldAPI === 'Tax_Amount__c') {
                return this.chosenParentTaxOption !== 'Out of scope of Tax';
            }
            // Keep all non-discount fields                       
            if (field.fieldAPI !== 'Discount_Percentage__c' &&
                field.fieldAPI !== 'Discount_Amount__c') { // FIXED: Correct field API name
                return true;
            }

            // Show discount fields based on selection and discount enabled state
            if (!this.isDiscountEnabled) {
                return false; // Hide both if discount is not enabled
            }

            // Show Discount Amount if type is Amount      
            if (this.selectedDiscountType === 'Amount' &&
                field.fieldAPI === 'Discount_Amount__c' && this.selectedDiscountMode !== 'Lumpsum Discount') { // FIXED: Correct field API name
                return true;
            }

            // Show Discount Percentage if type is Percentage
            if (this.selectedDiscountType === 'Percentage' &&
                field.fieldAPI === 'Discount_Percentage__c' && this.selectedDiscountMode !== 'Lumpsum Discount') {
                return true;
            }

            return false;
        });

        this.tableFieldMetadata = filteredMetadata;
        this.notifyChildOfMetadataChange();
    }

    notifyChildOfMetadataChange() {
        // Use setTimeout to ensure DOM is updated
        setTimeout(() => {
            const tableCreatorComponent = this.template.querySelector('c-table-creator');
            if (tableCreatorComponent) {
                tableCreatorComponent.handleMetadataChange();
            }
        }, 0);
    }


    handleDiscountToggle(event) {
        this.isDiscountEnabled = event.target.checked;

        // Reset discount selections if disabled
        if (!this.isDiscountEnabled) {
            this.selectedDiscountMode = '';
            this.selectedDiscountType = '';
        }

        // Update field visibility when discount is toggled
        this.applyDiscountFieldFiltering();
    }

    handleDiscountMode(event) {
        this.selectedDiscountMode = event.detail.value;
        this.applyDiscountFieldFiltering();
    }

    handleDiscountType(event) {
        this.selectedDiscountType = event.detail.value;

        // Update field visibility when discount type changes
        this.applyDiscountFieldFiltering();
    }

    handleCheckboxChange(event) {
        this.checkboxjournalflag = event.target.checked;
    }

    updateContactEmailList(event) {
        this.primaryContactEmail = event.target.value;
    }
    // Method to manually refresh table structure
    refreshTableStructure() {
        this.applyDiscountFieldFiltering();
    }


    // Getter for visible field count
    get visibleFieldCount() {
        return this.tableFieldMetadata.length;
    }

    // Method to get current discount field info
    getCurrentDiscountFieldInfo() {
        const info = {
            discountEnabled: this.isDiscountEnabled,
            discountMode: this.selectedDiscountMode,
            discountType: this.selectedDiscountType,
            visibleDiscountField: null
        };

        if (this.isDiscountEnabled) {
            if (this.selectedDiscountType === 'Amount') {
                info.visibleDiscountField = 'Discount_Amount__c';
            } else if (this.selectedDiscountType === 'Percentage') {
                info.visibleDiscountField = 'Discount_Percentage__c';
            }
        }

        return info;
    }
    //discount Ends

    @wire(getNslog)
    managedNamespacewire({ error, data }) {
        if (data) {
            this.objectProduct = data.nameSpace != 'null' ? data.nameSpace + this.objectProduct : this.objectProduct;
            this.currencyField = data.nameSpace != 'null' ? data.nameSpace + this.currencyField : this.currencyField;
            this.termField = data.nameSpace != 'null' ? data.nameSpace + this.termField : this.termField;
            this.discountModeField = data.nameSpace != 'null' ? data.nameSpace + this.discountModeField : this.discountModeField;
            this.discountTypeField = data.nameSpace != 'null' ? data.nameSpace + this.discountTypeField : this.discountTypeField;
            this.redirectToView = data.nameSpace != 'null' ? data.nameSpace + this.redirectToView : this.redirectToView;
            this.accOtherFieldApi = data.nameSpace != 'null' ? data.nameSpace + this.accOtherFieldApi : this.accOtherFieldApi;
            this.conAdditionalField = data.nameSpace != 'null' ? data.nameSpace + this.conAdditionalField : this.conAdditionalField;
        }
    }
    @wire(getAuthList)
    wiredMetadata({ error, data }) {
        if (data) {
            this.autComboBoxList = data.map((record) => ({
                label: record.MasterLabel,
                value: record.MasterLabel
            }));
        }
    }

    @wire(getAccBankInfo)
    wiredAccBankInfo({ error, data }) {
        if (data) {
            const placeOfSupply = data.placeOfSupply;
            if (placeOfSupply) {
                this.supplyOption = placeOfSupply
                    .split(',')
                    .map(item => item.trim())
                    .filter(item => item)
                    .map(val => ({ label: val, value: val }));
            }
            if (data.termsAndCondition) {
                this.termsAndCond = data.termsAndCondition;
            }
            if (data.name) {
                this.companyName = data.name;
            }
        } else if (error) {
            console.error('Error loading place of supply values', error);
        }
    }

    get parentTaxOptions() {
        return [
            { label: "Exclusive of Tax", value: "Exclusive of Tax" },
            { label: "Inclusive of Tax", value: "Inclusive of Tax" },
            { label: "Out of scope of Tax", value: "Out of scope of Tax" }
        ];
    }

    handleParentTaxChange(event) {
        this.chosenParentTaxOption = event.detail.value;
        // this.applyTaxFiltering(this.chosenParentTaxOption);
        this.applyDiscountFieldFiltering();
    }
    updateBillingAddress(event) {
        this.billingAddress = event.target.value;
    }

    handleCurrencyChange(event) {
        this.selectedCurrency = event.detail.value;
        const myArray = this.selectedCurrency.split("-");
        this.currencyCode = myArray[0];
        this.currencyCodeName = myArray[1];
    }

    handleExchangeRateChange(event) {
        this.exchangeRate = event.detail.value;
    }
    handleTermsChange(event) {
        this.chosenTerm = event.detail.value;
        this.chosenTermLabel = event.target.options.find(opt => opt.value === event.detail.value).label;

        if (this.invoiceDate !== null) {
            var data_out = new Date(this.invoiceDate);
            let termNumber = parseInt(this.chosenTerm.replace(/[^\d]/g, ''));
            let dateInMS = data_out.setDate(data_out.getDate() + termNumber);
            var data_out_02 = new Date(dateInMS);
            this.dueDate = data_out_02.toISOString().substring(0, 10);
        }
    }

    invoiceDateChange(event) {
        this.invoiceDate = event.target.value;

        if (this.chosenTerm) {
            var data_out = new Date(this.invoiceDate);
            let termNumber = parseInt(this.chosenTerm.replace(/[^\d]/g, ''));
            let dateInMS = data_out.setDate(data_out.getDate() + termNumber);
            var data_out_02 = new Date(dateInMS);
            // const dueDate = new Date(this.invoiceDate);
            // dueDate.setDate(dueDate.getDate() + parseInt(this.chosenTerm));
            // this.dueDate = dueDate.toISOString().substring(0, 10);
            this.dueDate = data_out_02.toISOString().substring(0, 10);
        }
    }

    handleValueSelectedOnAccount(event) {
        this.parentAccountSelectedRecord = event.detail;
        this.billingAddress = this.parentAccountSelectedRecord.subField;

        if (this.parentAccountSelectedRecord.additionalField) {
            const myArray = this.parentAccountSelectedRecord.additionalField.split("-");
            this.currencyCode = myArray[0];
            this.currencyCodeName = myArray[1];
        }
    }

    handleValueSelectedOnContact(event) {
        this.parentContactSelectedRecord = event.detail;
        this.primaryContactEmail = this.parentContactSelectedRecord.subField;
    }

    handleAccValRemoval(event) {
        this.parentAccountSelectedRecord.mainField = null;
        this.parentAccountSelectedRecord.subField = null;
        this.parentAccountSelectedRecord.id = null;
        this.parentAccountSelectedRecord.additionalField = null;
        this.parentContactSelectedRecord.mainField = null;
        this.parentContactSelectedRecord.subField = null;
        this.parentContactSelectedRecord.id = null;
        this.currencyCode = null;
    }
    handleCountryChange(event) {
        this.selectedCountry = event.target.value;
    }

    handleAuthChange(event) {
        this.authroizedSignature = event.target.value;
    }


    msgOnInvOnChange(event) {
        this.msgOnInv = event.target.value;
    }

    msgOnStmtOnChange(event) {
        this.msgOnStmt = event.target.value;
    }

    termsAndCondOnChange(event) {
        this.termsAndCond = event.target.value;
    }

    emailViewCnt(event) {
        this.EmailViewCount = event.target.value;
    }

    closeAction() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: redirectToView,
                actionName: 'list'
            }
        });
    }

    // handleCheckboxChange(event) {
    //     this.checkboxValue = event.target.checked;
    // }

    connectedCallback() {
        getPicklistValue({
            fieldApiName: this.discountModeField,
        })
            .then(data => {
                this.discountoptions = data.map(label => ({ label, value: label }));
            })
            .catch(error => {
                console.error('Error fetching tax picklist values:', error);
            });

        getPicklistValue({
            fieldApiName: this.discountTypeField
        })
            .then(data => {
                this.discountTypeoptions = data.map(label => ({ label, value: label }));
            })
            .catch(error => {
                console.error('Error fetching discount mode picklist values:', error);
            });

        getPicklistValue({
            fieldApiName: this.currencyField
        })
            .then(data => {
                this.currencyoptions = data.map(label => ({ label, value: label }));
            })
            .catch(error => {
                console.error('Error fetching discount type picklist values:', error);
            });
        getPicklistValue({
            fieldApiName: this.termField
        })
            .then(data => {
                this.termsOptions = data.map(label => ({ label, value: label }));
            })
            .catch(error => {
                console.error('Error fetching discount type picklist values:', error);
            });

        if (this.recordId) {
            this.loadInvoiceData(this.recordId);
        }
    }

    async saveAction() {
        console.log('Save button click');
        this.saveDisableFlag = true;
        try {
            this.spinnerFlag = false;
            console.log('abdul itemList`', (this.itemList))
            console.log('abdul tableRows', (this.tableRows))
            const ItemListFieldMapping = this.itemList?.tableRows?.map(row => {
                const item = {};
                item.invItemId = row.invItemId;
                item.totalAmountwithGST = this.totalwithTax;

                // Extract values from the fields array
                row.fields.forEach(field => {
                    const valueStr = field.value?.toString().trim() || '';
                    // Map field values based on fieldAPI
                    switch (field.fieldAPI) {
                        case 'Service_Date__c':
                            item.serviceDate = field.value;
                            break;
                        case 'Product1__c':
                            item.pdtId = field.value;
                            if (field.selectedSerialNumbers && field.selectedSerialNumbers.length > 0) {
                                item.serialNumbers = field.selectedSerialNumbers.map(serial => {
                                    if (typeof serial === 'object' && serial.label) {
                                        return {
                                            label: serial.label,
                                            value: serial.label,
                                            id: serial.id || null
                                        };
                                    } else if (typeof serial === 'string') {
                                        return {
                                            label: serial,
                                            value: serial,
                                            id: null
                                        };
                                    }
                                    return null;
                                }).filter(serial => serial !== null);
                            }
                            break;
                        case 'HsnSac__c':
                            item.hsn = field.value;
                            break;
                        case 'Description__c':
                            item.description = field.value;
                            break;
                        case 'Quantity__c':
                            item.qty = parseFloat(field.value) || 0;
                            break;
                        case 'Rate__c':
                            item.rate = parseFloat(field.value) || 0;
                            break;
                        case 'Amount__c':
                            item.amt = parseFloat(field.value) || 0;
                            break;
                        case 'Tax__c':
                            item.taxId = field.value;
                            break;
                        case 'Tax_Amount__c':
                            item.taxAmount = parseFloat(field.value) || 0;
                            break;
                        case 'Discount_Amount__c':
                            item.discountAmount = parseFloat(field.value) || 0;
                            break;
                        case 'Discount_Percentage__c':
                            item.discountPercentage = parseFloat(field.value) || 0;
                            break;
                    }
                });
                return item;
            })?.filter(item => {
                return (
                    item.serviceDate ||
                    item.pdtId ||
                    item.description ||
                    item.qty !== 0 ||
                    item.rate !== 0 ||
                    item.amt !== 0
                );
            }) || [];

            this.invWrapObj = {
                invId: this.recordId || '',
                name: '',
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
                selectedCurrency: this.selectedCurrency,
                exchangeRate: this.exchangeRate,
                msgOnInv: this.msgOnInv,
                msgOnStmt: this.msgOnStmt,
                termsAndCond: this.termsAndCond,
                companyName: this.companyName,
                currencyCode: this.selectedCurrency,
                currencyCodeName: this.currencyCodeName,
                selectedDiscountType: this.selectedDiscountType,
                selectedDiscountMode: this.selectedDiscountMode,
                lumpsumDiscountPercentage: this.lumpsumDiscountPercentage,
                lumpsumDiscountAmount: this.lumpsumDiscountAmount,
                parentTaxSelectedOption: this.chosenParentTaxOption,
                invoiceItemList: ItemListFieldMapping
            };

            console.log('invWrapObj structure:', this.invWrapObj);
            console.log('Sending to Apex:', JSON.stringify(this.invWrapObj));


            // FIXED: Add await here to wait for the Promise to resolve
            const result = await saveInvoiceRecord({
                invWrap: JSON.stringify(this.invWrapObj),
                sendEmailFlag: this.sendEmailFlag,
                checkboxjournalflag: this.checkboxjournalflag
            });

            console.log('Raw result from Apex:', result);
            console.log('Type of result:', typeof result);

            // Now result should be a string, not a Promise
            const response = JSON.parse(result);
            console.log('Parsed response:', response);

            if (response.successFlag) {
                this.showToast('Success', 'Invoice saved successfully', 'success');
                this.recordId = response.invoiceId;

                try {
                    await createTaxDetailRecords({
                        taxDetailsList: this.taxDetails,
                        invoiceId: this.recordId
                    });
                } catch (error) {
                    console.error('Error creating tax details:', error);
                    this.showToast('Warning', 'Invoice saved but tax details creation failed', 'warning');
                }
                if(this.checkboxjournalflag && this.recordId)
                try{
                    await processBusinessEvent({
                        eventName: 'Customer Invoice',
                        recordId: this.recordId,
                        relatedIds: [this.parentAccountSelectedRecord.id]
                    });
                }catch (error) {
                    console.error('Error processing business event:', error);
                    this.showToast('Warning', 'Invoice saved but business event processing failed', 'warning');
                }
                
                // Done By AK - Jun/30/25
                await this.loadInvoiceData(response.invoiceId);
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: response.invoiceId,
                        objectApiName: this.redirectToView,
                        actionName: 'view'
                    },
                });

            } else {
                console.error('Save failed:', response.errorMessage);
                this.showToast('Error', response.errorMessage, 'error');
            }

        } catch (error) {
            console.error('Exception occurred:', error);
            console.error('Error details:', {
                message: error.body?.message || error.message,
                stackTrace: error.stack
            });
            this.showToast('Error', error.body?.message || error.message || 'Unknown error occurred', 'error');
        } finally {
            this.saveDisableFlag = false;
            this.spinnerFlag = true;
        }
    }

    saveAndSendAction() {
        this.formDisableFlag = true;
        this.saveDisableFlag = true;
        this.sendEmailFlag = true; // Set sendEmailFlag to true
        // Similar to saveAction but with sendEmailFlag = true
        this.checkboxjournalflag;
        this.saveAction(true);
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(evt);
    }
    async loadInvoiceData(invoiceId) {
        try {
            if (!invoiceId) return;

            const result = await getInvoiceFormData({ invId: invoiceId });
            console.log('loadinvoice', result)
            const response = JSON.parse(result);

            // this.isDiscountEnabled = true;

            if (response.invWrapObj) {
                const data = response.invWrapObj;

                this.invNumber = data.name;
                this.parentAccountSelectedRecord.id = data.accId;
                this.parentContactSelectedRecord.id = data.conId;
                this.billingAddress = data.billingAddress;
                this.selectedCurrency = data.selectedCurrency;
                if (this.selectedCurrency != null) {
                    const myArray = this.selectedCurrency.split("-");
                    this.currencyCode = myArray[0];
                    this.currencyCodeName = myArray[1];
                }
                this.exchangeRate = data.exchangeRate;
                this.chosenTerm = data.termLabel;
                this.chosenTermLabel = data.termLabel;
                this.invoiceDate = data.invoiceDate;
                this.dueDate = data.dueDate;
                this.selectedCountry = data.placeOfSupply;
                this.authroizedSignature = data.authSign;
                this.msgOnInv = data.msgOnInv;
                this.msgOnStmt = data.msgOnStmt;
                this.termsAndCond = data.termsAndCond;
                this.companyName = data.companyName == null ? this.companyName : data.companyName;
                // this.currencyCode = data.currencyCode;
                // console.log('this.currencyCode', this.currencyCode);
                // this.currencyCodeName = data.currencyCodeName;
                // console.log('this.currencyCodeName', this.currencyCodeName);
                this.selectedDiscountMode = data.selectedDiscountMode;
                this.isDiscountEnabled = data.selectedDiscountMode ? true : false;
                this.selectedDiscountType = data.selectedDiscountType;
                this.lumpsumDiscountAmount = data.lumpsumDiscountAmount;
                this.lumpsumDiscountPercentage = data.lumpsumDiscountPercentage;
                this.chosenParentTaxOption = data.parentTaxSelectedOption;

                // Transform the rows
                const transformedRows = data.invoiceItemList?.tableRows
                    ? await this.transformInvoiceRows(data.invoiceItemList.tableRows)
                    : [];

                this.tableFieldMetadata = {
                    tableRows: transformedRows
                };
                // console.log("this.tableFieldMetadata", JSON.stringify(this.tableFieldMetadata));
                //this.notifyChildOfMetadataChange();


                this.primaryContactEmail = data.primaryConEmailAddresses;
                this.ccEmailAddressesStr = data.ccEmailAddresses;
                this.bccEmailAddressesStr = data.bccEmailAddresses;

                this.ccListLength = this.ccEmailAddressesStr ?
                    this.ccEmailAddressesStr.split(',').length : 0;
                this.bccListLength = this.bccEmailAddressesStr ?
                    this.bccEmailAddressesStr.split(',').length : 0;
                this.formDisableFlag = response.invWrapObj.invStatus == 'Draft' ? false : true;
                this.saveDisableFlag = this.formDisableFlag;
                // if(!this.formDisableFlag){
                //     this.showpdtcolmnfn=true;
                // }
            }
        } catch (error) {
            console.error('Error loading invoice data:', error);
            this.showToast('Error', 'Failed to load invoice data', 'error');
        }
    }

    generateTempId() {
        return Date.now().toString();
    }

    get showLumpsumPercentage() {
        return this.isDiscountEnabled &&
            this.selectedDiscountMode === 'Lumpsum Discount' &&
            this.selectedDiscountType === 'Percentage';
    }

    get showLumpsumAmount() {
        return this.isDiscountEnabled &&
            this.selectedDiscountMode === 'Lumpsum Discount' &&
            this.selectedDiscountType === 'Amount';
    }
    get subtotal() {
        if (!this.itemList || !this.itemList.tableRows) {
            return 0;
        }

        return this.itemList.tableRows.reduce((total, row) => {
            const amountField = row.fields.find(field => field.fieldAPI === 'Amount__c');
            const amount = amountField ? parseFloat(amountField.value) || 0 : 0;
            return total + amount;
        }, 0).toFixed(2);
    }
    
    async childHandler(event) {
        try {
            if (!event?.detail?.tableData) {
                return;
            }
    
            const receivedData = event.detail.tableData;
            if (!receivedData?.tableRows?.length) {
                return;
            }
            
            // Initialize/reset tax details
            this.taxDetails = [];  // Always reset to empty array to avoid duplicates
    
            // Calculate subtotal first to ensure we have a valid value
            const subtotalValue = receivedData.tableRows.reduce((total, row) => {
                const amountField = row.fields.find(field => field.fieldAPI === 'Amount__c');
                const amount = amountField ? parseFloat(amountField.value) || 0 : 0;
                return total + amount;
            }, 0);
    
            // Calculate lumpsum discount if applicable
            let lumpsumDiscountValue = 0;
            if (this.isDiscountEnabled && this.selectedDiscountMode === 'Lumpsum Discount') {
                if (this.selectedDiscountType === 'Amount' && this.lumpsumDiscountAmount > 0) {
                    lumpsumDiscountValue = parseFloat(this.lumpsumDiscountAmount) || 0;
                } else if (this.selectedDiscountType === 'Percentage' && this.lumpsumDiscountPercentage > 0) {
                    lumpsumDiscountValue = (subtotalValue * (parseFloat(this.lumpsumDiscountPercentage) || 0)) / 100;
                }
            }
    
            const taxCalculationPromises = [];
            
            // Create a temporary array to collect tax details for this specific call
            const currentTaxDetails = [];
    
            // Process each row
            receivedData.tableRows = receivedData.tableRows.map(row => {
                if (!row?.fields) return row;
    
                let quantity = 0, rate = 0, taxId = '', amount = 0;
                let discountAmount = 0, discountPercentage = 0;
    
                // Extract field values with proper null checks
                row.fields.forEach(field => {
                    if (!field?.fieldAPI) return;
    
                    switch (field.fieldAPI) {
                        case 'Quantity__c':
                            quantity = parseFloat(field.value) || 0;
                            break;
                        case 'Rate__c':
                            rate = parseFloat(field.value) || 0;
                            break;
                        case 'Tax__c':
                            taxId = field.value || '';
                            break;
                        case 'Discount_Amount__c':
                            discountAmount = parseFloat(field.value) || 0;
                            break;
                        case 'Discount_Percentage__c':
                            discountPercentage = parseFloat(field.value) || 0;
                            break;
                    }
                });
    
                // Calculate base amount from quantity × rate
                const baseAmount = quantity * rate;
                amount = baseAmount;
                let amountAfterDiscount = baseAmount;
    
                // Apply appropriate discount with proper validation
                if (this.isDiscountEnabled && baseAmount > 0) {
                    if (this.selectedDiscountMode === 'Line Item Discount') {
                        if (discountAmount > 0) {
                            amountAfterDiscount = Math.max(0, baseAmount - discountAmount);
                        } else if (discountPercentage > 0) {
                            const discountValue = (baseAmount * discountPercentage) / 100;
                            amountAfterDiscount = Math.max(0, baseAmount - discountValue);
                        }
                    } else if (this.selectedDiscountMode === 'Lumpsum Discount' && subtotalValue > 0) {
                        // CRITICAL FIX: Ensure subtotalValue is valid before division
                        const discountPerRow = (baseAmount / subtotalValue) * lumpsumDiscountValue;
                        amountAfterDiscount = Math.max(0, baseAmount - discountPerRow);
                    }
                }
    
                // Store the taxable amount (amount after discount) - ensure it's a valid number
                const taxableAmount = isNaN(amountAfterDiscount) ? 0 : Math.max(0, amountAfterDiscount);
    
                // DEBUG: Log the amounts being used
                console.log(`Row ${row.rowNumber} - Base: ${baseAmount}, Taxable: ${taxableAmount}, TaxId: ${taxId}`);
    
                // Update fields with calculated values
                if (Array.isArray(row.fields)) {
                    row.fields = row.fields.map(field => {
                        if (!field?.fieldAPI) return field;
    
                        switch (field.fieldAPI) {
                            case 'Amount__c':
                                return { ...field, value: amount > 0 ? amount.toFixed(2) : '0.00' };
                            default:
                                return field;
                        }
                    });
                }
    
                // Process tax calculations if applicable
                if (taxId && quantity > 0 && rate > 0 && taxableAmount > 0) {
                    if (this.chosenParentTaxOption !== 'Out of scope of Tax') {
                        const taxPromise = getAllChildTax({ taxId })
                            .then(result => {
                                console.log('Tax API Result:', JSON.stringify(result));
                                if (!result?.parentTaxArray?.[0]) return null;
    
                                const taxDetail = result.parentTaxArray[0];
                                let totalTaxAmount = 0;
    
                                // DEBUG: Log tax detail
                                console.log(`Processing tax for row ${row.rowNumber}:`, {
                                    taxDetail: taxDetail,
                                    taxableAmount: taxableAmount,
                                    hasChildTaxes: taxDetail?.childTaxes?.length > 0
                                });
    
                                // Handle child taxes if present (like CGST + SGST)
                                if (taxDetail?.childTaxes?.length > 0) {
                                    taxDetail.childTaxes.forEach(childTax => {
                                        if (!childTax || !childTax.taxPercentage) return;
                                        
                                        // Calculate tax amount on the taxable amount with validation
                                        const taxPercentage = parseFloat(childTax.taxPercentage) || 0;
                                        const taxAmt = (taxableAmount * taxPercentage) / 100;
                                        
                                        // Ensure tax amount is valid
                                        if (isNaN(taxAmt) || !isFinite(taxAmt)) {
                                            console.error(`Invalid tax calculation for ${childTax.name}:`, {
                                                taxableAmount,
                                                taxPercentage,
                                                result: taxAmt
                                            });
                                            return;
                                        }
                                        
                                        totalTaxAmount += taxAmt;
    
                                        console.log(`Child Tax Calculation:`, {
                                            taxName: childTax.name,
                                            taxPercentage: taxPercentage,
                                            taxableAmount: taxableAmount,
                                            calculatedTax: taxAmt
                                        });
    
                                        // Push to temporary array with validated values
                                        currentTaxDetails.push({
                                            invItemId: row.invItemId,
                                            taxId: childTax.id,
                                            rowNumber: row.rowNumber,
                                            taxName: childTax.name,
                                            taxPercentage: taxPercentage,
                                            taxAmount: parseFloat(taxAmt.toFixed(2))
                                        });
                                    });
                                } else if (taxDetail?.taxPercentage) {
                                    // Handle parent tax (single tax)
                                    const taxPercentage = parseFloat(taxDetail.taxPercentage) || 0;
                                    const parentTaxAmt = (taxableAmount * taxPercentage) / 100;
                                    
                                    // Ensure tax amount is valid
                                    if (!isNaN(parentTaxAmt) && isFinite(parentTaxAmt)) {
                                        totalTaxAmount = parentTaxAmt;
    
                                        console.log(`Parent Tax Calculation:`, {
                                            taxName: taxDetail.name,
                                            taxPercentage: taxPercentage,
                                            taxableAmount: taxableAmount,
                                            calculatedTax: parentTaxAmt
                                        });
    
                                        // Push to temporary array with validated values
                                        currentTaxDetails.push({
                                            invItemId: row.invItemId,
                                            rowNumber: row.rowNumber,
                                            taxId: taxDetail.id,
                                            taxName: taxDetail.name,
                                            taxPercentage: taxPercentage,
                                            taxAmount: parseFloat(parentTaxAmt.toFixed(2))
                                        });
                                    }
                                }
    
                                console.log(`Total tax amount for row ${row.rowNumber}: ${totalTaxAmount}`);
    
                                return {
                                    rowNumber: row.rowNumber,
                                    fields: row.fields.map(field => {
                                        if (field?.fieldAPI === 'Tax_Amount__c') {
                                            const taxValue = totalTaxAmount > 0 ? totalTaxAmount.toFixed(2) : '0.00';
                                            return { ...field, value: taxValue };
                                        }
                                        return field;
                                    }),
                                    totalTaxAmount
                                };
                            })
                            .catch(error => {
                                console.error('Tax calculation error for row:', row.rowNumber, error);
                                return null;
                            });
    
                        taxCalculationPromises.push(taxPromise);
                    }
                } else {
                    // Clear tax amount if no tax applies
                    row.fields = row.fields.map(field => {
                        if (field?.fieldAPI === 'Tax_Amount__c') {
                            return { ...field, value: '0.00' };
                        }
                        return field;
                    });
                }
    
                return row;
            });
    
            // Process all tax calculation promises
            if (taxCalculationPromises.length > 0) {
                const taxResults = await Promise.all(taxCalculationPromises);
                taxResults.forEach(result => {
                    if (!result) return;
                    const rowIndex = receivedData.tableRows.findIndex(row =>
                        row?.rowNumber === result.rowNumber
                    );
                    if (rowIndex !== -1 && result.fields) {
                        receivedData.tableRows[rowIndex].fields = result.fields;
                    }
                });
            }
    
            // CRITICAL FIX: Only assign the tax details after all calculations are complete
            this.taxDetails = currentTaxDetails;
    
            // DEBUG: Log final tax details
            console.log('Final Tax Details:', JSON.stringify(this.taxDetails));
    
            // Calculate totals for debugging - DYNAMIC VERSION
            const taxTotals = {};
            let grandTotalTax = 0;
            
            this.taxDetails.forEach(tax => {
                const taxName = tax.taxName;
                const taxAmount = parseFloat(tax.taxAmount) || 0;
                
                if (!taxTotals[taxName]) {
                    taxTotals[taxName] = 0;
                }
                taxTotals[taxName] += taxAmount;
                grandTotalTax += taxAmount;
            });
    
            console.log('Dynamic Tax Totals:', {
                byTaxType: taxTotals,
                grandTotal: grandTotalTax.toFixed(2),
                taxDetailsCount: this.taxDetails.length
            });
    
            this.itemList = receivedData;
    
        } catch (error) {
            console.error('Handler error:', error);
            this.showToast('Error', 'Processing error', 'error');
        }
    }
    get uniqueTaxDetails() {
        if (!this.taxDetails || this.taxDetails.length === 0) {
            return [];
        }

        const taxMap = new Map();

        this.taxDetails.forEach(tax => {
            if (taxMap.has(tax.taxName)) {
                const existingTax = taxMap.get(tax.taxName);
                existingTax.taxAmount = (parseFloat(existingTax.taxAmount) + parseFloat(tax.taxAmount)).toFixed(2);
            } else {
                taxMap.set(tax.taxName, {
                    taxName: tax.taxName,
                    taxAmount: tax.taxAmount
                });
            }
        });

        return Array.from(taxMap.values());
    }
    
    get total() {
        const subtotalValue = parseFloat(this.subtotal) || 0;
        const discountValue = parseFloat(this.totalDiscount) || 0;
        const amountAfterDiscount = subtotalValue - discountValue;

        const taxTotal = this.uniqueTaxDetails.reduce((sum, tax) => {
            return sum + (parseFloat(tax.taxAmount) || 0);
        }, 0);

        if (this.chosenParentTaxOption === 'Inclusive of Tax') {
            this.totalwithTax = amountAfterDiscount.toFixed(2);
            return amountAfterDiscount.toFixed(2);
        } else if (this.chosenParentTaxOption === 'Exclusive of Tax') {
            this.totalwithTax = (amountAfterDiscount + taxTotal).toFixed(2);
            return (amountAfterDiscount + taxTotal).toFixed(2);
        } else {
            return amountAfterDiscount.toFixed(2);
        }
    }

    handleLumpsumDiscountAmountChange(event) {
        this.lumpsumDiscountAmount = parseFloat(event.target.value) || 0;
        this.notifyChildOfMetadataChange();
    }

    handleLumpsumDiscountPercentageChange(event) {
        this.lumpsumDiscountPercentage = parseFloat(event.target.value) || 0;
        const child = this.template.querySelector('c-table-creator');
        this.notifyChildOfMetadataChange();
    }

    get totalDiscount() {
        if (!this.itemList || !this.itemList.tableRows) {
            return '0.00';
        }

        const lineItemDiscount = this.itemList.tableRows.reduce((total, row) => {
            const discountAmountField = row.fields.find(field => field.fieldAPI === 'Discount_Amount__c');
            const discountAmount = discountAmountField ? parseFloat(discountAmountField.value) || 0 : 0;

            const discountPercentageField = row.fields.find(field => field.fieldAPI === 'Discount_Percentage__c');
            const discountPercentage = discountPercentageField ? parseFloat(discountPercentageField.value) || 0 : 0;

            const amountField = row.fields.find(field => field.fieldAPI === 'Amount__c');
            const amount = amountField ? parseFloat(amountField.value) || 0 : 0;

            const percentageDiscount = (amount * discountPercentage) / 100;

            return total + (discountAmount || percentageDiscount);
        }, 0);

        let lumpsumDiscount = 0;
        if (this.isDiscountEnabled && this.selectedDiscountMode === 'Lumpsum Discount') {
            const subtotalValue = parseFloat(this.subtotal) || 0;

            if (this.selectedDiscountType === 'Amount' && this.lumpsumDiscountAmount > 0) {
                lumpsumDiscount = this.lumpsumDiscountAmount;
            } else if (this.selectedDiscountType === 'Percentage' && this.lumpsumDiscountPercentage > 0) {
                lumpsumDiscount = (subtotalValue * this.lumpsumDiscountPercentage) / 100;
            }
        }

        return (lineItemDiscount + lumpsumDiscount).toFixed(2);
    }


    toggleCcBccPopup() {
        this.showCcBccPopup = !this.showCcBccPopup;
    }

    toggleCcBccPopup() {
        // Store current values in temp variables when opening
        this.tempCcEmailAddressesStr = this.ccEmailAddressesStr;
        this.tempBccEmailAddressesStr = this.bccEmailAddressesStr;
        this.showCcBccPopup = true;
    }

    ccBccSecDone() {
        if (this.isInputValid()) {
            this.ccEmailAddressesStr = this.tempCcEmailAddressesStr;
            this.bccEmailAddressesStr = this.tempBccEmailAddressesStr;

            // Calculate lengths (optimized version of your logic)
            this.ccListLength = this.countEmails(this.ccEmailAddressesStr);
            this.bccListLength = this.countEmails(this.bccEmailAddressesStr);

            this.showCcBccPopup = false;
        }
    }

    ccBccSecCancel() {
        // Reset temp variables without saving
        this.tempCcEmailAddressesStr = this.ccEmailAddressesStr;
        this.tempBccEmailAddressesStr = this.bccEmailAddressesStr;
        this.showCcBccPopup = false;
    }

    ccOnChange(event) {
        this.tempCcEmailAddressesStr = event.target.value;
    }

    bccOnChange(event) {
        this.tempBccEmailAddressesStr = event.target.value;
    }

    // Helper method to count emails (extracted from your logic)
    countEmails(emailString) {
        if (!emailString) return 0;
        const cleanedString = emailString.replace(/\s/g, '');
        return cleanedString ? cleanedString.split(',').length : 0;
    }

    // Your validation method (keep your existing implementation)
    isInputValid() {
        // Add your validation logic here
        return true;
    }


}