global class ChatServiceMock implements HttpCalloutMock{
    global HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');

            // Endpoint-based responses
            if (req.getMethod() == 'GET' && req.getEndpoint().contains('table=message&conversation_id')) {
                res.setBody('[{"message_id":"msg-123","conversation_id":"conv-123","sender_type":"user","sender_id":"admin@demo.valarhr","message_text":"Hello","created_at":"2025-08-01","is_error":false,"reply_to_message_id":null}]');
            }else if (req.getMethod() == 'GET' && req.getEndpoint().contains('conversation')) {
                res.setBody('[{"conversation_id":"conv-123","user_id":"admin@demo.valarhr","topic":"Test Topic","created_at":"2025-08-01","status":"active","updatedAt":"2025-08-02"}]');
            } else if (req.getMethod() == 'POST' || req.getMethod() == 'PATCH') {
                res.setBody('{"status":"ok"}');
            }else if (req.getMethod() == 'DELETE' && req.getEndpoint().contains('message')) {
               res.setStatusCode(204);
                res.setBody('');
            }else if (req.getMethod() == 'DELETE'&& req.getEndpoint().contains('conversation')) {
            res.setStatusCode(204);
            }else {
                res.setStatusCode(404);
                res.setBody('{"error":"not found"}');
            }

            return res;
    }

}