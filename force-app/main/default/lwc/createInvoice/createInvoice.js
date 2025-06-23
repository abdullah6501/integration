import { LightningElement,api,track ,wire} from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { CurrentPageReference } from 'lightning/navigation';
import getSalesOrder from '@salesforce/apex/InvoiceCreationStockUpdate.getSalesOrder';
import getSoItems from '@salesforce/apex/InvoiceCreationStockUpdate.getSoItems';
import Createinvoice from '@salesforce/apex/InvoiceCreationStockUpdate.createInvoice';
import createJournalDeliveryNote from '@salesforce/apex/InvoiceCreationStockUpdate.CreateJournalDliveryNotes';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
export default class CreateInvoice extends NavigationMixin(LightningElement) {
   @api recordId;
   @track salesOrder;
   @track soItems;
   @track dateValue;
   @track isSalesOrderCreated = false;
   @track description = '';
   @track serialNumber = '';
   journalEntry = false;
   deliveryNotes = false;
   @track isButtonDisabled = false;
   @track isAmount = false;
   constructor() {
    super();
    const today = new Date();
    this.dateValue = this.formatDate(today);
     }

    formatDate(date) {
        const year = date.getFullYear();  
        const month = String(date.getMonth() + 1).padStart(2, '0');  
        const day = String(date.getDate()).padStart(2, '0');

        return `${year}-${month}-${day}`;
    }
    taxOptions = [
        { label: '5%', value: '5' },
        { label: '0%', value: '0' }
    ];
    get billingAddress() {
        const addr = this.salesOrder?.RFAB__Customer__r?.BillingAddress;
        if (addr) {
            return `${addr.street}, ${addr.city}, ${addr.postalCode}, ${addr.country}`;
        }
        return '';
    }
    
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.recordId = currentPageReference.attributes.recordId || this.recordId;
        }
    }
    @wire(getSalesOrder, { soId: '$recordId' })
    wiredSalesOrder({ error, data }) {
        
        if (data) {
            console.log('Sales Order Data:', JSON.stringify(data));
            if(data.RFAB__Status__c == 'Approved'){
              this.salesOrder = data;
            }else{
                this.showToast('Error', 'Unable to Create Invoice, Sales Order is not approved.', 'error');
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: this.recordId,
                        actionName: 'view'
                    }
                });
                setTimeout(() => {
                    window.location.reload();
                }, 2000);
                this.handleClose(); 
                //this.isSalesOrderCreated = true;
            }
            if (data.Total_Amount__c == null || data.Total_Amount__c == 0) {
                this.showToast('Error', 'SO items not created for this SalesOrder.', 'error');
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: this.recordId,
                        actionName: 'view'
                    }
                });
                this.handleClose();
                setTimeout(() => {
                    window.location.reload();
                }, 1000);
            }
            // this.isAmount = data.Discount_Type__c === 'Line Item Discount';
            this.isAmount = !data.Discount_Type__c || data.Discount_Type__c === 'Line Item Discount';

        } else if (error) {
            this.error = error;
            console.error('Error fetching sales order', this.error);
        }
    }
   
    @wire(getSoItems, { soId: '$recordId' })
    wiredData({ error, data }) {
        if (data) {
            if (data.errorMessage) {
                this.showToast('Error', data.errorMessage, 'error');
                this.isSalesOrderCreated = true;
            }
           // const serialMap = JSON.parse(JSON.stringify(data.stockSerials || {}));

            // this.soItems = data.items.map(item => ({
            //     ...item,
            //     Name: item.Name,
            //     RFAB__Quantity__c: item.RFAB__Quantity__c || 0, 
            //     RFAB__Unit_Price__c: item.RFAB__Unit_Price__c || 0.00,
            //     Tax_Percentage__c: item.Tax_Percentage__c || 0,
            //     RFAB__Total_Price__c: item.RFAB__Total_Price__c || 0.00,
            //     Serial_Number__c: item.RFAB__Is_Serial_Number__c ? '' : null 
            //     // ,
            //     // Serial_Number__c: (
            //     //     serialMap[item.RFAB__Product__c] &&
            //     //     serialMap[item.RFAB__Product__c].length > 0
            //     // )
            //     //     ? serialMap[item.RFAB__Product__c].pop()
            //     //     : '' 
                
            // }));
            this.soItems = data.items.map(item => {
                const isSerial = item.RFAB__Is_Serial_Number__c;
                return {
                    ...item,
                    Name: item.Name,
                    RFAB__Quantity__c: item.RFAB__Quantity__c || 0,
                    RFAB__Unit_Price__c: item.RFAB__Unit_Price__c || 0.00,
                    Tax_Percentage__c: item.Tax_Percentage__c || 0,
                    RFAB__Total_Price__c: item.RFAB__Total_Price__c || 0.00,
                    Serial_Number__c: isSerial ? '' : null,
                    isSerial: isSerial,
                    isSerialDisabled: !isSerial // explicit boolean
                };
            });
            
            
        } else if (error) {
            console.error('Error loading PurchaseOrder data', error);
        }
    }
    handleInputChange(event) {
        const fieldName = event.target.name;
        const index = event.target.dataset.index;
        const value = event.target.value;

        let updatedItem = { ...this.soItems[index] };
        updatedItem[fieldName] = value;

        if (fieldName === 'RFAB__Quantity__c' || fieldName === 'RFAB__Unit_Price__c') {
            const quantity = parseFloat(fieldName === 'RFAB__Quantity__c' ? value : updatedItem.RFAB__Quantity__c) || 0;
            const unitPrice = parseFloat(fieldName === 'RFAB__Unit_Price__c' ? value : updatedItem.RFAB__Unit_Price__c) || 0;
            const taxPercentage = parseFloat(updatedItem.Tax_Percentage__c) || 0;
            
            const subtotal = quantity * unitPrice;
            const taxAmount = subtotal * (taxPercentage / 100);
            updatedItem.RFAB__Total_Price__c = subtotal + taxAmount;
        }
        
        this.soItems = this.soItems.map((item, i) => 
            i == index ? updatedItem : item
        );
    }
    handleDeleteRow(event) {
        const index = event.target.dataset.index;
        // Remove the selected row from the saleOrderItems array
        this.soItems = this.soItems.filter((_, i) => i != index);
    }
    handleCheckboxChange(event) {
        const { name, checked } = event.target;
        if (name === "journalEntry") {
            this.journalEntry = checked;
        } else if (name === "deliveryNotes") {
            this.deliveryNotes = checked;
        }
    }
    handleSave() {
        this.isButtonDisabled = true;
        const missingSerial = this.soItems.some(item => item.isSerial && (!item.Serial_Number__c || item.Serial_Number__c.trim() === ''));

        if (missingSerial) {
            this.showToast('Error', 'Please enter all required Serial Numbers before saving.', 'error');
            return; // Stop execution if validation fails
        }
        let serialNumbers = this.soItems.map(item => item.Serial_Number__c || '');
        let description = this.soItems.map(item => item.Description__c || '');
        console.log('Serial Numbers:', serialNumbers, typeof serialNumbers);
        console.log('Description:', description, typeof description);
        console.log('Journal Entry:', this.journalEntry, typeof this.journalEntry);
        console.log('Delivery Notes:', this.deliveryNotes, typeof this.deliveryNotes);
        console.log('Sales Order ID:', this.recordId, typeof this.recordId);
        // Call Apex method
        Createinvoice({
            salesOrderId: this.recordId,
            soItemsJson: JSON.stringify(this.soItems), 
            description: description, 
            serialNumbers: serialNumbers,
            journalEntry: this.journalEntry,
            deliveryNotes: this.deliveryNotes
        })
        .then((invId) => {
            if(invId!= null){
            this.showToast('Success', 'Invoice Created Successfully', 'success');
            createJournalDeliveryNote({ inId: invId, soId:this.recordId})
             .then(() => {
                
                this.showToast('Success', 'Journal Entry Created Successfully', 'success');               
             });
            }
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.recordId,
                    actionName: 'view'
                }
            });
            
            setTimeout(() => {
                window.location.reload();
            }, 1000);
            this.handleClose(); 
             

        })
        .catch(error => {
            console.error('Error creating invoice:', error);
            const message = error?.body?.message || 'Unknown error';
             this.showToast('Error', message, 'error');
            // this.showToast('Error', 'Check Serial Number', 'error');
        });
    }
    showToast(title, message, variant) {
        const event = new ShowToastEvent({ title, message, variant });
        this.dispatchEvent(event);
    }
    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }
}