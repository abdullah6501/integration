//KK 25/Jul/25 - Debit Note Component to create debit Notes from Bill and Purchase Orderitems
//Tableconfig implemented
// Abdullah V S | 22-Aug-25 | Dynamically sets visibility, read-only, and required flags for fields
import { LightningElement, track, wire, api } from 'lwc';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';
import {NavigationMixin} from 'lightning/navigation';
import getNslog from '@salesforce/apex/InvoiceFormController.getNslog';
import getTableFieldMetadata from '@salesforce/apex/TableFieldConfigUtility.getTableFieldMetadata';
import getDebitNoteDetails from '@salesforce/apex/creditNoteTabHandler.getDebitNoteDetails';
import taxOptions from '@salesforce/apex/TaxUtility.getParentTaxes';
import saveDebitNote from '@salesforce/apex/creditNoteTabHandler.saveDebitNote';
import getBillData from '@salesforce/apex/creditNoteTabHandler.getBillData';
import getPurchaseOrderData from '@salesforce/apex/creditNoteTabHandler.getPurchaseOrderData';
import getCategoryPicklistValues from '@salesforce/apex/creditNoteTabHandler.getCategoryPicklistValues';
import getReferenceTypePickListvalues from '@salesforce/apex/creditNoteTabHandler.getReferenceTypePickListvalues';
import Utility from 'c/utility';

export default class DebitNoteTab extends NavigationMixin(LightningElement) {
    True = true;
    @api recordId;
    @track isSaveDisabled = false;
    @track isNotDisable = true;
    @track isBillDebitNote = false;
    @track isPODebitNote = false;
    @track currencyCode = '';
    @track componentName = 'debitNote';
    @track visibilityFlags = {};
    @track readOnlyFlags = {};
    @track requiredFlags = {};
    @track isFormDisabled = false;
    @track taxOptions = [];
    @track parentTaxOptions = [];
    @track showTable = false;
    @track chosenParentTaxOption = 'Exclusive of Tax';
    @track purchaseOrderDiscountType = '';
    @track purchaseOrderLumpsumTaxAmount = 0;
    @track purchaseOrderLumpsumTotalAmount = 0;
    @track purchaseOrderLumpsumItemCount = 0;
    @track purchaseOrderLumpsumItemQuantity = 0;
    @track currencyDisplay;//AP-05AUG25 Display the currencyCode
    // Selected Record tracking
    @track purchaseOrderSelectedRecord = {
        id: null,
        name: null
    };
    @track billSelectedRecord = {
        id: null,
        name: null
    };
    ns;
    productObjectApiName = 'Product__c';
    productAdditionalFieldApiName = 'Actual_Cost__c';
    productOtherFieldApiName = 'ProductCode__c';

    purchaseOrderObjectApiName = 'Purchase_Order__c';
    purchaseOrderAdditionalFieldApiName = 'PO_Type__c';
    purchaseOrderOtherFieldApiName = 'Tax_Amount__c';

    billObjectApiName = 'Bill__c';
    billOtherFieldApiName = 'Status__c';
    billAdditionalFieldApiName = 'Discount_Type__c';

    @track debitNote = {
        debitNoteId:'',
        name: '',
        purchaseOrderId: '',
        billId: '',
        referenceType: '',
        vendorId:'',
        category: '',
        billDate: '',
        vendorName: '',
        reason: '',
        createJournalEntry: false,
        message: '',
        exchangeRate: '',
        currency: ''
    };

    @track debitNoteItems = [{
        itemOrder: '',
        productId: '',
        description: '',
        quantityReturn: 0,
        unitPrice: 0,
        amount:0,
        taxRate: null,
        taxName:'',
        taxAmount: 0,
        totalAmount:0
    }];

    get allDebitNoteItems() {
        return this.debitNoteItems.map((item, index) => ({
            ...item,
            lineNumber: index + 1
        }));
    }

    get isItemNumberVisible() {
        return this.getFieldConfig('itemNumber');
    }

    get isProductVisible() {
        return this.getFieldConfig('Product');
    }

    get isDescriptionVisible() {
        return this.getFieldConfig('Description');
    }

    get isQuantityReturnVisible() {
        return this.getFieldConfig('QuantityReturn');
    }

    get isUnitPriceVisible() {
        return this.getFieldConfig('UnitPrice');
    }

    get isAmount() {
        return this.getFieldConfig('Amount');
    }

    get isTaxVisible() {
        const taxConfig = this.getFieldConfig('Tax');
        return {
            ...taxConfig,
            visible: taxConfig.visible && (this.chosenParentTaxOption !== 'Out of scope of Tax' || this.purchaseOrderDiscountType !== '' || this.purchaseOrderDiscountType !== 'Lumpsum Discount')
        };
    }

    get isTaxAmountVisible() {
        const taxAmountConfig = this.getFieldConfig('TaxAmount');
        return {
            ...taxAmountConfig,
            visible: taxAmountConfig.visible && (this.chosenParentTaxOption !== 'Out of scope of Tax' || this.purchaseOrderDiscountType !== '')
        };
    }

    get isTotalAmountVisible() {
        return this.getFieldConfig('TotalAmount');
    }

    get isButtonDisabled() {
        return this.isFormDisabled || this.isSaveDisabled;
    }

    connectedCallback() {
        if (this.recordId) {
            this.loadDebitNoteDetails();

        }
    }

    loadDebitNoteDetails() {
        if (this.recordId) {
            getDebitNoteDetails({
                    debitNoteId: this.recordId
                })
                .then(result => {
                    if(result.referenceType === 'Bill') {
                        this.billSelectedRecord = {
                                id: result.billId
                            };
                        this.isBillDebitNote = true;
                        getBillData({ billId: result.billId})
                        .then((resultBill) => {
                            this.showTable = true;
                            // Example: populate fields from result
                            this.chosenParentTaxOption = resultBill.amountsAre;
                            this.debitNote.vendorName = resultBill.vendorName;
                        })
                        .catch((error) => {
                            console.error('Error fetching Bill data:', error);
                        });
                    } else {
                        this.isPODebitNote = true;
                        this.purchaseOrderSelectedRecord = {
                                id: result.purchaseOrderId
                            };
                        getPurchaseOrderData({ purchaseOrderId: result.purchaseOrderId })
                        .then((result) => {
                            this.showTable = true;
                            // Example: populate fields from result
                            this.purchaseOrderDiscountType = result.discountType;
                            this.debitNote.vendorName = result.vendorName;
                            this.purchaseOrderLumpsumTaxAmount = result.lumpsumTaxAmount || 0;
                            this.purchaseOrderLumpsumTotalAmt = result.lumpsumTotalAmount || 0;
                        })
                        .catch((error) => {
                            console.error('Error fetching Purchase Order data:', error);
                        });
                    }
                    this.debitNote = {
                        debitNoteId: result.debitNoteId,                       
                        name: result.name,
                        billId: result.billId,
                        purchaseOrderId: result.purchaseOrderId,
                        referenceType: result.referenceType,
                        category: result.category,
                        billDate: result.billDate,
                        reason: result.reason,
                        createJournalEntry: result.createJournalEntry,
                        cashReturn: result.cashReturn,
                        totalAmount: result.grandTotal || 0,
                        message: result.message || '',
                        exchangeRate: result.exchangeRate || '',
                        currency: result.currencyCode || ''
                    };
                    this.currencyCode = result.currencyCode || '';
                    //AP-05AUG25 Extract only the currency code part (e.g., "INR") for display
                    this.currencyDisplay = Utility.extractCurrencyCode(this.currencyCode || '');

                    // Sort and update debitNote items
                    const sortedItems = result.debitNoteItems.sort((a, b) =>
                        (a.keyField || 0) - (b.keyField || 0)
                    );

                    this.debitNoteItems = sortedItems.map((item, index) => ({
                        itemOrder: index+1,
                        productId: item.productId,
                        description: item.description,
                        quantityReturn: Number(parseFloat(item.quantityReturn || 0)),
                        unitPrice: Number(parseFloat(item.unitPrice || 0)),
                        amount: Number(parseFloat(item.amount || 0)),
                        taxRate: item.taxRate,
                        taxAmount: Number(parseFloat(item.taxAmount || 0)),
                        totalAmount: Number(parseFloat(item.totalAmount || 0)),
                    }));

                    // Only calculate taxes if tax options are loaded
                    if (this.taxOptionsLoaded) {
                        setTimeout(() => {
                            this.calculateTaxesAfterLoad();
                        }, 0);
                    }

                })
                .catch(error => {
                    // this.showSpinner = false;
                    console.error('Error loading debitNote details:', error);
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Error',
                            message: 'Error loading debitNote details: ' + (error.body?.message || error.message),
                            variant: 'error'
                        })
                    );
                });
        }
    }

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
            this.taxOptionsLoaded = true; // Set flag when options are loaded

            if (this.debitNoteItems && this.debitNoteItems.length > 0) {
                this.calculateTaxesAfterLoad();
            }
        } else if (error) {
            console.error('Error fetching tax options:', error);
            this.taxOptions = [];
        }
    }

    @wire(getCategoryPicklistValues)
    wiredCategoryOptions({error, data}) {
        if (data) {
            this.categoryOptions = data.CreditNoteCategory.map(status => ({
                label: status,
                value: status
            }));
        } else if (error) {
            console.error('Error loading status options:', error);
        }
    }

    @wire(getReferenceTypePickListvalues)
    wiredReferenceTypeOptions({error, data}) {
        if (data) {
            this.referenceTypeOptions = data.referenceType.map(status => ({
                label: status,
                value: status
            }));
        } else if (error) {
            console.error('Error loading status options:', error);
        }
    }

    // Add this new method
    calculateTaxesAfterLoad() {
        if(this.debitNote.referenceType === 'Bill') {
            this.debitNoteItems.forEach((item, index) => {
                if (item.taxRate) {
                    this.calculateTaxForLineItem(index);
                }
            });
        }else if(this.debitNote.referenceType === 'Purchase Order') {
            // if(this.purchaseOrderDiscountType === 'Lumpsum Discount'){
                this.debitNoteItems.forEach((item, index) => {
                    if(item){
                        console.log('inside if---->');
                        this.calculateTaxForLineItem(index);
                    }
                    console.log('Completed--->');
                });
            // }else if(this.purchaseOrderDiscountType === 'Line Item Discount') {
            //     this.debitNoteItems.forEach((item, index) => {
            //         if (item.taxRate) {
            //             this.calculateTaxForLineItem(index);
            //         }
            //     });
            // }else if(this.purchaseOrderDiscountType === '') {
            //     this.debitNoteItems.forEach((item, index) => {
            //         if (item.taxRate) {
            //             this.calculateTaxForLineItem(index);
            //         }
            //     });
            // }
        }
        // Force refresh of the debitNote array
        this.debitNoteItems = [...this.debitNoteItems];
    }

    calculateTaxForLineItem(index) {
        const item = this.debitNoteItems[index];
        if(this.referenceType === 'Bill') {
            const selectedTax = this.taxOptions.find(option => option.value === item.taxRate);
            if (selectedTax && this.chosenParentTaxOption !== 'Out of scope of Tax') {
                // Ensure proper number parsing
                const subtotal = Number(parseFloat(item.amount || 0));
                let totalTaxAmount = 0;

                if (selectedTax.fullData.childTaxes && selectedTax.fullData.childTaxes.length > 0) {
                    selectedTax.fullData.childTaxes.forEach(childTax => {
                        const percentage = Number(parseFloat(childTax.childTaxPercentage || 0));
                        const taxAmount = (subtotal * percentage) / 100;
                        totalTaxAmount += taxAmount;
                    });
                } else {
                    const percentage = Number(parseFloat(selectedTax.percentage || 0));
                    totalTaxAmount = (subtotal * percentage) / 100;
                }

                // Store values as numbers, not strings
                this.debitNoteItems[index].taxAmount = Number(totalTaxAmount.toFixed(2));

                if (this.chosenParentTaxOption === 'Exclusive of Tax') {
                    this.debitNoteItems[index].totalAmount = Number((subtotal + totalTaxAmount).toFixed(2));
                } else if (this.chosenParentTaxOption === 'Inclusive of Tax') {
                    this.debitNoteItems[index].totalAmount = Number(subtotal.toFixed(2));
                }
            } else {
                this.debitNoteItems[index].taxAmount = 0;
                this.debitNoteItems[index].totalAmount = Number(parseFloat(item.amount || 0).toFixed(2));
            }
        }else{
            if(this.purchaseOrderDiscountType === 'Lumpsum Discount') {
                const item = this.debitNoteItems[index];

                const quantity = parseFloat(item.quantityReturn) || 0;
                const amount = parseFloat(item.amount) || 0;

                const totalPOQuantity = this.purchaseOrderLumpsumItemQuantity || 1; // Avoid division by zero
                const totalTax = this.purchaseOrderLumpsumTaxAmount || 0;

                // Per-unit tax from the whole PO
                const perUnitTax = totalTax / totalPOQuantity;

                // Tax for this item = quantity * per-unit tax
                const itemTax = quantity * perUnitTax;

                // Store updated tax and total
                this.debitNoteItems[index].taxAmount = parseFloat(itemTax.toFixed(2));
                this.debitNoteItems[index].totalAmount = parseFloat((amount + itemTax).toFixed(2));
            }else if(this.purchaseOrderDiscountType === 'Line Item Discount' || this.purchaseOrderDiscountType === '') {
                const selectedTax = this.taxOptions.find(option => option.value === item.taxRate);
                if (selectedTax) {
                    // Ensure proper number parsing
                    const subtotal = Number(parseFloat(item.amount || 0));
                    let totalTaxAmount = 0;

                    if (selectedTax.fullData.childTaxes && selectedTax.fullData.childTaxes.length > 0) {
                        selectedTax.fullData.childTaxes.forEach(childTax => {
                            const percentage = Number(parseFloat(childTax.childTaxPercentage || 0));
                            const taxAmount = (subtotal * percentage) / 100;
                            totalTaxAmount += taxAmount;
                        });
                    } else {
                        const percentage = Number(parseFloat(selectedTax.percentage || 0));
                        totalTaxAmount = (subtotal * percentage) / 100;
                    }

                    // Store values as numbers, not strings
                    this.debitNoteItems[index].taxAmount = Number(totalTaxAmount.toFixed(2));
                } else {
                    this.debitNoteItems[index].taxAmount = 0;
                    this.debitNoteItems[index].totalAmount = Number(parseFloat(item.amount || 0).toFixed(2));
                }
            }
        }        
    }

    get subtotal() {
        const total = this.debitNoteItems.reduce((sum, item) => {
            const itemTotal = Number(parseFloat(item.amount || 0));
            return sum + itemTotal;
        }, 0);
        return Number(total.toFixed(2));
    }

    get taxTotal() {
        if(this.debitNote.referenceType == 'Bill'){
            if (this.chosenParentTaxOption === 'Out of scope of Tax') {
                return 0;
            }else {
                const total = this.debitNoteItems.reduce((sum, item) => {
                    const taxAmount = Number(parseFloat(item.taxAmount || 0));
                    return sum + taxAmount;
                }, 0);
                return Number(total.toFixed(2));
            }          
        }
        else{
            // if(this.purchaseOrderDiscountType === 'Line Item Discount' || this.purchaseOrderDiscountType === '') {
                const total = this.debitNoteItems.reduce((sum, item) => {
                    const taxAmount = Number(parseFloat(item.taxAmount || 0));
                    return sum + taxAmount;
                }, 0);
                return Number(total.toFixed(2));
            // }else if(this.purchaseOrderDiscountType === 'Lumpsum Discount') {
            //     this.purchaseOrderLumpsumTaxAmount = this.purchaseOrderLumpsumTaxAmount || 0;
            //     return Number(parseFloat(this.purchaseOrderLumpsumTaxAmount).toFixed(2));
            // }
        }   
    }

    get grandTotal() {
        const subtotal = Number(this.subtotal);
        const taxTotal = Number(this.taxTotal);
        if(this.debitNote.referenceType === 'Bill') {
            if (this.chosenParentTaxOption === 'Exclusive of Tax') {
                return Number((subtotal + taxTotal).toFixed(2));
            } else {
                return Number(subtotal.toFixed(2));
            }
        }else{
            // if(this.purchaseOrderDiscountType === 'Line Item Discount' || this.purchaseOrderDiscountType === '' ) {
                return Number((subtotal + taxTotal).toFixed(2));
            // }
            // }else if(this.purchaseOrderDiscountType === 'Lumpsum Discount') {
            //     return Number((subtotal + this.purchaseOrderLumpsumTaxAmount).toFixed(2));
            // }
        }
    }

    @wire(getNslog)
    handleNamespace({error, data}) {
        if (data) {
            this.ns = data.nameSpace != 'null' ? data.nameSpace : '';

            // Configure Product namespace
            this.productobjectApiName = data.nameSpace != 'null' ? data.nameSpace + this.productobjectApiName : this.productobjectApiName;
            this.productAdditionalFieldApiName = data.nameSpace != 'null' ? data.nameSpace + this.productAdditionalFieldApiName : this.productAdditionalFieldApiName;
            this.productOtherFieldApiName = data.nameSpace != 'null' ? data.nameSpace + this.productOtherFieldApiName : this.productOtherFieldApiName;

            // Configure Account namespace
            this.purchaseOrderObjectApiName = data.nameSpace != 'null' ? data.nameSpace + this.purchaseOrderObjectApiName : this.purchaseOrderObjectApiName;
            this.purchaseOrderAdditionalFieldApiName = data.nameSpace != 'null' ? data.nameSpace + this.purchaseOrderAdditionalFieldApiName : this.purchaseOrderAdditionalFieldApiName;
            this.purchaseOrderOtherFieldApiName = data.nameSpace != 'null' ? data.nameSpace + this.purchaseOrderOtherFieldApiName : this.purchaseOrderOtherFieldApiName;

        } else if (error) {
            console.error('Error loading namespace:', error);
        }
    }

    @wire(getTableFieldMetadata, { componentName: '$componentName' })
    wiredTableConfig({error, data}) {
        if (data) {
            this.visibilityFlags = {};
            this.readOnlyFlags = {};
            this.requiredFlags = {};
            this.labelList = {};
            this.sizeClasses = {}; // add for width check
            data.forEach(row => {
                const {
                    fieldAPI,
                    visiblityMode,
                    label,
                    width // add for width check
                } = row;
                this.visibilityFlags[fieldAPI] = visiblityMode === 'Visible' || visiblityMode === 'Read Only' || visiblityMode === 'Required';
                this.labelList[fieldAPI] = row.label;
                this.readOnlyFlags[fieldAPI] = visiblityMode === 'Read Only';
				this.requiredFlags[fieldAPI] = visiblityMode === 'Required';
                const sldsSize = width ? `width: ${(width/12*100).toFixed(2)}%;` : ''; // add for width check
                this.sizeClasses[fieldAPI] = sldsSize; // add for width check
            });

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
            sldsSize: this.sizeClasses?.[fieldAPI] || '' // add for width check
        }
    }

    handleInputChange(event) {
        const field = event.target.dataset.id;
        this.debitNote[field] = event.target.value;
        if(field == 'referenceType'){
            this.isBillDebitNote = false;
            this.isPODebitNote = false;
            this.debitNoteItems = [];
            this.currentSelectedRecord.id = null;
            this.billSelectedRecord.id = null;
            this.purchaseOrderSelectedRecord.id = null;
            if(event.target.value === 'Bill'){
                this.isPODebitNote = false;
                this.isBillDebitNote = true;
            }else{
                this.isBillDebitNote = false;
                this.isPODebitNote = true;
            }
        }
    }

    handleCheckboxChange(event) {
        this.debitNote[event.target.dataset.id] = event.target.checked;
    }

    get amountInWords() {
        // KK 29-Jul-25 Convert total amount to words based on the selected currency using utility method.
        return Utility.convertToWords(this.grandTotal, this.currencyCode) + ' only';
    }

    //KK 29-Jul-25 Removed convertToWords method instead used same function from Utility Class

    get showTaxDetailsSection() {
        return this.isTaxVisible;
    }

    handleItemChange(event) {
        const index = parseInt(event.target.dataset.index);
        const field = event.target.dataset.id;
        this.debitNoteItems[index][field] = event.target.value;

        // Recalculate totals for this line item
        const item = this.debitNoteItems[index];
        const unitPrice = parseFloat(item.unitPrice) || 0;
        const quantity = parseFloat(item.quantityReturn) || 0;
        const subtotal = unitPrice * quantity;

        // Set the subtotal
        this.debitNoteItems[index].amount = parseFloat(subtotal.toFixed(2));

        if (field === 'quantityReturn') {
            this.calculateTaxForLineItem(index);
        }

        // this.calculateAllTaxTotals();

        this.debitNoteItems = [...this.debitNoteItems];
    }

    // Handle Vendor Selection
    handleValueSelectedBill(event) {
        if (!event.detail || !event.detail.id) {
            console.error('Invalid Bill selection event:', event);
            return;
        }
        this.billSelectedRecord = {
            id: event.detail.id,
            name: event.detail.mainField
        };
        // Call Apex to get invoice data
        getBillData({ billId: event.detail.id })
            .then((result) => {
                this.showTable = true;
                // Example: populate fields from result
                this.chosenParentTaxOption = result.amountsAre;
                this.debitNote.vendorName = result.vendorName;
                this.debitNote.billId = this.billSelectedRecord.id;
                this.debitNote.currency = result.currencyCode;
                this.debitNote.exchangeRate = result.exchangeRate;
                this.debitNote.vendorId = result.vendorId;
                this.currencyCode = result.currencyCode || '';
                //AP-05AUG25 Extract only the currency code part (e.g., "INR") for display
                this.currencyDisplay = Utility.extractCurrencyCode(this.currencyCode || '');

                // --- Populate item table ---
                this.debitNoteItems = result.items.map((item, index) => ({
                    keyField: index + 1,
                    id: item.id,
                    productId: item.productId,
                    description: item.description,
                    quantityReturn: item.quantity,
                    unitPrice: item.rate,
                    amount: item.amount,
                    taxRate: item.taxId,
                    taxName:item.taxName,
                    taxAmount: item.taxAmount,
                    totalAmount: item.amountWithTax
                }));
                console.log('Debit Note Items:', JSON.stringify(this.debitNoteItems));
                this.calculateTaxesAfterLoad(); // Optional: recalculate totals if needed
            })
            .catch((error) => {
                console.error('Error fetching Bill data:', error);
                this.showTable = false;
            });
    }

    handleValueSelectedPO(event) {
        if (!event.detail || !event.detail.id) {
            console.error('Invalid Purchase Order selection event:', event);
            return;
        }
        this.purchaseOrderSelectedRecord = {
            id: event.detail.id,
            name: event.detail.mainField
        };
        // Call Apex to get invoice data
        getPurchaseOrderData({ purchaseOrderId: event.detail.id })
            .then((result) => {
                this.showTable = true;
                this.debitNote.vendorName = result.vendorName;
                this.debitNote.purchaseOrderId = this.purchaseOrderSelectedRecord.id;
                this.debitNote.currency = result.currencyCode;
                this.debitNote.exchangeRate = result.exchangeRate;
                this.debitNote.vendorId = result.vendorId;
                this.currencyCode = result.currencyCode || '';
                this.purchaseOrderDiscountType = result.discountType || '';
                this.purchaseOrderLumpsumTaxAmount = result.lumpsumTaxAmount || '';
                this.purchaseOrderLumpsumTotalAmount = result.lumpsumTotalAmount || '';
                this.purchaseOrderLumpsumItemCount = result.lumpsumItemCount || 0;
                this.purchaseOrderLumpsumItemQuantity = result.lumpsumItemQuantity || 0;
                // --- Populate item table ---
                this.debitNoteItems = result.items.map((item, index) => ({
                    keyField: index + 1,
                    id: item.id,
                    productId: item.productId,
                    description: item.description,
                    quantityReturn: item.quantity,
                    unitPrice: item.rate,
                    amount: item.amount,
                    taxRate: item.taxId,
                    taxName:item.taxName,
                    taxAmount: item.taxAmount,
                    totalAmount: item.amountWithTax
                }));
                console.log('Debit Note Items:', JSON.stringify(this.debitNoteItems));
                this.calculateTaxesAfterLoad(); // Optional: recalculate totals if needed
            })
            .catch((error) => {
                console.error('Error fetching Purchase Order data:', error);
                this.showTable = false;
            });
    }
    get currentObjectApiName() {
        return this.isBillDebitNote ? this.billObjectApiName : this.purchaseOrderObjectApiName;
    }
    get currentOtherFieldApiName() {
        return this.isBillDebitNote ? this.billOtherFieldApiName : this.purchaseOrderOtherFieldApiName;
    }
    get currentAdditionalFieldApiName() {
        return this.isBillDebitNote ? this.billAdditionalFieldApiName : this.purchaseOrderAdditionalFieldApiName;
    }
    get currentSelectedRecord() {
        return this.isBillDebitNote ? this.billSelectedRecord : this.purchaseOrderSelectedRecord;
    }
    get lookupKey() {
        return this.isBillDebitNote ? 'bill' : 'po';
    }
    handleLookupSelection(event) {
        if (this.isBillDebitNote) {
            this.handleValueSelectedBill(event);
        } else {
            this.handleValueSelectedPO(event);
        }
    }


    handleCancel() {
        window.history.back();
    }

    handleSave() {
        this.isSaveDisabled = true;
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
            this.isSaveDisabled = false;
            return;
        }
        const debitNoteWrapper = {
            debitNoteId: this.recordId ?? '',
            name: this.debitNote?.name || '',
            referenceType: this.debitNote?.referenceType || '',
            billId: this.debitNote?.billId || null,
            purchaseOrderId: this.debitNote?.purchaseOrderId || null,
            vendorId: this.debitNote?.vendorId|| '',
            category: this.debitNote?.category || '',
            billDate: this.debitNote?.billDate || null, // ensure it's Date or convert if needed
            reason: this.debitNote?.reason || '',
            createJournalEntry: this.debitNote?.createJournalEntry || false,
            cashReturn: this.debitNote?.cashReturn || false,
            message: this.debitNote?.message || '',
            exchangeRate: this.debitNote?.exchangeRate || 1,
            currencyCode: this.debitNote?.currency || '', // default to INR
            lumpsumTaxAmount: this.taxTotal || 0,
            lumpsumTotalAmount: this.grandTotal || 0,
            lumpsum: this.purchaseOrderDiscountType === 'Lumpsum Discount' ? true : false,

            debitNoteItems: (this.debitNoteItems || [])
                .filter(item =>
                    item.productId || item.description || item.quantityReturn || item.unitPrice
                )
                .map((item, idx) => ({
                    keyField: item.keyField ?? idx + 1,
                    productId: item.productId || null,
                    description: item.description || '',
                    quantityReturn: item.quantityReturn ?? 0,
                    unitPrice: item.unitPrice ?? 0,
                    amount: item.amount ?? 0,
                    taxRate: item.taxRate || null,
                    taxName: item.taxName || '',
                    taxAmount: item.taxAmount ?? 0,
                    totalAmount: item.totalAmount ?? 0
                }))
        };
        saveDebitNote({debitNoteWrapperJson: JSON.stringify(debitNoteWrapper)})
            .then(debitNoteId => {
                if(debitNoteId){
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Success',
                            message: 'Debit Note Saved Successfully',
                            variant: 'success'
                        })
                    );
                }              
            })
            .catch(error => {
                console.error('Error saving debit Note:', error);
                this.isSaveDisabled = false;
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: error.body?.message || 'Failed to save debit Note. Please try again.',
                    variant: 'error'
                }));
            });
    }

    removeItem(event) {
        const index = Number(event.currentTarget.dataset.index);
        if (!isNaN(index) && index >= 0 && index < this.debitNoteItems.length) {
            this.debitNoteItems.splice(index, 1);
            this.debitNoteItems = [...this.debitNoteItems];
        }
    }

    clearAllItems() {
        this.debitNoteItems = [{
            itemOrder: '',
            productId: '',
            description: '',
            quantityReturn: 0,
            unitPrice: 0,
            amount:0,
            taxRate: null,
            taxName:'',
            taxAmount: 0,
            totalAmount: 0
        }];
    }
}