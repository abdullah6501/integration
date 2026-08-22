public class WhatsAppTemplateController {
    @AuraEnabled
    public static String sendTemplateMessage(String phoneNumber, String templateName, String language, List<String> bodyParams, List<String> buttonParams) {
        String phoneId = System.Label.Phone_Id;
        String accessToken = System.Label.Access_Token;
        String apiUrl = 'https://graph.facebook.com/v17.0/' + phoneId + '/messages';

        WhatsApp_Template__c tempData = [
            SELECT Template_Name__c, Language__c, Parameter_Format__c, Template_Body__c,
                   Header_Type__c, Header_Value__c, Template_Footer__c,
                   Button_Type__c, Button_Text__c, Button_Url__c, Button_Parameters__c,
                   Parameters__c, Header_Media_Id__c
            FROM WhatsApp_Template__c
            WHERE Template_Name__c = :templateName
            LIMIT 1
        ];

        if (tempData == null) {
            return 'Error: Template not found in Salesforce';
        }

        String parameterFormat = tempData.Parameter_Format__c;
        List<String> bodyParamNames = tempData.Parameters__c != null ? tempData.Parameters__c.split(', ') : new List<String>();
        System.debug(bodyParamNames);
        System.debug(bodyParamNames.size());

        String TemplateBody = tempData.Template_Body__c;
        if (TemplateBody != null) {
            for (Integer i = 0; i < bodyParamNames.size(); i++) {
            TemplateBody = TemplateBody.replace('{{' + bodyParamNames[i] + '}}', bodyParams[i]);
            }
        }
 
        if (bodyParams.size() != bodyParamNames.size()) {
            return 'Error: The number of bodyParams provided does not match the expected count';
        }

        List<Map<String, Object>> components = new List<Map<String, Object>>();

        if (String.isNotBlank(tempData.Header_Type__c) && String.isNotBlank(tempData.Header_Value__c)) {
            Map<String, Object> headerComponent = new Map<String, Object>();
            headerComponent.put('type', 'header');
            List<Map<String, Object>> headerParams = new List<Map<String, Object>>();

            String headerType = tempData.Header_Type__c.toLowerCase();
            if (headerType == 'image' || headerType == 'video' || headerType == 'document') {
                String mediaId = tempData.Header_Media_Id__c;
                headerParams.add(new Map<String, Object>{
                    'type' => headerType,
                    headerType => new Map<String, Object>{ 'id' => mediaId }
                });
            }
            if (!headerParams.isEmpty()) {
                headerComponent.put('parameters', headerParams);
                components.add(headerComponent);
            }
        }

        if (bodyParams != null && !bodyParams.isEmpty()) {
            List<Map<String, Object>> bodyParametersList = new List<Map<String, Object>>();
        
            if (parameterFormat == 'NAMED') {
                for (Integer i = 0; i < bodyParams.size(); i++) {
        
                    bodyParametersList.add(new Map<String, Object>{
                        'type' => 'text',
                        'parameter_name' => bodyParamNames != null && i < bodyParamNames.size() 
                            ? bodyParamNames[i] 
                            : 'param' + i,
                        'text' => bodyParams[i]
                    });
                }
            } else if (parameterFormat == 'POSITIONAL') {
                for (String bp : bodyParams) {
        
                    bodyParametersList.add(new Map<String, Object>{
                        'type' => 'text',
                        'text' => bp
                    });
                }
            } else {
                return 'Error: Unknown parameter format for body';
            }
        
            components.add(new Map<String, Object>{
                'type' => 'body',
                'parameters' => bodyParametersList
            });
        }               

        // if (String.isNotBlank(tempData.Template_Footer__c)) {
        //     components.add(new Map<String, Object>{
        //         'type' => 'footer',
        //         'parameters' => new List<Map<String, Object>>{
        //             new Map<String, Object>{ 'type' => 'text', 'text' => tempData.Template_Footer__c }
        //         }
        //     });
        // }

        // if (String.isNotBlank(tempData.Button_Text__c)) {
        //     Map<String, Object> buttonComponent = new Map<String, Object>();
        //     buttonComponent.put('type', 'button');
        //     buttonComponent.put('sub_type', tempData.Button_Type__c != null ? tempData.Button_Type__c.toLowerCase() : 'quick_reply');
        //     buttonComponent.put('index', '0');

        //     List<Map<String, Object>> buttonParameterList = new List<Map<String, Object>>();

        //     if (buttonParams != null && !buttonParams.isEmpty()) {
        //         for (String bp : buttonParams) {
        //             bp = bp.replace('Button - ', '').trim();
        //             buttonParameterList.add(new Map<String, Object>{ 'type' => 'text', 'text' => bp });
        //         }
        //     }

        //     if (!buttonParameterList.isEmpty()) {
        //         buttonComponent.put('parameters', buttonParameterList);
        //     }

        //     components.add(buttonComponent);
        // }

        Map<String, Object> body = new Map<String, Object>{
            'messaging_product' => 'whatsapp',
            'to' => phoneNumber,
            'type' => 'template',
            'template' => new Map<String, Object>{
                'name' => templateName,
                'language' => new Map<String, String>{ 'code' => tempData.Language__c },
                'components' => components
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

                Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());

                String messageId;
                if (responseBody.containsKey('messages')) {
                    List<Object> messages = (List<Object>) responseBody.get('messages');
                    if (!messages.isEmpty()) {
                        Map<String, Object> messageMap = (Map<String, Object>) messages[0];
                        messageId = (String) messageMap.get('id');
                    }
                }

                // Contact con = [
                //     SELECT Name
                //     FROM Contact
                //     WHERE MobilePhone = :phoneNumber
                //     LIMIT 1
                // ];
 
                // String receiverName = con != null ? con.Name : 'Unknown';
 
                Message__c sentMessage = new Message__c(
                    Sender__c = 'Me',
                    // Receiver__c = receiverName,
                    Receiver__c = phoneNumber,
                    Message_Body__c = TemplateBody,
                    Status__c = 'Sent',
                    Type__c = 'text',
                    Message_Id_Text__c = messageId
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

    @future(callout=true)
    public static void sendTemplateMessageForRequest(String phoneNumber, String templateName, String language, List<String> parameters) {
        String phoneId = System.Label.Phone_Id;
        String accessToken = System.Label.Access_Token;
        String apiUrl = 'https://graph.facebook.com/v17.0/' + phoneId + '/messages';
 
            WhatsApp_Template__c template = [
            SELECT Language__c, Parameter_Format__c, Parameters__c, Template_Body__c
            FROM WhatsApp_Template__c
            WHERE Template_Name__c = :templateName
            LIMIT 1
        ];

        if (template == null) {
            // return 'Error: Template not found in Salesforce';
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
            // return 'Error: The number of parameters provided does not match the expected count';
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
            // return 'Error: Unknown parameter format';
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
                Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());

                String messageId;
                if (responseBody.containsKey('messages')) {
                    List<Object> messages = (List<Object>) responseBody.get('messages');
                    if (!messages.isEmpty()) {
                        Map<String, Object> messageMap = (Map<String, Object>) messages[0];
                        messageId = (String) messageMap.get('id');
                    }
                }

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
                    Type__c = 'text',
                    Message_Id_Text__c = messageId
                );
                insert sentMessage;
                // return 'Template message sent successfully.';
            } else {
                // return 'Failed to send message: ' + response.getBody();
            }
        }
        catch (Exception e) {
            System.debug('Error sending template message: ' + e.getMessage());
            // return 'Error: ' + e.getMessage();
        }
    }
  
    @future(callout=true)
    public static void sendTemplateMessageForRequest(String phoneNumber, String templateName, String language, List<String> parameters, String context) {
        String phoneId = System.Label.Phone_Id;
        String accessToken = System.Label.Access_Token;
        String apiUrl = 'https://graph.facebook.com/v17.0/' + phoneId + '/messages';
 
            WhatsApp_Template__c template = [
            SELECT Language__c, Parameter_Format__c, Parameters__c, Template_Body__c
            FROM WhatsApp_Template__c
            WHERE Template_Name__c = :templateName
            LIMIT 1
        ];

        if (template == null) {
            // return 'Error: Template not found in Salesforce';
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
            // return 'Error: The number of parameters provided does not match the expected count';
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
            // return 'Error: Unknown parameter format';
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
                Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());

                String messageId;
                if (responseBody.containsKey('messages')) {
                    List<Object> messages = (List<Object>) responseBody.get('messages');
                    if (!messages.isEmpty()) {
                        Map<String, Object> messageMap = (Map<String, Object>) messages[0];
                        messageId = (String) messageMap.get('id');
                    }
                }

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
                    Type__c = 'text',
                    Request__c = context,
                    Message_Id_Text__c = messageId
                );
                insert sentMessage;
                // return 'Template message sent successfully.';
            } else {
                // return 'Failed to send message: ' + response.getBody();
            }
        }
        catch (Exception e) {
            System.debug('Error sending template message: ' + e.getMessage());
            // return 'Error: ' + e.getMessage();
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
 
    // @AuraEnabled(cacheable=true)
    // public static String getTemplateParameters(String templateName) {
    //     WhatsApp_Template__c template = [
    //         SELECT Parameters__c FROM WhatsApp_Template__c WHERE Template_Name__c = :templateName LIMIT 1
    //     ];
    //     System.debug('template parameter '+template.Parameters__c);
    //     return template != null ? template.Parameters__c : null;
    // }
    @AuraEnabled(cacheable=true)
    public static String getTemplateParameters(String templateName) {
        WhatsApp_Template__c template = [
            SELECT Parameters__c, Button_Parameters__c 
            FROM WhatsApp_Template__c 
            WHERE Template_Name__c = :templateName 
            LIMIT 1
        ];
        
        String allParams = '';
        if (template.Parameters__c != null) {
            allParams += template.Parameters__c;
        }
        if (template.Button_Parameters__c != null) {
            if (!String.isEmpty(allParams)) {
                allParams += ',';
            }
            allParams += template.Button_Parameters__c;
        }
        return allParams;
    }

    @AuraEnabled
    public static void getTemplates() {
        getTemplatesFuture();
    }
    @future(callout=true)
    public static void getTemplatesFuture() {
        String businessId = System.Label.Business_Id;
        String accessToken = System.Label.Access_Token;
        String apiUrl = 'https://graph.facebook.com/v17.0/' + businessId + '/message_templates';

        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(apiUrl);
        request.setMethod('GET');
        request.setHeader('Authorization', 'Bearer ' + accessToken);
        request.setHeader('Content-Type', 'application/json');

        try {
            HttpResponse response = http.send(request);
            System.debug('Templates API Response: ' + response.getBody());
            String payload = response.getBody();    
            // try {
            //     insert new WhatsApp_Template__c(
            //         Header_Value__c = payload
            //     );
            // } catch (Exception e) {
            //     System.debug('Error storing webhook payload: ' + e.getMessage());
            // }        

            if (response.getStatusCode() == 200 || response.getStatusCode() == 201) {
                parseAndStoreTemplates(response.getBody());
            } else {
                throw new AuraHandledException('Failed to fetch templates: ' + response.getBody());
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching templates: ' + e.getMessage());
        }
    }

    private static void parseAndStoreTemplates(String responseBody) {
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        List<Object> templates = (List<Object>) responseMap.get('data');
        if (templates == null) return;

        List<WhatsApp_Template__c> newTemplates = new List<WhatsApp_Template__c>();
        Set<String> existingTemplateNames = new Set<String>();

        for (WhatsApp_Template__c existing : [SELECT Template_Name__c FROM WhatsApp_Template__c]) {
            existingTemplateNames.add(existing.Template_Name__c);
        }

        for (Object templateObj : templates) {
            Map<String, Object> template = (Map<String, Object>) templateObj;
            String templateName = (String) template.get('name');
            if (existingTemplateNames.contains(templateName)) continue;

            WhatsApp_Template__c tempData = parseTemplateData(template);
            if (tempData != null) {
                newTemplates.add(tempData);
            }
        }

        if (!newTemplates.isEmpty()) {
            insert newTemplates;
            System.debug('Inserted ' + newTemplates.size() + ' new templates');
        }
    }

    private static WhatsApp_Template__c parseTemplateData(Map<String, Object> template) {
        String templateName = (String) template.get('name');
        String paramFormat = (String) template.get('parameter_format');
        String language = (String) template.get('language');
        String status = (String) template.get('status');
        String category = (String) template.get('category');
        String subCategory = (String) template.get('sub_category');

        List<Object> components = (List<Object>) template.get('components');
        if (components == null) return null;

        String templateBody = null;
        String headerType = null;
        String headerValue = null;
        String headerMediaId = null; 
        String footerText = null;
        String buttonType = null;
        String buttonText = null;
        String buttonUrl = null;
        List<String> parameterNames = new List<String>();
        List<String> buttonParameters = new List<String>();

        for (Object comp : components) {
            Map<String, Object> component = (Map<String, Object>) comp;
            String compType = (String) component.get('type');

            if ('BODY'.equalsIgnoreCase(compType)) {
                templateBody = (String) component.get('text');
                extractParametersFromBody(component, paramFormat, parameterNames);

            } else if ('HEADER'.equalsIgnoreCase(compType)) {
                headerType = (String) component.get('format');
                Map<String, String> headerData = extractHeaderValue(component, headerType);
                headerValue = headerData.get('value');
                headerMediaId = headerData.get('mediaId');

            } else if ('FOOTER'.equalsIgnoreCase(compType)) {
                footerText = (String) component.get('text');

            } if ('BUTTONS'.equalsIgnoreCase(compType)) {
                Map<String, String> buttonInfo = extractButtonInfo(component);
                buttonType = buttonInfo.get('type');
                buttonText = buttonInfo.get('text');
                buttonUrl = buttonInfo.get('url');
            
                if (buttonUrl != null && buttonUrl.contains('{{')) {
                    Pattern pattern = Pattern.compile('\\{\\{(\\d+)\\}\\}');
                    Matcher matcher = pattern.matcher(buttonUrl);
                    while (matcher.find()) {
                        String paramIndex = matcher.group(1);
                        buttonParameters.add(paramIndex);
                        // buttonParameters.add('Button - ' + paramIndex);
                    }
                }
            }
        }

        WhatsApp_Template__c tempData = new WhatsApp_Template__c();
        tempData.Template_Name__c = templateName;
        tempData.Parameter_Format__c = paramFormat;
        tempData.Language__c = language;
        tempData.Template_Body__c = templateBody;
        tempData.Header_Type__c = headerType;
        tempData.Header_Value__c = headerValue;
        tempData.Header_Media_Id__c = headerMediaId; // Store the media ID
        tempData.Template_Footer__c = footerText;
        tempData.Button_Type__c = buttonType;
        tempData.Button_Text__c = buttonText;
        tempData.Button_Url__c = buttonUrl;
        tempData.Status__c = status;
        tempData.Category__c = category;
        tempData.Sub_Category__c = subCategory;
        tempData.Parameters__c = parameterNames.isEmpty() ? null : String.join(parameterNames, ', ');
        tempData.Button_Parameters__c = buttonParameters.isEmpty() ? null : String.join(buttonParameters, ', ');

        return tempData;
    }

    @testVisible
    private static void extractParametersFromBody(Map<String, Object> component, String paramFormat, List<String> parameterNames) {
        if (!component.containsKey('example')) return;

        Map<String, Object> example = (Map<String, Object>) component.get('example');

        if (paramFormat == 'NAMED' && example.containsKey('body_text_named_params')) {
            List<Object> namedParams = (List<Object>) example.get('body_text_named_params');
            for (Object paramObj : namedParams) {
                Map<String, Object> paramMap = (Map<String, Object>) paramObj;
                parameterNames.add((String) paramMap.get('param_name'));
                // parameterNames.add('Body - ' + (String) paramMap.get('param_name'));
            }
        } else if (paramFormat == 'POSITIONAL' && example.containsKey('body_text')) {
            List<Object> bodyTextParams = (List<Object>) example.get('body_text');
            if (!bodyTextParams.isEmpty()) {
                List<Object> positionalParams = (List<Object>) bodyTextParams.get(0);
                for (Integer i = 0; i < positionalParams.size(); i++) {
                    parameterNames.add(String.valueOf(i + 1));
                    // parameterNames.add('Body - ' + String.valueOf(i + 1));
                }
            }
        }
    }

    @testVisible
    private static Map<String, String> extractHeaderValue(Map<String, Object> component, String headerType) {
        Map<String, String> result = new Map<String, String>();
        
        if (!component.containsKey('example')) {
            result.put('value', (String) component.get('text'));
            result.put('mediaId', null);
            return result;
        }

        Map<String, Object> headerExample = (Map<String, Object>) component.get('example');

        if ('TEXT'.equalsIgnoreCase(headerType) && headerExample.containsKey('header_text')) {
            List<Object> headerTextList = (List<Object>) headerExample.get('header_text');
            result.put('value', !headerTextList.isEmpty() ? String.valueOf(headerTextList[0]) : null);
            result.put('mediaId', null);

        } else if (headerExample.containsKey('header_handle')) {
            List<Object> mediaList = (List<Object>) headerExample.get('header_handle');
            if (!mediaList.isEmpty()) {
                String mediaUrl = String.valueOf(mediaList[0]);
                result.put('value', mediaUrl);
                
                // Convert URL to Media ID
                String mediaId = convertUrlToMediaId(mediaUrl, headerType);
                result.put('mediaId', mediaId);
            } else {
                result.put('value', null);
                result.put('mediaId', null);
            }
        } else {
            result.put('value', null);
            result.put('mediaId', null);
        }

        return result;
    }

    // Method to convert media URL to WhatsApp Media ID
    private static String convertUrlToMediaId(String mediaUrl, String headerType) {
        if (String.isBlank(mediaUrl)) {
            return null;
        }
        
        try {
            // Determine media type based on header type
            String mediaType;
            switch on headerType.toUpperCase() {
                when 'IMAGE' {
                    mediaType = 'image';
                }
                when 'DOCUMENT' {
                    mediaType = 'document';
                }
                when 'VIDEO' {
                    mediaType = 'video';
                }
                when 'AUDIO' {
                    mediaType = 'audio';
                }
                when else {
                    mediaType = 'document'; // default fallback
                }
            }
            
            // Get required values from custom labels
            String accessToken = System.Label.Access_Token;
            String phoneId = System.Label.Phone_Id;
            System.debug('phone id' + phoneId);
            
            
            // Call the media upload method
            String mediaId = uploadMediaToWhatsApp(mediaUrl, mediaType, accessToken, phoneId);
            
            if (String.isNotBlank(mediaId)) {
                System.debug('Successfully converted URL to Media ID: ' + mediaId);
                return mediaId;
            } else {
                System.debug('Failed to convert URL to Media ID for: ' + mediaUrl);
                return null;
            }
            
        } catch (Exception e) {
            System.debug('Error converting URL to Media ID: ' + e.getMessage());
            return null;
        }
    }

    // Include your fixed uploadMediaToWhatsApp method here
    private static String uploadMediaToWhatsApp(String fileUrl, String mediaType, String accessToken, String phoneId) {
        if (String.isBlank(fileUrl)) {
            System.debug('ERROR: File URL cannot be null or empty');
            return null;
        }
        
        try {
            // STEP 1: Download file as Blob
            Http http = new Http();
            HttpRequest fileRequest = new HttpRequest();
            fileRequest.setEndpoint(fileUrl);
            fileRequest.setMethod('GET');
            fileRequest.setTimeout(120000);
            
            HttpResponse fileResponse = http.send(fileRequest);
            if (fileResponse.getStatusCode() != 200) {
                System.debug('ERROR: File download failed with status ' + fileResponse.getStatusCode());
                return null;
            }
            
            Blob fileBlob = fileResponse.getBodyAsBlob();
            ContentVersion cv = new ContentVersion();
            cv.Title = 'image';
            cv.PathOnClient =  'image.jpg'; // or .png based on your image
            cv.VersionData = fileBlob;
            // insert cv;

            // // Step 3: Get the ContentDocument Id
            // cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
            // System.debug(cv.ContentDocumentId);
            System.debug('SUCCESS: File downloaded, size: ' + fileBlob.size() + ' bytes');
            
            String boundary = '----WebKitFormBoundary7MA4YWxkTrZu0gW';
            String apiUrl = 'https://graph.facebook.com/v17.0/' + phoneId + '/media';

            HttpRequest uploadRequest = new HttpRequest();
            uploadRequest.setEndpoint(apiUrl);
            uploadRequest.setMethod('POST');
            uploadRequest.setHeader('Authorization', 'Bearer ' + accessToken);
            uploadRequest.setHeader('Content-Type', 'multipart/form-data; boundary=' + boundary);

            String fileExtension = getFileExtension(mediaType);
            String mimeType = getMimeType(mediaType);

            // Part 1: Text field
            String preBody = '--' + boundary + '\r\n'
                + 'Content-Disposition: form-data; name="messaging_product"\r\n\r\n'
                + 'whatsapp\r\n'
                + '--' + boundary + '\r\n'
                + 'Content-Disposition: form-data; name="type"\r\n\r\n'
                + mediaType + '\r\n'
                + '--' + boundary + '\r\n'
                + 'Content-Disposition: form-data; name="file"; filename="file.' + fileExtension + '"\r\n'
                + 'Content-Type: ' + mimeType + '\r\n\r\n';

            // Part 2: Binary data (Blob)
            Blob preBodyBlob = Blob.valueOf(preBody);
            Blob postBodyBlob = Blob.valueOf('\r\n--' + boundary + '--');

            // Combine into one Blob for request body
            Blob bodyBlob = EncodingUtil.base64Decode(
                EncodingUtil.base64Encode(preBodyBlob) +
                EncodingUtil.base64Encode(fileBlob) +
                EncodingUtil.base64Encode(postBodyBlob)
            );

            uploadRequest.setBodyAsBlob(bodyBlob);
            
            HttpResponse uploadResponse = http.send(uploadRequest);
            System.debug('Upload response: ' + uploadResponse.getBody());
            
            if (uploadResponse.getStatusCode() == 200 || uploadResponse.getStatusCode() == 201) {
                Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(uploadResponse.getBody());
                if (respMap.containsKey('id')) {
                    String mediaId = (String) respMap.get('id');
                    System.debug('SUCCESS: Media uploaded, ID: ' + mediaId);
                    return mediaId;
                }
            }
            
            System.debug('ERROR: Media upload failed, status: ' + uploadResponse.getStatusCode());
            System.debug('ERROR: Response body: ' + uploadResponse.getBody());
            return null;
            
        } catch (Exception e) {
            System.debug('ERROR in uploadMediaToWhatsApp: ' + e.getMessage());
            return null;
        }
    }

    private static String getFileExtension(String mediaType) {
        switch on mediaType.toLowerCase() {
            when 'image' {
                return 'jpeg';
            }
            when 'document' {
                return 'pdf';
            }
            when 'audio' {
                return 'mp3';
            }
            when 'video' {
                return 'mp4';
            }
            when else {
                return 'bin';
            }
        }
    }

    private static String getMimeType(String mediaType) {
        switch on mediaType.toLowerCase() {
            when 'image' {
                return 'image/jpeg';
            }
            when 'document' {
                return 'application/pdf';
            }
            when 'audio' {
                return 'audio/mpeg';
            }
            when 'video' {
                return 'video/mp4';
            }
            when else {
                return 'application/octet-stream';
            }
        }
    }

    @testVisible
    private static Map<String, String> extractButtonInfo(Map<String, Object> component) {
        Map<String, String> buttonInfo = new Map<String, String>();
        List<Object> buttons = (List<Object>) component.get('buttons');
        if (buttons != null && !buttons.isEmpty()) {
            Map<String, Object> firstButton = (Map<String, Object>) buttons[0];
            buttonInfo.put('type', (String) firstButton.get('type'));
            buttonInfo.put('text', (String) firstButton.get('text'));
            buttonInfo.put('url', (String) firstButton.get('url'));
        }
        return buttonInfo;
    }

    // @AuraEnabled
    // public static void getTemplates() {
    //     String businessId = System.Label.Business_Id;
    //     String accessToken = System.Label.Access_Token;
    //     String apiUrl = 'https://graph.facebook.com/v17.0/' + businessId + '/message_templates';

    //     Http http = new Http();
    //     HttpRequest request = new HttpRequest();
    //     request.setEndpoint(apiUrl);
    //     request.setMethod('GET');
    //     request.setHeader('Authorization', 'Bearer ' + accessToken);
    //     request.setHeader('Content-Type', 'application/json');

    //     try {
    //         HttpResponse response = http.send(request);
    //         System.debug('Templates API Response: ' + response.getBody());
    //         String payload = response.getBody();    
    //         // try {
    //         //     insert new WhatsApp_Template__c(
    //         //         Header_Value__c = payload
    //         //     );
    //         // } catch (Exception e) {
    //         //     System.debug('Error storing webhook payload: ' + e.getMessage());
    //         // }        

    //         if (response.getStatusCode() == 200 || response.getStatusCode() == 201) {
    //             parseAndStoreTemplates(response.getBody());
    //         } else {
    //             throw new AuraHandledException('Failed to fetch templates: ' + response.getBody());
    //         }
    //     } catch (Exception e) {
    //         throw new AuraHandledException('Error fetching templates: ' + e.getMessage());
    //     }
    // }

    // private static void parseAndStoreTemplates(String responseBody) {
    //     Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
    //     List<Object> templates = (List<Object>) responseMap.get('data');
    //     if (templates == null) return;

    //     List<WhatsApp_Template__c> newTemplates = new List<WhatsApp_Template__c>();
    //     Set<String> existingTemplateNames = new Set<String>();

    //     for (WhatsApp_Template__c existing : [SELECT Template_Name__c FROM WhatsApp_Template__c]) {
    //         existingTemplateNames.add(existing.Template_Name__c);
    //     }

    //     for (Object templateObj : templates) {
    //         Map<String, Object> template = (Map<String, Object>) templateObj;
    //         String templateName = (String) template.get('name');
    //         if (existingTemplateNames.contains(templateName)) continue;

    //         WhatsApp_Template__c tempData = parseTemplateData(template);
    //         if (tempData != null) {
    //             newTemplates.add(tempData);
    //         }
    //     }

    //     if (!newTemplates.isEmpty()) {
    //         insert newTemplates;
    //         System.debug('Inserted ' + newTemplates.size() + ' new templates');
    //     }
    // }

    // private static WhatsApp_Template__c parseTemplateData(Map<String, Object> template) {
    //     String templateName = (String) template.get('name');
    //     String paramFormat = (String) template.get('parameter_format');
    //     String language = (String) template.get('language');
    //     String status = (String) template.get('status');
    //     String category = (String) template.get('category');
    //     String subCategory = (String) template.get('sub_category');

    //     List<Object> components = (List<Object>) template.get('components');
    //     if (components == null) return null;

    //     String templateBody = null;
    //     String headerType = null;
    //     String headerValue = null;
    //     String footerText = null;
    //     String buttonType = null;
    //     String buttonText = null;
    //     String buttonUrl = null;
    //     List<String> parameterNames = new List<String>();
    //     List<String> buttonParameters = new List<String>();

    //     for (Object comp : components) {
    //         Map<String, Object> component = (Map<String, Object>) comp;
    //         String compType = (String) component.get('type');

    //         if ('BODY'.equalsIgnoreCase(compType)) {
    //             templateBody = (String) component.get('text');
    //             extractParametersFromBody(component, paramFormat, parameterNames);

    //         } else if ('HEADER'.equalsIgnoreCase(compType)) {
    //             headerType = (String) component.get('format');
    //             headerValue = extractHeaderValue(component, headerType);

    //         } else if ('FOOTER'.equalsIgnoreCase(compType)) {
    //             footerText = (String) component.get('text');

    //         } if ('BUTTONS'.equalsIgnoreCase(compType)) {
    //             Map<String, String> buttonInfo = extractButtonInfo(component);
    //             buttonType = buttonInfo.get('type');
    //             buttonText = buttonInfo.get('text');
    //             buttonUrl = buttonInfo.get('url');
            
    //             if (buttonUrl != null && buttonUrl.contains('{{')) {
    //                 Pattern pattern = Pattern.compile('\\{\\{(\\d+)\\}\\}');
    //                 Matcher matcher = pattern.matcher(buttonUrl);
    //                 while (matcher.find()) {
    //                     String paramIndex = matcher.group(1);
    //                     buttonParameters.add('Button - ' + paramIndex);
    //                 }
    //             }
    //         }
    //     }

    //     WhatsApp_Template__c tempData = new WhatsApp_Template__c();
    //     tempData.Template_Name__c = templateName;
    //     tempData.Parameter_Format__c = paramFormat;
    //     tempData.Language__c = language;
    //     tempData.Template_Body__c = templateBody;
    //     tempData.Header_Type__c = headerType;
    //     tempData.Header_Value__c = headerValue;
    //     tempData.Template_Footer__c = footerText;
    //     tempData.Button_Type__c = buttonType;
    //     tempData.Button_Text__c = buttonText;
    //     tempData.Button_Url__c = buttonUrl;
    //     tempData.Status__c = status;
    //     tempData.Category__c = category;
    //     tempData.Sub_Category__c = subCategory;
    //     tempData.Parameters__c = parameterNames.isEmpty() ? null : String.join(parameterNames, ', ');
    //     tempData.Button_Parameters__c = buttonParameters.isEmpty() ? null : String.join(buttonParameters, ', ');

    //     return tempData;
    // }

    // @testVisible
    // private static void extractParametersFromBody(Map<String, Object> component, String paramFormat, List<String> parameterNames) {
    //     if (!component.containsKey('example')) return;

    //     Map<String, Object> example = (Map<String, Object>) component.get('example');

    //     if (paramFormat == 'NAMED' && example.containsKey('body_text_named_params')) {
    //         List<Object> namedParams = (List<Object>) example.get('body_text_named_params');
    //         for (Object paramObj : namedParams) {
    //             Map<String, Object> paramMap = (Map<String, Object>) paramObj;
    //             parameterNames.add('Body - ' + (String) paramMap.get('param_name'));
    //         }
    //     } else if (paramFormat == 'POSITIONAL' && example.containsKey('body_text')) {
    //         List<Object> bodyTextParams = (List<Object>) example.get('body_text');
    //         if (!bodyTextParams.isEmpty()) {
    //             List<Object> positionalParams = (List<Object>) bodyTextParams.get(0);
    //             for (Integer i = 0; i < positionalParams.size(); i++) {
    //                 parameterNames.add('Body - ' + String.valueOf(i + 1));
    //             }
    //         }
    //     }
    // }

    // @testVisible
    // private static String extractHeaderValue(Map<String, Object> component, String headerType) {
    //     if (!component.containsKey('example')) {
    //         return (String) component.get('text'); 
    //     }

    //     Map<String, Object> headerExample = (Map<String, Object>) component.get('example');

    //     if ('TEXT'.equalsIgnoreCase(headerType) && headerExample.containsKey('header_text')) {
    //         List<Object> headerTextList = (List<Object>) headerExample.get('header_text');
    //         return !headerTextList.isEmpty() ? String.valueOf(headerTextList[0]) : null;

    //     } else if (headerExample.containsKey('header_handle')) {
    //         List<Object> mediaList = (List<Object>) headerExample.get('header_handle');
    //         return !mediaList.isEmpty() ? String.valueOf(mediaList[0]) : null;
    //     }

    //     return null;
    // }

    // @testVisible
    // private static Map<String, String> extractButtonInfo(Map<String, Object> component) {
    //     Map<String, String> buttonInfo = new Map<String, String>();
    //     List<Object> buttons = (List<Object>) component.get('buttons');
    //     if (buttons != null && !buttons.isEmpty()) {
    //         Map<String, Object> firstButton = (Map<String, Object>) buttons[0];
    //         buttonInfo.put('type', (String) firstButton.get('type'));
    //         buttonInfo.put('text', (String) firstButton.get('text'));
    //         buttonInfo.put('url', (String) firstButton.get('url'));
    //     }
    //     return buttonInfo;
    // }
}