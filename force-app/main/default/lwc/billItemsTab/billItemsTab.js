//AR 11/07/2023 Table configuration from metadata - vIsiblity,label and width control
// AR 11/07/2023 Tax calculation and reverse charge handling
// AB 25JUL25 WIDTH CONTROL
// AAB 22AUG25 Rounding Off field Amount & total calculation update
// Abdullah V S | 22-Aug-25 | Dynamically sets visibility, read-only, and required flags for fields
import {LightningElement, track, api, wire} from 'lwc';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';
import {NavigationMixin} from 'lightning/navigation';
import saveBill from '@salesforce/apex/billItemsTabHandler.saveBill';
import getBillDetails from '@salesforce/apex/billItemsTabHandler.getBillDetails';
import getNslog from '@salesforce/apex/InvoiceFormController.getNslog';
import getStatusPicklistValues from '@salesforce/apex/billItemsTabHandler.getStatusPicklistValues';
import getTableFieldMetadata from '@salesforce/apex/TableFieldConfigUtility.getTableFieldMetadata'
import taxOptions from '@salesforce/apex/TaxUtility.getParentTaxes';
import createTaxDetailRecords from '@salesforce/apex/billItemsTabHandler.createTaxDetailRecords';
import deleteTaxDetails from '@salesforce/apex/billItemsTabHandler.deleteTaxDetails';
import Utility from 'c/utility';
//KK 12/Jul/25 Automated JE Function Implementation
import processBusinessEvent from '@salesforce/apex/JEEventService.processBusinessEvent';
export default class BillItemsTab extends NavigationMixin(LightningElement) {
	@api recordId; // To receive the record ID when in edit mode
	@track isNewMode = true;
	@track isSaveDisabled = false;
	//KK 1/Aug/25 - Flag to indicate if the save and send action is triggered
	@track saveAndSendFlag = false;
	@track showSpinner = false;
	@track currencyCode = ''; // Default currency code, can be customized as needed
	@track currencyDisplay = '';//AP-05AUG25 Display the currencyCode
	@track label;
	@track taxOptions = [];
	@track parentTaxOptions = [];
	@track componentName = 'billItem';
	@track visibilityFlags = {};
	@track readOnlyFlags = {};
	@track requiredFlags = {};
	@track isFormDisabled = false;
	@track taxDetails = [];
	@track uniqueTaxDetails = [];
	@track chosenParentTaxOption = 'Exclusive of Tax';
	@track isReverseChargeActive = false;
	@track tdsPercent;//AP-29AUG25 Track TDS percentage selected by the user (e.g., 2% or 10%)
	isTDS = false;//29AUG25 Boolean flag to check whether TDS toggle is enabled or not
	ns;
	productobjectApiName = 'Product__c';
	productadditionalFieldApiName = 'Actual_Cost__c';
	productotherFieldApiName = 'ProductCode__c';
	productlabel = 'Product';

	accountobjectApiName = 'Vendor__c';
	accountadditionalFieldApiName = 'TDS_Percentage__c';// AP-29AUG25 -- API name for TDS Percentage picklist field
	accountotherFieldApiName = 'Preferred_Currency_Code__c';
	accountlabel = 'Vendor';
	// Abdullah V S | 14-Aug-25 | Contract is removed from this component
	// contractobjectApiName = 'Contract';
	// contractadditionalFieldApiName = 'ContractNumber';
	// contractotherFieldApiName = 'ContractTerm';
	// contractlabel = 'Contract';


	rfqobjectApiName = 'RFQ__c';
	rfqadditionalFieldApiName = 'Scope_of_Work__c';
	rfqotherFieldApiName = 'Status__c';
	rfqlabel = 'RFQ';
	///AR 11/07/2023 Table configuration from metadata - vIsiblity,label and width control
	@wire(getTableFieldMetadata, { componentName: '$componentName' })
	wiredTableConfig({error, data}) {
		if (data) {
			this.visibilityFlags = {};
			this.readOnlyFlags = {};
			this.requiredFlags = {}; // Abdullah V S | 22-Aug-25
			this.labelList = {};
			//this.sizeClasses = {}; // add for width check
      this.width = {};
			data.forEach(row => {
				const {
					fieldAPI,
					visiblityMode,
					label,
					width // add for width check
				} = row;
				// Abdullah V S | 22-Aug-25 | Table Field Configuration Required Field implementation
				this.visibilityFlags[fieldAPI] = visiblityMode === 'Visible' || visiblityMode === 'Read Only' || visiblityMode === 'Required';
				this.labelList[fieldAPI] = row.label;
				this.readOnlyFlags[fieldAPI] = visiblityMode === 'Read Only';
				this.requiredFlags[fieldAPI] = visiblityMode === 'Required';
				//const sldsSize = width ? `width: ${(width/12*100).toFixed(2)}%;` : ''; // add for width check
				//this.sizeClasses[fieldAPI] = sldsSize; // add for width check
        		this.width[fieldAPI] = width;
			});

		} else if (error) {
			console.error('Error loading table configuration:', error);
		}
	}

	// Add this property at the top of your class with other properties


	// Modify the wiredTaxOptions method
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

			// If bill items are already loaded, calculate taxes
			if (this.billItems && this.billItems.length > 0) {
				this.calculateTaxesAfterLoad();
			}
		} else if (error) {
			console.error('Error fetching tax options:', error);
			this.taxOptions = [];
		}
	}

	// Add this new method
	calculateTaxesAfterLoad() {

		this.billItems.forEach((item, index) => {
			if (item.taxRate) {
				console.log(`Calculating tax for item ${index}:`, item);
				this.calculateTaxForLineItem(index);
			}
		});

		this.calculateAllTaxTotals();
		console.log('Final tax details:', this.taxDetails);

		// Force refresh of the billItems array
		this.billItems = [...this.billItems];
	}
	// Abdullah V S | 22-Aug-25 | Table Field Configuration Required Field implementation
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

	get vendorRecords() {
		return this.getFieldConfig('vendor');
	}

	get isRFQ() {
		return this.getFieldConfig('RFQ');
	}
	// Abdullah V S | 14-Aug-25 | Contract is removed from this component
	// get isContractVisible() {
	// 	return this.getFieldConfig('contract');
	// }

	get isCreateVoucherEntries() {
		return this.getFieldConfig('createVoucherEntries');
	}

	get isProduct() {
		return this.getFieldConfig('product');
    
	} 
  get isProductStyle() {
    return `width: ${this.isProduct.width};`;
  }



	get isSubTotal() {
		return this.getFieldConfig('subTotal');
	}
  get isSubTotalStyle() {
    return `width: ${this.isSubTotal.width};`;
  }

	get isTotal() {
		return this.getFieldConfig('total');
	}
  get isTotalStyle() {
    return `width: ${this.isTotal.width};`;
  }

	get isUnitPrice() {
		return this.getFieldConfig('unitPrice');
	}
  get isUnitPriceStyle() {
    return `width: ${this.isUnitPrice.width};`;
  }

	get isQuantity() {
		return this.getFieldConfig('quantity');
	}
  get isQuantityStyle() {
    return `width: ${this.isQuantity.width};`;
  }


	get isTax() {
		const taxConfig = this.getFieldConfig('tax');
		return {
			...taxConfig,
			visible: taxConfig.visible && this.chosenParentTaxOption !== 'Out of scope of Tax'
		};
	}
  get isTaxStyle() {
    return `width: ${this.isTax.width};`;
  }

	get isTaxAmount() {
		const taxAmountConfig = this.getFieldConfig('taxAmount');
		return {
			...taxAmountConfig,
			visible: taxAmountConfig.visible && this.chosenParentTaxOption !== 'Out of scope of Tax'
		};
	}
  get isTaxAmountStyle() {
    return `width: ${this.isTaxAmount.width};`;
  }
	get isDescription() {
		return this.getFieldConfig('description');
	}
  get isDescriptionStyle() {
    return `width: ${this.isDescription.width};`;
  }

	get isButtonDisabled() {
		return this.isFormDisabled || this.isSaveDisabled;
	}

	@wire(getNslog)
	handleNamespace({error, data}) {
		if (data) {
			this.ns = data.nameSpace != 'null' ? data.nameSpace : '';

			// Configure Product namespace
			this.productobjectApiName = data.nameSpace != 'null' ? data.nameSpace + this.productobjectApiName : this.productobjectApiName;
			this.productadditionalFieldApiName = data.nameSpace != 'null' ? data.nameSpace + this.productadditionalFieldApiName : this.productadditionalFieldApiName;
			this.productotherFieldApiName = data.nameSpace != 'null' ? data.nameSpace + this.productotherFieldApiName : this.productotherFieldApiName;
			this.productlabel = data.nameSpace != 'null' ? data.nameSpace + this.productlabel : this.productlabel;

			// Configure Account namespace
			this.accountobjectApiName = data.nameSpace != 'null' ? data.nameSpace + this.accountobjectApiName : this.accountobjectApiName;
			this.accountadditionalFieldApiName = data.nameSpace != 'null' ? data.nameSpace + this.accountadditionalFieldApiName : this.accountadditionalFieldApiName;
			this.accountotherFieldApiName = data.nameSpace != 'null' ? data.nameSpace + this.accountotherFieldApiName : this.accountotherFieldApiName;
			this.accountlabel = data.nameSpace != 'null' ? data.nameSpace + this.accountlabel : this.accountlabel;

			// Abdullah V S | 14-Aug-25 | Contract is removed from this component
			// Configure Contract namespace
			// this.contractobjectApiName = data.nameSpace != 'null' ? data.nameSpace + this.contractobjectApiName : this.contractobjectApiName;
			// this.contractadditionalFieldApiName = data.nameSpace != 'null' ? data.nameSpace + this.contractadditionalFieldApiName : this.contractadditionalFieldApiName;
			// this.contractotherFieldApiName = data.nameSpace != 'null' ? data.nameSpace + this.contractotherFieldApiName : this.contractotherFieldApiName;
			// this.contractlabel = data.nameSpace != 'null' ? data.nameSpace + this.contractlabel : this.contractlabel;

			// Configure RFQ namespace
			this.rfqobjectApiName = data.nameSpace != 'null' ? data.nameSpace + this.rfqobjectApiName : this.rfqobjectApiName;
			this.rfqadditionalFieldApiName = data.nameSpace != 'null' ? data.nameSpace + this.rfqadditionalFieldApiName : this.rfqadditionalFieldApiName;
			this.rfqotherFieldApiName = data.nameSpace != 'null' ? data.nameSpace + this.rfqotherFieldApiName : this.rfqotherFieldApiName;
			this.rfqlabel = data.nameSpace != 'null' ? data.nameSpace + this.rfqlabel : this.rfqlabel;

		} else if (error) {
			console.error('Error loading namespace:', error);
		}
	}

	@track billRecord = {
		Name: '',
		VendorAccount__c: '',
	// Abdullah V S | 14-Aug-25 | Contract is removed from this component
		// Contract__c: '', 
		RFQ__c: '',
		billDate: '',
		dueDate: '',
		status: '',
		createJournalEntry: false,
		amountsAre: '',
		message: '', // For Message_Of_Bill__c
		roundingOff: '0.00' // For Rounding_Off__c, default to '0.00'
	};

	// Selected Record tracking
	@track vendorSelectedRecord = {
		id: null,
		name: null
	};
	// Abdullah V S | 14-Aug-25 | Contract is removed from this component
	// @track contractSelectedRecord = {
	// 	id: null,
	// 	name: null
	// };
	@track rfqSelectedRecord = {
		id: null,
		name: null
	};

	// Handle Vendor Selection
	handleValueSelectedOnVendor(event) {
		if (!event.detail || !event.detail.id) {
			return;
		}
		this.vendorSelectedRecord = {
			id: event.detail.id,
			name: event.detail.mainField
		};
		this.currencyCode = event.detail.subField || ''; // Default to INR if not provided
		this.billRecord.VendorAccount__c = event.detail.id;
		this.preferredCurrency = event.detail.subField || '';
		this.tdsPercent = event.detail.additionalField; // Set TDS percentage
		// AP-04AUG25 | Extract only the currency code using Utility (e.g., "INR" from "INR - Indian Rupee")
		// AP-05AUG25 Renamed currencyCode to currencyDisplay
       this.currencyDisplay = Utility.extractCurrencyCode(this.preferredCurrency);
	   this.calculateTDSAmount();
	}

	handleVendorLoad(event) {
		console.log('Vendor loaded with currency code:', this.currencyCode);
		console.log('Vendor selected record:', JSON.stringify(event.detail));

	}

	handleVendorValRemoval() {
		this.vendorSelectedRecord = {
			id: null,
			name: null
		};
		this.billRecord.VendorAccount__c = null;
	}

	// Abdullah V S | 14-Aug-25 | Contract is removed from this component
	// Handle Contract Selection
	// handleValueSelectedOnContract(event) {
	// 	if (!event.detail || !event.detail.id) {
	// 		console.error('Invalid contract selection event:', event);
	// 		return;
	// 	}
	// 	this.contractSelectedRecord = {
	// 		id: event.detail.id,
	// 		name: event.detail.mainField
	// 	};
	// 	this.billRecord.Contract__c = event.detail.id;
	// }

	// handleContractValRemoval() {
	// 	this.contractSelectedRecord = {
	// 		id: null,
	// 		name: null
	// 	};
	// 	this.billRecord.Contract__c = null;
	// }

	// Handle RFQ Selection
	handleValueSelectedOnRFQ(event) {
		if (!event.detail || !event.detail.id) {
			console.error('Invalid RFQ selection event:', event);
			return;
		}
		this.rfqSelectedRecord = {
			id: event.detail.id,
			name: event.detail.mainField
		};
		this.billRecord.RFQ__c = event.detail.id;
	}

	@track billItems = [{
		itemOrder: '',
		productId: null, // Abdullah V S | 18-Aug-25 | Id should be null or value 
		billItemName: '', // AP-30JUL25 - Manual entry for item name 
		isBillItemName: false, // AP-30JUL25 - Flag to indicate if billItemName was manually entered
		description: '',
		unitPrice: 0,
		quantity: 1,
		taxRate: null,
		total: 0,
		taxAmount: 0,
		amount: 0,
		productSelectedRecord: null
	}];

	get numberedBillItems() {
		return this.billItems.map((item, index) => ({
			...item,
			lineNumber: index + 1
		}));
	}

	@wire(getStatusPicklistValues)
	wiredStatusOptions({error, data}) {
		if (data) {
			this.statusOptions = data.BillStatus.map(status => ({
				label: status,
				value: status
			}));
			this.parentTaxOptions = data.InvoiceAmountsAre.map(option => ({
				label: option,
				value: option
			}));
		} else if (error) {
			console.error('Error loading status options:', error);
		}
	}

	handleInputChange(event) {
		const field = event.target.dataset.id;
		this.billRecord[field] = event.target.value;
	}

	handleCheckboxChange(event) {
		this.billRecord[event.target.dataset.id] = event.target.checked;
	}

	get amountInWords() {
		// Abdullah V S | 25-Jul-25 | Convert total amount to words based on the selected currency using utility method.
        return Utility.convertToWords(this.grandTotal, this.currencyCode) + ' only';
	}

	//AR 11/07/2023 Tax calculation and reverse charge handling
	taxpercent(taxRate) {
		if (!taxRate || !this.taxOptions) {
			return 0;
		}
		const selectedTax = this.taxOptions.find(option => option.value === taxRate);
		return selectedTax ? parseFloat(selectedTax.percentage) : 0;
	}

	//reversed charge
	get showTaxDetailsSection() {
		//AR 8/Aug/25 Show tax details section only if tax is visible and not out of scope
		return !this.isReverseChargeActive && this.isTax &&
		this.chosenParentTaxOption !== 'Out of scope of Tax';
	}

	handleReverseChargeChange(event) {
		this.isReverseChargeActive = event.target.checked;
		if (this.isReverseChargeActive) {
			// Filter to show only RCM tax options
			this.taxOptions = this.taxOptions.filter(option =>
				option.fullData && option.fullData.isRCM === true
			);
		} else {
			this.refreshTaxOptions();
		}
	}

	// Add this method to refresh tax options
	refreshTaxOptions() {
		taxOptions()
			.then(result => {
				this.taxOptions = result.map(option => ({
					label: option.parentTaxName,
					value: option.parentTaxId,
					parentTaxId: option.parentTaxId,
					percentage: option.parentTaxPercentage,
					fullData: option
				}));
			})
			.catch(error => {
				console.error('Error refreshing tax options:', error);
			});
	}

	handleItemChange(event) {
		const index = parseInt(event.target.dataset.index);
		const field = event.target.dataset.id;
		this.billItems[index][field] = event.target.value;
        //AR 19/Aug/25 Set taxPercent based on taxRate
		if (field === 'taxRate') {
			const taxRate = event.target.value;
			this.billItems[index].taxPercent = this.taxpercent(taxRate);
		}
		// Recalculate totals for this line item
		const item = this.billItems[index];
		const unitPrice = parseFloat(item.unitPrice) || 0;
		const quantity = parseFloat(item.quantity) || 0;
		const subtotal = unitPrice * quantity;

		// Set the subtotal
		this.billItems[index].total = parseFloat(subtotal.toFixed(2));

		if (field === 'taxRate' || field === 'unitPrice' || field === 'quantity') {
			this.calculateTaxForLineItem(index);
		}

		this.calculateAllTaxTotals();
		this.billItems = [...this.billItems];
		this.calculateTDSAmount();
	}

	handleParentTaxChange(event) {
		this.chosenParentTaxOption = event.detail.value;
		this.billRecord.amountsAre = event.detail.value;
		this.billItems.forEach((item, index) => {
			if (this.chosenParentTaxOption === 'Out of scope of Tax') {
				item.taxRate = null;
			}
			//AR 8/Aug/25 Set taxDetails to empty if not out of scope
			else{
				this.taxDetails = [];
			}
			if (item.taxRate) {
				this.calculateTaxForLineItem(index);
			}

			this.billItems = [...this.billItems];

		});
		this.calculateTDSAmount();
	}
	// AP-29AUG25 -- Handle TDS toggle change
	handleTDS(event) {
		const name = event.target.name;

		if(name === "tdsToggle") {
			this.isTDS = event.target.checked;
		} else {
			this.isTDS = false;
		}
	}

	calculateTaxForLineItem(index) {
		const item = this.billItems[index];
		//AR 8/Aug/25 added zero tax detail record creation
		if (this.chosenParentTaxOption === 'Out of scope of Tax') {
			this.billItems[index].taxAmount = 0;
			this.billItems[index].amount = Number(parseFloat(item.total || 0).toFixed(2));
			return;
		}
		const selectedTax = this.taxOptions.find(option => option.value === item.taxRate);

		if (selectedTax && this.chosenParentTaxOption !== 'Out of scope of Tax') {
			// Ensure proper number parsing
			const subtotal = Number(parseFloat(item.total || 0));
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
			this.billItems[index].taxAmount = Number(totalTaxAmount.toFixed(2));

			if (this.chosenParentTaxOption === 'Exclusive of Tax') {
				this.billItems[index].amount = Number((subtotal + totalTaxAmount).toFixed(2));
			} else if (this.chosenParentTaxOption === 'Inclusive of Tax') {
				this.billItems[index].amount = Number(subtotal.toFixed(2));
			}
		} else {
			this.billItems[index].taxAmount = 0;
			this.billItems[index].amount = Number(parseFloat(item.total || 0).toFixed(2));
		}
	}

	calculateAllTaxTotals() {
		const taxDetails = [];
		//AR 8/Aug/25 added zero tax detail record creation
		if (this.chosenParentTaxOption === 'Out of scope of Tax') {
			const zeroTax = this.taxOptions.find(tax => tax.percentage === 0) || this.taxOptions[0];
			console.log('Zero Tax Option:', JSON.stringify(zeroTax));
	
			if (zeroTax) {
				taxDetails.push({
					taxName: zeroTax.label,
					taxId: zeroTax.value,
					taxAmount: 0,
					lineItemIndex: 0,  
					percentage: 0
				});
			}
		}
        else{
			this.billItems.forEach((item, index) => {
				if (!item.taxRate) return;

				const selectedTax = this.taxOptions.find(option => option.value === item.taxRate);
				if (!selectedTax) return;

				const subtotal = parseFloat(item.total) || 0;

				if (selectedTax.fullData.childTaxes && selectedTax.fullData.childTaxes.length > 0) {
					selectedTax.fullData.childTaxes.forEach(childTax => {
						const taxAmount = (subtotal * childTax.childTaxPercentage) / 100;
						taxDetails.push({
							taxName: childTax.childTaxName,
							taxId: childTax.childTaxId,
							taxAmount: parseFloat(taxAmount.toFixed(2)),
							lineItemIndex: index,
							billItemId: item.id || `item${index + 1}`,
							subtotal: subtotal,
							percentage: childTax.childTaxPercentage
						});
					});
				} else {
					console.log(`selectedTax.fullData.childTaxes.length === 0`);

					const taxAmount = (subtotal * selectedTax.percentage) / 100;
					taxDetails.push({
						taxName: selectedTax.label,
						taxId: selectedTax.value,
						taxAmount: parseFloat(taxAmount.toFixed(2)),
						lineItemIndex: index,
						billItemId: item.id || `item${index + 1}`,
						subtotal: subtotal,
						percentage: selectedTax.percentage
					});
					console.log(
						`selectedTax.fullData.childTaxes.length === 0`, taxDetails);

				}
			});
		}
		// Group taxes by name for display
		const groupedTaxes = taxDetails.reduce((acc, tax) => {
			if (!acc[tax.taxName]) {
				acc[tax.taxName] = {
					taxName: tax.taxName,
					taxAmount: 0,
					details: []
				};
			}
			acc[tax.taxName].details.push(tax);
			acc[tax.taxName].taxAmount += tax.taxAmount;
			return acc;
		}, {});

		this.taxDetails = Object.values(groupedTaxes).map(group => ({
			taxName: group.taxName,
			taxAmount: parseFloat(group.taxAmount.toFixed(2)),
			details: group.details
		}));
	}

	/// AR DRAG AND DROP
	@track dragSource;
	@track dragTarget;

	handleDragStart(event) {
		this.dragSource = event.target.closest('tr');
	}

	handleDragOver(event) {
		event.preventDefault();
		this.dragTarget = event.target.closest('tr');
	}
	handleDrop(event) {
		event.preventDefault();
		const fromIndex = parseInt(this.dragSource.dataset.index);
		const toIndex = parseInt(this.dragTarget.dataset.index);

		if (fromIndex === toIndex) return;

		const items = [...this.billItems];
		const [movedItem] = items.splice(fromIndex, 1);
		items.splice(toIndex, 0, movedItem);

		// Update keyFields and line numbers
		this.billItems = items.map((item, index) => ({
			...item,
			keyField: `item-${index}`,
			lineNumber: index + 1
		}));

		// Force component re-render
		this.billItems = [...this.billItems];

		this.isSaveDisabled = false;
	}

	// Debounce timer property for product selection

	productSelectionTimer;
	handleProductSelected(event) {
		// Clear any existing timeout
		if (this.productSelectionTimer) {
			clearTimeout(this.productSelectionTimer);
		}
		const index = event.target.dataset.index;
		const selectedItem = event.detail;
		if (this.billItems[index]) {
			this.billItems[index].billItemName =  selectedItem.value;// AP-30JUL25 - Save manually selected billItem name
			this.billItems[index].productId = null; 
		}
		const rowIndex = selectedItem.rowId;
		if (selectedItem && rowIndex !== undefined) {
			this.productSelectionTimer = setTimeout(() => {
				// Create a new copy of the bill item with updated values
				const updatedBillItem = {
					...this.billItems[rowIndex],
					productId: selectedItem.id,
					productSelectedRecord: true
				};

				// Update the array directly with the new item
				this.billItems = [
					...this.billItems.slice(0, rowIndex),
					updatedBillItem,
					...this.billItems.slice(rowIndex + 1)
				];
			}, 100); // 100ms delay
		}
	}

	handleProductRemoval(event) {
		const index = parseInt(event.target.dataset.index);

		// Reset all product related fields
		this.billItems[index].productId = null; // Abdullah V S | 14-Aug-25 
		this.billItems[index].description = '';
		this.billItems[index].unitPrice = 0;
		this.billItems[index].productSelectedRecord = null;


		this.updateItemTotals(index);

		// Force refresh 
		this.billItems = [...this.billItems];
	}

	updateItemTotals(index) {
		const item = this.billItems[index];
		const unitPrice = parseFloat(item.unitPrice) || 0;
		const quantity = parseFloat(item.quantity) || 0;
		let taxRatePercent = parseFloat(item.taxRate);

		// Handle invalid tax rates - store and display as percentage (e.g., 2 for 2%)
		taxRatePercent = !isNaN(taxRatePercent) ? taxRatePercent : 0;

		// Calculate subtotal first
		const subtotal = unitPrice * quantity;
		item.total = subtotal;

		// Tax calculation will be handled by formula field in the backend
		const taxAmount = subtotal * (taxRatePercent / 100);
		item.taxAmount = taxAmount;

		// Total amount includes tax
		item.amount = subtotal + taxAmount;

		// Force reactivity
		this.billItems = [...this.billItems];
	}

	addItem() {
		this.billItems.push({
			itemOrder: '',
			productId: null, // Abdullah V S | 18-Aug-25 | Id should be null or value 
			billItemName: '',// AP-30JUL25
			description: '',
			unitPrice: 0,
			quantity: 1,
			taxRate: null,
			total: 0,
			amount: 0
		});
		this.billItems = [...this.billItems];
	}

	removeItem(event) {
		const index = event.target.dataset.index;
		this.billItems.splice(index, 1);
		if (this.billItems.length === 0) {
			this.addItem();
		}
		this.billItems = [...this.billItems];
	}

	clearAllItems() {
		this.billItems = [{
			itemOrder: '',
			productId: null, // Abdullah V S | 18-Aug-25 | Id should be null or value 
			billItemName: '',// AP-30JUL25
			description: '',
			unitPrice: 0,
			quantity: 0,
			taxRate: null,
			total: 0,
			taxAmount: 0,
			amount: 0
		}];
	}

	get subtotal() {
		const total = this.billItems.reduce((sum, item) => {
			const itemTotal = Number(parseFloat(item.total || 0));
			return sum + itemTotal;
		}, 0);
		return Number(total.toFixed(2));
	}

	get taxTotal() {
		if (this.chosenParentTaxOption === 'Out of scope of Tax') {
			return 0;
		}
		const total = this.billItems.reduce((sum, item) => {
			const taxAmount = Number(parseFloat(item.taxAmount || 0));
			return sum + taxAmount;
		}, 0);
		return Number(total.toFixed(2));
	}

	@track roundingOff = '0.00'; // Default value

	handleRoundingOffChange(event) {
		let value = event.target.value;
		// Ensure value is a valid number, fallback to 0.00
		if (isNaN(value) || value === '') {
			value = '0.00';
		}
		this.roundingOff = value;
		this.calculateTDSAmount();

	}

	get grandTotal() {
		const subtotal = Number(this.subtotal) || 0;
		const taxTotal = Number(this.taxTotal) || 0;
		const rounding = Number(this.roundingOff) || 0;
		const billAmount = this.chosenParentTaxOption === 'Exclusive of Tax' && !this.isReverseChargeActive
			? subtotal + taxTotal + rounding
			: subtotal + rounding;
		
		// Always recalculate TDS if enabled and percentage is available
		if (this.isTDS && this.tdsPercent && !isNaN(parseFloat(this.tdsPercent))) {
			this.billRecord.tds = parseFloat(((parseFloat(this.tdsPercent) / 100) * billAmount).toFixed(2));
		} else if (!this.isTDS) {
			this.billRecord.tds = 0;
		}
		
		return parseFloat((billAmount - (this.billRecord.tds || 0)).toFixed(2));
	}

	// Add this getter to calculate the Net Payable Amount dynamically
	get netPayableAmount() {
		const billAmount = this.grandTotal || 0;
		const tdsAmount = (billAmount * this.tdsPercentage) / 100;
		this.tdsAmount = parseFloat(tdsAmount.toFixed(2));
		return parseFloat((billAmount - this.tdsAmount).toFixed(2));
	}
    
	handleSaveSubmit() {
		this.billRecord.status = 'Submitted';
		//KK 1/Aug/25 - Changing Flag to indicate if the save and send action is triggered
		this.saveAndSendFlag = true;
		this.handleSave();
	}

	handleSave() {
		this.isSaveDisabled = true;
        // Abdullah V S | 22-Aug-25 | Client-side validation for required input fields
		const inputs = this.template.querySelectorAll('.validate');
        let isValid = true;
		try {
			inputs.forEach(input => {
				// check if it's a standard input (has checkValidity function)
				if (typeof input.checkValidity === 'function') {
					if (!input.checkValidity()) {
						input.reportValidity();
						isValid = false;
					}
				} 
				// handle reusable lookup
				else if (input.tagName === 'C-REUSABLE-LOOKUP') {
					const selectedId = input.selectedRecordId;
					const isRequired = input.required;

					if (isRequired && !selectedId) {
						console.warn('Lookup required but not filled:', input);
						isValid = false;
					} 
				}
			});
		}
		catch {
			console.log('Error in validation' );
		}
        if(!isValid){
			this.isSaveDisabled = false;
            this.showToast('Error', 'Please fill all required fields.', 'warning');
            return;
        }
		console.log('Saving bill...', 'isValid:', isValid);
		this.billItems = this.billItems.map((item, index) => ({
			...item,
			keyField: index + 1
		}));
		console.log('Saving bill with items:', JSON.stringify(this.billItems));
		const billWrapper = {
			billId: this.recordId ?? null, // use billId instead of id
			name: this.billRecord.Name || '',
			vendorId: this.billRecord.VendorAccount__c || null,
			// Abdullah V S | 14-Aug-25 | Contract is removed from this component
			// contractId: this.billRecord.Contract__c || null, 
			rfqId: this.billRecord.RFQ__c || null,
			billDate: this.billRecord.billDate || null,
			dueDate: this.billRecord.dueDate || null,
			grandTotal: this.grandTotal,
			status: this.billRecord.status || 'Inprogress', // AAB 29AUG25 changed default status to 'Inprogress'
			createJournalEntry: this.billRecord.createJournalEntry || false,
			amountsAre: this.chosenParentTaxOption,
			isRCM: this.isReverseChargeActive,
			message: this.billRecord.message || '', // Map to Message_Of_Bill__c
			//AR 19/Aug/25 - Added tax Amount to store in bill
			taxAmount: this.taxTotal,
			roundingOff: parseFloat(this.roundingOff) || 0, // Always send as number
			tds: this.billRecord.tds,// AP-29AUG25 -- TDS value from the bill record
			billItems: this.billItems
			// The below lines were commented intentionally because some bill items
		    // are added without a productId (e.g., manual/service entries).
		    // We should not filter them out unless business logic requires strict validation.
		   // .filter(item => item.productId || item.description) // Only include items that have either a product or description

				// .map((item, idx) => ({
				// 	...item,
				// 	keyField: item.keyField, // Include keyField
				// 	itemOrder: item.keyField.toString() // Use keyField for itemOrder
				// }))
		};
		console.log('Bill Wrapper:', JSON.stringify(billWrapper));
		// AAB 29AUG25 - Prevent saving if no vendor is selected
		if(billWrapper == null || billWrapper.vendorId == null){
			this.isSaveDisabled = false;
			this.showToast('Error', 'Bill data is required.', 'warning');
			return;
		}
		saveBill({billWrapperJson: JSON.stringify(billWrapper)})
			.then(billId => {
				//AR 8/Aug/25 - Remove deleted tax details check its already handle in apex method
				// Create tax detail records only if we have tax details
				//AR 8/Aug/25 - removes the check for 'Out of scope of Tax' here
				if (this.taxDetails && this.taxDetails.length > 0) {
					createTaxDetailRecords({
							taxDetailsList: this.taxDetails,
							billId: billId,
							isReverseChargeActive: this.isReverseChargeActive
						})
						.then(async () => {
							this.dispatchEvent(new ShowToastEvent({
								title: 'Success',
								message: 'Bill and tax details saved successfully!',
								variant: 'success'
							}));
              				//KK 12/Jul/25 Automated JE Function Implementation
							//processBusinessEvent here after tax details are fully saved
							//KK 1/Aug/25 - Added check for saveAndSendFlag
							if (this.billRecord.createJournalEntry && billId && this.saveAndSendFlag) {
								try {
									await processBusinessEvent({
										eventName: 'Vendor Bill Received',
										recordId: billId,
										relatedIds: [this.billRecord.VendorAccount__c]
									});
									// KK 29AUG25 Rounding Off JE (Dr/Cr Rounding vs Vendor)
									if (billWrapper.roundingOff != 0) {
										let relatedIds = [this.billRecord.VendorAccount__c];

										if (billWrapper.roundingOff > 0) {
											// Bill is higher → Expense
											relatedIds.push('RoundingOffExpense');
										} else {
											// Bill is lower → Income
											relatedIds.push('RoundingOffIncome');
										}
										console.log('Processing Rounding Off JE with relatedIds:', relatedIds);
										await processBusinessEvent({
											eventName: 'Vendor Bill Received',
											recordId: billId,
											relatedIds: relatedIds
										});
									}
								} catch (error) {
									console.error('Error processing business event:', error);
									this.showToast('Warning', 'Bill saved but business event processing failed', 'warning');
								}
							}
            })
						.catch(error => {
							console.error('Error creating tax details:', error);
							this.dispatchEvent(new ShowToastEvent({
								title: 'Warning',
								message: 'Bill saved but error creating tax details: ' + (error.body?.message || error.message),
								variant: 'warning'
							}));
						});
				} else {
					this.dispatchEvent(new ShowToastEvent({
						title: 'Success',
						message: 'Bill saved successfully!',
						variant: 'success'
					}));
            //KK 12/Jul/25 Automated JE Function Implementation
					//Without tax details, we can process the business event
					if (this.billRecord.createJournalEntry && billId && this.chosenParentTaxOption == 'Out of scope of Tax' && this.saveAndSendFlag) {
						try {
							processBusinessEvent({
								eventName: 'Vendor Bill Received',
								recordId: billId,
								relatedIds: [this.billRecord.VendorAccount__c]
							});
							// KK 29AUG25 Rounding Off JE (Dr/Cr Rounding vs Vendor)
							if (billWrapper.roundingOff != 0) {
								let relatedIds = [this.billRecord.VendorAccount__c];

								if (billWrapper.roundingOff > 0) {
									// Bill is higher → Expense
									relatedIds.push('RoundingOffExpense');
								} else {
									// Bill is lower → Income
									relatedIds.push('RoundingOffIncome');
								}
								console.log('Processing Rounding Off JE with relatedIds:', relatedIds);
								processBusinessEvent({
									eventName: 'Vendor Bill Received',
									recordId: billId,
									relatedIds: relatedIds
								});
							}
						} catch (error) {
							console.error('Error processing business event:', error);
							this.showToast('Warning', 'Bill saved but business event processing failed', 'warning');
						}
					}
				}

				setTimeout(() => {
					this[NavigationMixin.Navigate]({
						type: 'standard__recordPage',
						attributes: {
							recordId: billId,
							objectApiName: this.ns ? this.ns + 'Bill__c' : 'Bill__c',
							actionName: 'view'
						}
					});
				}, 3000);
			})
			.catch(error => {
				console.error('Error saving bill:', error);
				this.dispatchEvent(new ShowToastEvent({
					title: 'Error',
					message: error.body?.message || 'Failed to save bill. Please try again.',
					variant: 'error'
				}));
			});
    }
	clearForm() {
		this.billRecord = {
			Name: '',
			VendorAccount__c: '',
			RFQ__c: '',
			billDate: '',
			dueDate: '',
			status: '',
			createJournalEntry: false,
			amountsAre: '',
			message: '',
			roundingOff: '0.00' // Reset to default
		};

    	this.vendorSelectedRecord = {
			id: null,
			name: null
		};
		// Abdullah V S | 14-Aug-25 | Contract is removed from this component
		// this.contractSelectedRecord = {
		// 	id: null,
		// 	name: null
		// };
		this.rfqSelectedRecord = {
			id: null,
			name: null
		};

		this.clearAllItems();
	}

	handleCancel() {
		window.history.back();
	}

	validateFields() {
		// All fields are optional now
		return true;
	}
	connectedCallback() {
		if (this.recordId) {
			this.isNewMode = false;
			this.loadBillDetails();

		}
	}

	// AAB 29AUG25 - Disable quanity when form is disabled or readOnly
	get quantityDisabled() {
		return this.isFormDisabled || this.isQuantity.readOnly; 
	}

	loadBillDetails() {
		this.showSpinner = true;
		if (this.recordId) {
			getBillDetails({
					billId: this.recordId
				})
				.then(result => {
					console.log('Bill details loaded:', JSON.stringify(result));
					console.log('Bill item:', JSON.stringify(result.billItems));
					this.chosenParentTaxOption = result.amountsAre || 'Exclusive of Tax';
					if (result.status == 'Draft' || result.status == 'Submitted') { // AAB 29AUG25 - Freeze form if status is Draft or Submitted
						this.isFormDisabled = true;
					}
					if(result.tds && result.tds > 0){
						this.isTDS = true;
					}
					// Update bill record
					this.billRecord = {
						Name: result.name,
						VendorAccount__c: result.vendorId,
						tdsPercentage: result.tdsPercentage,
						// Abdullah V S | 14-Aug-25 | Contract is removed from this component
						// Contract__c: result.contractId, 
						RFQ__c: result.rfqId,
						billDate: result.billDate,
						dueDate: result.dueDate,
						currencyCode: result.currencyCode,
						status: result.status,
						createJournalEntry: result.createJournalEntry,
						amountsAre: result.amountsAre,
						totalAmount: result.grandTotal || 0,
						message: result.message || '',
						tds: result.tds || '0.00',// AP-29AUG25 -- Assign TDS value, defaulting to '0.00'
						roundingOff: result.roundingOff || '0.00' // Default to '0.00' if null 
					};
					this.tdsPercent = result.vendorTDSPercent; // AP-29AUG25 -- Set vendor TDS percent to local variable
					this.roundingOff = this.billRecord.roundingOff;
					this.isReverseChargeActive = result.isRCM;
					this.currencyCode = result.currencyCode || '';
					//AP-05AUG25 Extract only the currency code part (e.g., "INR") for display
					this.currencyDisplay = Utility.extractCurrencyCode(result.currencyCode || '');


					// Update selected records - THIS IS THE FIX
					this.vendorSelectedRecord = {
						id: result.vendorId,
						name: result.vendorName
					};
					// Fixed code:
					// Abdullah V S | 14-Aug-25 | Contract is removed from this component
					// this.contractSelectedRecord = {
					// 	id: result.contractId,
					// 	name: result.contractNumber || result.contractName // Use the correct field name
					// };

					this.rfqSelectedRecord = {
						id: result.rfqId,
						name: result.rfqNumber || result.rfqName
					};

					// Sort and update bill items
					const sortedItems = result.billItems.sort((a, b) =>
						(a.keyField || 0) - (b.keyField || 0)
					);

					this.billItems = sortedItems.map((item, index) => ({
						itemOrder: item.itemOrder,
						keyField: item.keyField || (index + 1),
						productId: item.productId,
						billItemName: item.productId ? '' : item.billItemName,// AP-30JUL25 - Use billItemName if productId is null (manual entry)
						isBillItemName: item.productId ? false : true,// AP-30JUL25 - Flag to indicate manual entry mode
						description: item.description,
						unitPrice: Number(parseFloat(item.unitPrice || 0)),
						quantity: Number(parseFloat(item.quantity || 1)),
						taxRate: item.taxRate,
						//AR 19/Aug/2025 Added taxPercent for tax calculation
						taxPercent: item.taxPercent,
						total: Number(parseFloat(item.total || 0)),
						taxAmount: Number(parseFloat(item.taxAmount || 0)),
						amount: Number(parseFloat(item.amount || 0))
					}));

					// Only calculate taxes if tax options are loaded
					if (this.taxOptionsLoaded) {
						setTimeout(() => {
							this.calculateTaxesAfterLoad();
							
						}, 0);
					}
					this.showSpinner = false;
					// Abdullah V S | 14-Aug-25 | Contract is removed from this component
					// console.log('Contract data from server:--->', JSON.stringify({
					// 	contractId: result.contractId,
					// 	contractNumber: result.contractNumber,
					// 	contractName: result.contractName
					// }));
				})
				.catch(error => {
					this.showSpinner = false;
					console.error('Error loading bill details:', error);
					this.dispatchEvent(
						new ShowToastEvent({
							title: 'Error',
							message: 'Error loading bill details: ' + (error.body?.message || error.message),
							variant: 'error'
						})
					);
				});
		}
	}
// AP-29AUG25 -- Method to calculate TDS amount based on selected percentage and bill values
	calculateTDSAmount() {
		if (!this.isTDS || !this.tdsPercent || isNaN(parseFloat(this.tdsPercent))) {
			this.billRecord.tds = this.isTDS ? this.billRecord.tds || 0 : 0;
		    return;
		}
		const subtotal = Number(this.subtotal) || 0;
		const taxTotal = Number(this.taxTotal) || 0;
		const rounding = Number(this.roundingOff) || 0;
		const billAmount = this.chosenParentTaxOption === 'Exclusive of Tax' && !this.isReverseChargeActive
			? subtotal + taxTotal + rounding
			: subtotal + rounding;
		
		this.billRecord.tds = parseFloat(((parseFloat(this.tdsPercent) / 100) * billAmount).toFixed(2));
	}

	showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
    }
}