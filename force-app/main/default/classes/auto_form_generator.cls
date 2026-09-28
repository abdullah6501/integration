//AT 10MAY2025 to get genearted form from openai
public with sharing class auto_form_generator {

    @AuraEnabled
    public static string generat_form(string prompt,List<Map<String, Object>> chatHistory, List<Map<String, Object>>  pages, String currentPage_id, String attachment_url) {

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
        requestBody.put('pages', pages);
        requestBody.put('currentPage_id', currentPage_id);
        requestBody.put('doc_url', attachment_url);
        // requestBody.put('fields', this.getfields(objectName));
        System.debug('requestbody: '+requestBody);

        request.setBody(JSON.serialize(requestBody));

        try {
            return '{"sucess":"ok"}';
            // HttpResponse response = http.send(request);
            // if (response.getStatusCode() == 200) {
            //     System.debug('response: ' + response.getBody());
            //     return response.getBody();
            // } else {
            //     System.debug('Failed response: ' + response.getBody());
            //     throw new AuraHandledException('API call failed: ' + response.getStatus());
            // }
        } catch (Exception e) {
            System.debug('Callout error: ' + e.getMessage());
            throw new AuraHandledException('Callout error: ' + e.getMessage());
        }
           }

    @AuraEnabled
    public static string generate_pdf(string prompt,List<Map<String, Object>> chatHistory, List<Map<String, Object>>  structure, String attachment_url) {
        return '{"sucess":"ok"}';

        // Http http = new Http();
        // HttpRequest request = new HttpRequest();
        // request.setEndpoint(System.Label.fg_assistant_endpoint+'/generate-pdf');
        // request.setMethod('POST');
        // request.setHeader('Content-Type', 'application/json');
        // request.setHeader('Accept', 'application/json');
        // request.setTimeout(120000); 
        // request.setHeader('Authorization', 'Bearer ' + System.Label.fg_assistant_token);

        // Map<String, Object> requestBody = new Map<String, Object>();
        // requestBody.put('prompt', prompt);
        // requestBody.put('chatHistory', chatHistory);
        // requestBody.put('fields', structure);
        // requestBody.put('doc_url', attachment_url);
        // // requestBody.put('fields', this.getfields(objectName));
        // System.debug('requestbody: '+requestBody);

        // request.setBody(JSON.serialize(requestBody));

        // try {
        //     HttpResponse response = http.send(request);
        //     if (response.getStatusCode() == 200) {
        //         System.debug('response: ' + response.getBody());
        //         return response.getBody();
        //     } else {
        //         System.debug('Failed response: ' + response.getBody());
        //         throw new AuraHandledException('API call failed: ' + response.getStatus());
        //     }
        // } catch (Exception e) {
        //     System.debug('Callout error: ' + e.getMessage());
        //     throw new AuraHandledException('Callout error: ' + e.getMessage());
        // }
           }

    // public static string getfields(string objectName) {
    //     Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
    //     List<String> fieldNames = new List<String>();

    //     if (globalDescribe.containsKey(objectName)) {
    //         Schema.SObjectType sObjectType = globalDescribe.get(objectName);
    //         Map<String, Schema.SObjectField> fieldMap = sObjectType.getDescribe().fields.getMap();

    //         for (String fieldName : fieldMap.keySet()) {
    //             Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
    //             String label = fieldDescribe.getLabel();
    //             String apiName = fieldDescribe.getName();
    //             String description = fieldDescribe.getInlineHelpText();
    //         }
    //     } else {
    //         System.debug('Object ' + objectName + ' not found in global describe.');
    //     }
    //     Map<String, Schema.SObjectField> fieldsMap = Schema.getGlobalDescribe().get(objectName).getDescribe().fields.getMap();
    //     for (String fieldName : fieldsMap.keySet()) {
    //         fieldNames.add(fieldName);
    //     }
    //     return JSON.serialize(fieldNames);
    // }

    public auto_form_generator() {

    }
}