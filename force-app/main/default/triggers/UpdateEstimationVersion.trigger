trigger UpdateEstimationVersion on ContentDocumentLink (after insert) {
    EstimationHelper.updateEstimationVersion(Trigger.new);
}
