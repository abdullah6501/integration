public with sharing class GenericAutoNumberUtil {
    private static Boolean hasRun = false;

    public static void assignAutoNumbers(String objectApiName, List<SObject> records) {
        if (hasRun) return;
        hasRun = true;

        AutoNumberTracker__c tracker = [
            SELECT Id, Prefix__c, Digits__c, Last_Number__c, Target_Field_API_Name__c
            FROM AutoNumberTracker__c
            WHERE Object_API_Name__c = :objectApiName
            LIMIT 1
            FOR UPDATE
        ];

        if (String.isBlank(tracker.Target_Field_API_Name__c)) {
            throw new AuraHandledException('Target field API name is missing in the tracker.');
        }

        Integer current = (tracker.Last_Number__c == null) ? 0 : tracker.Last_Number__c.intValue();
        Integer digits = tracker.Digits__c.intValue();
        List<SObject> recordsToUpdate = new List<SObject>();

        for (SObject record : records) {
            current++;
            String padded = String.valueOf(current).leftPad(digits, '0');
            String finalNumber = tracker.Prefix__c + padded;

            // Create a new instance of the same object type and set ID + dynamic field
            SObject clone = record.getSObjectType().newSObject(record.Id);
            clone.put(tracker.Target_Field_API_Name__c, finalNumber);
            recordsToUpdate.add(clone);
        }

        if (!recordsToUpdate.isEmpty()) {
            update recordsToUpdate;
        }

        tracker.Last_Number__c = current;
        update tracker;
    }
}
