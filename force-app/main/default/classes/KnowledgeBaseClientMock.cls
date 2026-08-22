@isTest
global class KnowledgeBaseClientMock implements HttpCalloutMock {
    // global HTTPResponse respond(HTTPRequest req) {
    //     HttpResponse res = new HttpResponse();
    //     res.setHeader('Content-Type', 'application/json');
    //     res.setBody('{"status":"success","message":"Collection created"}');
    //     res.setStatusCode(200);
    //     return res;
    // }
    global HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');

        if (req.getEndpoint().contains('/api/collection/create')) {
            res.setBody('{"status":"success","message":"Collection created"}');
            res.setStatusCode(200);
        } else if (req.getEndpoint().contains('/api/collection/delete')) {
            res.setBody('{"status":"success","message":"Collection deleted"}');
            res.setStatusCode(200);
        } else if (req.getEndpoint().contains('/api/share_knowledge')) {
            res.setBody('{"message":"Shared"}');
            res.setStatusCode(200);
        }else if (req.getMethod() == 'GET' && req.getEndpoint().contains('/api/knowledgeContent')) {
            res.setBody('{"content":"Test content","source":"source-123","error":null}');
            res.setStatusCode(200);
        }else if (req.getMethod() == 'PUT' && req.getEndpoint().contains('/api/knowledgeContent')) {
            res.setBody('{"message":"Document updated"}');
            res.setStatusCode(200);
        }else if (req.getMethod() == 'DELETE' && req.getEndpoint().contains('/api/knowledgeContent')) {
            res.setBody('{"message":"Document deleted"}');
            res.setStatusCode(200);
        }else if (req.getEndpoint().contains('/api/suggest')) {
            res.setBody('[{"key":"topic","value":"AI"},{"key":"source","value":"Docs"}]');
            res.setStatusCode(200);
        } else {
            res.setBody('{"status":"error","message":"Unknown endpoint"}');
            res.setStatusCode(400);
        }

        return res;
    }
}