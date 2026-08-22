trigger automateNumberEstimation on Estimation__c (after insert) {
    RFAB.GenericAutoNumberUtil.assignAutoNumbers('Estimation__c', Trigger.new);
}