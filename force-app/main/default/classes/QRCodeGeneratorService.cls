public with sharing class QRCodeGeneratorService {
    public static void generateQRCodeAndStore(String param1, String param2, String param3, String param4) {
        try {
            Map<String, Object> requestBody = new Map<String, Object>();
            requestBody.put('sellerName', param1);
            requestBody.put('vatNumber', param2);
            requestBody.put('date', param3);
            requestBody.put('totalInvoiceAmount', param4);
            
            String requestBodyJson = JSON.serialize(requestBody);
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://zatca-api.rangerfusion.com/generateQR');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(requestBodyJson);
            
            Http http = new Http();
            HttpResponse res = http.send(req);

            System.debug('Response: ' + res.getBody());
            
            if (res.getStatusCode() == 200 && String.isNotBlank(res.getBody())) {
                String base64QR = res.getBody();
                generateQRCodeFromBase64(base64QR);
            } else {
                System.debug('Error: ' + res.getStatus());
            }
        } catch (Exception e) {
            System.debug('Exception in generateQRCodeAndStore: ' + e.getMessage());
        }
    }

    public static void generateQRCodeFromBase64(String base64String) {
        try {
            if (String.isBlank(base64String)) {
                System.debug('Empty Base64 string received');
                return;
            }

            String qrCodeUrl = 'https://quickchart.io/qr?text=' + EncodingUtil.urlEncode(base64String, 'UTF-8');

            HttpRequest req = new HttpRequest();
            req.setEndpoint(qrCodeUrl);
            req.setMethod('GET');

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                Blob qrImageBlob = res.getBodyAsBlob();
                String publicUrl = saveQRImageAsPublicFile(qrImageBlob, 'GeneratedQRCode');

                if (publicUrl != null) {
                    QRCode__c qrRecord = new QRCode__c();
                    qrRecord.QRCode_URL__c = publicUrl;
                    if (Schema.sObjectType.QRCode__c.isCreateable()) {
                        insert qrRecord;
                        System.debug('QR Code Stored Successfully: ' + publicUrl);
                    } else {
                        System.debug('No permission to create QRCode__c record');
                    }
                    System.debug('QR Code Stored Successfully: ' + publicUrl);
                }
            } else {
                System.debug('Failed to fetch QR code image, Status Code: ' + res.getStatusCode());
            }
        } catch (Exception e) {
            System.debug('Exception in generateQRCodeFromBase64: ' + e.getMessage());
        }
    }

    private static String saveQRImageAsPublicFile(Blob imageBlob, String fileName) {
        try {
            if (imageBlob == null) {
                System.debug('Image Blob is null');
                return null;
            }
        
            ContentVersion cv = new ContentVersion();
            cv.Title = fileName;
            cv.PathOnClient = fileName + '.png';
            cv.VersionData = imageBlob;
            cv.IsMajorVersion = true;
            if (Schema.sObjectType.ContentVersion.isCreateable()) {
                insert cv;
            } else {
                System.debug('No permission to create ContentVersion record');
                return null;
            }

            ContentDocument cd;
            if (Schema.sObjectType.ContentDocument.isAccessible()) {
                cd = [SELECT Id FROM ContentDocument WHERE LatestPublishedVersionId = :cv.Id LIMIT 1];
            } else {
                System.debug('No permission to access ContentDocument records');
                return null;
            }

            ContentDistribution distribution = new ContentDistribution(
                Name = cv.Title,
                ContentVersionId = cv.Id,
                PreferencesAllowViewInBrowser = true
            );
            if (Schema.sObjectType.ContentDistribution.isCreateable()) {
                insert distribution;
            } else {
                System.debug('No permission to create ContentDistribution record');
                return null;
            }

            ContentDistribution shareFile = [
                SELECT Id, ContentDownloadUrl, DistributionPublicUrl 
                FROM ContentDistribution 
                WHERE Id = :distribution.Id
            ];

            return shareFile.DistributionPublicUrl;
        } catch (Exception e) {
            System.debug('Error in saveQRImageAsPublicFile: ' + e.getMessage());
            return null;
        }
    }
}