trigger Estimationnumber on Estimation__c (after insert) {
	GenericAutoNumberUtil.assignAutoNumbers('Estimation__c', Trigger.new);
}