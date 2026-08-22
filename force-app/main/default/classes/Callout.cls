public class Callout {
    public static String token { get; set; }

    public static void get_token() {
        try{
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:focusr/sap/bc/zdp_so_crt_srv/post?sap-client=800');
            req.setMethod('GET');
            req.setHeader('x-csrf-token', 'Fetch'); 
            
            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200 && token != null) {
                token = res.getHeader('x-csrf-token');
                System.debug('CSRF token fetched successfully: ' + token);
            } else {
                throw new CalloutException('Error fetching CSRF token: ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Callout error: ' + e.getMessage());
        }
    }
    public static String get_material_master() {
        String result=null;

        try{
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:focusr/zsd_material/Material?sap-client=800');
            req.setMethod('GET');
            get_token();
            req.setHeader('x-csrf-token', token); 
            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200 && token != null) {
                System.debug('meterial master got successfully: ' + token);
                result= res.getBody();
            } else {
                throw new CalloutException('Error fetching CSRF token: ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Callout error: ' + e.getMessage());
        }
        return result;
    }
    
    public static String[] sale_order_post(String json){
        String[] external_ids = new List<String>{'645656456565'};

        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:focusr/sap/bc/zdp_so_crt_srv/post?sap-client=800');
            req.setMethod('Post');
            get_token();
            req.setHeader('x-csrf-token', token); 
            req.setHeader('content-type', 'json'); 
            Http http = new Http();
            HttpResponse res = http.send(req);
            if (res.getStatusCode() == 200) {
                String jsonResponse = res.getBody();

            List<Map<String, Object>> jsonList = (List<Map<String, Object>>) system.JSON.deserializeUntyped(jsonResponse);

            for (Map<String, Object> record : jsonList) {
                external_ids.add((String) record.get('VBELN'));
                System.debug('sale order posted successfully');
            }

            } else {
                throw new CalloutException('sales order didn\'t posted: ' + res.getbody());
            }
        } catch (Exception e) {
            System.debug('Callout error: ' + e.getMessage());
        }
        System.debug('external_ids: ' + external_ids);
        return external_ids;

    }
    public static void customer_post(String json){
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:focusr/zsrv_bp/bp?sap-client=800');
            req.setMethod('Post');
            get_token();
            req.setHeader('x-csrf-token', token); 
            req.setHeader('content-type', json); 
            Http http = new Http();
            HttpResponse res = http.send(req);
            if (res.getStatusCode() == 200) {
                System.debug('customer posted successfully');
            } else {
                throw new CalloutException('customer didn\'t posted: ' + res.getbody());
            }
        } catch (Exception e) {
            System.debug('Callout error: ' + e.getMessage());
        }
    }

}