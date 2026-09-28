public class GenerateEInvoice {

    // Request Wrapper
    public class GenerateInvoiceRequest {
        public String clientId;
        public String version;
        public String taxScheme;
        public String supplyType;
        public String documentType;
        public String regRev;
        public String igstOnIntra;
        public String invoiceNumber;
        public String invoiceDate;

        // Seller
        public String sellerGstin;
        public String sellerLegalName;
        public String sellerTradeName;
        public String sellerAddress1;
        public String sellerAddress2;
        public String sellerLocation;
        public Integer sellerPin;
        public String sellerStateCode;
        public String sellerPhone;
        public String sellerEmail;

        // Buyer
        public String buyerGstin;
        public String buyerLegalName;
        public String buyerTradeName;
        public String buyerAddress1;
        public String buyerAddress2;
        public String buyerLocation;
        public Integer buyerPin;
        public String buyerStateCode;
        public String buyerPhone;
        public String buyerEmail;

        // POS / Transaction
        public String pos;
        public String transactionType;

        // Ship To (optional)
        public String shipToGstin;
        public String shipToLegalName;
        public String shipToTradeName;
        public String shipToAddress1;
        public String shipToAddress2;
        public String shipToLocation;
        public Integer shipToPin;
        public String shipToStateCode;

        // Payment
        public String payeeName;
        public String payeeAccountNumber;
        public String paymentMode;
        public String bankIfscCode;
        public String paymentTerms;
        public String paymentInstruction;
        public String creditTransferRefNo;
        public String directDebitTransferRef;
        public Integer creditPeriodInDays;
        public Decimal payAmt;
        public Decimal paidAmt;
        public Decimal invoiceDiscount;
        public Decimal invoiceOtherCharges;

        // Items
        public List<GenerateEInvoice.Item> items;
    }

    public class Item {
        public String slNo;
        public String description;
        public String isService;
        public String hsn;
        public Decimal quantity;
        public Decimal freeQuantity;
        public String unit;
        public Decimal unitPrice;
        public Decimal discount;
        public Decimal gstRate;
        public Decimal cessRate;
        public Decimal nonAdvolCessAmount;
        public Decimal stateCessRate;
        public Decimal stateNonAdvolCessAmount;
        public Decimal otherCharges;
    }

    @AuraEnabled
    public static String generateInvoice(Id invoiceId) {
        // Query Invoice with items
        Invoice__c inv = [
            SELECT Id, Name, Invoice_Date__c, TotalAmount__c,
                Supply_Type__c, Document_Type__c, Transaction_Type__c, PlaceOfSupply__c,
                Account__r.Name, Account__r.GSTIN__c, Account__r.BillingStreet, 
                Account__r.BillingCity, Account__r.BillingState, Account__r.BillingPostalCode,
                Account__r.Phone, Account__r.Email__c,
                (SELECT Id, Product1__r.Name, Product1__r.Description__c, Quantity__c, 
                        Rate__c, Discount_Amount__c, GST_Amount__c, Cess__c, HsnSac__c
                    FROM Invoice_Items__r)
            FROM Invoice__c
            WHERE Id = :invoiceId
            LIMIT 1
        ];

        Location__c location = [
            SELECT GSTIN__c, Name, Address__c, Act_From_State_Code__c, From_State_Code__c, Email__c, Phone__c
            FROM Location__c
            WHERE Name = :inv.PlaceOfSupply__c
            LIMIT 1
        ];
        Map<String,Object> locMap = (Map<String,Object>) JSON.deserializeUntyped(location.Address__c);

        // Build Request
        GenerateInvoiceRequest req = new GenerateInvoiceRequest();
        req.clientId = 'AIHPR33TXP5ZBJ4';
        req.version = '1.1';
        req.taxScheme = 'GST';
        req.supplyType = inv.Supply_Type__c;
        req.documentType = inv.Document_Type__c;
        req.regRev = 'N';
        req.igstOnIntra = 'N';
        req.invoiceNumber = inv.Name;
        req.invoiceDate = String.valueOf(inv.Invoice_Date__c);

        // Seller from Location__c
        req.sellerGstin = location.GSTIN__c;
        req.sellerLegalName = location.Name;
        req.sellerTradeName = location.Name;
        req.sellerAddress1 = (String)locMap.get('PlotNo');
        req.sellerAddress2 = (String)locMap.get('Street');
        req.sellerLocation = (String)locMap.get('City');
        req.sellerPin = Integer.valueOf((String)locMap.get('PostalCode'));
        req.sellerStateCode = location.From_State_Code__c;
        req.sellerPhone = location.Phone__c;
        req.sellerEmail = location.Email__c;

        // Buyer
        req.buyerGstin = inv.Account__r.GSTIN__c;
        req.buyerLegalName = inv.Account__r.Name;
        req.buyerTradeName = inv.Account__r.Name;
        req.buyerAddress1 = inv.Account__r.BillingStreet;
        req.buyerLocation = inv.Account__r.BillingCity;
        req.buyerPin = Integer.valueOf(inv.Account__r.BillingPostalCode);
        req.buyerStateCode = inv.Account__r.BillingState;
        req.buyerPhone = inv.Account__r.Phone;
        req.buyerEmail = inv.Account__r.Email__c;

        // POS + Transaction
        req.pos = inv.PlaceOfSupply__c;
        req.transactionType = inv.Transaction_Type__c;

        // Add Items
        req.items = new List<Item>();
        Integer count = 1;
        for (Invoice_Item__c ii : inv.Invoice_Items__r) {
            Item item = new Item();
            item.slNo = String.valueOf(count++);
            item.description = ii.Product1__r.Description__c;
            item.isService = 'N';
            item.hsn = ii.HsnSac__c;
            item.quantity = ii.Quantity__c;
            item.freeQuantity = 0;
            item.unit = 'NOS';
            item.unitPrice = ii.Rate__c;
            item.discount = ii.Discount_Amount__c;
            item.gstRate = ii.GST_Amount__c;
            item.cessRate = ii.Cess__c;
            item.nonAdvolCessAmount = 0;
            item.stateCessRate = 0;
            item.stateNonAdvolCessAmount = 0;
            item.otherCharges = 0;
            req.items.add(item);
        }

        // Call API
        Http http = new Http();
        HttpRequest httpReq = new HttpRequest();
        httpReq.setEndpoint('http://localhost:8080/generateInvoice');
        httpReq.setMethod('POST');
        httpReq.setHeader('Content-Type', 'application/json');
        httpReq.setHeader('accept', 'application/pdf');
        httpReq.setBody(JSON.serialize(req));

        HttpResponse res = http.send(httpReq);

        if (res.getStatusCode() == 200) {
            ContentVersion cv = new ContentVersion(
                Title = inv.Name + '_EInvoice',
                PathOnClient = inv.Name + '.pdf',
                VersionData = res.getBodyAsBlob(),
                IsMajorVersion = true
            );
            insert cv;
            return 'E-Invoice generated successfully.';
        } else {
            return 'Error: ' + res.getStatusCode() + ' - ' + res.getBody();
        }
    }
}
