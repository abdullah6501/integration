public class QRCodeService {
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
            
            if (res.getStatusCode() == 200) {
                // Response is Base64 string (QR Code)
                String base64QR = res.getBody();

                
                
                if (base64QR != null && base64QR.length() > 0) {
                    // Save as Salesforce File
                    String publicUrl = saveBase64AsPublicFile(base64QR, 'QRCode');
                    System.debug('Public URL got: ' + publicUrl);
                    
                    // Create a new record in QRCode__c object
                    if (publicUrl != null) {
                        QRCode__c qrRecord = new QRCode__c();
                        qrRecord.QRCode_URL__c = publicUrl;
                        if (Schema.sObjectType.QRCode__c.isCreateable()) {
                            insert qrRecord;
                        } else {
                            System.debug('No permission to create QRCode__c records.');
                        }
                    }
                }
            } else {
                System.debug('Error: ' + res.getStatus());
            }
            // if (res.getStatusCode() == 200) {
            //     // Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            //     String base64QR = res.getBody();
                
            //     if (responseMap.containsKey('base64QR')) {
            //         String base64QR = (String) responseMap.get('base64QR');
                    
            //         String publicUrl = saveBase64AsPublicFile(base64QR, 'QRCode');
                    
            //         if (publicUrl != null) {
            //             QRCode__c qrRecord = new QRCode__c();
            //             qrRecord.QRCode_URL__c = publicUrl;
            //             if (Schema.sObjectType.QRCode__c.isCreateable()) {
            //                 insert qrRecord;
            //             } else {
            //                 System.debug('No permission to create QRCode__c records.');
            //             }
            //         }
            //     }
            // } else {
            //     System.debug('Error: ' + res.getStatus());
            // }
        } catch (Exception e) {
            System.debug('Exception: ' + e.getMessage());
        }
    }

    private static String saveBase64AsPublicFile(String base64Data, String fileName) {
        try {
            System.debug('base64Data: ' + base64Data);
            System.debug('fileName: ' + fileName);
            Blob fileBlob = EncodingUtil.base64Decode(base64Data);
            
            ContentVersion cv = new ContentVersion();
            cv.Title = fileName;
            cv.PathOnClient = fileName + '.png';
            cv.VersionData = fileBlob;
            cv.IsMajorVersion = true;
            if (Schema.sObjectType.ContentVersion.isCreateable()) {
                insert cv;
            } else {
                System.debug('No permission to create ContentVersion records.');
            }

            ContentDocument cd;
            if (Schema.sObjectType.ContentDocument.isAccessible()) {
                cd = [SELECT Id FROM ContentDocument WHERE LatestPublishedVersionId = :cv.Id LIMIT 1];
                System.debug('ContentDocument Id: ' + cd.Id);
            } else {
                System.debug('No permission to read ContentDocument records.');
                return null;
            }

            ContentDistribution distribution = new ContentDistribution(Name = fileName,
                                                                       ContentVersionId = cv.Id,
                                                                       PreferencesAllowViewInBrowser = true);

            if (Schema.sObjectType.ContentDistribution.isCreateable()) {
                insert distribution;
            } else {
                System.debug('No permission to create ContentDistribution records.');
                return null;
            }
            ContentDistribution shareFile = [SELECT Id, ContentDownloadUrl, DistributionPublicUrl FROM ContentDistribution WHERE Id = :distribution.Id];
            String publicUrl = shareFile.DistributionPublicUrl;
            // ContentDistribution cdistro = new ContentDistribution();
            // cdistro.Name = fileName;
            // cdistro.ContentVersionId = cv.Id;
            // cdistro.PreferencesAllowViewInBrowser = true;
            // cdistro.PreferencesAllowOriginalDownload = true;
            // if (Schema.sObjectType.ContentDistribution.isCreateable()) {
            //     System.debug('Inserting ContentDistribution record...');
            //     insert cdistro;
            // } else {
            //     System.debug('No permission to create ContentDistribution records.');
            //     return null;
            // }

            System.debug('Public URL: ' + publicUrl);

            return publicUrl;
        } catch (Exception e) {
            System.debug('Error: ' + e.getMessage());
            return null;
        }
    }
}
