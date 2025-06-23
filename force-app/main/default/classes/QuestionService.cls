/** Date            version       Author                Modifiedby                      Description
                    1.0
    28-Mar-2025     1.1                                 Mohamed Abdul Kadher             In previous version code logic support single record. so now it code logic was changed to handle bulkified logic.
 
 */
public with sharing class QuestionService {
  // MR 23NOV23 Function to update Field Meta to Fields_Meta__c on Question

  public static void updateFieldMeta(Set<Id> qIds) {
    if (qIds == null || qIds.isEmpty()) {
      return;
    }

    // **Bulk Query to get Field Meta Records**
    String selectedObject = Field_Meta__c.sObjectType.getDescribe().getName();
    Map<String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
    Schema.SObjectType objectSchema = schemaMap.get(selectedObject);
    Map<String, Schema.SObjectField> fieldMap = objectSchema.getDescribe()
      .fields.getMap();

    Map<String, String> fieldNameTypeMap = new Map<String, String>();
    Map<String, String> fieldApiJsonNameMap = new Map<String, String>();

    for (String fieldName : fieldMap.keySet()) {
      fieldApiJsonNameMap.put(fieldName, Utility.jsName(fieldName));
      fieldNameTypeMap.put(
        fieldName,
        '' + fieldMap.get(fieldName).getDescribe().getType()
      );
    }

    // **Bulk Query to Fetch Records**
    List<Question__c> questionsToUpdate = new List<Question__c>();
    String queryStr =
      'SELECT ' +
      String.join(fieldNameTypeMap.keySet(), ', ') +
      ' FROM ' +
      selectedObject +
      ' WHERE Question__c IN :qIds' +
      ' ORDER BY order__c';

    // **Bulk Query Execution**
    List<Field_Meta__c> allFieldMetaRecords = Database.query(queryStr);

    // VD 24Apr25 changes Collect all referenced question IDs
    Set<Id> referencedQuestionIds = new Set<Id>();
    for (Field_Meta__c fm : allFieldMetaRecords) {
      if (fm.question_reference__c != null) {
        referencedQuestionIds.add(fm.question_reference__c);
      }
    }
    Map<Id, String> referencedJSONMap = getReferenceQuestion(
      referencedQuestionIds
    );

    Map<Id, List<Field_Meta__c>> fieldMetaRecordsMap = new Map<Id, List<Field_Meta__c>>();
    for (Field_Meta__c fm : allFieldMetaRecords) {
      if (!fieldMetaRecordsMap.containsKey(fm.Question__c)) {
        fieldMetaRecordsMap.put(fm.Question__c, new List<Field_Meta__c>());
      }
      fieldMetaRecordsMap.get(fm.Question__c).add(fm);
    }
    for (Id qId : qIds) {
      if (!fieldMetaRecordsMap.containsKey(qId))
        continue;
      QuestionHandler qh = new QuestionHandler();
      JSONGenerator jsonGen = JSON.createGenerator(true);
      jsonGen.writeStartArray();

      for (Field_Meta__c fm : fieldMetaRecordsMap.get(qId)) {
        jsonGen.writeStartObject();
        for (String field : fieldNameTypeMap.keySet()) {
          if (fm.get(field) != null) {
            switch on fieldNameTypeMap.get(field) {
              when 'BOOLEAN' {
                jsonGen.writeBooleanField(
                  fieldApiJsonNameMap.get(field),
                  (Boolean) fm.get(field)
                );
              }
              when 'STRING' {
                jsonGen.writeStringField(
                  fieldApiJsonNameMap.get(field),
                  (String) fm.get(field)
                );
              }
              when 'ID' {
                jsonGen.writeStringField(
                  fieldApiJsonNameMap.get(field),
                  (Id) fm.get(field)
                );
              }
              when 'PICKLIST' {
                jsonGen.writeStringField(
                  fieldApiJsonNameMap.get(field),
                  (String) fm.get(field)
                );
              }
              when 'MULTIPICKLIST' {
                String multiPicklistValue = (String) fm.get(field);
                multiPicklistValue = multiPicklistValue
                  ?.replaceAll('\\s*;\\s*', ',');
                jsonGen.writeStringField(
                  fieldApiJsonNameMap.get(field),
                  multiPicklistValue
                );
              }
              when 'DOUBLE' {
                jsonGen.writeNumberField(
                  fieldApiJsonNameMap.get(field),
                  (Decimal) fm.get(field)
                );
              }
              when 'REFERENCE' {
                if (field == 'question_reference__c') {
                  // VD24Apr25 rmove inside query to avoid too many SOQL
                  // remove the unwanted multiple slashes on question object json
                  String rawJson = referencedJSONMap.get((Id) fm.get(field));
                  if (rawJson != null) {
                    try {
                      // VD 26Apr25 json read changes
                      Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(
                        rawJson
                      );
                      if (parsed != null) {
                        // Serialize the full parsed object properly (without manually replacing backslashes!)
                        String cleanJson = JSON.serialize(parsed);
                        jsonGen.writeStringField(
                          fieldApiJsonNameMap.get(field),
                          cleanJson
                        );
                      }
                    } catch (Exception e) {
                      System.debug(
                        LoggingLevel.ERROR,
                        'Error parsing question JSON: ' + e.getMessage()
                      );
                    }
                  }
                }
              }
              when else {
                //jsonGen.writeStringField(field, fm.get(field));
              }
            }
          }
        }
        jsonGen.writeEndObject();
      }
      jsonGen.writeEndArray();

      // **Prepare bulk update list**
      Question__c qObj = new Question__c();
      qObj.Id = qId;
      qObj.Fields_Meta__c = jsonGen.getAsString();
      questionsToUpdate.add(qObj);
    }

    // **Bulk Update**
    if (!questionsToUpdate.isEmpty()) {
      update questionsToUpdate;
    }
  }

  public static void updateStyle(Set<Id> qIds) {
    if (qIds == null || qIds.isEmpty()) {
      return;
    }

    // **Bulk Query to get Style Records**
    String selectedObject = Style__c.sObjectType.getDescribe().getName();
    Map<String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
    Schema.SObjectType objectSchema = schemaMap.get(selectedObject);
    Map<String, Schema.SObjectField> fieldMap = objectSchema.getDescribe()
      .fields.getMap();

    Map<String, String> fieldNameTypeMap = new Map<String, String>();
    Map<String, String> fieldApiJsonNameMap = new Map<String, String>();

    for (String fieldName : fieldMap.keySet()) {
      fieldApiJsonNameMap.put(fieldName, Utility.jsName(fieldName));
      fieldNameTypeMap.put(
        fieldName,
        '' + fieldMap.get(fieldName).getDescribe().getType()
      );
    }

    // **Bulk Query to Fetch Records**
    List<Question__c> questionsToUpdate = new List<Question__c>();
    String queryStr =
      'SELECT ' +
      String.join(fieldNameTypeMap.keySet(), ', ') +
      ' FROM ' +
      selectedObject +
      ' WHERE Question__c IN :qIds';

    // **Bulk Query Execution**
    List<Style__c> allFieldMetaRecords = Database.query(queryStr);

    Map<Id, List<Style__c>> fieldMetaRecordsMap = new Map<Id, List<Style__c>>();
    for (Style__c fm : allFieldMetaRecords) {
      if (!fieldMetaRecordsMap.containsKey(fm.Question__c)) {
        fieldMetaRecordsMap.put(fm.Question__c, new List<Style__c>());
      }
      fieldMetaRecordsMap.get(fm.Question__c).add(fm);
    }
    for (Id qId : qIds) {
      if (!fieldMetaRecordsMap.containsKey(qId))
        continue;
      QuestionHandler qh = new QuestionHandler();
      JSONGenerator jsonGen = JSON.createGenerator(true);
      jsonGen.writeStartArray();

      for (Style__c fm : fieldMetaRecordsMap.get(qId)) {
        jsonGen.writeStartObject();
        for (String field : fieldNameTypeMap.keySet()) {
          if (fm.get(field) != null) {
            switch on fieldNameTypeMap.get(field) {
              when 'BOOLEAN' {
                jsonGen.writeBooleanField(
                  fieldApiJsonNameMap.get(field),
                  (Boolean) fm.get(field)
                );
              }
              when 'STRING' {
                jsonGen.writeStringField(
                  fieldApiJsonNameMap.get(field),
                  (String) fm.get(field)
                );
              }
              when 'ID' {
                jsonGen.writeStringField(
                  fieldApiJsonNameMap.get(field),
                  (Id) fm.get(field)
                );
              }
              when 'PICKLIST' {
                jsonGen.writeStringField(
                  fieldApiJsonNameMap.get(field),
                  (String) fm.get(field)
                );
              }
              when 'MULTIPICKLIST' {
                String multiPicklistValue = (String) fm.get(field);
                multiPicklistValue = multiPicklistValue
                  ?.replaceAll('\\s*;\\s*', ',');
                jsonGen.writeStringField(
                  fieldApiJsonNameMap.get(field),
                  multiPicklistValue
                );
              }
              when 'DOUBLE' {
                jsonGen.writeNumberField(
                  fieldApiJsonNameMap.get(field),
                  (Decimal) fm.get(field)
                );
              }
              when else {
                //jsonGen.writeStringField(field, fm.get(field));
              }
            }
          }
        }
        jsonGen.writeEndObject();
      }
      jsonGen.writeEndArray();

      // **Prepare bulk update list**
      Question__c qObj = new Question__c();
      qObj.Id = qId;
      String jsonStr = jsonGen.getAsString();
      List<Object> jsonList = (List<Object>)JSON.deserializeUntyped(jsonStr);
      qObj.Style__c = jsonList.isEmpty() ? null : JSON.serialize(jsonList[0]);
      questionsToUpdate.add(qObj);
    }

    // **Bulk Update**
    if (!questionsToUpdate.isEmpty()) {
      update questionsToUpdate;
    }
  }

  // MR 24NOV23 Fuction to store the questions of a QB Reference in the Question QB_Reference_Questions__c
  public static void updateQuestionMeta(
    Set<String> qIds,
    Map<String, String> qbRefMap
  ) {
    if (qIds == null || qIds.isEmpty()) {
      return; // Prevent unnecessary execution
    }

    List<Question__c> questionsToUpdate = new List<Question__c>();

    for (String qId : qIds) {
      QuestionBookHandler qbh = new QuestionBookHandler();
      qbh.setContext('createAnswerBookFlag', false);
      Question__c qObj = new Question__c();
      qObj.Id = qId;
      qObj.QB_Reference_Questions__c = qbh.readRecords(qbRefMap.get(qId), '');
      questionsToUpdate.add(qObj);
    }

    if (!questionsToUpdate.isEmpty()) {
      update questionsToUpdate;
    }
  }

  // VD 24APRL25 method to get the reference question
  private static Map<Id, String> getReferenceQuestion(
    Set<Id> referencedQuestionIds
  ) {
    Map<Id, String> referencedJSONMap = new Map<Id, String>();

    if (referencedQuestionIds.isEmpty())
      return referencedJSONMap;

    Map<Id, Question__c> referencedQuestions = new Map<Id, Question__c>(
      [
        SELECT
          Id,
          Name,
          Reference_Field__c,
          Unique_Identifier__c,
          Additional_Rich__c,
          Group__c,
          Is_Date_Backward__c,
          Title__c,
          SubTitle__c,
          Is_Date_Forward__c,
          Is_Optional__c,
          Is_Title__c,
          Read_Only__c,
          IsAddRowAction__c,
          isSno__c,
          Is_Row_Draggable__c,
          Is_Serial_No__c,
          Print_Mode__c,
          IsDeleteRowAction__c,
          Is_Hide__c,
          Help_Text__c,
          Next_Question__c,
          Error_Message__c,
          X24_Hours__c,
          Allowed_File_Extensions__c,
          Question_Text__c,
          Question__c,
          Question_No__c,
          Question_Book__c,
          Question_Parent__c,
          Size__c,
          Type__c,
          Sub_Text__c,
          Fields_Meta__c,
          RecordType.Name,
          RecordTypeId,
          Tracking_ID__c,
          Date_Text__c,
          Time_Text__c,
          Record_Id__c,
          Question_Book__r.SubTitle__c,
          QB_Reference__c,
          QB_Reference_Questions__c,
          Style__c,
          Is_Dependent__c,
          (
            SELECT
              Id,
              Name,
              Value__c,
              Unique_Identifier__c,
              Next_Question__c,
              Question__c,
              Is_Default__c,
              Tracking_ID__c
            FROM Question_Options__r
            ORDER BY Order__c
          ),
          (
            SELECT
              Id,
              Name,
              Reference_Field__c,
              Unique_Identifier__c,
              Additional_Rich__c,
              Group__c,
              Is_Date_Backward__c,
              Title__c,
              SubTitle__c,
              Is_Date_Forward__c,
              Is_Optional__c,
              Is_Title__c,
              Read_Only__c,
              IsAddRowAction__c,
              isSno__c,
              Is_Row_Draggable__c,
              Is_Serial_No__c,
              Print_Mode__c,
              IsDeleteRowAction__c,
              Is_Hide__c,
              Help_Text__c,
              Next_Question__c,
              Error_Message__c,
              X24_Hours__c,
              Allowed_File_Extensions__c,
              Question_Text__c,
              Question__c,
              Question_No__c,
              Question_Book__c,
              Question_Parent__c,
              Size__c,
              Type__c,
              Sub_Text__c,
              Fields_Meta__c,
              RecordType.Name,
              RecordTypeId,
              Tracking_ID__c,
              Date_Text__c,
              Time_Text__c,
              Record_Id__c,
              Question_Book__r.SubTitle__c,
              QB_Reference__c,
              QB_Reference_Questions__c,
              Style__c,
              Is_Dependent__c
            FROM Questions__r
            ORDER BY Question_No__c
          )
        FROM Question__c
        WHERE Id IN :referencedQuestionIds
      ]
    );

    Set<Id> subQuestionIds = new Set<Id>();
    for (Question__c q : referencedQuestions.values()) {
      if (q.Questions__r != null) {
        for (Question__c subQ : q.Questions__r) {
          subQuestionIds.add(subQ.Id);
        }
      }
    }

    Map<Id, List<Option__c>> subQOptionsMap = new Map<Id, List<Option__c>>();
    if (!subQuestionIds.isEmpty()) {
      for (Option__c opt : [
        SELECT
          Id,
          Name,
          Value__c,
          Unique_Identifier__c,
          Next_Question__c,
          Is_Default__c,
          Question__c
        FROM Option__c
        WHERE Question__c IN :subQuestionIds
        ORDER BY Order__c
      ]) {
        if (!subQOptionsMap.containsKey(opt.Question__c)) {
          subQOptionsMap.put(opt.Question__c, new List<Option__c>());
        }
        subQOptionsMap.get(opt.Question__c).add(opt);
      }
    }

    for (Id refId : referencedQuestions.keySet()) {
      JSONGenerator jsonGen = JSON.createGenerator(true);
      jsonGen.writeStartObject();

      QuestionWrapper wrapper = new QuestionWrapper(
        referencedQuestions.get(refId)
      );

      if (wrapper.subQuestions != null) {
        for (QuestionWrapper sub : wrapper.subQuestions) {
          if (subQOptionsMap.containsKey(sub.id)) {
            sub.options = new List<OptionWrapper>();
            for (Option__c o : subQOptionsMap.get(sub.id)) {
              sub.options.add(new OptionWrapper(o));
            }
          }
        }
      }

      jsonGen.writeStringField('status', 'success');
      jsonGen.writeObjectField('question', wrapper);
      jsonGen.writeEndObject();

      referencedJSONMap.put(refId, jsonGen.getAsString());
    }

    return referencedJSONMap;
  }
}