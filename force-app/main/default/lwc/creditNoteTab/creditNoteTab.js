//KK 18/Jul/25 - Credit Note Component to create credit Notes from invoice items
//Tableconfig implemented
// Abdullah V S | 22-Aug-25 | Dynamically sets visibility, read-only, and required flags for fields
import { LightningElement, track, wire, api } from 'lwc';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';
import {NavigationMixin} from 'lightning/navigation';
import getNslog from '@salesforce/apex/InvoiceFormController.getNslog';
import getTableFieldMetadata from '@salesforce/apex/TableFieldConfigUtility.getTableFieldMetadata';
import getCreditNoteDetails from '@salesforce/apex/creditNoteTabHandler.getCreditNoteDetails';
import taxOptions from '@salesforce/apex/TaxUtility.getParentTaxes';
import saveCreditNote from '@salesforce/apex/creditNoteTabHandler.saveCreditNote';
import getInvoiceData from '@salesforce/apex/creditNoteTabHandler.getInvoiceData';
import getCategoryPicklistValues from '@salesforce/apex/creditNoteTabHandler.getCategoryPicklistValues';
import Utility from 'c/utility';

export default class CreditNoteTab extends NavigationMixin(LightningElement) {
    True = true;
    @api recordId;
    @track isSaveDisabled = false;
    @track isNotDisable = true;
    @track isNewMode = true;
    @track currencyCode = '';
    @track currencyDisplay = '';//AP-05AUG25 Display the currencyCode
    @track componentName = 'creditNote';
    @track visibilityFlags = {};
	@track readOnlyFlags = {};
	@track requiredFlags = {};
 	@track isFormDisabled = false;
    @track taxOptions = [];
	@track parentTaxOptions = [];
    @track showTable = false;
    invoiceLabel ='Invoice List'
    @track chosenParentTaxOption = 'Exclusive of Tax';
    // Selected Record tracking
    @track invoiceSelectedRecord = {
        id: null,
        name: null
    };
    ns;
	productobjectApiName = 'Product__c';
	productadditionalFieldApiName = 'Actual_Cost__c';
	productotherFieldApiName = 'ProductCode__c';

	invoiceObjectApiName = 'Invoice__c';
	invoiceadditionalFieldApiName = 'Account__c';
	invoiceotherFieldApiName = 'Currency__c';

    @track creditNote = {
        creditNoteId:'',
		name: '',
		invoice: '',
        customerId:'',
		category: '',
		billDate: '',
		customerName: '',
		reason: '',
		createJournalEntry: false,
		cashReturn: false,
		message: '',
        exchangeRate: '',
        currency: ''
	};

    //KK 1/Aug/25 - Added creditNoteItems to track items in the credit note
    @track creditNoteItems = [{
		itemOrder: '',
		productId: '',
        invoiceItemId: '',
		description: '',
        quantityReturn: 0,
		unitPrice: 0,
        amount:0,
		taxRate: null,
        taxName:'',
		taxAmount: 0,
        totalAmount:0
	}];

    get allCreditNoteItems() {
		return this.creditNoteItems.map((item, index) => ({
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
			visible: taxConfig.visible && this.chosenParentTaxOption !== 'Out of scope of Tax'
		};
	}

	get isTaxAmountVisible() {
        const taxAmountConfig = this.getFieldConfig('TaxAmount');
		return {
			...taxAmountConfig,
			visible: taxAmountConfig.visible && this.chosenParentTaxOption !== 'Out of scope of Tax'
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
			this.isNewMode = false;
			this.loadCreditNoteDetails();

		}
	}

    loadCreditNoteDetails() {
        if (this.recordId) {
            getCreditNoteDetails({
                    creditNoteId: this.recordId
                })
                .then(result => {
                    getInvoiceData({ invoiceId: result.invoiceId})
                    .then((result) => {
                        this.showTable = true;

                        // Example: populate fields from result
                        this.chosenParentTaxOption = result.amountsAre;
                        this.creditNote.customerName = result.accountName;
                    })
                    .catch((error) => {
                        console.error('Error fetching invoice data:', error);
                    });
                    this.creditNote = {
                        creditNoteId: result.creditNoteId,                       
                        name: result.name,
                        invoice: result.invoiceId,
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

                    // Update selected records - THIS IS THE FIX
                    this.invoiceSelectedRecord = {
                        id: result.invoiceId
                    };

                    // Sort and update creditNote items
                    const sortedItems = result.creditNoteItems.sort((a, b) =>
                        (a.keyField || 0) - (b.keyField || 0)
                    );

                    //KK 1/Aug/25 - Added creditNoteItems to track items in the credit note
                    this.creditNoteItems = sortedItems.map((item, index) => ({
                        itemOrder: index+1,
                        productId: item.productId,
                        invoiceItemId: item.id,
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
                    console.error('Error loading creditNote details:', error);
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Error',
                            message: 'Error loading creditNote details: ' + (error.body?.message || error.message),
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

            if (this.creditNoteItems && this.creditNoteItems.length > 0) {
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

    // Add this new method
	calculateTaxesAfterLoad() {
		this.creditNoteItems.forEach((item, index) => {
			if (item.taxRate) {
				this.calculateTaxForLineItem(index);
			}
		});
		// Force refresh of the creditNote array
		this.creditNoteItems = [...this.creditNoteItems];
	}

    calculateTaxForLineItem(index) {
		const item = this.creditNoteItems[index];
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
			this.creditNoteItems[index].taxAmount = Number(totalTaxAmount.toFixed(2));

			if (this.chosenParentTaxOption === 'Exclusive of Tax') {
				this.creditNoteItems[index].totalAmount = Number((subtotal + totalTaxAmount).toFixed(2));
			} else if (this.chosenParentTaxOption === 'Inclusive of Tax') {
				this.creditNoteItems[index].totalAmount = Number(subtotal.toFixed(2));
			}
		} else {
			this.creditNoteItems[index].taxAmount = 0;
			this.creditNoteItems[index].totalAmount = Number(parseFloat(item.amount || 0).toFixed(2));
		}
	}

    get subtotal() {
		const total = this.creditNoteItems.reduce((sum, item) => {
			const itemTotal = Number(parseFloat(item.amount || 0));
			return sum + itemTotal;
		}, 0);
		return Number(total.toFixed(2));
	}

    get taxTotal() {
		if (this.chosenParentTaxOption === 'Out of scope of Tax') {
			return 0;
		}
		const total = this.creditNoteItems.reduce((sum, item) => {
			const taxAmount = Number(parseFloat(item.taxAmount || 0));
			return sum + taxAmount;
		}, 0);
		return Number(total.toFixed(2));
	}

    get grandTotal() {
		const subtotal = Number(this.subtotal);
		const taxTotal = Number(this.taxTotal);

		if (this.chosenParentTaxOption === 'Exclusive of Tax') {
			return Number((subtotal + taxTotal).toFixed(2));
		} else {
			return Number(subtotal.toFixed(2));
		}
	}

    @wire(getNslog)
    handleNamespace({error, data}) {
        if (data) {
            this.ns = data.nameSpace != 'null' ? data.nameSpace : '';

            // Configure Product namespace
            this.productobjectApiName = data.nameSpace != 'null' ? data.nameSpace + this.productobjectApiName : this.productobjectApiName;
            this.productadditionalFieldApiName = data.nameSpace != 'null' ? data.nameSpace + this.productadditionalFieldApiName : this.productadditionalFieldApiName;
            this.productotherFieldApiName = data.nameSpace != 'null' ? data.nameSpace + this.productotherFieldApiName : this.productotherFieldApiName;

            // Configure Account namespace
            this.invoiceObjectApiName = data.nameSpace != 'null' ? data.nameSpace + this.invoiceObjectApiName : this.invoiceObjectApiName;
            this.invoiceadditionalFieldApiName = data.nameSpace != 'null' ? data.nameSpace + this.invoiceadditionalFieldApiName : this.invoiceadditionalFieldApiName;
            this.invoiceotherFieldApiName = data.nameSpace != 'null' ? data.nameSpace + this.invoiceotherFieldApiName : this.invoiceotherFieldApiName;

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
		this.creditNote[field] = event.target.value;
	}

    handleCheckboxChange(event) {
		this.creditNote[event.target.dataset.id] = event.target.checked;
	}

    get amountInWords() {
        // Abdullah V S | 25-Jul-25 | Convert total amount to words based on the selected currency using utility method.
        return Utility.convertToWords(this.grandTotal, this.currencyCode) + ' only';
	}

    get showTaxDetailsSection() {
		return this.isTaxVisible;
	}

    handleItemChange(event) {
		const index = parseInt(event.target.dataset.index);
		const field = event.target.dataset.id;
		this.creditNoteItems[index][field] = event.target.value;

		// Recalculate totals for this line item
		const item = this.creditNoteItems[index];
		const unitPrice = parseFloat(item.unitPrice) || 0;
		const quantity = parseFloat(item.quantityReturn) || 0;
		const subtotal = unitPrice * quantity;

		// Set the subtotal
		this.creditNoteItems[index].amount = parseFloat(subtotal.toFixed(2));

		if (field === 'taxRate' || field === 'unitPrice' || field === 'quantityReturn') {
			this.calculateTaxForLineItem(index);
		}

		// this.calculateAllTaxTotals();

		this.creditNoteItems = [...this.creditNoteItems];
	}

    // Handle Vendor Selection
	handleValueSelected(event) {
		if (!event.detail || !event.detail.id) {
			console.error('Invalid Invoice selection event:', event);
			return;
		}
		this.invoiceSelectedRecord = {
			id: event.detail.id,
			name: event.detail.mainField
		};
        // Call Apex to get invoice data
        getInvoiceData({ invoiceId: event.detail.id })
            .then((result) => {
                this.showTable = true;
                // Example: populate fields from result
                this.chosenParentTaxOption = result.amountsAre;
                this.creditNote.customerName = result.accountName;
                this.creditNote.invoice = this.invoiceSelectedRecord.id;
                this.creditNote.currency = result.currencyCode;
                this.creditNote.exchangeRate = result.exchangeRate;
                this.creditNote.customerId = result.accountId;
                // --- Populate item table ---
                //KK 1/Aug/25 - Updated creditNoteItems Key name id to invoiceItemId
                this.creditNoteItems = result.items.map((item, index) => ({
                    keyField: index + 1,
                    productId: item.productId,
                    invoiceItemId: item.id,
                    description: item.description,
                    quantityReturn: item.quantity,
                    unitPrice: item.rate,
                    amount: item.amount,
                    taxRate: item.taxId,
                    taxName:item.taxName,
                    taxAmount: item.taxAmount,
                    totalAmount: item.amountWithGST
                }));
                this.calculateTaxesAfterLoad(); // Optional: recalculate totals if needed
            })
            .catch((error) => {
                console.error('Error fetching invoice data:', error);
                this.showTable = false;
            });
		this.currencyCode = event.detail.subField || ''; // Default to INR if not provided
        //AP-05AUG25 Extract only the currency code part (e.g., "INR") for display
        this.currencyDisplay = Utility.extractCurrencyCode(this.currencyCode || '');
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
        const creditNoteWrapper = {
            creditNoteId: this.recordId ?? '',
            name: this.creditNote?.name || '',
            invoiceId: this.creditNote?.invoice || '',
            customerId: this.creditNote?.customerId|| '',
            category: this.creditNote?.category || '',
            billDate: this.creditNote?.billDate || null, // ensure it's Date or convert if needed
            reason: this.creditNote?.reason || '',
            createJournalEntry: this.creditNote?.createJournalEntry || false,
            cashReturn: this.creditNote?.cashReturn || false,
            message: this.creditNote?.message || '',
            exchangeRate: this.creditNote?.exchangeRate || 1,
            currencyCode: this.creditNote?.currency || '', // default to INR
            //KK 14/08/25 - Total of all creditNote Items totalAmount
            creditNoteTotalAmount: (this.creditNoteItems || []).reduce(
                (acc, item) => acc + (item.totalAmount ?? 0),
                0
            ),

            creditNoteItems: (this.creditNoteItems || [])
                .filter(item =>
                    item.productId || item.description || item.quantityReturn || item.unitPrice
                )
                .map((item, idx) => ({
                    keyField: item.keyField ?? idx + 1,
                    productId: item.productId || null,
                    invoiceItemId: item.invoiceItemId || null, //KK 1/Aug/25 - Added Key in creditNoteItems
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
        saveCreditNote({creditNoteWrapperJson: JSON.stringify(creditNoteWrapper)})
            .then(creditNoteId => {
                if(creditNoteId){
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Success',
                            message: 'Credit Note Saved Successfully',
                            variant: 'success'
                        })
                    );
                }              
            })
            .catch(error => {
                console.error('Error saving credit Note:', error);
                this.isSaveDisabled = false;
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: error.body?.message || 'Failed to save credit Note. Please try again.',
                    variant: 'error'
                }));
            });
    }

    removeItem(event) {
		const index = Number(event.currentTarget.dataset.index);
        if (!isNaN(index) && index >= 0 && index < this.creditNoteItems.length) {
            this.creditNoteItems.splice(index, 1);
            this.creditNoteItems = [...this.creditNoteItems];
        }
    }

    clearAllItems() {
		this.creditNoteItems = [{
			itemOrder: '',
            productId: '',
            invoiceItemId: '', //KK 1/Aug/25 - Added Key in creditNoteItems
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