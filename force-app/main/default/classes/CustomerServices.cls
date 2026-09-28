public with sharing class CustomerServices {
    @AuraEnabled
    public static string generat_form(string prompt,List<Map<String, Object>> chatHistory, String attachment_url) {
        Id orgId = UserInfo.getOrganizationId();
        Id userId = UserInfo.getUserId();

        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(System.Label.fg_assistant_endpoint+'/generate-form');
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Accept', 'application/json');
        request.setTimeout(120000); 
        request.setHeader('Authorization', 'Bearer ' + System.Label.fg_assistant_token);

        Map<String, Object> requestBody = new Map<String, Object>();
        requestBody.put('prompt', prompt);
        requestBody.put('chatHistory', chatHistory);
        requestBody.put('orgId', orgId);
        requestBody.put('userId', userId);
        requestBody.put('doc_url', attachment_url);
        System.debug('requestbody: '+requestBody);

        request.setBody(JSON.serialize(requestBody));

        try {
            HttpResponse response = http.send(request);
            if (response.getStatusCode() == 200) {
                System.debug('response: ' + response.getBody());
                return response.getBody();
            } else {
                System.debug('Failed response: ' + response.getBody());
                throw new AuraHandledException('API call failed: ' + response.getStatus());
            }
        } catch (Exception e) {
            System.debug('Callout error: ' + e.getMessage());
            throw new AuraHandledException('Callout error: ' + e.getMessage());
        }
    }
}