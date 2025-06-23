public with sharing class PdfService {
    @AuraEnabled
    public static Map<String, Object> fetchAndStorePDF(String json, String relatedRecordId, String pdfName,String qbName) {
        // system.debug('Input JSON: ' + json);
        // system.debug('Related Record ID: ' + relatedRecordId);
        Map<String, Object> resultMap = new Map<String, Object>();
        try {
            BatchLabelPDF__c settings = BatchLabelPDF__c.getInstance();
            String endpointUrl = settings.PDFGenerateEndpoint__c;
            if (String.isBlank(endpointUrl)) {
                resultMap.put('success', false);
                resultMap.put('message', 'PDF Generate Endpoint not configured in Custom Settings.');
                return resultMap;
            }
            if (String.isBlank(pdfName)) {
                pdfName = 'Generated_PDF';
            }
            if (String.isBlank(qbName)) {
                qbName = 'QB';
            }
            String authCode = 'R_NXT_2.82';
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpointUrl);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('x-salesforce-auth', authCode);
            req.setBody('{"questionbook":' + json + '}');

            Http http = new Http();
            HttpResponse response = http.send(req);

            if (response.getStatusCode() == 200) {
                String responseString = response.getBody();
                Map<String, Object> responseMap = (Map<String, Object>) System.JSON.deserializeUntyped(responseString);

                if (responseMap.containsKey('success') && (Boolean) responseMap.get('success')) {
                    String base64Data = (String) responseMap.get('data');

                    if (String.isNotBlank(base64Data)) {
                        Blob pdfBlob = EncodingUtil.base64Decode(base64Data);
                        
                        List<ContentVersion> existingFiles = [
                            SELECT Title FROM ContentVersion 
                            WHERE Title LIKE :pdfName + ' ' + qbName + '%'
                        ];
                        
                        String newTitle = getNextAvailableTitle(existingFiles, pdfName, qbName);

                        ContentVersion contentVersion = new ContentVersion();
                        contentVersion.Title = newTitle;
                        contentVersion.PathOnClient = newTitle + '.pdf';
                        contentVersion.VersionData = pdfBlob;
                        contentVersion.ContentLocation = 'S';

                        if (Schema.sObjectType.ContentVersion.isCreateable()) {
                            insert contentVersion;
                        } else {
                            resultMap.put('success', false);
                            resultMap.put('message', 'Insufficient permissions to create ContentVersion record.');
                            return resultMap;
                        }

                        ContentDocument contentDoc = [
                            SELECT Id FROM ContentDocument 
                            WHERE Id IN (SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id) 
                            LIMIT 1
                        ];

                        ContentDocumentLink contentLink = new ContentDocumentLink();
                        contentLink.ContentDocumentId = contentDoc.Id;
                        contentLink.LinkedEntityId = relatedRecordId; 
                        contentLink.ShareType = 'V'; 
                        if (Schema.sObjectType.ContentDocumentLink.isCreateable()) {
                            insert contentLink;
                        } else {
                            resultMap.put('success', false);
                            resultMap.put('message', 'Insufficient permissions to create ContentDocumentLink record.');
                            return resultMap;
                        }

                        resultMap.put('success', true);
                        resultMap.put('message', 'PDF stored successfully!');
                    } else {
                        resultMap.put('success', false);
                        resultMap.put('message', 'Base64 data is empty.');
                    }
                } else {
                    resultMap.put('success', false);
                    resultMap.put('message', 'API Response unsuccessful.');
                }
            } else {
                resultMap.put('success', false);
                resultMap.put('message', 'HTTP Error: ' + response.getStatusCode());
            }
        } catch (Exception e) {
            resultMap.put('success', false);
            resultMap.put('message', 'Exception: ' + e.getMessage());
        }
        system.debug('Result Map: ' + resultMap);
        return resultMap;
    }

    private static String getNextAvailableTitle(List<ContentVersion> existingFiles, String pdfName, String qbName) {
        Set<Integer> usedNumbers = new Set<Integer>();
        
        for (ContentVersion file : existingFiles) {
            String title = file.Title;
            if (title == pdfName + ' ' + qbName) {
                usedNumbers.add(0);
            } else if (title.startsWith(pdfName + ' ' + qbName + ' ')) {
                String suffix = title.substring((pdfName + ' ' + qbName + ' ').length());
                if (!String.isEmpty(suffix) && suffix.isNumeric()) {
                    usedNumbers.add(Integer.valueOf(suffix));
                }
            }
        }
        
        Integer nextNumber = 0;
        while (usedNumbers.contains(nextNumber)) {
            nextNumber++;
        }
        
        return nextNumber == 0 ? pdfName + ' ' + qbName : pdfName + ' ' + qbName + ' ' + String.valueOf(nextNumber);
    }
}