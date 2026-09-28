// JavaScript wrapper for SalesOrderWrapper Apex class
//RT 18/07/2025 Wrapper changes 
export default class SoWrapper {
    id;
    customerName;
    salesOrderName;
    lumpsumDiscountAmount;
    lumpsumDiscountPercentage;
    discountMode;
    discountType;
    taxPercentage;
    taxPercent;
    customerId;
    customerPORef;
    shippingTerms;
    paymentTerms;
    salesDate;
    status;
    type;
    title;

    constructor(data = {}) {
        this.id = data.id || null;
        this.customerName = data.customerName || '';
        this.customerPORef = data.customerPORef || '';
        this.salesOrderName = data.salesOrderName || '';
        this.lumpsumDiscountAmount = data.lumpsumDiscountAmount || 0;
        this.lumpsumDiscountPercentage = data.lumpsumDiscountPercenxtage || 0;
        this.discountMode = data.discountMode || '';
        this.discountType = data.discountType || '';
        this.taxPercentage = data.taxPercentage || '';
        this.taxPercent = data.taxPercent || 0;
        this.customerId = data.customerId || '';
        this.shippingTerms = data.shippingTerms || '';
        this.paymentTerms = data.paymentTerms || '';
        this.salesDate = data.salesDate || null;
        this.status = data.status || '';
        this.type = data.type || '';
        this.title = data.title || '';
    }
}