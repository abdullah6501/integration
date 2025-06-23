@isTest
global class MockHttpResponseGenerator implements HttpCalloutMock {
    private Integer statusCode;
    private String responseBody;
    
    public MockHttpResponseGenerator(Integer statusCode, String responseBody) {
        this.statusCode = statusCode;
        this.responseBody = responseBody;
    }
    
    global HttpResponse respond(HttpRequest req) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(statusCode);
        res.setBody(responseBody);
        return res;
    }
}