// JavaScript wrapper for SOItemWrapper Apex class
//RT 18/07/2025 Wrapper changes 
export default class SOItemWrapper {
    id;
    productId;
    productName;
    productSku;
    stockAvailable;
    //<!-- AR 5 Sep 2025 Added description -->
    description;
    listingPrice;
    quantity;
    taxPercentage;
    taxPercent;
    unitPrice;
    discountAmount;
    discountPercentage;
    salesOrderDiscountType;
    discountType;
    key;
    searchResults;

    constructor(data = {}) {
        this.id = data.id || null;
        this.productId = data.productId || null;
        this.productName = data.productName || '';
        this.productSku = data.productSku || '';
        this.stockAvailable = data.stockAvailable || 0;
        //<!-- AR 5 Sep 2025 Added description -->
        this.description = data.description || '';
        this.listingPrice = data.listingPrice || 0;
        this.quantity = data.quantity || 0;
        this.taxPercentage = data.taxPercentage || '';
        this.taxPercent = data.taxPercent || '';
        this.unitPrice = data.unitPrice || 0;
        this.discountAmount = data.discountAmount || 0;
        this.discountPercentage = data.discountPercentage || 0;
        this.salesOrderDiscountType = data.salesOrderDiscountType || '';
        this.discountType = data.discountType || '';
        this.key = data.key || 0;
        this.searchResults = data.searchResults || [];
    }
}