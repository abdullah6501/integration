public with sharing class PieChartController {
    public class ChartItem {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public Decimal value { get; set; }

        public ChartItem(String label, Decimal value) {
            this.label = label;
            this.value = value;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<ChartItem> getChartData() {
        List<ChartItem> chartData = new List<ChartItem>();
        for (Item__c item : [
            SELECT Name, Price__c FROM Item__c LIMIT 100
        ]) {
            chartData.add(new ChartItem(item.Name, item.Price__c));
        }
        return chartData;
    }
}
