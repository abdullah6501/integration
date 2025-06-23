public class Sale_order_wrapper {
    public Header HEADER { get; set; }
    public List<line_items> LINE_ITEM { get; set; }

    public Sale_order_wrapper(Account  acc, Order_line_item__c[] opps) {
        
        //for header init
        Header header = new Header();
        //for line item init
        this.LINE_ITEM = new List<line_items>();

        header.web_order_no=acc.Web_Order_No__c;
        header.customer_name=acc.Name;
       header.order_Status=acc.Order_Status__c;
        header.currencie=acc.CurrencyIsoCode__c;
        header.order_type=acc.Order_Type__c;
        header.order_Date=acc.Order_Date__c;
        header.customer_po=acc.Customer_PO__c;
        header.payment_terms=acc.Payment_Terms__c;
        header.freight_term=acc.Freight_Term__c;
        header.operating_unit=acc.Operating_Unit__c;
        header.shipmentPriority=acc.Shipment_Priority__c;
        header.bill_to=acc.Bill_To_Code__c;
        header.ship_to=acc.Ship_To_Code__c;
        header.bill_to_address=acc.BillingStreet + ', ' + acc.BillingCity + ', ' +
        acc.BillingState + ' ' + acc.BillingPostalCode + ', ' + acc.BillingCountry;
        header.ship_to_address=acc.ShippingStreet + ', ' + acc.ShippingCity + ', ' +
        acc.ShippingState + ' ' + acc.ShippingPostalCode + ', ' + acc.ShippingCountry;
        header.packing_instructions=acc.Packing_Instructions__c;
        header.bill_to_gst_no=acc.Billing_GST_No__c;
        header.ship_to_gst_no=acc.Shipping_GST_No__c;
        header.bill_to_pan_no=acc.Billing_PAN_No__c;
        header.ship_to_pan_no=acc.Shipping_PAN_No__c;
        header.shipping_instructions=acc.Shipping_Instructions__c;
        header.outstanding=acc.Outstanding_Amount__c;
        header.credit_limit=acc.Credit_Limit__c;
        header.remarks=acc.Remarks__c;
        
        this.HEADER=header;

        for(Order_line_item__c opp : opps){
            line_items item = new line_items();

            item.line_no = opp.Line_No__c;
            item.order_item = opp.Product2Id__c;
            item.description = opp.Description__c;
            item.quantity = opp.Quantity__c;
            item.uom = opp.UnitOfMeasure__c;
            item.price = opp.UnitPrice__c;
            item.selling_price = opp.SalesPrice__c;
            item.total = opp.TotalPrice__c;
            item.request_ship_date = opp.RequestShipDate__c;
            item.line_status = opp.Line_Status__c;
            
            this.LINE_ITEM.add(item);
        }

    }

public class Header {
    public String web_order_no { get; set; }
    public String customer_name { get; set; }
    public String order_Status { get; set; }
    public String currencie { get; set; }
    public String order_type { get; set; }
    public Date order_Date { get; set; }
    public String customer_po { get; set; }
    public String payment_terms { get; set; }
    public String freight_term { get; set; }
    public String operating_unit { get; set; }
    public String shipmentPriority { get; set; }
    public String bill_to { get; set; }
    public String ship_to { get; set; }
    public String bill_to_address { get; set; }
    public String ship_to_address { get; set; }
    public String packing_instructions { get; set; }
    public String bill_to_gst_no { get; set; }
    public String ship_to_gst_no { get; set; }
    public String bill_to_pan_no { get; set; }
    public String ship_to_pan_no { get; set; }
    public String shipping_instructions { get; set; }
    public Decimal outstanding { get; set; }
    public Decimal credit_limit { get; set; }
    public String remarks { get; set; }

}

    public class line_items {
        public Decimal line_no { get; set; }
        public Id order_item { get; set; }
        public String description { get; set; }
        public Decimal quantity { get; set; }
        public String uom { get; set; }
        public Decimal price { get; set; }
        public Decimal selling_price { get; set; }
        public Decimal total { get; set; }
        public Date request_ship_date { get; set; }
        public String line_status { get; set; }
 
    }
}