public class CancelEInvoice {

    public class CancelInvoiceWrapper {
        public String invoiceId;
        public String cnlRsn;
        public String cnlRem;
    }

    @AuraEnabled
    public static String cancelInvoice(CancelInvoiceWrapper wrapReq) {
        if (wrapReq == null || String.isBlank(wrapReq.invoiceId)) {
            return 'Error: Missing Invoice Id';
        }

        Invoice__c inv = [
            SELECT Id, IRN__c
            FROM Invoice__c 
            WHERE Id = :wrapReq.invoiceId 
            LIMIT 1
        ];

        if (String.isBlank(inv.IRN__c)) {
            return 'Error: No IRN found for this Invoice';
        }

        Map<String, Object> req = new Map<String, Object>();
        req.put('Irn', inv.IRN__c); 
        req.put('CnlRsn', wrapReq.cnlRsn);
        req.put('CnlRem', wrapReq.cnlRem);

        Http http = new Http();
        HttpRequest httpReq = new HttpRequest();
        httpReq.setEndpoint('http://localhost:8080/cancelInvoice'); 
        httpReq.setMethod('POST');
        httpReq.setHeader('Content-Type', 'application/json');
        httpReq.setHeader('accept', 'application/json');
        httpReq.setBody(JSON.serialize(req));

        HttpResponse res = http.send(httpReq);

        if (res.getStatusCode() == 200) {
            return 'Invoice Cancelled Successfully. Response: ' + res.getBody();
        } else {
            return 'Error: ' + res.getStatusCode() + ' - ' + res.getBody();
        }
    }
}
