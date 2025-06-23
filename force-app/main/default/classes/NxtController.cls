global with sharing class NxtController {
  global static String nxtAppVersion {
    get {
      return '2.50';
    }
    set;
  }
  //VD -27-dec-24 removed global method changes
  @remoteAction
  @AuraEnabled(cacheable=true)
  global static String process(
    String dataType,
    String operation,
    String param1


    
  ) {
    String responseJSON = '';
    String languageCode = '';

    String className = '';
    if (dataType == 'Booklet') {
      className = 'BookletHandler';
    } else if (dataType == 'Question') {
      className = 'QuestionHandler';
    } else if (dataType == 'QuestionBook') {
      className = 'QuestionBookHandler';
    } else if (dataType == 'Answer') {
      className = 'AnswerHandler';
    } else if (dataType == 'AnswerBook') {
      className = 'AnswerBookHandler';
    } else if (dataType == 'Attachment') {
      className = 'AttachmentHandler';
    } //getting answer count
    else if (dataType == 'answerCount') {
      AnswerHandler ah = new AnswerHandler();
      return ah.getAnswerCount(param1);
    }

    Type controller = Type.forName(className);
    DataHandler reader = (DataHandler) controller.newInstance();

    if (operation.equalsIgnoreCase('list')) {
      responseJSON = reader.getRecords();
    } else if (operation.equalsIgnoreCase('read')) {
      responseJSON = reader.readRecords(param1, languageCode);
    } else if (operation.equalsIgnoreCase('create')) {
      responseJSON = reader.createRecords(param1);
    } else if (operation.equalsIgnoreCase('update')) {
      responseJSON = reader.updateRecords(param1);
    } else if (operation.equalsIgnoreCase('delete')) {
      responseJSON = reader.deleteRecords(param1);
    }

    return responseJSON.replaceAll('RNXT__', '');
  }

  // MR - 22OCT23 - New Function with additional params
  //VD -27-dec-24 removed global method changes
  @RemoteAction
  @AuraEnabled(cacheable=true)
  global static String processNew(
    String dataType,
    String operation,
    String param1,
    String paramJSON
  ) {
    Map<String, Object> paramMap = (Map<String, Object>) JSON.deserializeUntyped(
      paramJSON
    );
    String responseJSON = '';
    String languageCode = '';

    String className = getClassName(dataType);

    Type controller = Type.forName(className);
    DataHandler reader = (DataHandler) controller.newInstance();

    // Set the Context Variables
    if (paramMap.size() > 0) {
      for (String key : paramMap.keySet()) {
        reader.setContext(key, paramMap.get(key));
      }
    }

    if (operation.equalsIgnoreCase('list')) {
      responseJSON = reader.getRecords();
    } else if (operation.equalsIgnoreCase('read')) {
      responseJSON = reader.readRecords(param1, languageCode);
    } else if (operation.equalsIgnoreCase('create')) {
      responseJSON = reader.createRecords(param1);
    } else if (operation.equalsIgnoreCase('update')) {
      responseJSON = reader.updateRecords(param1);
    } else if (operation.equalsIgnoreCase('delete')) {
      responseJSON = reader.deleteRecords(param1);
    }

    return responseJSON.replaceAll('RNXT__', '');
  }
  // VD 01FEB24 - new method without (cacheable=true)
  //VD -27-dec-24 removed global method changes
  @RemoteAction
  @AuraEnabled
  global static String newProcess(
    String dataType,
    String operation,
    String param1,
    String paramJSON
  ) {
    Map<String, Object> paramMap = (Map<String, Object>) JSON.deserializeUntyped(
      paramJSON
    );
    String responseJSON = '';
    String languageCode = '';

    String className = getClassName(dataType);

    Type controller = Type.forName(className);
    DataHandler reader = (DataHandler) controller.newInstance();

    if (paramMap.size() > 0) {
      for (String key : paramMap.keySet()) {
        reader.setContext(key, paramMap.get(key));
      }
    }

    if (operation.equalsIgnoreCase('list')) {
      responseJSON = reader.getRecords();
    } else if (operation.equalsIgnoreCase('read')) {
      responseJSON = reader.readRecords(param1, languageCode);
    } else if (operation.equalsIgnoreCase('create')) {
      responseJSON = reader.createRecords(param1);
    } else if (operation.equalsIgnoreCase('update')) {
      responseJSON = reader.updateRecords(param1);
    } else if (operation.equalsIgnoreCase('delete')) {
      responseJSON = reader.deleteRecords(param1);
    }

    return responseJSON.replaceAll('RNXT__', '');
  }
  // VD -27-dec-24 used new method with param as json
  @RemoteAction
  @AuraEnabled
  global static String processData(String requestJSON) {
    Map<String, Object> requestMap = (Map<String, Object>) JSON.deserializeUntyped(
      requestJSON
    );
    Object dataTypeObj = requestMap.get('dataType');
    String dataType = (dataTypeObj != null) ? (String) dataTypeObj : null;

    Object operationObj = requestMap.get('operation');
    String operation = (operationObj != null) ? (String) operationObj : null;

    Object param1Obj = requestMap.get('param1');
    String param1 = (param1Obj != null) ? (String) param1Obj : null;

    String paramJSONStr = (String) requestMap.get('paramJSON');
    Map<String, Object> paramJSON = (Map<String, Object>) JSON.deserializeUntyped(
      paramJSONStr
    );

    Object languageCodeObj = requestMap.get('languageCode');
    String languageCode = (languageCodeObj != null)
      ? (String) languageCodeObj
      : null;
    String responseJSON = '';

    String className = getClassName(dataType);
    Type controller = Type.forName(className);

    DataHandler reader = (DataHandler) controller.newInstance();

    if (paramJSON.size() > 0) {
      for (String key : paramJSON.keySet()) {
        reader.setContext(key, paramJSON.get(key));
      }
    }

    if (operation.equalsIgnoreCase('list')) {
      responseJSON = reader.getRecords();
    } else if (operation.equalsIgnoreCase('read')) {
      responseJSON = reader.readRecords(param1, languageCode);
    } else if (operation.equalsIgnoreCase('create')) {
      responseJSON = reader.createRecords(param1);
    } else if (operation.equalsIgnoreCase('update')) {
      responseJSON = reader.updateRecords(param1);
    } else if (operation.equalsIgnoreCase('delete')) {
      responseJSON = reader.deleteRecords(param1);
    }

    return responseJSON.replaceAll('RNXT__', '');
  }

  public static String getClassName(String dataType) {
    String className = '';
    if (dataType == 'Booklet') {
      className = 'BookletHandler';
    } else if (dataType == 'Question') {
      className = 'QuestionHandler';
    } else if (dataType == 'QuestionBook') {
      className = 'QuestionBookHandler';
    } else if (dataType == 'Answer') {
      className = 'AnswerHandler';
    } else if (dataType == 'AnswerBook') {
      className = 'AnswerBookHandler';
    } else if (dataType == 'Attachment') {
      className = 'AttachmentHandler';
    }

    return className;
  }
}