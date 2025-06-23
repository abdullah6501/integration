public with sharing class PdfGenerate {
    @AuraEnabled
    public static Map<String, Object> fetchAndStorePDF(String json, String relatedRecordId) {
        try {
            System.debug('Related Record ID: ' + relatedRecordId);
            System.debug('JSON: ' + json);

            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://server-js-c21c9b744b68.herokuapp.com/json-to-pdf');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(json);
            // req.setBody('questionbook',json);

            Http http = new Http();
            HttpResponse response = http.send(req);

            String res = response.getBody();

            if (response.getStatusCode() == 200) {
                System.debug('Response: ' + res);
                String responseString = response.getBody();
                Map<String, Object> responseMap = (Map<String, Object>) System.JSON.deserializeUntyped(responseString); 

                if (responseMap.containsKey('success') && (Boolean) responseMap.get('success')) {
                    String base64Data = (String) responseMap.get('data');

                    if (String.isNotBlank(base64Data)) {
                        Blob pdfBlob = EncodingUtil.base64Decode(base64Data);
                        
                        ContentVersion contentVersion = new ContentVersion();
                        contentVersion.Title = 'Generated_PDF';
                        contentVersion.PathOnClient = 'Generated_PDF.pdf';
                        contentVersion.VersionData = pdfBlob;
                        contentVersion.ContentLocation = 'S';
                        if (Schema.sObjectType.ContentVersion.isCreateable()) {
                            insert contentVersion;

                            ContentDocument contentDoc = [
                                SELECT Id FROM ContentDocument 
                                WHERE Id IN (SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id) 
                                LIMIT 1
                            ];

                            if (Schema.sObjectType.ContentDocumentLink.isCreateable()) {
                                ContentDocumentLink contentLink = new ContentDocumentLink();
                                contentLink.ContentDocumentId = contentDoc.Id;
                                contentLink.LinkedEntityId = relatedRecordId; 
                                contentLink.ShareType = 'V'; 
                                insert contentLink;

                                System.debug('PDF stored successfully in Files and linked to record: ' + relatedRecordId);
                            } else {
                                System.debug('Insufficient permissions to create ContentDocumentLink.');
                            }
                        } else {
                            System.debug('Insufficient permissions to create ContentVersion.');
                        }
                        
                        System.debug('PDF stored successfully in Files and linked to record: ' + relatedRecordId);
                    } else {
                        System.debug('Base64 data is empty.');
                    }
                } else {
                    System.debug('API Response unsuccessful.');
                }
            } else {
                System.debug('HTTP Error: ' + response.getStatusCode() + ' - ' + response.getBody());
            }
        } catch (Exception e) {
            System.debug('Exception: ' + e.getMessage());
        }
        return null;
    }
}
