public class IntegrationLogService {
    
    @AuraEnabled(cacheable=true)
    public static List<IntegrationWrapper> getIntegrationLogs() {
        try {
            // Query using indexed fields only - no ORDER BY for Big Objects
            List<Integration_Record__b> intlogs = [
                SELECT Integration_Id__c, Status__c, Integration_Date__c,
                       Integration_Name__c, Endpoint__c, Request_Payload__c, Response_Payload__c
                FROM Integration_Record__b
                LIMIT 50
            ];

            List<IntegrationWrapper> wrappers = new List<IntegrationWrapper>();
            for (Integration_Record__b log : intlogs) {
                IntegrationWrapper wrapper = new IntegrationWrapper();
                wrapper.integrationId = log.Integration_Id__c;
                wrapper.integrationStatus = log.Status__c;
                wrapper.integrationDate = log.Integration_Date__c.date();
                wrapper.integrationName = log.Integration_Name__c;
                wrapper.endpointLabel = log.Endpoint__c;
                wrapper.requestPayload = log.Request_Payload__c;
                wrapper.responsePayload = log.Response_Payload__c;
                wrappers.add(wrapper);
            }
            return wrappers;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching Integration Logs: ' + e.getMessage());
        }
    }

    // Enhanced method for Big Objects with date-based pagination
    @AuraEnabled(cacheable=true)
    public static IntegrationLogResponse getIntegrationLogsPaginated(Integer pageSize, DateTime lastRecordDate, String lastRecordId) {
        try {
            List<Integration_Record__b> intlogs;
            
            // If we have a lastRecordDate, use it for pagination (assuming Integration_Date__c is indexed)
            if (lastRecordDate != null && String.isNotBlank(lastRecordId)) {
                intlogs = [
                    SELECT Integration_Id__c, Status__c, Integration_Date__c,
                           Integration_Name__c, Endpoint__c, Request_Payload__c, Response_Payload__c
                    FROM Integration_Record__b
                    WHERE Integration_Date__c < :lastRecordDate
                    OR (Integration_Date__c = :lastRecordDate AND Integration_Id__c > :lastRecordId)
                    LIMIT :pageSize
                ];
            } else {
                // First load - get most recent records
                intlogs = [
                    SELECT Integration_Id__c, Status__c, Integration_Date__c,
                           Integration_Name__c, Endpoint__c, Request_Payload__c, Response_Payload__c
                    FROM Integration_Record__b
                    LIMIT :pageSize
                ];
            }

            // Check if there are more records by trying to fetch one extra
            List<Integration_Record__b> checkMore;
            if (!intlogs.isEmpty()) {
                Integration_Record__b lastRecord = intlogs[intlogs.size() - 1];
                checkMore = [
                    SELECT Integration_Id__c
                    FROM Integration_Record__b
                    WHERE Integration_Date__c < :lastRecord.Integration_Date__c
                    OR (Integration_Date__c = :lastRecord.Integration_Date__c AND Integration_Id__c > :lastRecord.Integration_Id__c)
                    LIMIT 1
                ];
            }

            List<IntegrationWrapper> wrappers = new List<IntegrationWrapper>();
            for (Integration_Record__b log : intlogs) {
                IntegrationWrapper wrapper = new IntegrationWrapper();
                wrapper.integrationId = log.Integration_Id__c;
                wrapper.integrationStatus = log.Status__c;
                wrapper.integrationDate = log.Integration_Date__c.date();
                wrapper.integrationName = log.Integration_Name__c;
                wrapper.endpointLabel = log.Endpoint__c;
                wrapper.requestPayload = log.Request_Payload__c;
                wrapper.responsePayload = log.Response_Payload__c;
                wrapper.integrationDateTime = log.Integration_Date__c; // Keep full DateTime for pagination
                wrappers.add(wrapper);
            }

            IntegrationLogResponse response = new IntegrationLogResponse();
            response.logs = wrappers;
            response.hasMore = checkMore != null && !checkMore.isEmpty();
            response.totalCount = wrappers.size();

            return response;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching Integration Logs: ' + e.getMessage());
        }
    }

    // Simple method for when you just want to load all available records
    @AuraEnabled(cacheable=true)
    public static IntegrationLogResponse getAllIntegrationLogs(Integer maxRecords) {
        try {
            if (maxRecords == null || maxRecords <= 0) {
                maxRecords = 200; // Default maximum
            }
            
            List<Integration_Record__b> intlogs = [
                SELECT Integration_Id__c, Status__c, Integration_Date__c,
                       Integration_Name__c, Endpoint__c, Request_Payload__c, Response_Payload__c
                FROM Integration_Record__b
                LIMIT :maxRecords
            ];

            List<IntegrationWrapper> wrappers = new List<IntegrationWrapper>();
            for (Integration_Record__b log : intlogs) {
                IntegrationWrapper wrapper = new IntegrationWrapper();
                wrapper.integrationId = log.Integration_Id__c;
                wrapper.integrationStatus = log.Status__c;
                wrapper.integrationDate = log.Integration_Date__c.date();
                wrapper.integrationName = log.Integration_Name__c;
                wrapper.endpointLabel = log.Endpoint__c;
                wrapper.requestPayload = log.Request_Payload__c;
                wrapper.responsePayload = log.Response_Payload__c;
                wrapper.integrationDateTime = log.Integration_Date__c;
                wrappers.add(wrapper);
            }

            // Sort in memory since we can't sort in SOQL for Big Objects
            wrappers.sort(new IntegrationDateComparator());

            IntegrationLogResponse response = new IntegrationLogResponse();
            response.logs = wrappers;
            response.hasMore = false; // We loaded all available records
            response.totalCount = wrappers.size();

            return response;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching Integration Logs: ' + e.getMessage());
        }
    }

    public class IntegrationWrapper {
        @AuraEnabled public String integrationId;
        @AuraEnabled public String integrationStatus;
        @AuraEnabled public String integrationName;
        @AuraEnabled public String endpointLabel;
        @AuraEnabled public String requestPayload;
        @AuraEnabled public String responsePayload;
        @AuraEnabled public Date integrationDate;
        @AuraEnabled public DateTime integrationDateTime; // For pagination
    }

    public class IntegrationLogResponse {
        @AuraEnabled public List<IntegrationWrapper> logs;
        @AuraEnabled public Boolean hasMore;
        @AuraEnabled public Integer totalCount;
    }

    // Custom comparator for sorting by date in descending order
    public class IntegrationDateComparator implements Comparator<IntegrationWrapper> {
        public Integer compare(IntegrationWrapper a, IntegrationWrapper b) {
            if (a.integrationDateTime == b.integrationDateTime) return 0;
            if (a.integrationDateTime > b.integrationDateTime) return -1;
            return 1;
        }
    }

    /**
     * Log wrapper data immediately to big object
     */
    public static void logWrapperAsync(
        String integrationId,
        String integrationName,
        String endpointLabel,
        IntegrationWrapper.CalloutResult result
    ) {
        System.debug('IntegrationLogService.logWrapperAsync called for integrationId=' + integrationId
            + ', integrationName=' + integrationName
            + ', endpointLabel=' + endpointLabel
            + ', result=' + result);
        
        if (result == null) {
            System.debug('IntegrationLogService.logWrapperAsync: result is null, skipping');
            return;
        }

        try {
            Integration_Record__b rec = buildLogRecord(
                integrationId,
                integrationName,
                endpointLabel,
                result
            );
            System.debug('IntegrationLogService.logWrapperAsync built record: ' + rec);

            // Immediately store the log record
            storeLogRecord(rec);
        } catch (Exception e) {
            System.debug('IntegrationLogService.logWrapperAsync error: ' + e.getMessage());
            // Continue execution even if logging fails
        }
    }

    /**
     * Store single log record immediately
     */
    private static void storeLogRecord(Integration_Record__b rec) {
        System.debug('IntegrationLogService.storeLogRecord called with rec: ' + rec);
        if (rec == null) {
            System.debug('IntegrationLogService.storeLogRecord: record is null, skipping');
            return;
        }

        try {
            // Create a list with single record for the queueable job
            List<Integration_Record__b> recordsToInsert = new List<Integration_Record__b>{ rec };
            
            System.debug('IntegrationLogService.storeLogRecord: enqueueing job for immediate insert');
            System.enqueueJob(new IntegrationLogInsertWorker(recordsToInsert));
            
        } catch (Exception e) {
            System.debug('IntegrationLogService.storeLogRecord error enqueueing job: ' + e.getMessage());
            
            // Fallback: try immediate insert if queueable fails
            try {
                System.debug('IntegrationLogService.storeLogRecord: attempting immediate fallback insert');
                Database.insertImmediate(new List<Integration_Record__b>{ rec });
                System.debug('IntegrationLogService.storeLogRecord: fallback insert successful');
            } catch (Exception fallbackException) {
                System.debug('IntegrationLogService.storeLogRecord: fallback insert failed: ' + fallbackException.getMessage());
            }
        }
    }



    /**
     * Build a log record from wrapper
     */
    private static Integration_Record__b buildLogRecord(
        String integrationId,
        String integrationName,
        String endpointLabel,
        IntegrationWrapper.CalloutResult result
    ) {
        System.debug('IntegrationLogService.buildLogRecord called with integrationId=' + integrationId
            + ', integrationName=' + integrationName
            + ', endpointLabel=' + endpointLabel
            + ', result=' + result);
        
        Integration_Record__b logRec = new Integration_Record__b();

        // INDEX FIELDS - with proper validation
        logRec.Integration_Id__c = String.isBlank(integrationId) ? 'UNKNOWN00000000000'
            : safeTruncate(integrationId, 18);

        logRec.Status__c = (result.response?.statusCode == null)
            ? 'ERR'
            : String.valueOf(result.response.statusCode);

        logRec.Integration_Date__c = System.today();

        logRec.Request_Id__c = String.isBlank(result.requestId)
            ? String.valueOf(Crypto.getRandomLong())
            : safeTruncate(result.requestId, 100);

        // NON-INDEX FIELDS
        logRec.Integration_Name__c = safeTruncate(integrationName, 255);
        logRec.Direction__c = 'OUTBOUND';
        logRec.Endpoint__c = safeTruncate(endpointLabel, 255);

        if (result.response != null) {
            logRec.HTTP_Status__c = result.response.statusCode;
            logRec.Short_Message__c = safeTruncate(result.response.status, 255);
        } else {
            logRec.Short_Message__c = 'No response';
        }

        if (result.startTime != null && result.response != null) {
            logRec.Latency_ms__c = System.now().getTime() - result.startTime.getTime();
        }

        // Payloads with safe extraction
        String requestBody = null;
        String responseBody = null;
        Map<String, String> requestHeaders = null;
        Map<String, String> responseHeaders = null;
        
        try {
            requestBody = result.request?.body;
            responseBody = result.response?.body;
            requestHeaders = result.request?.headers;
            responseHeaders = result.response?.headers;
        } catch (Exception e) {
            System.debug('IntegrationLogService.buildLogRecord error extracting payloads: ' + e.getMessage());
        }

        logRec.Request_Payload__c = safeTruncate(requestBody, 131072);
        logRec.Response_Payload__c = safeTruncate(responseBody, 131072);
        logRec.Request_Headers__c = safeTruncate(mapToString(requestHeaders), 2000);
        logRec.Response_Headers__c = safeTruncate(mapToString(responseHeaders), 2000);

        System.debug('IntegrationLogService.buildLogRecord built logRec: ' + logRec);
        return logRec;
    }

    private static String safeTruncate(String s, Integer maxLen) {
        if (String.isBlank(s) || maxLen == null || maxLen <= 0) return s;
        return (s.length() <= maxLen) ? s : s.substring(0, maxLen);
    }

    private static String mapToString(Map<String, String> m) {
        if (m == null || m.isEmpty()) return null;
        
        String result = '';
        try {
            for (String k : m.keySet()) {
                if (String.isNotBlank(k)) {
                    String value = m.get(k);
                    result += k + ': ' + (value != null ? value : '') + '\n';
                }
            }
        } catch (Exception e) {
            System.debug('IntegrationLogService.mapToString error: ' + e.getMessage());
            return 'Error processing headers: ' + e.getMessage();
        }
        
        return String.isBlank(result) ? null : result;
    }
}