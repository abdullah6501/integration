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
            SELECT Name, Price__c FROM Item__c LIMIT 6
        ]) {
            chartData.add(new ChartItem(item.Name, item.Price__c));
        }
        return chartData;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getComparisonChartData() {
        List<Map<String, Object>> result = new List<Map<String, Object>>();

        for (Item__c item : [
            SELECT Name, Price__c, Rate__c FROM Item__c LIMIT 4
        ]) {
            Map<String, Object> row = new Map<String, Object>();
            row.put('label', item.Name);
            row.put('goldPrice', item.Price__c != null ? item.Price__c : 0);
            row.put('silverPrice', item.Rate__c != null ? item.Rate__c : 0);
            result.add(row);
        }

        return result;
    }
}
