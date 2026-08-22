public class IntegrationLogInsertWorker implements Queueable {
    private List<Integration_Record__b> logs;
    private Integer retryCount;
    private static final Integer MAX_RETRIES = 3;

    public IntegrationLogInsertWorker(List<Integration_Record__b> logs) {
        this.logs = logs;
        this.retryCount = 0;
    }

    public IntegrationLogInsertWorker(List<Integration_Record__b> logs, Integer retryCount) {
        this.logs = logs;
        this.retryCount = retryCount != null ? retryCount : 0;
    }

    public void execute(QueueableContext context) {
        System.debug('IntegrationLogInsertWorker.execute called with ' + (logs != null ? logs.size() : 0) + ' records to insert. Retry count: ' + retryCount);
        
        if (logs == null || logs.isEmpty()) {
            System.debug('IntegrationLogInsertWorker.execute: No records to insert');
            return;
        }

        try {
            // Validate records before insertion
            List<Integration_Record__b> validRecords = validateRecords(logs);
            
            if (validRecords.isEmpty()) {
                System.debug('IntegrationLogInsertWorker.execute: No valid records to insert after validation');
                return;
            }

            // Big Object insert requires insertImmediate
            System.debug('IntegrationLogInsertWorker.execute: Inserting ' + validRecords.size() + ' Integration_Record__b records');
            Database.insertImmediate(validRecords);
            System.debug('IntegrationLogInsertWorker.execute: Successfully inserted ' + validRecords.size() + ' Integration Logs');
            
        } catch (DmlException e) {
            handleDmlException(e, context);
        } catch (Exception e) {
            handleGenericException(e, context);
        }
    }

    private List<Integration_Record__b> validateRecords(List<Integration_Record__b> records) {
        List<Integration_Record__b> validRecords = new List<Integration_Record__b>();
        
        for (Integration_Record__b record : records) {
            try {
                // Basic validation - ensure required fields are present
                if (record != null && 
                    String.isNotBlank(record.Integration_Id__c) && 
                    record.Integration_Date__c != null) {
                    validRecords.add(record);
                } else {
                    System.debug('IntegrationLogInsertWorker.validateRecords: Skipping invalid record: ' + record);
                }
            } catch (Exception e) {
                System.debug('IntegrationLogInsertWorker.validateRecords: Error validating record: ' + e.getMessage());
            }
        }
        
        System.debug('IntegrationLogInsertWorker.validateRecords: ' + validRecords.size() + ' valid records out of ' + records.size() + ' total records');
        return validRecords;
    }

    private void handleDmlException(DmlException e, QueueableContext context) {
        System.debug('IntegrationLogInsertWorker.handleDmlException: DML error occurred: ' + e.getMessage());
        System.debug('IntegrationLogInsertWorker.handleDmlException: DML error details: ' + e.getDmlMessage(0));
        
        // Check if we should retry
        if (retryCount < MAX_RETRIES && isRetryableError(e)) {
            System.debug('IntegrationLogInsertWorker.handleDmlException: Retrying operation. Attempt: ' + (retryCount + 1));
            System.enqueueJob(new IntegrationLogInsertWorker(logs, retryCount + 1));
        } else {
            System.debug('IntegrationLogInsertWorker.handleDmlException: Max retries exceeded or non-retryable error. Operation failed permanently.');
            // Could add custom platform event here to notify of permanent failure
        }
    }

    private void handleGenericException(Exception e, QueueableContext context) {
        System.debug('IntegrationLogInsertWorker.handleGenericException: Generic error occurred: ' + e.getMessage());
        System.debug('IntegrationLogInsertWorker.handleGenericException: Stack trace: ' + e.getStackTraceString());
        
        // Check if we should retry
        if (retryCount < MAX_RETRIES) {
            System.debug('IntegrationLogInsertWorker.handleGenericException: Retrying operation. Attempt: ' + (retryCount + 1));
            System.enqueueJob(new IntegrationLogInsertWorker(logs, retryCount + 1));
        } else {
            System.debug('IntegrationLogInsertWorker.handleGenericException: Max retries exceeded. Operation failed permanently.');
            // Could add custom platform event here to notify of permanent failure
        }
    }

    private Boolean isRetryableError(DmlException e) {
        // Define which DML errors are worth retrying
        String errorMessage = e.getMessage().toLowerCase();
        
        // Common retryable errors
        return errorMessage.contains('unable_to_lock_row') ||
               errorMessage.contains('timeout') ||
               errorMessage.contains('temporary') ||
               errorMessage.contains('server error') ||
               errorMessage.contains('connection') ||
               e.getDmlType(0) == StatusCode.UNABLE_TO_LOCK_ROW;
    }
}



// public class IntegrationLogInsertWorker implements Queueable {
//     private List<Integration_Record__b> logs;

//     public IntegrationLogInsertWorker(List<Integration_Record__b> logs) {
//         this.logs = logs;
//     }

//     public void execute(QueueableContext context) {
//         System.debug('IntegrationLogInsertWorker.execute called with ' + logs.size() + ' records to insert.');
//         try {
//             if (!logs.isEmpty()) {
//                 // Big Object insert requires insertImmediate
//                 System.debug('Inserting ' + logs.size() + ' Integration_Record__b records.' + logs);
//                 Database.insertImmediate(logs);
//                 System.debug('Integration Logs inserted: ' + logs.size());
//             }
//         } catch (Exception e) {
//             System.debug('IntegrationLogInsertWorker failed: ' + e.getMessage());
//         }
//     }
// }