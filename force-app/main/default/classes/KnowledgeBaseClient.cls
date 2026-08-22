// Thoufic-30JUL25 to manage knowedge documents
public class KnowledgeBaseClient {
    public static final String BASE_URL = 'https://ai-api.valarhr.com';
    private static final String ranger_token_for_chatservice = 'ranger-4e1b2a0c-3d7f-4f8b-bc5d-6a9e0f1a2b3c_gRUMAteb4274lJ21KTc2g4FCXyw83HX8Q1NuPCz6e5YUysj-lW5r82luwlAA';
    public static String companyId = UserInfo.getOrganizationId(); 

     // -------------------- Classes --------------------

    public class MetadataSuggestion {
        public String key;
        public String value;
    }

    public class ManualDocument {
        @AuraEnabled public String title { get; set; }
        @AuraEnabled public String content { get; set; }
    }

    public class FileDocument {
        @AuraEnabled public String title { get; set; }
        @AuraEnabled public String Url { get; set; }
    }
    public class KnowledgeDocumentWrapper {
        @AuraEnabled public List<ManualDocument> manualDocuments { get; set; }
        @AuraEnabled public List<String> urls { get; set; }
        @AuraEnabled public List<FileDocument> fileDocuments { get; set; }

        public KnowledgeDocumentWrapper() {}
    }

    public class Metadata {
        @AuraEnabled public String source { get; set; }
        @AuraEnabled public String title { get; set; }
        @AuraEnabled public String createdAt { get; set; }
        @AuraEnabled public String updatedAt { get; set; }

        public Metadata() {}
    }

    public class KnowledgeBrowserWrapper {
        @AuraEnabled public String document { get; set; }
        @AuraEnabled public Metadata metadata { get; set; }
        @AuraEnabled public String error { get; set; }
        @AuraEnabled public Boolean forceVectorUpdate { get; set; }
        @AuraEnabled public Boolean forceVersionUpdate { get; set; }

        public KnowledgeBrowserWrapper() {}
        public KnowledgeBrowserWrapper(String document, Metadata metadata, String error) {
            this.document = document;
            this.metadata = metadata;
            this.error = error;
        }
    }

    // -------------------- API Methods --------------------
    // section: shareKnowledge to the bot
    @AuraEnabled
    public static String shareKnowledge(KnowledgeDocumentWrapper knowledgeDocuments) {
            // Build JSON payload
            String jsonPayload = JSON.serialize(new Map<String, Object>{
                'knowledge_map' => knowledgeDocuments.manualDocuments,
                'URLs' => knowledgeDocuments.urls,
                'Documents' => knowledgeDocuments.fileDocuments
            });

            // HTTP Setup
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://ai-api.valarhr.com/api/share_knowledge');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + ranger_token_for_chatservice);
            req.setBody(jsonPayload);
            return sendRequest(req);


        //                 Http http = new Http();
        //     HttpResponse res = http.send(req);

        //     System.debug('Status: ' + res.getStatus());
        //     System.debug('Response Body: ' + res.getBody());
        //     return res.getBody();

        // } catch (Exception e) {
        //     System.debug('Error: ' + e.getMessage());
        //     throw new AuraHandledException('Failed to send knowledge data: ' + e.getMessage());
        // }

    }

    // section: Knowledge Browsing from the vectorDB

    //--------collection creation and deletion for a org  to store knowledge base documents--------------
    @AuraEnabled
    public static String createCollection() {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(BASE_URL + '/api/collection/create?companyId=' + EncodingUtil.urlEncode(companyId, 'UTF-8'));
        req.setMethod('POST');

        return sendRequest(req);
    }
    @AuraEnabled
    public static String deleteCollection() {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(BASE_URL + '/api/collection/delete?companyId=' + EncodingUtil.urlEncode(companyId, 'UTF-8'));
        req.setMethod('DELETE');

        return sendRequest(req);
    }

    //--------knowledge documents management--------------------
    @AuraEnabled
    public static KnowledgeBrowserWrapper getDocumentBySource(String source) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(BASE_URL + '/api/knowledgeContent?source=' + EncodingUtil.urlEncode(source, 'UTF-8'));
        req.setMethod('GET');
        String response = sendRequest(req); 
        Map<String, Object> raw = (Map<String, Object>) JSON.deserializeUntyped(response);

        String document = (String) raw.get('content');
        String error = (String) raw.get('error');
        Metadata metadata = new Metadata();
        metadata.source = (String) raw.get('source');
        // metadata.title = (String) metaMap.get('title');
        // metadata.createdAt = (String) metaMap.get('createdAt');
        // metadata.updatedAt = (String) metaMap.get('updatedAt');

        KnowledgeBrowserWrapper wrapper = new KnowledgeBrowserWrapper(document, metadata, error);
            return wrapper;
    }

    @AuraEnabled
    public static String updateDocumentBySource(KnowledgeBrowserWrapper browser) {
        HttpRequest req = new HttpRequest();        
        req.setEndpoint(BASE_URL + '/api/knowledgeContent?source=' + EncodingUtil.urlEncode(browser.metadata.source, 'UTF-8'));
        req.setMethod('PUT');
        req.setHeader('Content-Type', 'application/json');

        Map<String, Object> payload = new Map<String, Object>{
            'new_content' => browser.document,
            'new_metadata' => browser.metadata,
            'force_vector_update' => browser.forceVectorUpdate,
            'force_version_update' => browser.forceVersionUpdate

        };
        req.setBody(JSON.serialize(payload));

        return sendRequest(req);
    }
    @AuraEnabled
    public static String deleteDocumentBySource(String source) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(BASE_URL + '/api/knowledgeContent?source=' + EncodingUtil.urlEncode(source, 'UTF-8'));
        req.setMethod('DELETE');

        return sendRequest(req);
    }

    //--------knowledge content searching --------------------
    @AuraEnabled
    public static List<MetadataSuggestion> suggestMetadata(String query) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(BASE_URL + '/api/suggest?query=' + EncodingUtil.urlEncode(query, 'UTF-8'));
        req.setMethod('GET');

        String res = sendRequest(req);
        return (List<MetadataSuggestion>) JSON.deserialize(res, List<MetadataSuggestion>.class);
    }

    //--------common callout method --------------------
    private static String sendRequest(HttpRequest req) {
        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
            return res.getBody();
        } else {
            throw new CalloutException('Request failed: ' + res.getStatusCode() + ' - ' + res.getBody());
        }
    }
}