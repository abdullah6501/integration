trigger StyleAfterTrigger on Style__c (
    after insert,
    after update,
    after delete
  ) {
    // MR 23NOV23 handling field meta updates
    Set<Id> questionIds = new Set<Id>();
  
    if (Trigger.isInsert || Trigger.isUpdate) {
      for (Style__c fm : Trigger.new) {
        if (fm.Question__c != null) {
          questionIds.add(fm.Question__c);
        }
      }
    }
  
    if (Trigger.isDelete) {
      for (Style__c fm : Trigger.old) {
        if (fm.Question__c != null) {
          questionIds.add(fm.Question__c);
        }
      }
    }
  
    if (!questionIds.isEmpty()) {
      QuestionService.updateStyle(questionIds);
    }
  }