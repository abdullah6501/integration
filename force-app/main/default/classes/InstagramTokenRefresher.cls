global class InstagramTokenRefresher implements Schedulable {
    global void execute(SchedulableContext sc) {
        List<Instagram_Token__c> tokens = [SELECT Id, Access_Token__c FROM Instagram_Token__c];

        for (Instagram_Token__c token : tokens) {
            try {
                HttpRequest req = new HttpRequest();
                req.setEndpoint('https://graph.instagram.com/refresh_access_token' +
                    '?grant_type=ig_refresh_token' +
                    '&access_token=' + EncodingUtil.urlEncode(token.Access_Token__c, 'UTF-8'));
                req.setMethod('GET');

                Http http = new Http();
                HttpResponse res = http.send(req);

                if (res.getStatusCode() == 200) {
                    Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    String newAccessToken = (String) responseMap.get('access_token');
                    Object expiresIn = responseMap.get('expires_in');

                    token.Access_Token__c = newAccessToken;
                    update token;

                    System.debug('Refreshed token: ' + newAccessToken);
                } else {
                    System.debug('Error refreshing token: ' + res.getBody());
                }
            } catch (Exception e) {
                System.debug('Exception during token refresh: ' + e.getMessage());
            }
        }
    }
}
