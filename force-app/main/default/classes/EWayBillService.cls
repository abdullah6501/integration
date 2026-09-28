public class EWayBillService {

    // Wrapper
    public class Item {
        public String productName;
        public String productDesc;
        public String hsnCode;
        public Decimal quantity;
        public String qtyUnit;
        public Decimal taxableAmount;
        public Decimal sgstRate;
        public Decimal cgstRate;
        public Decimal igstRate;
        public Decimal cessRate;
    }

    public class EWayBillRequest {
        public String supplyType;
        public String subSupplyType;
        public String subSupplyDesc;
        public String docType;
        public String docNo;
        public String docDate;
        public String fromGstin;
        public String fromTrdName;
        public String fromAddr1;
        public String fromAddr2;
        public String fromPlace;
        public Integer actFromStateCode;
        public Integer fromPincode;
        public Integer fromStateCode;
        public String toGstin;
        public String toTrdName;
        public String toAddr1;
        public String toAddr2;
        public String toPlace;
        public Integer toPincode;
        public Integer actToStateCode;
        public Integer toStateCode;
        public Integer transactionType;
        public String dispatchFromGSTIN;
        public String dispatchFromTradeName;
        public String shipToGSTIN;
        public String shipToTradeName;
        public Decimal totalValue;
        // public Decimal cgstValue;
        // public Decimal sgstValue;
        // public Decimal igstValue;
        // public Decimal cessValue;
        // public Decimal cessNonAdvolValue;
        public Decimal totInvValue;
        public String transMode;
        public String transDistance;
        public String transporterName;
        public String transporterId;
        public String transDocNo;
        public String transDocDate;
        public String vehicleNo;
        public String vehicleType;
        public List<Item> itemList;
    }

    public class AuthRequest {
        public String Username { get; set; }
        public String Password { get; set; }
        public String clientId { get; set; }
        public String clientSecret { get; set; }
        public String gstIn { get; set; }
        public String emailId { get; set; }
    }
    
    @AuraEnabled
    public static String generateEWayBillAuth(String reqJson, String recordId) {
        AuthRequest reqWrapper = (AuthRequest) JSON.deserialize(reqJson, AuthRequest.class);
    
        // Integration Log wrapper
        IntegrationWrapper.CalloutResult result = new IntegrationWrapper.CalloutResult();
        result.requestTime = Datetime.now();
        System.debug('Auth Request Wrapper: ' + result.requestTime);
        // result.endpoint = 'https://test-e-inv-api.rangerfusion.com/IN/EwayBillAuth';
        result.requestPayload = reqJson;
        System.debug('Request Payload: ' + result.requestPayload);
    
        try {
            String queryParams = 'email=' + EncodingUtil.urlEncode(reqWrapper.emailId, 'UTF-8') +
                                 '&username=' + EncodingUtil.urlEncode(reqWrapper.Username, 'UTF-8') +
                                 '&password=' + EncodingUtil.urlEncode(reqWrapper.Password, 'UTF-8');
    
            String endpoint = 'https://test-e-inv-api.rangerfusion.com/IN/EwayBillAuth?' + queryParams;
            result.endpoint = endpoint;
            System.debug('Auth Endpoint: ' + result.endpoint);
    
            // Call secondary method
            return sendGetRequestForAuth(
                endpoint, 
                reqWrapper.clientId, 
                reqWrapper.clientSecret, 
                reqWrapper.gstIn, 
                reqWrapper.emailId, 
                reqWrapper.Username, 
                reqWrapper.Password, 
                recordId,
                result 
            );
    
        } catch (Exception e) {
            result.errorMessage = e.getMessage();
            System.debug('Auth Exception: ' + result.errorMessage);
            System.debug('record id' + recordId + '---' + 'result' + result);
            IntegrationLogService.logWrapperAsync(
                recordId, 'EWayBillAuth', 'EWayBill Endpoint', result
            );
            return '{"status":"ERROR","message":"' + e.getMessage() + '"}';
        }
    }
    
    private static String sendGetRequestForAuth(
        String endpoint, 
        String clientId, 
        String clientSecret, 
        String gstIn, 
        String emailId, 
        String userName, 
        String password, 
        String recordId,
        IntegrationWrapper.CalloutResult result
    ) {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpoint);
        request.setMethod('GET');
        request.setHeader('accept', 'application/json');
        request.setHeader('clientId', clientId);
        request.setHeader('clientSecret', clientSecret);
        request.setHeader('gstin', gstIn);
    
        try {
            HttpResponse response = http.send(request);
    
            // Capture response
            result.statusCode = response.getStatusCode();
            System.debug('Auth Response: ' + result.statusCode);
            result.responsePayload = response.getBody();
            System.debug('Status Code: ' + result.responsePayload);
    
            if (response.getStatusCode() == 200) {
                Authentication__c authRec = new Authentication__c();
                authRec.User_Name__c = userName;
                authRec.Password__c = password;
                authRec.Email__c = emailId;
                authRec.Client_Id__c = clientId;
                authRec.Client_Secret__c = clientSecret;
                authRec.GSTIN__c = gstIn;
                authRec.Type__c = 'E-Way Bill';
    
                if (String.isNotBlank(recordId)) {
                    authRec.Id = recordId;
                    update authRec;
                } else {
                    insert authRec;
                }
    
                // Log success
                System.debug('record id' + recordId + '---' + 'result' + result);
                IntegrationLogService.logWrapperAsync(
                    recordId, 'EWayBillAuth', 'EWayBill Endpoint', result
                );
    
                return response.getBody();
            } else {
                result.errorMessage = 'Error ' + response.getBody();
                System.debug('Auth Error: ' + result.errorMessage);
                throw new CalloutException(
                    'GET request failed. Status: ' + response.getStatusCode() + 
                    ', Body: ' + response.getBody()
                );
            }
    
        } catch (Exception ex) {
            result.errorMessage = ex.getMessage();
            System.debug('Auth Exception in sendGetRequestForAuth: ' + result.errorMessage);
            throw ex;
        } finally {
            // Always log
            System.debug('Final record id' + recordId + '---' + 'result' + result);
            IntegrationLogService.logWrapperAsync(
                recordId, 'EWayBillAuth', 'EWayBill Endpoint', result
            );
        }
    }
    
    /*@AuraEnabled
    public static String generateEWayBillAuth(String reqJson, String recordId) {
        AuthRequest reqWrapper = (AuthRequest) JSON.deserialize(reqJson, AuthRequest.class);
    
        // Integration Log wrapper
        IntegrationWrapper.CalloutResult result = new IntegrationWrapper.CalloutResult();
        result.requestTime = Datetime.now();
        // result.endpoint = 'https://test-e-inv-api.rangerfusion.com/IN/EwayBillAuth';
        result.requestPayload = reqJson;
    
        try {
            String queryParams = 'email=' + EncodingUtil.urlEncode(reqWrapper.emailId, 'UTF-8') +
                                 '&username=' + EncodingUtil.urlEncode(reqWrapper.Username, 'UTF-8') +
                                 '&password=' + EncodingUtil.urlEncode(reqWrapper.Password, 'UTF-8');
    
            String endpoints = 'https://test-e-inv-api.rangerfusion.com/IN/EwayBillAuth?' + queryParams;
            result.endpoint = endpoints;
    
            // Call secondary method
            return sendGetRequestForAuth(
                endpoints, 
                reqWrapper.clientId, 
                reqWrapper.clientSecret, 
                reqWrapper.gstIn, 
                reqWrapper.emailId, 
                reqWrapper.Username, 
                reqWrapper.Password, 
                recordId,
                result 
            );
    
        } catch (Exception e) {
            result.errorMessage = e.getMessage();
            IntegrationLogService.logWrapperAsync(
                recordId, 'EWayBillAuth', 'EWayBill Endpoint', result
            );
            return '{"status":"ERROR","message":"' + e.getMessage() + '"}';
        }
    }
    
    private static String sendGetRequestForAuth(
        String endpoint, 
        String clientId, 
        String clientSecret, 
        String gstIn, 
        String emailId, 
        String userName, 
        String password, 
        String recordId,
        IntegrationWrapper.CalloutResult result
    ) {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpoint);
        request.setMethod('GET');
        request.setHeader('accept', 'application/json');
        request.setHeader('clientId', clientId);
        request.setHeader('clientSecret', clientSecret);
        request.setHeader('gstin', gstIn);
    
        try {
            HttpResponse response = http.send(request);
    
            // Capture response
            result.statusCode = response.getStatusCode();
            result.responsePayload = response.getBody();
    
            if (response.getStatusCode() == 200) {
                Authentication__c authRec = new Authentication__c();
                authRec.User_Name__c = userName;
                authRec.Password__c = password;
                authRec.Email__c = emailId;
                authRec.Client_Id__c = clientId;
                authRec.Client_Secret__c = clientSecret;
                authRec.GSTIN__c = gstIn;
                authRec.Type__c = 'E-Way Bill';
    
                if (String.isNotBlank(recordId)) {
                    authRec.Id = recordId;
                    update authRec;
                } else {
                    insert authRec;
                }
    
                // Log success
                IntegrationLogService.logWrapperAsync(
                    recordId, 'EWayBillAuth', 'EWayBill Endpoint', result
                );
    
                return response.getBody();
            } else {
                result.errorMessage = 'Error ' + response.getBody();
                throw new CalloutException(
                    'GET request failed. Status: ' + response.getStatusCode() + 
                    ', Body: ' + response.getBody()
                );
            }
    
        } catch (Exception ex) {
            result.errorMessage = ex.getMessage();
            throw ex;
        } finally {
            // Always log
            IntegrationLogService.logWrapperAsync(
                recordId, 'EWayBillAuth', 'EWayBill Endpoint', result
            );
        }
    } */

    /* @AuraEnabled
    public static String generateEWayBillAuth(String reqJson,String recordId) {
        System.debug('Request JSON: ' + reqJson);
        System.debug('Record ID: ' + recordId);
        AuthRequest reqWrapper = (AuthRequest) JSON.deserialize(reqJson, AuthRequest.class);
        try {
            String queryParams = 'email=' + EncodingUtil.urlEncode(reqWrapper.emailId, 'UTF-8') +
                                 '&username=' + EncodingUtil.urlEncode(reqWrapper.Username, 'UTF-8') +
                                 '&password=' + EncodingUtil.urlEncode(reqWrapper.Password, 'UTF-8');
            
            String endpoint = 'https://test-e-inv-api.rangerfusion.com/IN/EwayBillAuth?' + queryParams;

            return sendGetRequestForAuth(endpoint, reqWrapper.clientId, reqWrapper.clientSecret, reqWrapper.gstIn, reqWrapper.emailId, reqWrapper.Username, reqWrapper.Password,recordId);

        } catch (Exception e) {
            return '{"status":"ERROR","message":"' + e.getMessage() + '"}';
        }
    }

    private static String sendGetRequestForAuth(String endpoint, String clientId, String clientSecret, String gstIn, String emailId, String userName, String password,String recordId) {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpoint);
        request.setMethod('GET');
        request.setHeader('accept', 'application/json');
        request.setHeader('clientId', clientId);
        request.setHeader('clientSecret', clientSecret);
        request.setHeader('gstin', gstIn);

        HttpResponse response = http.send(request);
        System.debug('Auth Response: ' + response.getBody());
        System.debug('Status Code: ' + response.getStatusCode());

        if (response.getStatusCode() == 200) {
            System.debug('GET request successful. Response: ' + response.getBody());
            // return response.getBody();
            Authentication__c authRec = new Authentication__c();
            authRec.User_Name__c = userName;
            authRec.Password__c = password;
            authRec.Email__c = emailId;
            authRec.Client_Id__c = clientId;
            authRec.Client_Secret__c = clientSecret;
            authRec.GSTIN__c = gstIn;
            authRec.Type__c = 'E-Way Bill';

            if (recordId != null && recordId != '') {
                authRec.Id = recordId;
                update authRec;
            } else {
                insert authRec;
            }
            return response.getBody();
        } else {
            throw new CalloutException(
                'GET request failed. Status: ' + response.getStatusCode() + 
                ', Body: ' + response.getBody()
            );
        }
    } */

    private static final String BASE_URL = 'https://indian-e-inv-api.rangerfusion.com';

    public static String getTransporterDetails(String transNo) {
        return sendGetRequest(BASE_URL + '/getTransporterDetails?transNo=' + EncodingUtil.urlEncode(transNo, 'UTF-8'));
    }

    public static String getHsnCodeDetails(String hsnCodeNo) {
        return sendGetRequest(BASE_URL + '/getHsnCodeDetails?hsnCodeNo=' + EncodingUtil.urlEncode(hsnCodeNo, 'UTF-8'));
    }

    public static String ewayBillsRejectedByOthers(String ewDate) {
        return sendGetRequest(BASE_URL + '/ewayBillsRejectedByOthers?date=' + EncodingUtil.urlEncode(ewDate, 'UTF-8'));
    }

    public static String ewayBillsOfOtherParty(String ewDate) {
        return sendGetRequest(BASE_URL + '/ewayBillsOfOtherParty?date=' + EncodingUtil.urlEncode(ewDate, 'UTF-8'));
    }

    public static String ewayBillsForTransporter(String ewDate) {
        return sendGetRequest(BASE_URL + '/ewayBillsForTransporter?date=' + EncodingUtil.urlEncode(ewDate, 'UTF-8'));
    }

    public static String ewayBillsByDate(String ewDate) {
        return sendGetRequest(BASE_URL + '/ewayBillsByDate?date=' + EncodingUtil.urlEncode(ewDate, 'UTF-8'));
    }

    public static String ewayBillReportByTransporterAssignedDate(String ewDate, String stateCode) {
        return sendGetRequest(BASE_URL + '/ewayBillReportByTransporterAssignedDate?date=' + EncodingUtil.urlEncode(ewDate, 'UTF-8') + '&stateCode=' + EncodingUtil.urlEncode(stateCode, 'UTF-8'));
    }

    public static String ewayBillDetails(String ewbNo) {
        return sendGetRequest(BASE_URL + '/ewayBillDetails?ewbNo=' + EncodingUtil.urlEncode(ewbNo, 'UTF-8'));
    }

    public static String ewayBillDetailsByState(String stateCode, String ewDate) {
        return sendGetRequest(BASE_URL + '/ewayBillDetailsByState?stateCode=' + EncodingUtil.urlEncode(stateCode, 'UTF-8') + '&date=' + EncodingUtil.urlEncode(ewDate, 'UTF-8'));
    }

    public static String ewayBillDetailsByGstin(String gstin, String ewDate) {
        return sendGetRequest(BASE_URL + '/ewayBillDetailsByGstin?gstin=' + EncodingUtil.urlEncode(gstin, 'UTF-8') + '&date=' + EncodingUtil.urlEncode(ewDate, 'UTF-8'));
    }

    public static String ewayBillByConsigner(String docType, String docNo) {
        return sendGetRequest(BASE_URL + '/ewayBillByConsigner?docType=' + EncodingUtil.urlEncode(docType, 'UTF-8') + '&docNo=' + EncodingUtil.urlEncode(docNo, 'UTF-8'));
    }

    public static String consolidatedEwayBillDetails(String tripSheetNo) {
        return sendGetRequest(BASE_URL + '/ConsolidatedEwayBillDetails?tripSheetNo=' + EncodingUtil.urlEncode(tripSheetNo, 'UTF-8'));
    }

    private static String sendGetRequest(String endpoint) {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpoint);
        request.setMethod('GET');
        request.setHeader('accept', 'application/json');

        HttpResponse response = http.send(request);

        if (response.getStatusCode() == 200) {
            return response.getBody();
        } else {
            throw new CalloutException(
                'GET request failed. Status: ' + response.getStatusCode() + 
                ', Body: ' + response.getBody()
            );
        }
    }


    // Update Vehicle Number
    public class UpdateVehicleRequest {
        public String ewbNo;
        public String vehicleNo;
        public String fromPlace;
        public Integer fromState;
        public String reasonCode;
        public String reasonRem;
        public String transDocNo;
        public String transDocDate;
        public String transMode;
    }

    // Generate Consolidated E-Way Bill
    public class TripSheetEwbBill {
        public Long ewbNo;
    }

    public class ConsolidatedEWayBillRequest {
        public String fromPlace;
        public Integer fromState;
        public String vehicleNo;
        public String transMode;
        public String transDocNo;
        public String transDocDate;
        public List<Object> tripSheetEwbBills;
    }

    // Cancel E-Way Bill
    public class CancelEWayBillRequest {
        public String ewbNo;
        public String cancelRsnCode;
        public String cancelRmrk;
    }

    // Reject Eway Bill
    public class RejectEwayBillRequest {
        public String ewbNo;
    }

    // Update Transporter
    public class UpdateTransporterRequest {
        public String ewbNo;
        public String transporterId;
    }

    // Extend Validity
    public class ExtendValidityRequest {
        public String ewbNo;
        public String vehicleNo;
        public String fromPlace;
        public String fromState;
        // public Integer fromState;
        public Integer remainingDistance;
        public String transDocNo;
        public Date transDocDate;
        // public String transDocDate;
        public String transMode;
        public String extnRsnCode;
        public String extnRemarks;
        public String fromPincode;
        public String consignmentStatus;
        public String transitType;
        public String addressLine1;
        public String addressLine2;
        public String addressLine3;
    }

    // Re-Generate Consolidated
    public class ReGenerateConsolidatedRequest {
        public String tripSheetNo;
        public String vehicleNo;
        public String fromPlace;
        public String fromState;
        // public Integer fromState;
        public String reasonCode;
        public String reasonRem;
        public String transDocNo;
        public Date transDocDate;
        // public String transDocDate;
        public String transMode;
    }

    // Initiate Multi Vehicle
    public class InitiateMultiVehicleRequest {
        public String ewbNo;
        public String fromPlace;
        // public Integer fromState;
        public String fromState;
        public String toPlace;
        public Integer toState;
        public String reasonCode;
        public String reasonRem;
        public Decimal totalQuantity;
        public String unitCode;
        public String transMode;
    }

    public class ChangeMultiVehicleRequest {
        public Long ewbNo;
        public Integer groupNo;
        public String oldvehicleNo;
        public String newVehicleNo;
        public String oldTranNo;
        public String newTranNo;
        public String fromPlace;
        public Integer fromState;
        public String reasonCode;
        public String reasonRem;
    }   

    public class AddMultiVehicleRequest {
        public Long ewbNo;
        public String vehicleNo;
        public Integer groupNo;
        public String transDocNo;
        public String transDocDate;
        public Decimal quantity;
    }   

    public class InputWrapper {
        @AuraEnabled public String supplyType { get; set; }
        @AuraEnabled public String subSupplyType { get; set; }
        @AuraEnabled public String documentType { get; set; }
        @AuraEnabled public String subSupplyDesc { get; set; }
        @AuraEnabled public String vehicleType { get; set; }
        @AuraEnabled public String transportType { get; set; }
        @AuraEnabled public String transporterName { get; set; }
        @AuraEnabled public String transportDocNo { get; set; }
        @AuraEnabled public String vehicleNumber { get; set; }
        @AuraEnabled public String transportDistance { get; set; }
        @AuraEnabled public String vendorId { get; set; }
        @AuraEnabled public String gstin { get; set; }
        @AuraEnabled public String transportDocDate { get; set; }
    }

    @AuraEnabled
    public static String generateEWayBill(Id deliveryNoteId, String inputJson) {

        InputWrapper input = (InputWrapper) JSON.deserialize(inputJson, InputWrapper.class);

        Delivery_Note__c dn = [
            SELECT Id, Vehicle_Number__c, Transport_Mode__c, Transport_Distance__c, Transporter_Name__c,Supply_Type__c, Sub_Supply_Type__c,
                Transport_Id__c, Transport_Document_Number__c, Transport_Document_Date__c, Vehicle_Type__c, Sub_Supply_Description__c,
                E_Way_Bill_Date__c, E_Way_Bill_Number__c, Valid_Upto__c, Vendor__r.GSTIN__c, Document_Type__c,
                Invoice__r.Id, Invoice__r.Name, Invoice__r.Invoice_Date__c, Invoice__r.TotalAmount__c, 
                Invoice__r.Sum_Of_Amount_With_GST__c, Invoice__r.PlaceOfSupply__c,
                Invoice__r.Transaction_Type__c, Invoice__r.IGST__c, Invoice__r.CGST__c, Invoice__r.Cess__c, 
                Invoice__r.Cess_Non_Advol_Value__c, Invoice__r.SGST__c,
                Invoice__r.Account__r.Name, Invoice__r.Account__r.GSTIN__c,
                Invoice__r.Account__r.BillingStreet, Invoice__r.Account__r.BillingCity,
                Invoice__r.Account__r.BillingState, Invoice__r.Account__r.BillingPostalCode, 
                Invoice__r.Account__r.Act_To_State_Code__c, Invoice__r.Account__r.To_State_Code__c
            FROM Delivery_Note__c
            WHERE Id = :deliveryNoteId
            LIMIT 1
        ];

        Invoice__c inv = dn.Invoice__r;

        List<Invoice_Item__c> invoiceItems = [
            SELECT Id, Product1__r.Name, Product1__r.Description__c, Product1__r.HSNSAC__c, Quantity__c, Rate__c, 
                CESS__c, CGST__c, IGST__c, SGST__c, Amount_With_GST__c, HsnSac__c, GST_Amount__c
            FROM Invoice_Item__c
            WHERE Invoice__c = :inv.Id
        ];

        Location__c location = [
            SELECT GSTIN__c, Name, Address__c, Act_From_State_Code__c, From_State_Code__c
            FROM Location__c
            WHERE Name = :inv.PlaceOfSupply__c
            LIMIT 1
        ];

        EWayBillRequest req = new EWayBillRequest();

        Map<String, String> supplyMap = new Map<String, String>{
            'Inward'  => 'I',
            'Outward' => 'O'
        };
        // req.supplyType = supplyMap.containsKey(inv.Supply_Type__c) ? supplyMap.get(inv.Supply_Type__c) : 'O';
        req.supplyType = supplyMap.containsKey(input.supplyType) ? supplyMap.get(input.supplyType) : 'O';

        Map<String, String> subSupplyMap = new Map<String, String>{
            'Supply' => '1',
            'Import' => '2',
            'Export' => '3',
            'Job Work' => '4',
            'For Own Use' => '5',
            'Job work Returns' => '6',
            'Sales Return' => '7',
            'Others' => '8',
            'SKD/CKD/Lots' => '9',
            'Line Sales' => '10',
            'Recipient Not Known' => '11',
            'Exhibition or Fairs' => '12'
        };
        // req.subSupplyType = subSupplyMap.containsKey(inv.Sub_Supply_Type__c) ? subSupplyMap.get(inv.Sub_Supply_Type__c) : '1';
        req.subSupplyType = subSupplyMap.containsKey(input.subSupplyType) ? subSupplyMap.get(input.subSupplyType) : '1';
        // req.subSupplyDesc = inv.Sub_Supply_Description__c;
        req.subSupplyDesc = (input.subSupplyDesc != null) ? input.subSupplyDesc : '';

        Map<String, String> docMap = new Map<String, String>{
            'Tax Invoice'      => 'INV',
            'Bill of Supply'   => 'BIL',
            'Bill of Entry'    => 'BOE',
            'Delivery Challan' => 'CHL',
            'Others'           => 'OTH'
        };
        // req.docType = docMap.containsKey(inv.Document_Type__c) ? docMap.get(inv.Document_Type__c) : 'INV';
        req.docType = docMap.containsKey(input.documentType) ? docMap.get(input.documentType) : 'INV'; 
        
        req.docNo = inv.Name;
        // req.docDate = String.valueOf(inv.Invoice_Date__c);
        if (inv.Invoice_Date__c != null) {
            // Convert Date → DateTime (midnight time) and then format
            req.docDate = DateTime.newInstance(inv.Invoice_Date__c, Time.newInstance(0,0,0,0))
                                  .format('dd/MM/yyyy');
        }

        Map<String, Integer> stateMap = new Map<String, Integer>{
            'JAMMU AND KASHMIR' => 1,
            'HIMACHAL PRADESH' => 2,
            'PUNJAB' => 3,
            'CHANDIGARH' => 4,
            'UTTARAKHAND' => 5,
            'HARYANA' => 6,
            'DELHI' => 7,
            'RAJASTHAN' => 8,
            'UTTAR PRADESH' => 9,
            'BIHAR' => 10,
            'SIKKIM' => 11,
            'ARUNACHAL PRADESH' => 12,
            'NAGALAND' => 13,
            'MANIPUR' => 14,
            'MIZORAM' => 15,
            'TRIPURA' => 16,
            'MEGHALAYA' => 17,
            'ASSAM' => 18,
            'WEST BENGAL' => 19,
            'JHARKHAND' => 20,
            'ODISHA' => 21,
            'CHHATTISGARH' => 22,
            'MADHYA PRADESH' => 23,
            'GUJARAT' => 24,
            'DAMAN AND DIU' => 25,
            'DADRA AND NAGAR HAVELI' => 26,
            'MAHARASHTRA' => 27,
            'KARNATAKA' => 29,
            'GOA' => 30,
            'LAKSHADWEEP' => 31,
            'KERALA' => 32,
            'TAMIL NADU' => 33,
            'PUDUCHERRY' => 34,
            'ANDAMAN AND NICOBAR' => 35,
            'TELANGANA' => 36,
            'ANDHRA PRADESH' => 37,
            'LADAKH' => 38
        };

        // Seller
        Map<String, Object> locMap = (Map<String, Object>) JSON.deserializeUntyped(location.Address__c);
        req.fromGstin = location.GSTIN__c;
        req.fromTrdName = location.Name;
        req.fromAddr1 = (String) locMap.get('PlotNo');
        req.fromAddr2 = (String) locMap.get('Street');
        req.fromPlace = (String) locMap.get('City');
        req.fromPincode = Integer.valueOf((String) locMap.get('PostalCode'));
        // req.actFromStateCode = Integer.valueOf(location.Act_From_State_Code__c);
        req.actFromStateCode = stateMap.containsKey(location.Act_From_State_Code__c) 
            ? stateMap.get(location.Act_From_State_Code__c) : null;
        // req.fromStateCode = Integer.valueOf(location.From_State_Code__c);
        req.fromStateCode = stateMap.containsKey(location.From_State_Code__c) 
            ? stateMap.get(location.From_State_Code__c) : null;

        // Buyer
        req.toGstin = inv.Account__r.GSTIN__c;
        req.toTrdName = inv.Account__r.Name;
        req.toAddr1 = inv.Account__r.BillingStreet;
        req.toAddr2 = '';
        req.toPlace = inv.Account__r.BillingCity;
        req.toPincode = (inv.Account__r.BillingPostalCode != null ) ? Integer.valueOf(inv.Account__r.BillingPostalCode) : null;
        // req.actToStateCode = Integer.valueOf(inv.Account__r.Act_To_State_Code__c);
        req.actToStateCode = stateMap.containsKey(inv.Account__r.Act_To_State_Code__c) 
            ? stateMap.get(inv.Account__r.Act_To_State_Code__c) : null;
        // req.toStateCode = Integer.valueOf(inv.Account__r.To_State_Code__c);
        req.toStateCode = stateMap.containsKey(inv.Account__r.To_State_Code__c) 
            ? stateMap.get(inv.Account__r.To_State_Code__c) : null;

        // Transaction type mapping
        Map<String, Integer> txnMap = new Map<String, Integer>{
            'Regular' => 1,
            'Bill To - Ship To' => 2,
            'Bill From - Dispatch From' => 3,
            'Combination of 2 and 3' => 4
        };
        req.transactionType = txnMap.containsKey(inv.Transaction_Type__c) ? txnMap.get(inv.Transaction_Type__c) : 1;

        // req.dispatchFromGSTIN = location.GSTIN__c;
        // req.dispatchFromTradeName = location.Name;
        // req.shipToGSTIN = inv.Account__r.GSTIN__c;
        // req.shipToTradeName = inv.Account__r.Name;

        // Totals
        req.totalValue = inv.TotalAmount__c;
        // req.cgstValue = (inv.CGST__c != null) ? inv.CGST__c : 0;
        // req.sgstValue = (inv.SGST__c != null) ? inv.SGST__c : 0;
        // req.igstValue = inv.IGST__c;
        // req.cessValue = (inv.Cess__c != null) ? inv.Cess__c : 0;
        // req.cessNonAdvolValue = inv.Cess_Non_Advol_Value__c;
        req.totInvValue = inv.Sum_Of_Amount_With_GST__c;

        // Transport from Delivery Note
        Map<String, String> transportModeMap = new Map<String, String>{
            'Road'      => '1',
            'Rail'      => '2',
            'Air'       => '3',
            'Ship'      => '4',
            'InTransit' => '5'
        };
        Map<String, String> vehicleTypeMap = new Map<String, String>{
            'Regular' => 'R',
            'ODC(Over Dimentional Cargo)' => 'O'
        };

        req.transMode = transportModeMap.containsKey(input.transportType) ? transportModeMap.get(input.transportType) : '1';
        req.transDistance = (input.transportDistance != null) ? input.transportDistance : '0';
        req.transporterName = (input.transporterName != null) ? input.transporterName : '';
        req.transporterId = (input.gstin != null) ? input.gstin : '';
        req.transDocNo = (input.transportDocNo != null) ? input.transportDocNo : '';
        // req.transDocDate = (input.transportDocDate != null) ? input.transportDocDate : String.valueOf(Date.today());
        if (input.transportDocDate != null) {
            Date dt = Date.valueOf(input.transportDocDate); 
            req.transDocDate = DateTime.newInstance(dt, Time.newInstance(0,0,0,0))
                                       .format('dd/MM/yyyy');
        } else {
            req.transDocDate = DateTime.newInstance(Date.today(), Time.newInstance(0,0,0,0))
                                       .format('dd/MM/yyyy');
        }
        req.vehicleNo = (input.vehicleNumber != null) ? input.vehicleNumber : '';
        req.vehicleType = vehicleTypeMap.containsKey(input.vehicleType) ? vehicleTypeMap.get(input.vehicleType) : 'R';

        // Items
        req.itemList = new List<Item>();
        for (Invoice_Item__c ii : invoiceItems) {
            Item it = new Item();
            it.productName = ii.Product1__r.Name;
            it.productDesc = (ii.Product1__r.Description__c != null) ? ii.Product1__r.Description__c : '';
            it.hsnCode = (ii.Product1__r.HSNSAC__c != null) ? ii.Product1__r.HSNSAC__c : '';
            it.quantity = ii.Quantity__c;
            it.qtyUnit = 'BOX';
            it.taxableAmount = ii.Amount_With_GST__c;
            it.sgstRate = (ii.SGST__c != null) ? ii.SGST__c : 0;
            it.cgstRate = (ii.CGST__c != null) ? ii.CGST__c : 0;
            it.igstRate = ii.GST_Amount__c;
            it.cessRate = (ii.CESS__c != null) ? ii.CESS__c : 0;
            req.itemList.add(it);
        }

        String resBody = sendCallout(BASE_URL + '/generateEwayBill', req);

        try {
            Map<String, Object> resMap = (Map<String, Object>) JSON.deserializeUntyped(resBody);
            if (resMap.containsKey('data')) {
                Map<String, Object> data = (Map<String, Object>) resMap.get('data');

                String ewbNo    = String.valueOf(data.get('ewayBillNo'));
                String ewbDate  = String.valueOf(data.get('ewayBillDate'));
                String validUpto = String.valueOf(data.get('validUpto'));

                // if (dn.E_Way_Bill_Number__c == null) {
                //     dn.E_Way_Bill_Number__c = ewbNo;
                //     dn.E_Way_Bill_Date__c   = ewbDate;
                //     dn.Valid_Upto__c        = validUpto;
                // } else {
                    dn.E_Way_Bill_Number__c = ewbNo;
                    dn.E_Way_Bill_Date__c = ewbDate;
                    dn.Valid_Upto__c = validUpto;
                    dn.Vehicle_Number__c = input.vehicleNumber;
                    dn.Transport_Mode__c = input.transportType;
                    dn.Transport_Distance__c = Integer.valueOf(input.transportDistance);
                    dn.Transporter_Name__c = input.transporterName;
                    dn.Transport_Id__c = input.gstin;
                    dn.Transport_Document_Number__c = input.transportDocNo;
                    dn.Transport_Document_Date__c = Date.valueOf(input.transportDocDate);
                    dn.Vehicle_Type__c = input.vehicleType;
                    dn.Vendor__c = input.vendorId;
                    dn.Supply_Type__c = input.supplyType;
                    dn.Sub_Supply_Type__c = input.subSupplyType;
                    dn.Sub_Supply_Description__c = input.subSupplyDesc;
                    dn.Document_Type__c = input.documentType;
                // }

                upsert dn;
            }
        } catch (Exception e) {
            System.debug('Error parsing response: ' + e.getMessage());
        }

        return resBody;
    }

    public class CancelWrapper {
        public String cancelRsnCode;
        public String cancelRemarks;
    }

    // Cancel E-Way Bill
    @AuraEnabled
    public static String cancelEWayBill(Id deliveryNoteId, String inputJson) {
        System.debug('Input JSON: ' + inputJson);
        System.debug('Delivery Note ID: ' + deliveryNoteId);
        CancelWrapper input = (CancelWrapper) JSON.deserialize(inputJson, CancelWrapper.class);
        Delivery_Note__c dn = [
            SELECT Id, E_Way_Bill_Number__c, Cancel_Reason_Code__c, Cancel_Remarks__c
            FROM Delivery_Note__c 
            WHERE Id = :deliveryNoteId 
            LIMIT 1
        ];
        System.debug('Delivery Note Record: ' + dn.E_Way_Bill_Number__c);

        if (dn.E_Way_Bill_Number__c == null) {
            throw new AuraHandledException('No E-Way Bill number found for this Delivery Note.');
        }

        Map<String, String> cancelReasonMap = new Map<String, String>{
            'Duplicate' => '1',
            'Order Cancelled' => '2',
            'Data Entry mistake' => '3',
            'Others' => '4'
        };
        String reasonCode = cancelReasonMap.containsKey(input.cancelRsnCode) ? cancelReasonMap.get(input.cancelRsnCode) : input.cancelRsnCode;
        // String reasonCode = cancelReasonMap.containsKey(wrapReq.cnlRsn) ? cancelReasonMap.get(wrapReq.cnlRsn) : wrapReq.cnlRsn;


        CancelEWayBillRequest req = new CancelEWayBillRequest();
        req.ewbNo = String.valueOf(dn.E_Way_Bill_Number__c);
        req.cancelRsnCode = reasonCode;
        req.cancelRmrk = input.cancelRemarks;
        // req.cancelRsnCode = dn.Cancel_Reason_Code__c;
        // req.cancelRmrk = dn.Cancel_Remarks__c;

        String jsonBody = JSON.serialize(req);
        String response = sendCallout(BASE_URL + '/cancelEwayBill', jsonBody);

        dn.E_Way_Bill_Number__c = null;
        dn.E_Way_Bill_Date__c = null;
        dn.Valid_Upto__c = null;
        dn.Vehicle_Number__c = null;
        dn.Transport_Mode__c = null;
        dn.Transport_Distance__c = null;
        dn.Transporter_Name__c = null;
        dn.Transport_Id__c = null;
        dn.Transport_Document_Number__c = null;
        dn.Transport_Document_Date__c = null;
        dn.Vehicle_Type__c = null;
        dn.Vendor__c = null;
        dn.Supply_Type__c = null;
        dn.Sub_Supply_Type__c = null;
        dn.Sub_Supply_Description__c = null;
        dn.Document_Type__c = null;
        update dn;

        return response;
    }

    // Reject EWB
    @AuraEnabled
    public static String rejectEwayBill(Id deliveryNoteId) {
        Delivery_Note__c dn = [
            SELECT Id, E_Way_Bill_Number__c
            FROM Delivery_Note__c 
            WHERE Id = :deliveryNoteId 
            LIMIT 1
        ];

        if (dn.E_Way_Bill_Number__c == null) {
            throw new AuraHandledException('No E-Way Bill number found for this Delivery Note.');
        }

        RejectEwayBillRequest req = new RejectEwayBillRequest();
        req.ewbNo = String.valueOf(dn.E_Way_Bill_Number__c);

        String jsonBody = JSON.serialize(req);
        String response = sendCallout(BASE_URL + '/rejectEwayBill', jsonBody);

        Map<String, Object> resMap = (Map<String, Object>) JSON.deserializeUntyped(response);
        if (resMap.containsKey('status_cd') && String.valueOf(resMap.get('status_cd')) == '1') {
            dn.E_Way_Bill_Number__c = null;
            dn.E_Way_Bill_Date__c = null;
            dn.Valid_Upto__c = null;
            dn.Vehicle_Number__c = null;
            dn.Transport_Mode__c = null;
            dn.Transport_Distance__c = null;
            dn.Transporter_Name__c = null;
            dn.Transport_Id__c = null;
            dn.Transport_Document_Number__c = null;
            dn.Transport_Document_Date__c = null;
            dn.Vehicle_Type__c = null;
            dn.Vendor__c = null;
            dn.Supply_Type__c = null;
            dn.Sub_Supply_Type__c = null;
            dn.Sub_Supply_Description__c = null;
            dn.Document_Type__c = null;
            update dn;
        }

        return response;
    }

    // Update Transporter
    @AuraEnabled
    public static String updateTransporter(Id deliveryNoteId, String inputJson) {
        System.debug('Input JSON: ' + inputJson);
        System.debug('Delivery Note ID: ' + deliveryNoteId);
        InputWrapper input = (InputWrapper) JSON.deserialize(inputJson, InputWrapper.class);
        Delivery_Note__c dn = [
            SELECT Id, E_Way_Bill_Number__c
            FROM Delivery_Note__c
            WHERE Id = :deliveryNoteId
            LIMIT 1
        ];
        System.debug('Delivery Note Record: ' + dn);
        UpdateTransporterRequest req = new UpdateTransporterRequest();
        req.ewbNo = String.valueOf(dn.E_Way_Bill_Number__c);
        System.debug('ewbNo: ' + req.ewbNo);

        req.transporterId = input.gstin;

        // String jsonBody = JSON.serialize(req);
        System.debug('JSON Body: ' + req);
        String resBody = sendCallout(BASE_URL + '/updateTransporter', req);
        System.debug('Response Body: ' + resBody);

        try {
            Map<String, Object> resMap = (Map<String, Object>) JSON.deserializeUntyped(resBody);
            if (resMap.containsKey('data')) {
                Map<String, Object> data = (Map<String, Object>) resMap.get('data');
                
                String transUpdateDate = (String) data.get('transUpdateDate');
                if (!String.isBlank(transUpdateDate)) {
                    dn.Valid_Upto__c = transUpdateDate;
                    dn.Vehicle_Number__c = input.vehicleNumber;
                    dn.Transport_Mode__c = input.transportType;
                    dn.Transport_Distance__c = Integer.valueOf(input.transportDistance);
                    dn.Transporter_Name__c = input.transporterName;
                    dn.Transport_Id__c = input.gstin;
                    dn.Transport_Document_Number__c = input.transportDocNo;
                    dn.Transport_Document_Date__c = Date.valueOf(input.transportDocDate);
                    dn.Vehicle_Type__c = input.vehicleType;
                    dn.Vendor__c = input.vendorId;
                    dn.Supply_Type__c = input.supplyType;
                    dn.Sub_Supply_Type__c = input.subSupplyType;
                    dn.Sub_Supply_Description__c = input.subSupplyDesc;
                    dn.Document_Type__c = input.documentType;
                    update dn;
                }
            }
        } catch (Exception e) {
            System.debug('Error parsing updateTransporter response: ' + e.getMessage());
        }

        return resBody;
    }

    // @AuraEnabled
    // public static String updateEWayBillVehicle(Id deliveryNoteId) {
    //     Delivery_Note__c dn = [
    //         SELECT Id, Vehicle_Number__c, Transport_Mode__c, Transport_Distance__c, Transporter_Name__c,
    //             Transport_Id__c, Transport_Document_Number__c, Transport_Document_Date__c, Vehicle_Type__c,
    //             E_Way_Bill_Number__c, Reason_Code__c, Reason_Remarks__c,
    //             Invoice__r.Id, Invoice__r.PlaceOfSupply__c
    //         FROM Delivery_Note__c
    //         WHERE Id = :deliveryNoteId
    //         LIMIT 1
    //     ];

    //     Location__c location = [
    //         SELECT GSTIN__c, Name, Address__c, Act_From_State_Code__c, From_State_Code__c
    //         FROM Location__c
    //         WHERE Name = :dn.Invoice__r.PlaceOfSupply__c
    //         LIMIT 1
    //     ];

    //     UpdateVehicleRequest req = new UpdateVehicleRequest();
    //     req.ewbNo       = String.valueOf(dn.E_Way_Bill_Number__c);
    //     req.vehicleNo   = dn.Vehicle_Number__c;
    //     req.reasonCode  = dn.Reason_Code__c;
    //     req.reasonRem   = dn.Reason_Remarks__c;
    //     req.transMode   = dn.Transport_Mode__c;
    //     req.transDocNo  = dn.Transport_Document_Number__c;
    //     req.transDocDate= (dn.Transport_Document_Date__c != null) ? String.valueOf(dn.Transport_Document_Date__c) : null;

    //     Map<String, Object> locMap = (Map<String, Object>) JSON.deserializeUntyped(location.Address__c);
    //     req.fromPlace = (String) locMap.get('City');
    //     req.fromState = Integer.valueOf((String)locMap.get('State'));

    //     String jsonBody = JSON.serialize(req);
    //     return sendCallout(BASE_URL + '/updateEwayBillVehicleNo', jsonBody);
    // }

    // Extend Validity
    // @AuraEnabled
    // public static String extendValidity(Id deliveryNoteId) {
    //     Delivery_Note__c dn = [
    //         SELECT Id, Vehicle_Number__c, Remaining_Distance__c,
    //             Transport_Document_Number__c, Transport_Document_Date__c,
    //             Transport_Mode__c, Consignment_Status__c,
    //             Transit_Type__c, Address_Line1__c, Address_Line2__c, Address_Line3__c,
    //             E_Way_Bill_Number__c,
    //             Invoice__r.PlaceOfSupply__c
    //         FROM Delivery_Note__c
    //         WHERE Id = :deliveryNoteId
    //         LIMIT 1
    //     ];

    //     if (dn.E_Way_Bill_Number__c == null) {
    //         throw new AuraHandledException('No E-Way Bill number found for this Delivery Note.');
    //     }

    //     Location__c location = [
    //         SELECT GSTIN__c, Name, Address__c, Act_From_State_Code__c, From_State_Code__c
    //         FROM Location__c
    //         WHERE Name = :dn.Invoice__r.PlaceOfSupply__c
    //         LIMIT 1
    //     ];

    //     ExtendValidityRequest req = new ExtendValidityRequest();
    //     req.ewbNo = String.valueOf(dn.E_Way_Bill_Number__c);
    //     req.vehicleNo = dn.Vehicle_Number__c;
    //     req.remainingDistance = (dn.Remaining_Distance__c != null) ? Integer.valueOf(dn.Remaining_Distance__c) : 0;
    //     req.transDocNo = dn.Transport_Document_Number__c;
    //     req.transDocDate = dn.Transport_Document_Date__c;
    //     req.transMode = dn.Transport_Mode__c;
    //     req.consignmentStatus = dn.Consignment_Status__c;
    //     req.transitType  = dn.Transit_Type__c != null ? dn.Transit_Type__c : '';
    //     req.addressLine1 = dn.Address_Line1__c != null ? dn.Address_Line1__c : '';
    //     req.addressLine2 = dn.Address_Line2__c != null ? dn.Address_Line2__c : '';
    //     req.addressLine3 = dn.Address_Line3__c != null ? dn.Address_Line3__c : '';

    //     Map<String, Object> locMap = (Map<String, Object>) JSON.deserializeUntyped(location.Address__c);
    //     req.fromPlace   = (String) locMap.get('City');
    //     req.fromState   = (String) locMap.get('State');
    //     req.fromPincode = String.valueOf(locMap.get('PostalCode'));

    //     String jsonBody = JSON.serialize(req);
    //     String response = sendCallout(BASE_URL + '/extendValidity', jsonBody);

    //     Map<String, Object> resMap = (Map<String, Object>) JSON.deserializeUntyped(response);
    //     if (resMap.containsKey('status_cd') && String.valueOf(resMap.get('status_cd')) == '1') {
    //         Map<String, Object> dataMap = (Map<String, Object>) resMap.get('data');
    //         if (dataMap != null && dataMap.containsKey('validityUpdateDate')) {
    //             String dateStr = String.valueOf(dataMap.get('validityUpdateDate'));
    //             try {
    //                 dn.Valid_Upto__c = dateStr;
    //                 update dn;
    //             } catch (Exception e) {
    //                 System.debug('Failed to parse validityUpdateDate: ' + e.getMessage());
    //             }
    //         }
    //     }

    //     return response;
    // }

    // @AuraEnabled
    // public static String generateConsolidatedEWayBill(Id invoiceId) {
    //     Invoice__c inv = [
    //         SELECT Id, Name, Invoice_Date__c, TotalAmount__c, Sum_Of_Amount_With_GST__c, PlaceOfSupply__c,
    //             Document_Type__c, Sub_Supply_Type__c, Sub_Supply_Description__c, Transaction_Type__c, 
    //             IGST__c, CGST__c, Cess__c, Cess_Non_Advol_Value__c, SGST__c, Account__r.Name, Account__r.GSTIN__c,
    //             Account__r.BillingStreet, Account__r.BillingCity,
    //             Account__r.BillingState, Account__r.BillingPostalCode, Account__r.Act_To_State_Code__c, Account__r.To_State_Code__c,
    //             (SELECT Id, Product1__r.Name, Product1__r.Description__c, Quantity__c, Rate__c, CESS__c,CGST__c, IGST__c, SGST__c,
    //                     Amount_With_GST__c, HsnSac__c
    //                 FROM Invoice_Items__r),
    //             (SELECT Id, Transport_Id__c, Transport_Mode__c, Vehicle_Number__c, Transport_Distance__c, Transporter_Name__c,
    //                 Transport_Document_Number__c, Transport_Document_Date__c, Vehicle_Type__c, E_Way_Bill_Number__c,
    //                 Reason_Code__c, Reason_Remarks__c
    //                 FROM Delivery_Notes__r)
    //         FROM Invoice__c WHERE Id = :invoiceId LIMIT 1
    //     ];

    //     Location__c location = [
    //         SELECT GSTIN__c, Name, Address__c, Act_From_State_Code__c, From_State_Code__c FROM Location__c
    //         WHERE Name =: inv.PlaceOfSupply__c LIMIT 1
    //     ];

    //     ConsolidatedEWayBillRequest req = new ConsolidatedEWayBillRequest();
    //     Map<String, Object> locMap = (Map<String, Object>) JSON.deserializeUntyped(location.Address__c);
    //     req.fromPlace = (String) locMap.get('City');
    //     req.fromState = (Integer) locMap.get('State');
    //     if (!inv.Delivery_Notes__r.isEmpty()) {
    //         Delivery_Note__c dn = inv.Delivery_Notes__r[0];
    //         req.vehicleNo = dn.Vehicle_Number__c;
    //         req.transMode = dn.Transport_Mode__c;
    //         req.transDocNo = dn.Transport_Document_Number__c; 
    //         req.transDocDate = String.valueOf(dn.Transport_Document_Date__c);
    //     }
    //     List<Object> tripSheetList = new List<Object>();
    //     if (inv.Delivery_Notes__r != null && !inv.Delivery_Notes__r.isEmpty()) {
    //         for (Delivery_Note__c dn : inv.Delivery_Notes__r) {
    //             if (dn.E_Way_Bill_Number__c != null) {
    //                 tripSheetList.add(new Map<String, Object>{ 'ewbNo' => Integer.valueOf(dn.E_Way_Bill_Number__c) });
    //             }
    //         }
    //     }
    //     req.tripSheetEwbBills = tripSheetList;

    //     String jsonBody = JSON.serialize(req);
    //     return sendCallout(BASE_URL + '/generateConsolidatedEwayBill', jsonBody);
    // }

    // Re-Generate Consolidated
    // public static String reGenerateConsolidated(Id invoiceId) {
    //     Invoice__c inv = [
    //         SELECT Id, Name, Invoice_Date__c, TotalAmount__c, Sum_Of_Amount_With_GST__c, PlaceOfSupply__c,
    //             Document_Type__c, Sub_Supply_Type__c, Sub_Supply_Description__c, Transaction_Type__c, 
    //             IGST__c, CGST__c, Cess__c, Cess_Non_Advol_Value__c, SGST__c, Account__r.Name, Account__r.GSTIN__c,
    //             Account__r.BillingStreet, Account__r.BillingCity,
    //             Account__r.BillingState, Account__r.BillingPostalCode, Account__r.Act_To_State_Code__c, Account__r.To_State_Code__c,
    //             (SELECT Id, Product1__r.Name, Product1__r.Description__c, Quantity__c, Rate__c, CESS__c,CGST__c, IGST__c, SGST__c,
    //                     Amount_With_GST__c, HsnSac__c
    //                 FROM Invoice_Items__r),
    //             (SELECT Id, Transport_Id__c, Transport_Mode__c, Vehicle_Number__c, Transport_Distance__c, Transporter_Name__c,
    //                 Transport_Document_Number__c, Transport_Document_Date__c, Vehicle_Type__c, E_Way_Bill_Number__c,
    //                 Reason_Code__c, Reason_Remarks__c, Cancel_Reason_Code__cc, Cancel_Remarks__c, Remaining_Distance__c,
    //                 Extension_Reason_Code__c, Extension_Remarks__c, Transit_Type__c, Address_Line1__c, Address_Line2__c, Address_Line3__c,
    //                 Trip_Sheet_Number__c
    //                 FROM Delivery_Notes__r)
    //         FROM Invoice__c WHERE Id = :invoiceId LIMIT 1
    //     ];

    //     Location__c location = [
    //         SELECT GSTIN__c, Name, Address__c, Act_From_State_Code__c, From_State_Code__c FROM Location__c
    //         WHERE Name =: inv.PlaceOfSupply__c LIMIT 1
    //     ];

    //     ReGenerateConsolidatedRequest req = new ReGenerateConsolidatedRequest();
    //     if (!inv.Delivery_Notes__r.isEmpty()) {
    //         Delivery_Note__c dn = inv.Delivery_Notes__r[0];
    //         req.tripSheetNo = String.valueOf(dn.Trip_Sheet_Number__c);
    //         req.vehicleNo = dn.Vehicle_Number__c;
    //         req.reasonCode = dn.Reason_Code__c;
    //         req.reasonRem = dn.Reason_Remarks__c;
    //         req.transDocNo = dn.Transport_Document_Number__c; 
    //         req.transDocDate = dn.Transport_Document_Date__c;
    //         req.transMode = dn.Transport_Mode__c;
    //     }
    //     Map<String, Object> locMap = (Map<String, Object>) JSON.deserializeUntyped(location.Address__c);
    //     req.fromPlace = (String) locMap.get('City');
    //     req.fromState = (String) locMap.get('State');

    //     String jsonBody = JSON.serialize(req);
    //     return sendCallout(BASE_URL + '/reGenerateConsolidatedEwayBill', jsonBody);
    // }

    // Initiate Multi-Vehicle
    // public static String initiateMultiVehicle(Id invoiceId) {
    //     Invoice__c inv = [
    //         SELECT Id, Name, Invoice_Date__c, TotalAmount__c, Sum_Of_Amount_With_GST__c, PlaceOfSupply__c,
    //             Document_Type__c, Sub_Supply_Type__c, Sub_Supply_Description__c, Transaction_Type__c, 
    //             IGST__c, CGST__c, Cess__c, Cess_Non_Advol_Value__c, SGST__c, Account__r.Name, Account__r.GSTIN__c,
    //             Account__r.BillingStreet, Account__r.BillingCity,
    //             Account__r.BillingState, Account__r.BillingPostalCode, Account__r.Act_To_State_Code__c, Account__r.To_State_Code__c,
    //             (SELECT Id, Product1__r.Name, Product1__r.Description__c, Quantity__c, Rate__c, CESS__c,CGST__c, IGST__c, SGST__c,
    //                     Amount_With_GST__c, HsnSac__c
    //                 FROM Invoice_Items__r),
    //             (SELECT Id, Transport_Id__c, Transport_Mode__c, Vehicle_Number__c, Transport_Distance__c, Transporter_Name__c,
    //                 Transport_Document_Number__c, Transport_Document_Date__c, Vehicle_Type__c, E_Way_Bill_Number__c,
    //                 Reason_Code__c, Reason_Remarks__c, Cancel_Reason_Code__cc, Cancel_Remarks__c, Remaining_Distance__c,
    //                 Extension_Reason_Code__c, Extension_Remarks__c, Transit_Type__c, Address_Line1__c, Address_Line2__c, Address_Line3__c,
    //                 Trip_Sheet_Number__c
    //                 FROM Delivery_Notes__r)
    //         FROM Invoice__c WHERE Id = :invoiceId LIMIT 1
    //     ];

    //     Location__c location = [
    //         SELECT GSTIN__c, Name, Address__c, Act_From_State_Code__c, From_State_Code__c FROM Location__c
    //         WHERE Name =: inv.PlaceOfSupply__c LIMIT 1
    //     ];

    //     InitiateMultiVehicleRequest req = new  InitiateMultiVehicleRequest();
    //     if (!inv.Delivery_Notes__r.isEmpty()) {
    //         Delivery_Note__c dn = inv.Delivery_Notes__r[0];
    //         req.ewbNo = String.valueOf(dn.E_Way_Bill_Number__c);
    //         req.reasonCode = dn.Reason_Code__c;
    //         req.reasonRem = dn.Reason_Remarks__c;
    //         req.transMode = dn.Transport_Mode__c;
    //         req.totalQuantity = dn.Total_Quantity__c;
    //         req.unitCode = dn.Unit_Code__c;
    //     }
    //     Map<String, Object> locMap = (Map<String, Object>) JSON.deserializeUntyped(location.Address__c);
    //     req.fromPlace = (String) locMap.get('City');
    //     req.fromState = (String) locMap.get('State');
    //     req.toPlace = inv.Account__r.BillingCity;
    //     req.toState = Integer.valueOf(inv.Account__r.BillingState);

    //     String jsonBody = JSON.serialize(req);
    //     return sendCallout(BASE_URL + '/initiateMultiVehicle', jsonBody);
    // }

    // public static String changeMultiVehicle(Id invoiceId) {
    //     // Fetch related invoice and company data
    //     Invoice__c inv = [
    //         SELECT Id, Name, EWay_Bill_No__c, From_Place__c, From_State__c, 
    //             Reason_Code__c, Reason_Remark__c, Old_Vehicle_No__c, New_Vehicle_No__c,
    //             Old_Transporter_No__c, New_Transporter_No__c, Group_No__c
    //         FROM Invoice__c WHERE Id = :invoiceId
    //     ];

    //     Company_Settings__mdt settings = Company_Settings__mdt.getInstance('Default');

    //     ChangeMultiVehicleRequest req = new ChangeMultiVehicleRequest();
    //     req.ewbNo = Long.valueOf(inv.EWay_Bill_No__c);
    //     req.groupNo = (Integer)inv.Group_No__c;
    //     req.oldvehicleNo = inv.Old_Vehicle_No__c;
    //     req.newVehicleNo = inv.New_Vehicle_No__c;
    //     req.oldTranNo = inv.Old_Transporter_No__c;
    //     req.newTranNo = inv.New_Transporter_No__c;
    //     req.fromPlace = inv.From_Place__c;
    //     req.fromState = (Integer)inv.From_State__c;
    //     req.reasonCode = inv.Reason_Code__c;
    //     req.reasonRem = inv.Reason_Remark__c;

    //     return sendCallout('/changeMultiVehicle',req);
    // }

    // Add Multi Vehicle
    // public static String addMultiVehicle(Id invoiceId) {
    //     // Fetch invoice, items, and company settings
    //     Invoice__c inv = [
    //         SELECT Id, Name, EWay_Bill_No__c, Vehicle_No__c, Group_No__c,
    //             Transport_Doc_No__c, Transport_Doc_Date__c
    //         FROM Invoice__c WHERE Id = :invoiceId
    //     ];

    //     List<Invoice_Item__c> items = [
    //         SELECT Id, Quantity__c
    //         FROM Invoice_Item__c WHERE Invoice__c = :invoiceId LIMIT 1
    //     ];

    //     Company_Settings__mdt settings = Company_Settings__mdt.getInstance('Default');

    //     AddMultiVehicleRequest req = new AddMultiVehicleRequest();
    //     req.ewbNo = Long.valueOf(inv.EWay_Bill_No__c);
    //     req.vehicleNo = inv.Vehicle_No__c;
    //     req.groupNo = (Integer)inv.Group_No__c;
    //     req.transDocNo = inv.Transport_Doc_No__c;
    //     req.transDocDate = inv.Transport_Doc_Date__c != null ? 
    //         inv.Transport_Doc_Date__c.format() : null;
    //     req.quantity = (items.isEmpty() ? 0 : items[0].Quantity__c);

    //     return sendCallout('/addMultiVehicle', req);
    // }

    private static String sendCallout(String endpoint, Object reqWrapper) {
        System.debug(JSON.serialize(reqWrapper));
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        HttpResponse res;
        try {
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(reqWrapper));
            res = http.send(req);
            return res.getBody();
        } catch (Exception e) {
            return '{"status":"ERROR","message":"' + e.getMessage() + '"}';
        }
    }

    @AuraEnabled(cacheable=true)
    public static InputWrapper getDeliveryNoteDetails(Id deliveryNoteId) {
        System.debug('Fetching details for Delivery Note Id: ' + deliveryNoteId);
        Delivery_Note__c dn = [
            SELECT Id,
                   E_Way_Bill_Number__c,
                   Vehicle_Number__c,
                   Transport_Mode__c,
                   Transport_Distance__c,
                   Transporter_Name__c,
                   Transport_Id__c,
                   Transport_Document_Number__c,
                   Transport_Document_Date__c,
                   Vehicle_Type__c,
                   Vendor__c,
                   Supply_Type__c,
                   Sub_Supply_Type__c,
                   Sub_Supply_Description__c,
                   Document_Type__c
            FROM Delivery_Note__c
            WHERE Id = :deliveryNoteId
            LIMIT 1
        ];

        // DeliveryNoteWrapper wrap = new DeliveryNoteWrapper();
        // // wrap.ewayBillNumber       = String.valueOf(dn.E_Way_Bill_Number__c);
        // wrap.vehicleNumber        = dn.Vehicle_Number__c;
        // wrap.transportMode        = dn.Transport_Mode__c;
        // wrap.transportDistance    = dn.Transport_Distance__c != null ? String.valueOf(dn.Transport_Distance__c) : '';
        // wrap.transporterName      = dn.Transporter_Name__c;
        // wrap.transporterId        = dn.Transport_Id__c;
        // wrap.transportDocNo       = dn.Transport_Document_Number__c;
        // wrap.transportDocDate     = dn.Transport_Document_Date__c != null ? String.valueOf(dn.Transport_Document_Date__c) : '';
        // wrap.vehicleType          = dn.Vehicle_Type__c;
        // wrap.vendor               = dn.Vendor__c;
        // wrap.supplyType           = dn.Supply_Type__c;
        // wrap.subSupplyType        = dn.Sub_Supply_Type__c;
        // wrap.subSupplyDesc        = dn.Sub_Supply_Description__c;
        // wrap.documentType         = dn.Document_Type__c;
        InputWrapper wrap = new InputWrapper();
        // wrap.ewayBillNumber       = String.valueOf(dn.E_Way_Bill_Number__c);
        wrap.vehicleNumber        = dn.Vehicle_Number__c;
        wrap.transportType        = dn.Transport_Mode__c;
        wrap.transportDistance    = dn.Transport_Distance__c != null ? String.valueOf(dn.Transport_Distance__c) : '';
        wrap.transporterName      = dn.Transporter_Name__c;
        wrap.gstin                = dn.Transport_Id__c;
        wrap.transportDocNo       = dn.Transport_Document_Number__c;
        wrap.transportDocDate     = dn.Transport_Document_Date__c != null ? String.valueOf(dn.Transport_Document_Date__c) : '';
        wrap.vehicleType          = dn.Vehicle_Type__c;
        wrap.vendorId             = dn.Vendor__c;
        wrap.supplyType           = dn.Supply_Type__c;
        wrap.subSupplyType        = dn.Sub_Supply_Type__c;
        wrap.subSupplyDesc        = dn.Sub_Supply_Description__c;
        wrap.documentType         = dn.Document_Type__c;
        System.debug('Delivery Note details: ' + JSON.serialize(wrap));
        return wrap;
    }

    // public class DeliveryNoteWrapper {
    //     @AuraEnabled public String ewayBillNumber;
    //     @AuraEnabled public String vehicleNumber;
    //     @AuraEnabled public String transportMode;
    //     @AuraEnabled public String transportDistance;
    //     @AuraEnabled public String transporterName;
    //     @AuraEnabled public String transporterId;
    //     @AuraEnabled public String transportDocNo;
    //     @AuraEnabled public String transportDocDate;
    //     @AuraEnabled public String vehicleType;
    //     @AuraEnabled public String vendor;
    //     @AuraEnabled public String supplyType;
    //     @AuraEnabled public String subSupplyType;
    //     @AuraEnabled public String subSupplyDesc;
    //     @AuraEnabled public String documentType;
    // }

    @AuraEnabled(cacheable=true)
    public static List<String> getCancelReasons() {
        List<String> picklistValues = new List<String>();
        Schema.DescribeFieldResult fieldResult = Delivery_Note__c.Cancel_Reason_Code__c.getDescribe();
        List<Schema.PicklistEntry> rsnCode = fieldResult.getPicklistValues();
        for (Schema.PicklistEntry code : rsnCode) {
            picklistValues.add(code.getValue());
        }
        return picklistValues;
    }
    public class AuthWrapper {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String Username { get; set; }
        @AuraEnabled public String Password { get; set; }
        @AuraEnabled public String clientId { get; set; }
        @AuraEnabled public String clientSecret { get; set; }
        @AuraEnabled public String gstIn { get; set; }
        @AuraEnabled public String emailId { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static AuthWrapper getDetails() {
        Authentication__c auth = [
            SELECT Id, Client_Id__c, Client_Secret__c, Email__c, GSTIN__c, Password__c, User_Name__c
            FROM Authentication__c
            WHERE Type__c = 'E-Way Bill'
            LIMIT 1
        ];

        AuthWrapper wrap = new AuthWrapper();
        wrap.id = (auth.Id != null) ? auth.Id : null;
        wrap.Username     = (auth.User_Name__c != null) ? auth.User_Name__c : null;
        wrap.Password     = (auth.Password__c != null) ? auth.Password__c : null;
        wrap.clientId     = (auth.Client_Id__c != null) ? auth.Client_Id__c : null;
        wrap.clientSecret = (auth.Client_Secret__c != null) ? auth.Client_Secret__c : null;
        wrap.gstIn        = (auth.GSTIN__c != null) ? auth.GSTIN__c : null;
        wrap.emailId      = (auth.Email__c != null) ? auth.Email__c : null;

        System.debug('Returning wrapper: ' + JSON.serialize(wrap));
        return wrap;
    }
    
}