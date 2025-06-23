public with sharing class WhatsAppTemplateController {
    @AuraEnabled
    public static String sendTemplateMessage(String phoneNumber, String templateName, String language, List<String> parameters) {
        String phoneId = '386100344590283'; //Ranger
        // String phoneId = '551350278069887';
        String accessToken = 'EAAXlnOd7Gv0BO2UK1GLm3ALR9FqXpXtKfULirhohhDEzcc7zPFJa7y4nx0aZB9XZBhvWyS5uZApqzKtu6GS5R6K6Nj9uGcwXvNbpFZB5rJy7iAO147FxfGZCCVSwajSFB98LkcmhE9XSsVM8bpeolIsc0RHB7zzQ43ZC0NZBo64X6Gm34HAAnNRAblMro72ZC5LDZCQZDZD'; //Ranger
        // String accessToken = 'EAAV3QI4oOUYBOZCJSMD1aYKAa6TmPTcRVKAA4QENJ0wlV5zzzcoPwQm2gRa8x5BmaDqoYrjC1R3dsRvRzoWiTPibx0nFoXsv5YsSg5CwLKZAmY0oXZCpV3jBxnqnOSGZCBu3q9in6eUOLLPnMxtmdLCxa0DZCcLJASyC49oZCcRedo46xLBpR0A4TjZAYSh8GZBZA3QZDZD';
        String apiUrl = 'https://graph.facebook.com/v17.0/' + phoneId + '/messages';
 
            WhatsApp_Template__c template = [
            SELECT Language__c, Parameter_Format__c, Parameters__c, Template_Body__c
            FROM WhatsApp_Template__c
            WHERE Template_Name__c = :templateName
            LIMIT 1
        ];
 
        if (template == null) {
            return 'Error: Template not found in Salesforce';
        }
 
        String parameterFormat = template.Parameter_Format__c;
        String lang = template.Language__c;
        List<String> parameterNames = template.Parameters__c != null ? template.Parameters__c.split(', ') : new List<String>();

        String TemplateBody = template.Template_Body__c;
        if (TemplateBody != null) {
            for (Integer i = 0; i < parameterNames.size(); i++) {
            TemplateBody = TemplateBody.replace('{{' + parameterNames[i] + '}}', parameters[i]);
            }
        }
 
        if (parameters.size() != parameterNames.size()) {
            return 'Error: The number of parameters provided does not match the expected count';
        }
 
        List<Map<String, Object>> paramList = new List<Map<String, Object>>();
 
        if (parameterFormat == 'NAMED') {
            for (Integer i = 0; i < parameters.size(); i++) {
                paramList.add(new Map<String, Object>{
                    'type' => 'text',
                    'parameter_name' => parameterNames[i],
                    'text' => parameters[i]
                });
            }
        } else if (parameterFormat == 'POSITIONAL') {
            for (String param : parameters) {
                paramList.add(new Map<String, Object>{
                    'type' => 'text',
                    'text' => param
                });
            }
        } else {
            return 'Error: Unknown parameter format';
        }
 
        Map<String, Object> body = new Map<String, Object>{
            'messaging_product' => 'whatsapp',
            'to' => phoneNumber,
            'type' => 'template',
            'template' => new Map<String, Object>{
                'name' => templateName,
                'language' => new Map<String, String>{'code' => lang},
                'components' => new List<Map<String, Object>>{
                    new Map<String, Object>{
                        'type' => 'body',
                        'parameters' => paramList
                    }
                }
            }
        };
        HttpRequest request = new HttpRequest();
        request.setEndpoint(apiUrl);
        request.setMethod('POST');
        request.setHeader('Authorization', 'Bearer ' + accessToken);
        request.setHeader('Content-Type', 'application/json');
        request.setBody(JSON.serialize(body));
 
        Http http = new Http();
        try {
            HttpResponse response = http.send(request);
            System.debug('Response: ' + response.getBody());
 
            if (response.getStatusCode() == 200 || response.getStatusCode() == 201) {
                Contact con = [
                    SELECT Name
                    FROM Contact
                    WHERE MobilePhone = :phoneNumber
                    LIMIT 1
                ];
 
                String receiverName = con != null ? con.Name : 'Unknown';
 
                Message__c sentMessage = new Message__c(
                    Sender__c = 'Me',
                    // Receiver__c = receiverName,
                    Receiver__c = phoneNumber,
                    Message_Body__c = TemplateBody,
                    Status__c = 'Sent',
                    Type__c = 'text'
                );
                insert sentMessage;
                return 'Template message sent successfully.';
            } else {
                return 'Failed to send message: ' + response.getBody();
            }
        }
        catch (Exception e) {
            System.debug('Error sending template message: ' + e.getMessage());
            return 'Error: ' + e.getMessage();
        }
    }
 
    @AuraEnabled(cacheable=true)
    public static List<Contact> getWhatsAppNumber() {
        if (!Schema.sObjectType.Contact.isAccessible()) {
            throw new AuraHandledException('You don\'t have access to Contact records.');
        }
        return [SELECT Name, MobilePhone FROM Contact WHERE MobilePhone != null AND MobilePhone != ''];
    }
 
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getTemplateNames() {
        List<Map<String, String>> templateData = new List<Map<String, String>>();
        for (WhatsApp_Template__c template : [SELECT Template_Name__c, Language__c FROM WhatsApp_Template__c]) {
            templateData.add(new Map<String, String>{
                'name' => template.Template_Name__c,
                'language' => template.Language__c
            });
        }
        return templateData;
    }
 
    @AuraEnabled(cacheable=true)
    public static String getTemplateParameters(String templateName) {
        WhatsApp_Template__c template = [
            SELECT Parameters__c FROM WhatsApp_Template__c WHERE Template_Name__c = :templateName LIMIT 1
        ];
        System.debug('template parameter '+template.Parameters__c);
        return template != null ? template.Parameters__c : null;
    }
 
    @AuraEnabled
    public static void getTemplates() {
        String businessId = '384964341372165'; //Ranger
        // String businessId = '1642193499732421';
        String accessToken = 'EAAXlnOd7Gv0BO2UK1GLm3ALR9FqXpXtKfULirhohhDEzcc7zPFJa7y4nx0aZB9XZBhvWyS5uZApqzKtu6GS5R6K6Nj9uGcwXvNbpFZB5rJy7iAO147FxfGZCCVSwajSFB98LkcmhE9XSsVM8bpeolIsc0RHB7zzQ43ZC0NZBo64X6Gm34HAAnNRAblMro72ZC5LDZCQZDZD'; //Ranger
        // String accessToken = 'EAAV3QI4oOUYBOZCJSMD1aYKAa6TmPTcRVKAA4QENJ0wlV5zzzcoPwQm2gRa8x5BmaDqoYrjC1R3dsRvRzoWiTPibx0nFoXsv5YsSg5CwLKZAmY0oXZCpV3jBxnqnOSGZCBu3q9in6eUOLLPnMxtmdLCxa0DZCcLJASyC49oZCcRedo46xLBpR0A4TjZAYSh8GZBZA3QZDZD';
        String apiUrl = 'https://graph.facebook.com/v17.0/' + businessId + '/message_templates';
 
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(apiUrl);
        request.setMethod('GET');
        request.setHeader('Authorization', 'Bearer ' + accessToken);
        request.setHeader('Content-Type', 'application/json');
 
        try {
            HttpResponse response = http.send(request);
            System.debug('Response: ' + response.getBody());
            String payload = response.getBody();

            // try {
            //     insert new Webhook_Payload__c(
            //         Payload__c = payload
            //     );
            // } catch (Exception e) {
            //     System.debug('Error storing webhook payload: ' + e.getMessage());
            // }
    
            if (response.getStatusCode() == 200 || response.getStatusCode() == 201) {
                Map<String, Object> parsedResponse = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                List<Object> data = (List<Object>) parsedResponse.get('data');
    
                Set<String> existingTemplateNames = new Set<String>();
                for (WhatsApp_Template__c existingTemplate : [
                    SELECT Template_Name__c FROM WhatsApp_Template__c
                ]) {
                    existingTemplateNames.add(existingTemplate.Template_Name__c);
                }
    
                List<WhatsApp_Template__c> newTemplates = new List<WhatsApp_Template__c>();
                for (Object item : data) {
                    Map<String, Object> template = (Map<String, Object>) item;
                    if (template != null) {
                        String templateName = (String) template.get('name');
                        String paramformat = (String) template.get('parameter_format');
                        String language = (String) template.get('language');
                        String parameterFormat = (String) template.get('parameter_format');
                        List<String> parameterNames = new List<String>();
                        String templateBody = null;
    
                        if (!existingTemplateNames.contains(templateName)) {
                            if (template.containsKey('components')) {
                                List<Object> components = (List<Object>) template.get('components');
                                for (Object comp : components) {
                                    Map<String, Object> component = (Map<String, Object>) comp;

                                    if ('BODY'.equalsIgnoreCase((String) component.get('type'))) {
                                        templateBody = (String) component.get('text');
                                    }

                                    if (component.containsKey('example')) {
                                        Map<String, Object> example = (Map<String, Object>) component.get('example');
                                        
                                        if (example.containsKey('body_text_named_params')) {
                                            List<Object> namedParams = (List<Object>) example.get('body_text_named_params');
                                            for (Object paramObj : namedParams) {
                                                Map<String, Object> paramMap = (Map<String, Object>) paramObj;
                                                parameterNames.add((String) paramMap.get('param_name'));
                                            }
                                        } else if (example.containsKey('body_text')) {
                                            List<Object> bodyTextParams = (List<Object>) example.get('body_text');
                                            if (!bodyTextParams.isEmpty()) {
                                                List<Object> positionalParams = (List<Object>) bodyTextParams.get(0);
                                                for (Integer i = 0; i < positionalParams.size(); i++) {
                                                    parameterNames.add(String.valueOf(i + 1));
                                                }
                                            }
                                        }
                                    }
                                }
                            }
    
                            WhatsApp_Template__c tempData = new WhatsApp_Template__c();
                            tempData.Template_Name__c = templateName;
                            tempData.Parameter_Format__c = paramformat;
                            tempData.Language__c = language;
                            tempData.Parameters__c = parameterNames.isEmpty() ? null : String.join(parameterNames, ', ');
                            tempData.Template_Body__c = templateBody;
    
                            newTemplates.add(tempData);
                        } else {
                            System.debug('Duplicate Template Ignored: ' + templateName);
                        }
                    }
                }
    
                if (!newTemplates.isEmpty()) {
                    try {
                        insert newTemplates;
                        System.debug('Templates Inserted Successfully.');
                    } catch (DmlException dmlEx) {
                        System.debug('DML Error: ' + dmlEx.getMessage());
                        throw new AuraHandledException('Error inserting templates: ' + dmlEx.getMessage());
                    }
                } else {
                    System.debug('No new templates to insert.');
                }
            } else {
                System.debug('Error Response: ' + response.getBody());
                throw new AuraHandledException('Failed to receive message: ' + response.getBody());
            }
        }
        catch (Exception e) {
            System.debug('Error receiving message: ' + e.getMessage());
            throw new AuraHandledException('Error receiving message: ' + e.getMessage());
        }
    }
}