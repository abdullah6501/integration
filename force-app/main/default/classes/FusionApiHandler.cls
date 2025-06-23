public class FusionApiHandler {
    @future(callout=true)
    public static void process(Boolean isInsert, Boolean isUpdate, Boolean isDelete, String objectName, List<Id> ids, List<String> names) {
        System.debug('Processing records with objectName: ' + objectName + ', ids: ' + ids);
        for (Integer i = 0; i < ids.size(); i++) {
            Id recordId = ids[i];
            String name = names[i];
            System.debug('entering loop for recordId: ' + recordId);
            if (isInsert) {
                System.debug('Processing insert for record: ' + recordId);
                FusionApi.doPost(recordId, objectName, 'POST', name);
                System.debug('Record inserted: ' + recordId);
            } else if (isUpdate) {
                System.debug('Processing update for record: ' + recordId);
                if (objectName == 'employee') {
                    FusionApi.doPost(recordId, objectName, 'PATCH', name);
                } else {
                    FusionApi.doPost(recordId, objectName, 'POST', name);
                }
                // FusionApi.doPost(recordId, objectName, 'PATCH', name);
                System.debug('Record updated: ' + recordId);
            } else if (isDelete) {
                System.debug('Processing delete for record: ' + recordId);
                FusionApi.doPost(recordId, objectName, 'DELETE', name);
                System.debug('Record deleted: ' + recordId);
            }
        }
    }

    public static void handleTrigger(List<SObject> records, Boolean isInsert, Boolean isUpdate, Boolean isDelete) {
        System.debug('Handling trigger for records: ' + records);
        if (records.isEmpty()) return;

        String objectName = '';
        List<Id> ids = new List<Id>();
        List<String> names = new List<String>();
        System.debug('Processing records: ' + records.size() + ', isInsert: ' + isInsert + ', isUpdate: ' + isUpdate);

        SObject first = records[0];
        
        System.debug('First record type: ' + first.getSObjectType());
        System.debug('First record ID: ' + first);
        if (first instanceof RFAB__Employee__c) {
            objectName = 'employee';
        } else if (first instanceof RFAB__Sales_Order__c) {
            objectName = 'salesorder';
        } else if (first instanceof Asset) {
            objectName = 'asset';
        } else if (first instanceof RFAB__Expense__c) {
            objectName = 'expense';
        }
        System.debug('Determined object name: ' + objectName);
        
        for (SObject obj : records) {
            ids.add(obj.Id);
            names.add(obj.get('Name') != null ? (String)obj.get('Name') : 'No Name');
        }
        System.debug('Collected IDs: ' + ids);

        if (!ids.isEmpty() && objectName != '') {
            System.debug('Calling FusionApiHandler.process with objectName: ' + objectName + ', ids: ' + ids);
            process(isInsert, isUpdate, isDelete, objectName, ids, names);
        }
    }
}