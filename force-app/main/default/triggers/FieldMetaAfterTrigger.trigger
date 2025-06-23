trigger FieldMetaAfterTrigger on Field_Meta__c(
  after insert,
  after update,
  after delete
) {
  // MR 23NOV23 handling field meta updates
  Set<Id> questionIds = new Set<Id>();

  if (Trigger.isInsert || Trigger.isUpdate) {
    for (Field_Meta__c fm : Trigger.new) {
      if (fm.Question__c != null) {
        questionIds.add(fm.Question__c);
      }
    }
  }

  if (Trigger.isDelete) {
    for (Field_Meta__c fm : Trigger.old) {
      if (fm.Question__c != null) {
        questionIds.add(fm.Question__c);
      }
    }
  }

  if (!questionIds.isEmpty()) {
    QuestionService.updateFieldMeta(questionIds);
  }
}