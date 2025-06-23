public with sharing class InstagramController {

    private static final String IG_BUSINESS_ACCOUNT_ID = '17841472020303557';
    // private static final String TOKEN = 'EAAPZBLY8xk8kBO06ZAUs9PZCcZAr0ipkxi7SAo4VXUZBpZCP0Gbfb6A5CjncTbk0yGFaaOsWJqj2cAxyrJyIvR37Dpd6vkjtggw6rr4tpRnElXEHxJqXJWc22SnNnbpRlQJRUGEWFsajg4etO4AbG15tn457pjI8Bs4ohv1hNH9U6ZBBYef68dU5dasziYy91SDwC2ym3LElkTb';
    // private static final String TOKEN = 'EAAPZBLY8xk8kBO9x0qN7LBZCQZByPiCIFH9BcAcaiWtjN7bXyskzgx7Bs9slRH3DqWQLYOwC2bKJPtxaOwP87ZBMSUILcRxwex8rB0JmZC3n1aIqQtXruMdPpDFZAoKrjO0G1klw0yhcuQEh18FNFDIMNgorDMzOwZC0jvOZCOIN2ZBZC9vuq6HISBC1JkhTJVNgIV97VJYGwm0ZAeFIgFWnkdRIvZCNMOcMVhhlWpjjVVOy2NAwga1ErSAZD'; // Message
    private static final String TOKEN = 'EAAPZBLY8xk8kBO2n7pQQLMVbVMEz3ZCmqZAyVtWZCnyG184ilzOdZBTnijZA6mjdsL62mZBdIXo8ZCOtIDqWVtqvoAolb8vMZAxvNQflQZC02WhObpWZCK5aMMWs0nGAVRKVcOWwZCMgzPHSI81g42XKjntwjm3gyKsiWE7xvCUq1gV8c2yO9B1jZC7RLpsO9uR4jXqjJTm928vZCNxVfm9YpidW7UXyUtKEIN56wSmyI4DduWfCBFvxWU1ygZD'; // Message
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getInstagramProfile() {
        Instagram_Token__c token = [SELECT Access_Token__c FROM Instagram_Token__c ORDER BY CreatedDate DESC LIMIT 1];

        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://graph.instagram.com/me?fields=id,username,media_count,account_type&access_token=' + token.Access_Token__c);
        req.setMethod('GET');

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return new Map<String, String>{
                'id' => String.valueOf(data.get('id')),
                'username' => String.valueOf(data.get('username')),
                'media_count' => String.valueOf(data.get('media_count')),
                'account_type' => String.valueOf(data.get('account_type'))
            };
        } else {
            throw new AuraHandledException('Failed to retrieve profile: ' + res.getBody());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getInstagramMedia() {
        Instagram_Token__c token = [SELECT Access_Token__c FROM Instagram_Token__c ORDER BY CreatedDate DESC LIMIT 1];

        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://graph.instagram.com/me/media?fields=id,caption,media_url,timestamp&access_token=' + token.Access_Token__c);
        req.setMethod('GET');

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> data = (List<Object>) jsonResponse.get('data');
            List<Map<String, String>> result = new List<Map<String, String>>();
            for (Object obj : data) {
                Map<String, Object> item = (Map<String, Object>) obj;
                result.add(new Map<String, String>{
                    'id' => String.valueOf(item.get('id')),
                    'caption' => String.valueOf(item.get('caption')),
                    'media_url' => String.valueOf(item.get('media_url')),
                    'timestamp' => String.valueOf(item.get('timestamp'))
                });
            }
            return result;
        } else {
            throw new AuraHandledException('Failed to retrieve media: ' + res.getBody());
        }
    }

    @AuraEnabled
    public static String uploadInstagramMedia(String base64Data, String fileName, String caption) {
        System.debug('base64Data: ' + base64Data);
        System.debug('fileName: ' + fileName);
        System.debug('caption: ' + caption);
        Instagram_Token__c token = [SELECT Access_Token__c FROM Instagram_Token__c ORDER BY CreatedDate DESC LIMIT 1];
        System.debug('Access Token: ' + token.Access_Token__c);
        ContentVersion cv = new ContentVersion();
        cv.Title = fileName;
        cv.PathOnClient = '/' + fileName;
        cv.VersionData = EncodingUtil.base64Decode(base64Data);
        insert cv;

        ContentVersion uploaded = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

        ContentDistribution dist = new ContentDistribution();
        dist.Name = fileName;
        dist.ContentVersionId = cv.Id;
        dist.PreferencesAllowViewInBrowser = true;
        dist.PreferencesAllowOriginalDownload = true;
        insert dist;

        dist = [SELECT DistributionPublicUrl FROM ContentDistribution WHERE Id = :dist.Id LIMIT 1];
        String publicUrl = dist.DistributionPublicUrl;

        postToInstagramAsync(publicUrl, caption, token.Access_Token__c);

        return 'Upload Success. Instagram post will be processed.';
    }

    @future(callout=true)
    public static void postToInstagramAsync(String publicUrl, String caption, String accessToken) {
        System.debug('Inside future method');
        System.debug('publicUrl: ' + publicUrl);
        System.debug('caption: ' + caption);
        System.debug('accessToken: ' + accessToken);
        Http http = new Http();

        HttpRequest req1 = new HttpRequest();
        req1.setEndpoint('https://graph.facebook.com/v19.0/' + IG_BUSINESS_ACCOUNT_ID + '/media');
        req1.setMethod('POST');
        req1.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req1.setBody('image_url=' + EncodingUtil.urlEncode(publicUrl, 'UTF-8') +
                    '&caption=' + EncodingUtil.urlEncode(caption, 'UTF-8') +
                    '&access_token=' + TOKEN);

        HttpResponse res1 = http.send(req1);

        System.debug('Response status code: ' + res1.getStatusCode());
        if (res1.getStatusCode() == 200) {
            System.debug('Successfully posted to /media: ' + res1.getBody());
        } else {
            System.debug('Error posting to /media: ' + res1.getBody());
            return;
        }
        System.debug('Response from /media: ' + res1.getBody());
        System.debug('Response status code: ' + res1.getStatusCode());
        System.debug('Response status: ' + res1.getStatus());
        Map<String, Object> response1 = (Map<String, Object>) JSON.deserializeUntyped(res1.getBody());
        String creationId = String.valueOf(response1.get('id'));

        HttpRequest req2 = new HttpRequest();
        req2.setEndpoint('https://graph.facebook.com/v19.0/' + IG_BUSINESS_ACCOUNT_ID + '/media_publish');
        req2.setMethod('POST');
        req2.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req2.setBody('creation_id=' + creationId + '&access_token=' + TOKEN);
        System.debug('sendingggg');
        HttpResponse res2 = http.send(req2);
        if (res2.getStatusCode() == 200) {
            System.debug('Post published successfully: ' + res2.getBody());
        } else {
            System.debug('Error posting to /media_publish: ' + res2.getBody());
        }
    }
}
