export default class BillWrapper {
    constructor(billRecord, billItems, recordId = null) {
        this.billId = recordId;
        this.name = billRecord.Name || '';
        this.vendorId = billRecord.Vendor__c || null;
		// Abdullah V S | 14-Aug-25 | Contract is removed from this component
        // this.contractId = billRecord.Contract__c || null;
        this.rfqId = billRecord.RFQ__c || null;
        this.billDate = billRecord.Bill_Date__c || null;
        this.dueDate = billRecord.Due_Date__c || null;
        this.status = billRecord.Status__c || 'Draft';
        this.createJournalEntry = billRecord.Create_Journal_Entry__c || false;
        this.billItems = this.processBillItems(billItems);
    }

    processBillItems(items) {
        return items
            .filter(item => item.Product__c || item.Description__c)
            .map(item => ({
                itemOrder: item.Item_Order__c || '',
                productId: item.Product__c || null,
                description: item.Description__c || '',
                unitPrice: item.Unit_Price__c || 0,
                quantity: item.Quantity__c || 0,
                taxRate: Math.round(parseFloat(item.Tax_Rate__c || 0) * 100), // Convert decimal to percentage
                selectedSerialNumbers: (item.selectedSerialNumbers || []).map(sn => sn.value)
            }));
    }

    toJSON() {
        return JSON.stringify(this);
    }
}