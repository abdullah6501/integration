public with sharing class QuestionBookHandler implements DataHandler {
  @testvisible
  private Boolean createAnswerBookFlag = false;
  @testvisible
  private Map<String, Object> paramMap = new Map<String, Object>();
  
  public QuestionBookHandler(Boolean answerFlag) {
    this.createAnswerBookFlag = answerFlag;
  }
  
  public QuestionBookHandler() {
  }
  
  public void setContext(String fieldName, Object fieldValue) {
    this.paramMap.put(fieldName, fieldValue);
    if (fieldName == 'createAnswerBookFlag') {
      this.createAnswerBookFlag = (Boolean) fieldValue;
    }
  }
  
  public String getRecords() {
    return '{"status":"failure","message":"List operation is not supported"}';
  }
  
  public String readRecords(String inputJSON, String languageCode) {
    system.debug('inputJSON' + inputJSON);
    JSONGenerator jsonGen = JSON.createGenerator(true);// qbId , recId
    jsonGen.writeStartObject();
    Id inpId = (Id) inputJSON;
    String ansId = inputJSON;
    String sObjName = inpId.getSObjectType().getDescribe().getName();
    jsonGen.writeStringField('objName', sObjName);
    
    Question_Book__c retQB = new Question_Book__c();
    Answer_Book__c retAB = new Answer_Book__c();
    
    if (sObjName == 'Answer_Book__c') {
      // Input param is AnswerBook Id
      retAB = [
        SELECT
          Id,
          Question_Book__c,
          Name,
          Status__c,
          RecordId__c,
          Answer_Long__c,
          (
            SELECT
              Id,
              Number__c,
              Answer_Book__c,
              Question_Rich_Text__c,
              Answer_Long__c,
              Question_Ref__c,
              Question_Type__c,
              recordId__c,
              Question_Group_Text__c,
              Question_Text__c
            FROM Answers__r
          )
        FROM Answer_Book__c
        WHERE id = :inpId
        WITH SECURITY_ENFORCED
        LIMIT 1
      ][0];
      
      retQB = [
        SELECT
          Id,
          Name,
          Parent_Booklet_QB__c,
          Status__c,
          Title__c,
          isShengel__c,
          SubTitle__c,
          First_Question__c,
          First_Question__r.Type__c,
          Last_Question__c,
          Category__c,
          Total_Questions__c,
          Next__c,
          Back__c,
          Submit__c,
          Cancel__c,
          Api_Key__c,
          Edit__c,
          Actions__c,
          Possibilities__c,
          Summary_Text__c,
          Summary_Sub_Text__c,
          Progress_Bar__c,
          Next_Tracking_ID__c,
          Back_Tracking_ID__c,
          Cancel_Tracking_ID__c,
          Submit_Tracking_ID__c,
          Unique_Identifier__c,
          Query__c,
          Style__c,
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
              Is_Hide__c,
              Help_Text__c,
              Read_Only__c,
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
              Next__c,
              Back__c,
              Submit__c,
              Cancel__c,
              Edit__c,
              Style__c
            FROM Questions__r
            ORDER BY Question_No__c
          )
        FROM Question_Book__c
        WHERE id = :retAB.Question_Book__c
        WITH SECURITY_ENFORCED
        LIMIT 1
      ][0];
    } else if (sObjName == 'Question_Book__c') {
      for (Question_Book__c qb : [
        SELECT
          Id,
          Name,
          Parent_Booklet_QB__c,
          Status__c,
          Title__c,
          isShengel__c,
          SubTitle__c,
          First_Question__c,
          First_Question__r.Type__c,
          Last_Question__c,
          Category__c,
          Total_Questions__c,
          Next__c,
          Back__c,
          Submit__c,
          Api_Key__c,
          Cancel__c,
          Edit__c,
          Actions__c,
          Possibilities__c,
          Summary_Text__c,
          Summary_Sub_Text__c,
          Progress_Bar__c,
          Next_Tracking_ID__c,
          Back_Tracking_ID__c,
          Cancel_Tracking_ID__c,
          Submit_Tracking_ID__c,
          Query__c,
          Unique_Identifier__c,
          Style__c,
          (SELECT Id, API_Name__c, Type__c FROM Inputs__r),
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
              Is_Hide__c,
              Help_Text__c,
              Read_Only__c,
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
              Record_Id__c,
              Type__c,
              Sub_Text__c,
              Fields_Meta__c,
              RecordType.Name,
              RecordTypeId,
              Tracking_ID__c,
              Date_Text__c,
              Time_Text__c,
              Question_Book__r.SubTitle__c,
              QB_Reference__c,
              QB_Reference_Questions__c,
              Next__c,
              Back__c,
              Submit__c,
              Cancel__c,
              Edit__c,
              Style__c
            FROM Questions__r
            ORDER BY Question_No__c
          )
        FROM Question_Book__c
        WHERE id = :inpId
        WITH SECURITY_ENFORCED
        LIMIT 1
      ]) {
        if (qb.Id != null) {
          retQB = qb;
        }
      }
      
      if (this.createAnswerBookFlag == true) {
        retAB.Question_Book__c = inpId;
        retAB.Status__c = 'Pending';
        SObjectAccessDecision createAcces = Security.stripInaccessible(
          AccessType.CREATABLE,
          new List<Answer_Book__c>{ retAB }
        );
        
        if (createAcces.getRecords().size() > 0) {
          if (
            Answer_Book__c.SObjectType.getDescribe().isCreateable() &&
            Schema.sObjectType.Answer_Book__c.fields.Question_Book__c.isCreateable() &&
            Schema.sObjectType.Answer_Book__c.fields.Status__c.isCreateable()
          ) {
            Database.insert(retAB);
          } else {
            jsonGen.writeStringField(
              'error',
              'No Access to create Answer_Book__c with Question Book and Status'
            );
          }
        } else {
          jsonGen.writeStringField(
            'error',
            'No Access to create Answer_Book__c'
          );
        }
      } else {
        jsonGen.writeStringField(
          'error',
          'createAnswerBookFlag is ' + createAnswerBookFlag + ' and ' + inpId
        );
      }
    } else {
      //invalid id
    }
    
    // Process the Query for reading the data from DB
    if (String.isNotBlank(retQB.Query__c)) {
      String qStr = retQB.Query__c;
      System.debug('qStr ' + qStr);
      system.debug('inputs ' + retQB.Inputs__r);
      
      for (Input__c inp : retQB.Inputs__r) {
        if (
          inp.Type__c == 'String' && this.paramMap.containsKey(inp.API_Name__c)
        ) {
          qStr = qStr.replace(
            '{' + inp.API_Name__c + '}',
            '\'' + (String) this.paramMap.get(inp.API_Name__c) + '\''
          );
        }
      }
      
      retQB.Query__c = qStr;
      System.debug('inp.API_Name__c'+  retQB.Query__c); 

      try {
        List<SObject> lstResult = database.query(qStr);
        jsonGen.writeObjectField('qbQueryResult', lstResult);
      } catch (Exception e) {
        jsonGen.writeObjectField('qbQueryResult', new List<SObject>());
        jsonGen.writeStringField('exception', e.getMessage());
      }
    } else {
      jsonGen.writeObjectField('qbQueryResult', new List<SObject>());
    }

    // Enhanced table input processing
    List<Map<String, Object>> tableInputs = new List<Map<String, Object>>();
    
    // Process table inputs for each question with table type
    if (retQB.Questions__r != null) {
      for (Question__c question : retQB.Questions__r) {
        if (question.Type__c == 'Table' && question.Fields_Meta__c != null) {
          Map<String, Object> tableInput = new Map<String, Object>();
          tableInput.put('questionId', question.Id);
          tableInput.put('questionName', question.Name);
          
          // Safely parse Fields_Meta__c
          List<Object> fieldsMetadataRaw = 
            (List<Object>) JSON.deserializeUntyped(question.Fields_Meta__c);
          
          List<Map<String, Object>> fieldsMetadata = new List<Map<String, Object>>();
          
          // Convert raw objects to Map<String, Object>
          for (Object metaObj : fieldsMetadataRaw) {
            fieldsMetadata.add((Map<String, Object>) metaObj);
          }
          
          List<Map<String, Object>> tableColumns = new List<Map<String, Object>>();
          
          for (Map<String, Object> fieldMeta : fieldsMetadata) {
            if (fieldMeta.containsKey('outputFlag') && 
                (Boolean) fieldMeta.get('outputFlag') == true) {
              Map<String, Object> columnData = new Map<String, Object>();
              columnData.put('name', fieldMeta.get('name'));
              columnData.put('apiName', fieldMeta.get('apiName'));
              columnData.put('type', fieldMeta.get('fldType'));
              
              // Parse question reference if available
              if (fieldMeta.containsKey('questionReference')) {
                Map<String, Object> questionRef = 
                  (Map<String, Object>) JSON.deserializeUntyped(
                    (String) fieldMeta.get('questionReference')
                  );
                columnData.put('questionReference', questionRef);
              }
              
              tableColumns.add(columnData);
            }
          }
          
          tableInput.put('columns', tableColumns);
          
          // Prepare for dynamic query based on table configuration
          String filterQuery = question.SubTitle__c;
          System.debug('filterQuery' + filterQuery);
          String objectApiName = question.Title__c;
          
          // Replace recordId placeholder if needed
          //structure & recordId = null
          if (filterQuery != null && filterQuery.contains('{recordId}')) {
            System.debug('inside if ->>' + filterQuery);
            // filterQuery = filterQuery.replace('{recordId}', '\'' + 'a0CfK00000OKY1o' + '\'');
            System.debug('after replace ->' + filterQuery);
            Id salesId = 'a0CfK00000OKY1o';
            filterQuery = 'SELECT Name, Description__c, Qty__c, Unit_Price__c, Total_Price__c, Id FROM SO_Items__c WHERE Sales_Order__r.Id =: salesId   ORDER BY CreatedDate LIMIT 100';
            System.debug('after replace ->' + filterQuery);
          }
          
          try {
            List<SObject> tableRecords = Database.query(filterQuery);
            System.debug('tableRecords' + tableRecords);
            
            // Transform records to match table input structure
            List<Map<String, Object>> processedRecords = new List<Map<String, Object>>();
            for (SObject record : tableRecords) {
              Map<String, Object> processedRecord = new Map<String, Object>();
              processedRecord.put('recordId', record.Id);
              
              List<Map<String, Object>> cellInputs = new List<Map<String, Object>>();
              for (Map<String, Object> column : tableColumns) {
                Map<String, Object> cellInput = new Map<String, Object>();
                cellInput.put('fieldName', column.get('name'));
                cellInput.put('fieldApiName', column.get('apiName'));
                cellInput.put('fieldValue', record.get((String)column.get('apiName')));
                
                // Add question reference details if available
                if (column.containsKey('questionReference')) {
                  cellInput.put('questionReference', column.get('questionReference'));
                }
                
                cellInputs.add(cellInput);
              }
              
              processedRecord.put('value', cellInputs);
              processedRecords.add(processedRecord);
            }
            
            tableInput.put('records', processedRecords);
          } catch (Exception e) {
            tableInput.put('error', e.getMessage());
          }
          
          tableInputs.add(tableInput);
        }
      }
    }
    
    // Add table inputs to JSON response
    jsonGen.writeObjectField('tableInputs', tableInputs);

    QuestionBookWrapper wrapper = new QuestionBookWrapper(retQB);
    AnswerBookwrapper wraper = new AnswerBookwrapper(retAB);
    jsonGen.writeObjectField('questionbook', wrapper);
    jsonGen.writeObjectField('answerbook', wraper);

    // Process the Dropdown Options
    Map<Id, Object> sqOptMap = new Map<Id, Object>();
    if (retQB.Questions__r != null && retQB.Questions__r.size() > 0) {
      Set<Id> qoIds = new Set<Id>();
      for (Question__c qo : retQB.Questions__r) {
        if (qo.Type__c == 'Dropdown' || qo.Type__c == 'Radio') {
          qoIds.add(qo.Id);
        }
      }
      
      if (qoIds.size() > 0) {
        for (Question__c q : [
          SELECT
            Id,
            Name,
            (
              SELECT
                Id,
                Name,
                Value__c,
                Unique_Identifier__c,
                Question__c,
                Next_Question__c
              FROM Question_Options__r
              ORDER BY Order__c
            )
          FROM Question__c
          WHERE Id IN :qoIds
          WITH SECURITY_ENFORCED
        ]) {
          Map<String, Object> questionData = new Map<String, Object>();
          questionData.put('Id', q.Id);
          questionData.put('Name', q.Name);
          
          List<OptionWrapper> optionsList = new List<OptionWrapper>();
          if (q.Question_Options__r != null) {
            for (Option__c opt : q.Question_Options__r) {
              optionsList.add(new OptionWrapper(opt));
            }
          }
          
          questionData.put('QuestionOptions', optionsList);
          sqOptMap.put(q.Id, questionData);
        }
      }
    }
    
    jsonGen.writeObjectField('sqOptions', sqOptMap);
    jsonGen.writeEndObject();
    return jsonGen.getAsString();
  }
  
  public String createRecords(String inputJSON) {
    return '{"status":"failure","message":"Create operation is not supported"}';
  }
  
  public String updateRecords(String inputJSON) {
    return '{"status":"failure","message":"Update operation is not supported"}';
  }
  
  public String deleteRecords(String inputJSON) {
    return '{"status":"failure","message":"Delete operation is not supported"}';
  }
}