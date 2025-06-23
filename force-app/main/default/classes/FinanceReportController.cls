public with sharing class FinanceReportController {
    public class FinanceWrapper {
        // public String id;
        // public String assetName;
        public String chartSubCategory;
        public String chartOfAccountName;
        // public String type;
        public Decimal amountInCurrentYearMinusTwo;
        public Decimal amountInCurrentYearMinusOne;
        public Decimal amountInCurrentYear;
    }

    @AuraEnabled
    public static String generateFinanceReport(String inpValue) {
        JSONGenerator jsonGen = JSON.createGenerator(true);
        jsonGen.writeStartObject();
        // Map<String,List<FinanceWrapper>> reportMap = new Map<String,List<FinanceWrapper>>();
        if(inpValue == 'Asset' || inpValue == ''){
            try {
                String dynamicQuery = '';
                dynamicQuery = ' Chart_of_Accounts__r.Name, Chart_of_Accounts__r.Parent_Account__r.Name, ' +
                               'Chart_of_Accounts__r.Parent_Account__r.Parent_Account__r.Name, ' +
                               'Chart_of_Accounts__r.Parent_Account__r.Parent_Account__r.Parent_Account__r.Name, ' +
                               'Chart_of_Accounts__r.Parent_Account__r.Parent_Account__r.Parent_Account__r.Parent_Account__r.Name, ' +
                               'Total_Amount__c, Date__c FROM Asset__c WITH SECURITY_ENFORCED';

                List<FinanceWrapper> currentAssetList = new List<FinanceWrapper>();
                List<FinanceWrapper> nonCurrentAssetList = new List<FinanceWrapper>();
                for (Asset__c ts : Database.query('SELECT Id,' + dynamicQuery)) {
                    FinanceWrapper iw = new FinanceWrapper();
                    
                    // Get the highest level parent account name
                    String topLevelCategory = null;
                    if (ts.Chart_of_Accounts__r.Parent_Account__r.Parent_Account__r.Parent_Account__r.Parent_Account__r.Name != null) {
                        topLevelCategory = ts.Chart_of_Accounts__r.Parent_Account__r.Parent_Account__r.Parent_Account__r.Parent_Account__r.Name;
                    } else if (ts.Chart_of_Accounts__r.Parent_Account__r.Parent_Account__r.Parent_Account__r.Name != null) {
                        topLevelCategory = ts.Chart_of_Accounts__r.Parent_Account__r.Parent_Account__r.Parent_Account__r.Name;
                    } else if (ts.Chart_of_Accounts__r.Parent_Account__r.Parent_Account__r.Name != null) {
                        topLevelCategory = ts.Chart_of_Accounts__r.Parent_Account__r.Parent_Account__r.Name;
                    } else if (ts.Chart_of_Accounts__r.Parent_Account__r.Name != null) {
                        topLevelCategory = ts.Chart_of_Accounts__r.Parent_Account__r.Name;
                    } else {
                        topLevelCategory = ts.Chart_of_Accounts__r.Name;
                    }
                    
                    iw.chartSubCategory = topLevelCategory;
                    iw.chartOfAccountName = ts.Chart_of_Accounts__r.Name;
                    
                    if(ts.Date__c >= date.newInstance(System.Today().year(), 1, 1)){
                        iw.amountInCurrentYear = ts.Total_Amount__c != null ? ts.Total_Amount__c : 0;
                    } else if(ts.Date__c >= date.newInstance((System.Today().year())-1, 1, 1)){
                        iw.amountInCurrentYearMinusOne = ts.Total_Amount__c != null ? ts.Total_Amount__c : 0;
                    } else if(ts.Date__c >= date.newInstance((System.Today().year()-2), 1, 1)){
                        iw.amountInCurrentYearMinusTwo = ts.Total_Amount__c != null ? ts.Total_Amount__c : 0;
                    }
                    
                    if(topLevelCategory == 'Current Asset' ||
                        topLevelCategory == 'Accounts Receivable' || 
                       topLevelCategory == 'Bank' || 
                       topLevelCategory == 'Cash' || 
                       topLevelCategory == 'Inventory'){
                        currentAssetList.add(iw);
                    } else {
                        nonCurrentAssetList.add(iw);
                    }
                }
                // reportMap.put('currentAsset',currentAssetList);
                // reportMap.put('nonCurrentAsset',nonCurrentAssetList);
                jsonGen.writeObjectField('currentAssets', currentAssetList);
                jsonGen.writeObjectField('nonCurrentAssets', nonCurrentAssetList);
                dynamicQuery = ' Chart_of_Accounts__r.Name, Chart_of_Accounts__r.Parent_Account__r.Name, ' +
                               'Chart_of_Accounts__r.Parent_Account__r.Parent_Account__r.Name, ' +
                               'Chart_of_Accounts__r.Parent_Account__r.Parent_Account__r.Parent_Account__r.Name, ' +
                               'Chart_of_Accounts__r.Parent_Account__r.Parent_Account__r.Parent_Account__r.Parent_Account__r.Name, ' +
                               'Total_Amount__c, Date__c FROM Equity__c WITH SECURITY_ENFORCED';

                List<FinanceWrapper> currentEquityList = new List<FinanceWrapper>();
                List<FinanceWrapper> nonCurrentEquityList = new List<FinanceWrapper>();
                for (Equity__c ts : Database.query('SELECT Id,' + dynamicQuery)) {
                    FinanceWrapper iw = new FinanceWrapper();
                    
                    // Get the highest level parent account name
                    String topLevelCategory = null;
                    if (ts.Chart_of_Accounts__r.Parent_Account__r.Parent_Account__r.Parent_Account__r.Parent_Account__r.Name != null) {
                        topLevelCategory = ts.Chart_of_Accounts__r.Parent_Account__r.Parent_Account__r.Parent_Account__r.Parent_Account__r.Name;
                    } else if (ts.Chart_of_Accounts__r.Parent_Account__r.Parent_Account__r.Parent_Account__r.Name != null) {
                        topLevelCategory = ts.Chart_of_Accounts__r.Parent_Account__r.Parent_Account__r.Parent_Account__r.Name;
                    } else if (ts.Chart_of_Accounts__r.Parent_Account__r.Parent_Account__r.Name != null) {
                        topLevelCategory = ts.Chart_of_Accounts__r.Parent_Account__r.Parent_Account__r.Name;
                    } else if (ts.Chart_of_Accounts__r.Parent_Account__r.Name != null) {
                        topLevelCategory = ts.Chart_of_Accounts__r.Parent_Account__r.Name;
                    } else {
                        topLevelCategory = ts.Chart_of_Accounts__r.Name;
                    }
                    
                    iw.chartSubCategory = topLevelCategory;
                    iw.chartOfAccountName = ts.Chart_of_Accounts__r.Name;
                    
                    if(ts.Date__c >= date.newInstance(System.Today().year(), 1, 1)){
                        iw.amountInCurrentYear = ts.Total_Amount__c != null ? ts.Total_Amount__c : 0;
                    } else if(ts.Date__c >= date.newInstance((System.Today().year())-1, 1, 1)){
                        iw.amountInCurrentYearMinusOne = ts.Total_Amount__c != null ? ts.Total_Amount__c : 0;
                    } else if(ts.Date__c >= date.newInstance((System.Today().year())-2, 1, 1)){
                        iw.amountInCurrentYearMinusTwo = ts.Total_Amount__c != null ? ts.Total_Amount__c : 0;
                    }
                    
                    if(topLevelCategory == 'Owners Equity'){
                        currentEquityList.add(iw);
                    } else {
                        nonCurrentEquityList.add(iw);
                    }
                }
                // reportMap.put('currentEquity',currentEquityList);
                // reportMap.put('nonCurrentEquity',nonCurrentEquityList);
                jsonGen.writeObjectField('currentEquity', currentEquityList);
                jsonGen.writeObjectField('nonCurrentEquity', nonCurrentEquityList);
                dynamicQuery = ' Chart_of_Accounts__r.Name, Chart_of_Accounts__r.Parent_Account__r.Name, ' +
                               'Chart_of_Accounts__r.Parent_Account__r.Parent_Account__r.Name, ' +
                               'Chart_of_Accounts__r.Parent_Account__r.Parent_Account__r.Parent_Account__r.Name, ' +
                               'Chart_of_Accounts__r.Parent_Account__r.Parent_Account__r.Parent_Account__r.Parent_Account__r.Name, ' +
                               'Total_Amount__c, Date__c FROM Liability__c WITH SECURITY_ENFORCED';

                List<FinanceWrapper> currentliabilityList = new List<FinanceWrapper>();
                List<FinanceWrapper> nonCurrentliabilityList = new List<FinanceWrapper>();
                for (Liability__c ts : Database.query('SELECT Id,' + dynamicQuery)) {
                    FinanceWrapper iw = new FinanceWrapper();
                    
                    // Get the highest level parent account name
                    String topLevelCategory = null;
                    if (ts.Chart_of_Accounts__r.Parent_Account__r.Parent_Account__r.Parent_Account__r.Parent_Account__r.Name != null) {
                        topLevelCategory = ts.Chart_of_Accounts__r.Parent_Account__r.Parent_Account__r.Parent_Account__r.Parent_Account__r.Name;
                    } else if (ts.Chart_of_Accounts__r.Parent_Account__r.Parent_Account__r.Parent_Account__r.Name != null) {
                        topLevelCategory = ts.Chart_of_Accounts__r.Parent_Account__r.Parent_Account__r.Parent_Account__r.Name;
                    } else if (ts.Chart_of_Accounts__r.Parent_Account__r.Parent_Account__r.Name != null) {
                        topLevelCategory = ts.Chart_of_Accounts__r.Parent_Account__r.Parent_Account__r.Name;
                    } else if (ts.Chart_of_Accounts__r.Parent_Account__r.Name != null) {
                        topLevelCategory = ts.Chart_of_Accounts__r.Parent_Account__r.Name;
                    } else {
                        topLevelCategory = ts.Chart_of_Accounts__r.Name;
                    }
                    
                    iw.chartSubCategory = topLevelCategory;
                    iw.chartOfAccountName = ts.Chart_of_Accounts__r.Name;
                    
                    if(ts.Date__c >= date.newInstance(System.Today().year(), 1, 1)){
                        iw.amountInCurrentYear = ts.Total_Amount__c != null ? ts.Total_Amount__c : 0;
                    } else if(ts.Date__c >= date.newInstance((System.Today().year())-1, 1, 1)){
                        iw.amountInCurrentYearMinusOne = ts.Total_Amount__c != null ? ts.Total_Amount__c : 0;
                    } else if(ts.Date__c >= date.newInstance((System.Today().year())-2, 1, 1)){
                        iw.amountInCurrentYearMinusTwo = ts.Total_Amount__c != null ? ts.Total_Amount__c : 0;
                    }
                    
                    if(topLevelCategory == 'Current Liabilities' || 
                       topLevelCategory == 'Accounts Payable' ){
                        currentliabilityList.add(iw);
                    } else {
                        nonCurrentliabilityList.add(iw);
                    }
                }
                jsonGen.writeObjectField('currentLiability', currentliabilityList);
                jsonGen.writeObjectField('nonCurrentLiability', nonCurrentliabilityList);
                // reportMap.put('currentLiability',currentliabilityList);
                // reportMap.put('nonCurrentLiability',nonCurrentliabilityList);
                // jsonGen.writeObjectField('financeReportMap', reportMap));
            } catch (Exception ae) {
                jsonGen.writeObjectField('status', 'failure');
                jsonGen.writeObjectField('lineno', ae.getLineNumber());
                jsonGen.writeObjectField('message', ae.getMessage());
                jsonGen.writeObjectField('strack', ae.getStackTraceString());
            }
        } else if(inpValue == 'Revenue'){
            try {
                String dynamicQuery = '';
                dynamicQuery = ' Chart_of_Accounts__r.Name, Chart_of_Accounts__r.SubCategory__c, Total_Amount__c, Date__c  FROM Asset__c WITH SECURITY_ENFORCED';
                
                List<FinanceWrapper> currentAssetList = new List<FinanceWrapper>();
                List<FinanceWrapper> nonCurrentAssetList = new List<FinanceWrapper>();
                for (Asset__c ts : Database.query('SELECT Id,' +dynamicQuery)) {
                    FinanceWrapper iw = new FinanceWrapper();
                    iw.chartSubCategory = ts.Chart_of_Accounts__r.SubCategory__c;
                    iw.chartOfAccountName = ts.Chart_of_Accounts__r.Name;
                    if(ts.Date__c >= date.newInstance(System.Today().year(), 1, 1)){
                        iw.amountInCurrentYear = ts.Total_Amount__c != null ? ts.Total_Amount__c : 0;
                    } else if(ts.Date__c >= date.newInstance((System.Today().year())-1, 1, 1)){
                        iw.amountInCurrentYearMinusOne = ts.Total_Amount__c != null ? ts.Total_Amount__c : 0;
                    } else if(ts.Date__c >= date.newInstance((System.Today().year()-2), 1, 1)){
                        iw.amountInCurrentYearMinusTwo = ts.Total_Amount__c != null ? ts.Total_Amount__c : 0;
                    }
                    if(iw.chartSubCategory == 'Accounts Receivable' || iw.chartSubCategory == 'Bank' || iw.chartSubCategory == 'Cash' || iw.chartSubCategory == 'Other Current Asset'){
                        currentAssetList.add(iw);
                    } else {
                        nonCurrentAssetList.add(iw);
                    }
                }
                // reportMap.put('currentAsset',currentAssetList);
                // reportMap.put('nonCurrentAsset',nonCurrentAssetList);
                jsonGen.writeObjectField('currentAssets', currentAssetList);
                jsonGen.writeObjectField('nonCurrentAssets', nonCurrentAssetList);
                dynamicQuery = ' Chart_of_Accounts__r.Name, Chart_of_Accounts__r.SubCategory__c, Total_Amount__c, Date__c FROM Equity__c WITH SECURITY_ENFORCED';
                List<FinanceWrapper> currentEquityList = new List<FinanceWrapper>();
                List<FinanceWrapper> nonCurrentEquityList = new List<FinanceWrapper>();
                for (Equity__c ts : Database.query('SELECT Id,' +dynamicQuery)) {
                    FinanceWrapper iw = new FinanceWrapper();
                    iw.chartSubCategory = ts.Chart_of_Accounts__r.SubCategory__c;
                    iw.chartOfAccountName = ts.Chart_of_Accounts__r.Name;
                    
                    if(ts.Date__c >= date.newInstance(System.Today().year(), 1, 1)){
                        iw.amountInCurrentYear = ts.Total_Amount__c != null ? ts.Total_Amount__c : 0;
                    } else if(ts.Date__c >= date.newInstance((System.Today().year())-1, 1, 1)){
                        iw.amountInCurrentYearMinusOne = ts.Total_Amount__c != null ? ts.Total_Amount__c : 0;
                    } else if(ts.Date__c >= date.newInstance((System.Today().year())-2, 1, 1)){
                        iw.amountInCurrentYearMinusTwo = ts.Total_Amount__c != null ? ts.Total_Amount__c : 0;
                    }
                    if(iw.chartSubCategory == 'Accounts Receivable' || iw.chartSubCategory == 'Bank' || iw.chartSubCategory == 'Cash' || iw.chartSubCategory == 'Other Current Asset'){
                        currentEquityList.add(iw);
                    } else {
                        nonCurrentEquityList.add(iw);
                    }
                }
                // reportMap.put('currentEquity',currentEquityList);
                // reportMap.put('nonCurrentEquity',nonCurrentEquityList);
                jsonGen.writeObjectField('currentEquity', currentEquityList);
                jsonGen.writeObjectField('nonCurrentEquity', nonCurrentEquityList);
                dynamicQuery = ' Chart_of_Accounts__r.Name, Chart_of_Accounts__r.SubCategory__c, Total_Amount__c, Date__c FROM Liability__c WITH SECURITY_ENFORCED';
                List<FinanceWrapper> currentliabilityList = new List<FinanceWrapper>();
                List<FinanceWrapper> nonCurrentliabilityList = new List<FinanceWrapper>();
                for (Liability__c ts : Database.query('SELECT Id,' +dynamicQuery)) {
                    FinanceWrapper iw = new FinanceWrapper();
                    iw.chartSubCategory = ts.Chart_of_Accounts__r.SubCategory__c;
                    iw.chartOfAccountName = ts.Chart_of_Accounts__r.Name;
                    
                    if(ts.Date__c >= date.newInstance(System.Today().year(), 1, 1)){
                        iw.amountInCurrentYear = ts.Total_Amount__c != null ? ts.Total_Amount__c : 0;
                    } else if(ts.Date__c >= date.newInstance((System.Today().year())-1, 1, 1)){
                        iw.amountInCurrentYearMinusOne = ts.Total_Amount__c != null ? ts.Total_Amount__c : 0;
                    } else if(ts.Date__c >= date.newInstance((System.Today().year())-2, 1, 1)){
                        iw.amountInCurrentYearMinusTwo = ts.Total_Amount__c != null ? ts.Total_Amount__c : 0;
                    }
                    if(iw.chartSubCategory == 'Accounts Receivable' || iw.chartSubCategory == 'Bank' || iw.chartSubCategory == 'Cash' || iw.chartSubCategory == 'Other Current Asset'){
                        currentliabilityList.add(iw);
                    } else {
                        nonCurrentliabilityList.add(iw);
                    }
                }
                jsonGen.writeObjectField('currentLiability', currentliabilityList);
                jsonGen.writeObjectField('nonCurrentLiability', nonCurrentliabilityList);
                // reportMap.put('currentLiability',currentliabilityList);
                // reportMap.put('nonCurrentLiability',nonCurrentliabilityList);
                // jsonGen.writeObjectField('financeReportMap', reportMap));
            } catch (Exception ae) {
                jsonGen.writeObjectField('status', 'failure');
                jsonGen.writeObjectField('lineno', ae.getLineNumber());
                jsonGen.writeObjectField('message', ae.getMessage());
                jsonGen.writeObjectField('strack', ae.getStackTraceString());
            }
        } else if(inpValue == 'CashFlows'){
            try {
                String dynamicQuery = '';
                dynamicQuery = ' Chart_of_Accounts__r.Name, Chart_of_Accounts__r.SubCategory__c, Total_Amount__c, Date__c  FROM Asset__c WITH SECURITY_ENFORCED';
                
                List<FinanceWrapper> currentAssetList = new List<FinanceWrapper>();
                List<FinanceWrapper> nonCurrentAssetList = new List<FinanceWrapper>();
                for (Asset__c ts : Database.query('SELECT Id,' +dynamicQuery)) {
                    FinanceWrapper iw = new FinanceWrapper();
                    iw.chartSubCategory = ts.Chart_of_Accounts__r.SubCategory__c;
                    iw.chartOfAccountName = ts.Chart_of_Accounts__r.Name;
                    if(ts.Date__c >= date.newInstance(System.Today().year(), 1, 1)){
                        iw.amountInCurrentYear = ts.Total_Amount__c != null ? ts.Total_Amount__c : 0;
                    } else if(ts.Date__c >= date.newInstance((System.Today().year())-1, 1, 1)){
                        iw.amountInCurrentYearMinusOne = ts.Total_Amount__c != null ? ts.Total_Amount__c : 0;
                    } else if(ts.Date__c >= date.newInstance((System.Today().year()-2), 1, 1)){
                        iw.amountInCurrentYearMinusTwo = ts.Total_Amount__c != null ? ts.Total_Amount__c : 0;
                    }
                    if(iw.chartSubCategory == 'Accounts Receivable' || iw.chartSubCategory == 'Bank' || iw.chartSubCategory == 'Cash' || iw.chartSubCategory == 'Other Current Asset'){
                        currentAssetList.add(iw);
                    } else {
                        nonCurrentAssetList.add(iw);
                    }
                }
                // reportMap.put('currentAsset',currentAssetList);
                // reportMap.put('nonCurrentAsset',nonCurrentAssetList);
                jsonGen.writeObjectField('currentAssets', currentAssetList);
                jsonGen.writeObjectField('nonCurrentAssets', nonCurrentAssetList);
                dynamicQuery = ' Chart_of_Accounts__r.Name, Chart_of_Accounts__r.SubCategory__c, Total_Amount__c, Date__c FROM Liability__c WITH SECURITY_ENFORCED';
                List<FinanceWrapper> currentliabilityList = new List<FinanceWrapper>();
                List<FinanceWrapper> nonCurrentliabilityList = new List<FinanceWrapper>();
                for (Liability__c ts : Database.query('SELECT Id,' +dynamicQuery)) {
                    FinanceWrapper iw = new FinanceWrapper();
                    iw.chartSubCategory = ts.Chart_of_Accounts__r.SubCategory__c;
                    iw.chartOfAccountName = ts.Chart_of_Accounts__r.Name;
                    
                    if(ts.Date__c >= date.newInstance(System.Today().year(), 1, 1)){
                        iw.amountInCurrentYear = ts.Total_Amount__c != null ? ts.Total_Amount__c : 0;
                    } else if(ts.Date__c >= date.newInstance((System.Today().year())-1, 1, 1)){
                        iw.amountInCurrentYearMinusOne = ts.Total_Amount__c != null ? ts.Total_Amount__c : 0;
                    } else if(ts.Date__c >= date.newInstance((System.Today().year())-2, 1, 1)){
                        iw.amountInCurrentYearMinusTwo = ts.Total_Amount__c != null ? ts.Total_Amount__c : 0;
                    }
                    if(iw.chartSubCategory == 'Accounts Receivable' || iw.chartSubCategory == 'Bank' || iw.chartSubCategory == 'Cash' || iw.chartSubCategory == 'Other Current Asset'){
                        currentliabilityList.add(iw);
                    } else {
                        nonCurrentliabilityList.add(iw);
                    }
                }
                jsonGen.writeObjectField('currentLiability', currentliabilityList);
                jsonGen.writeObjectField('nonCurrentLiability', nonCurrentliabilityList);
                // reportMap.put('currentLiability',currentliabilityList);
                // reportMap.put('nonCurrentLiability',nonCurrentliabilityList);
                // jsonGen.writeObjectField('financeReportMap', reportMap));
            } catch (Exception ae) {
                jsonGen.writeObjectField('status', 'failure');
                jsonGen.writeObjectField('lineno', ae.getLineNumber());
                jsonGen.writeObjectField('message', ae.getMessage());
                jsonGen.writeObjectField('strack', ae.getStackTraceString());
            }
        }
        
        jsonGen.writeEndObject();
        return jsonGen.getAsString();
        // return reportMap;
    }
}