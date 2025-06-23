public with sharing class ZATCA_GenerateCSR {
    public static void generateCSR() {
        try {
            if (!Schema.sObjectType.ContentVersion.isAccessible()) {
                System.debug('No access to ContentVersion object');
                return;
            }

            ContentVersion cv = [SELECT Id, VersionData FROM ContentVersion 
                                 WHERE Title = 'csr-config-example-EN' ORDER BY CreatedDate DESC LIMIT 1];

            if (cv == null) {
                System.debug('CSR Config file not found in Salesforce');
                return;
            }

            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://zatca-api.rangerfusion.com/generateCSR');
            req.setMethod('POST');
            req.setHeader('accept', 'application/json');
            req.setHeader('OTP', '123456');
            req.setHeader('Content-Type', 'multipart/form-data; boundary=----WebKitFormBoundary');

            String boundary = '----WebKitFormBoundary';
            String bodyStart = '--' + boundary + '\r\n' +
                               'Content-Disposition: form-data; name="CSR CONFIG FILE"; filename="csr-config-example-EN.properties"\r\n' +
                               'Content-Type: text/plain\r\n\r\n';

            String bodyEnd = '\r\n--' + boundary + '--';

            String fileContent = EncodingUtil.base64Encode(cv.VersionData);
            String finalBody = bodyStart + EncodingUtil.base64Decode(fileContent).toString() + bodyEnd;

            req.setBody(finalBody);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                String csrFullContent = res.getBody();
                System.debug('CSR Generated Successfully: ' + csrFullContent);

                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(csrFullContent);
                String csrContent = (String) responseMap.get('csr'); 

                ZATCA_CONFIG__c config = new ZATCA_CONFIG__c();
                config.CSR__c = csrContent;

                if (Schema.sObjectType.ZATCA_CONFIG__c.isCreateable()) {
                    insert config;
                    System.debug('CSR stored in ZATCA_CONFIG__c: ' + csrContent);

                    System.enqueueJob(new ZATCA_CCSIDQueueable(config.Id, csrContent));
                } else {
                    System.debug('No create access to ZATCA_CONFIG__c object');
                }
            } else {
                System.debug('Error in CSR Generation: ' + res.getStatus() + ' - ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Exception in CSR Generation: ' + e.getMessage());
        }
    }

    public class ZATCA_CCSIDQueueable implements Queueable, Database.AllowsCallouts {
        private Id configId;
        private String csrContent;
 
        public ZATCA_CCSIDQueueable(Id configId, String csrContent) {
           this.configId = configId;
           this.csrContent = csrContent;
        }
 
        public void execute(QueueableContext context) {
            try {
                HttpRequest req = new HttpRequest();
                req.setEndpoint('https://zatca-api.rangerfusion.com/complianceCSID');
                req.setMethod('POST');
                req.setHeader('accept', 'application/json');
                req.setHeader('OTP', '123456');
                req.setHeader('Accept-Version', 'V2');
                req.setHeader('Content-Type', 'application/json');
                String requestBody = '{"csr": "' + csrContent + '"}';
                req.setBody(requestBody);
 
                Http http = new Http();
                HttpResponse res = http.send(req);
 
                if (res.getStatusCode() == 200) {
                    Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    Long requestID = (Long) responseMap.get('requestID');
                    String dispositionMessage = (String) responseMap.get('dispositionMessage');
                    String binarySecurityToken = (String) responseMap.get('binarySecurityToken');
                    String secret = (String) responseMap.get('secret');
                    String error = (String) responseMap.get('errors');
                    System.debug('error' + error);
 
                    System.debug('Compliance CSID Response: ' + res.getBody());
 
                    ZATCA_CONFIG__c config = [SELECT Id FROM ZATCA_CONFIG__c WHERE Id = :configId LIMIT 1];
                    config.Compliance_Request_ID__c = requestID;
                    config.Compliance_Disposition_Message__c = dispositionMessage;
                    config.Compliance_Binary_Security_Token__c = binarySecurityToken;
                    config.Compliance_Secret__c = secret;
                    config.Compliance_Error__c = error;
 
                    update config;
                    System.debug('Compliance CSID stored in ZATCA_CONFIG__c');
 
                    System.enqueueJob(new ZATCA_ProductionCSIDQueueable(config.Id, requestID, binarySecurityToken, secret));
                } else {
                    System.debug('Error in Compliance CSID: ' + res.getStatus() + ' - ' + res.getBody());
                }
            } catch (Exception e) {
                System.debug('Exception in Compliance CSID Fetching: ' + e.getMessage());
            }
        }
    }

    public class ZATCA_ProductionCSIDQueueable implements Queueable, Database.AllowsCallouts {
        private Id configId;
        private Long requestID;
        private String binarySecurityToken;
        private String secret;

        public ZATCA_ProductionCSIDQueueable(Id configId, Long requestID, String binarySecurityToken, String secret) {
            this.configId = configId;
            this.requestID = requestID;
            this.binarySecurityToken = binarySecurityToken;
            this.secret = secret;
        }

        public void execute(QueueableContext context) {
            try {
                String authString = binarySecurityToken + ':' + secret;
                String encodedAuth = 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(authString));

                HttpRequest req = new HttpRequest();
                req.setEndpoint('https://zatca-api.rangerfusion.com/productionCSID');
                req.setMethod('POST');
                req.setHeader('accept', 'application/json');
                req.setHeader('Accept-Version', 'V2');
                req.setHeader('Authorization', encodedAuth);    
                req.setHeader('Content-Type', 'text/plain');
                req.setBody(String.valueOf(requestID));

                Http http = new Http();
                HttpResponse res = http.send(req);

                if (res.getStatusCode() == 200) {
                    Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    Long productionRequestID = (Long) responseMap.get('requestID');
                    String tokenType = (String) responseMap.get('tokenType');
                    String dispositionMessage = (String) responseMap.get('dispositionMessage');
                    String productionBinarySecurityToken = (String) responseMap.get('binarySecurityToken');
                    String productionSecret = (String) responseMap.get('secret');

                    System.debug('Production CSID Response: ' + res.getBody());

                    ZATCA_CONFIG__c config = [SELECT Id FROM ZATCA_CONFIG__c WHERE Id = :configId LIMIT 1];
                    config.Production_Request_ID__c = productionRequestID;
                    config.Production_Token_Type__c = tokenType;
                    config.Production_Disposition_Message__c = dispositionMessage;
                    config.Production_Binary_Security_Token__c = productionBinarySecurityToken;
                    config.Production_Secret__c = productionSecret;

                    update config;
                    System.debug('Production CSID stored in ZATCA_CONFIG__c');
                } else {
                    System.debug('Error in Production CSID: ' + res.getStatus() + ' - ' + res.getBody());
                }
            } catch (Exception e) {
                System.debug('Exception in Production CSID Fetching: ' + e.getMessage());
            }
        }
    }
}