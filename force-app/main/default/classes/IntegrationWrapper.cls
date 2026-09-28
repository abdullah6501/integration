public class IntegrationWrapper {
    public class Request {
        public String method;        
        public String endpoint;      
        public Map<String, String> headers;
        public String body;
    }

    public class Response {
        public Integer statusCode;
        public String status;
        public String body;
        public Map<String, String> headers;
    }

    public class CalloutResult {
        public String requestId;
        public String requestPayload;
        public Datetime requestTime;
        public Datetime startTime; 
        public String endpoint;
        public String responsePayload;
        public Integer statusCode;
        public String errorMessage;
        public Request request;
        public Response response;
        // public Datetime responseTime;
    }
}