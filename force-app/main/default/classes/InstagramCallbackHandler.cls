@RestResource(urlMapping='/instagram-callback')
global with sharing class InstagramCallbackHandler {

    @HttpGet
    global static void handleCallback() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'text/plain');

        String code = req.params.get('code');
        System.debug('Received code: ' + code);

        if (String.isEmpty(code)) {
            res.responseBody = Blob.valueOf('Authorization code missing');
            res.statusCode = 400;
            return;
        }

        try {
            String clientId = '1395033111913501';
            String clientSecret = 'f24e2c95929946e9ffb7090cae4fa31c';
            String redirectUri = 'https://rangertechnologies38-dev-ed.develop.my.salesforce-sites.com/whatsappwebhook/services/apexrest/instagram-callback';

            HttpRequest httpReq = new HttpRequest();
            httpReq.setEndpoint('https://api.instagram.com/oauth/access_token');
            httpReq.setMethod('POST');
            httpReq.setHeader('Content-Type', 'application/x-www-form-urlencoded');

            String payload = 'client_id=' + clientId +
                '&client_secret=' + clientSecret +
                '&grant_type=authorization_code' +
                '&redirect_uri=' + EncodingUtil.urlEncode(redirectUri, 'UTF-8') +
                '&code=' + EncodingUtil.urlEncode(code, 'UTF-8');

            httpReq.setBody(payload);

            Http http = new Http();
            HttpResponse httpRes = http.send(httpReq);

            if (httpRes.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(httpRes.getBody());
                String shortLivedToken = (String) responseMap.get('access_token');
                String userId = String.valueOf(responseMap.get('user_id'));

                HttpRequest longLivedReq = new HttpRequest();
                longLivedReq.setMethod('GET');
                longLivedReq.setEndpoint('https://graph.instagram.com/access_token' +
                    '?grant_type=ig_exchange_token' +
                    '&client_secret=' + EncodingUtil.urlEncode(clientSecret, 'UTF-8') +
                    '&access_token=' + EncodingUtil.urlEncode(shortLivedToken, 'UTF-8'));

                Http longLivedHttp = new Http();
                HttpResponse longLivedRes = longLivedHttp.send(longLivedReq);

                if (longLivedRes.getStatusCode() == 200) {
                    Map<String, Object> longTokenMap = (Map<String, Object>) JSON.deserializeUntyped(longLivedRes.getBody());
                    String longLivedToken = (String) longTokenMap.get('access_token');
                    Object expiresIn = longTokenMap.get('expires_in');

                    System.debug('Long-Lived Access Token: ' + longLivedToken);
                    System.debug('Expires In (seconds): ' + expiresIn);

                    insert new Instagram_Token__c(Access_Token__c = longLivedToken, User_ID__c = userId);

                    res.responseBody = Blob.valueOf('Integration successful. Long-Lived Access Token: ' + longLivedToken);
                    res.statusCode = 200;
                } else {
                    System.debug('Error getting long-lived token: ' + longLivedRes.getBody());
                    res.responseBody = Blob.valueOf('Error getting long-lived access token');
                    res.statusCode = longLivedRes.getStatusCode();
                }
                // System.debug('Access Token: ' + accessToken);
                // System.debug('User ID: ' + userId);

                // insert new Instagram_Token__c(Access_Token__c = accessToken, User_ID__c = userId);

                // res.responseBody = Blob.valueOf('Integration successful. Access Token: ' + accessToken);
                // res.statusCode = 200;
            } else {
                System.debug('Error Response: ' + httpRes.getBody());
                res.responseBody = Blob.valueOf('Error exchanging code for access token');
                res.statusCode = httpRes.getStatusCode();
            }

        } catch (Exception e) {
            System.debug('Exception occurred: ' + e.getMessage());
            res.responseBody = Blob.valueOf('Internal server error');
            res.statusCode = 500;
        }
    }
}
