public with sharing class TrailBalance {
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getChartOfAccount(Date fromDate, Date toDate) {

        // Step 0: Query Ledger Records
        List<General_Ledger__c> ledger = [
            SELECT Id, Name, Chart_of_Accounts__c, Entry_Date__c, Amount__c, Last_Transaction_Type__c
            FROM General_Ledger__c
            WHERE Entry_Date__c >= :fromDate AND Entry_Date__c <= :toDate
            WITH SECURITY_ENFORCED
        ];

        // Step 1: Prepare Debit/Credit Maps
        Map<Id, Decimal> coaDebitMap = new Map<Id, Decimal>();
        Map<Id, Decimal> coaCreditMap = new Map<Id, Decimal>();
        Set<Id> coaIdsFromLedger = new Set<Id>();

        for (General_Ledger__c gl : ledger) {
            if (gl.Chart_of_Accounts__c == null) continue;

            coaIdsFromLedger.add(gl.Chart_of_Accounts__c);

            if (gl.Last_Transaction_Type__c == 'Debit') {
                Decimal existingDebit = coaDebitMap.containsKey(gl.Chart_of_Accounts__c) ? coaDebitMap.get(gl.Chart_of_Accounts__c) : 0;
                coaDebitMap.put(gl.Chart_of_Accounts__c, existingDebit + (gl.Amount__c != null ? gl.Amount__c : 0));

            } else if (gl.Last_Transaction_Type__c == 'Credit') {
               Decimal existingCredit = coaCreditMap.containsKey(gl.Chart_of_Accounts__c) ? coaCreditMap.get(gl.Chart_of_Accounts__c) : 0;
                coaCreditMap.put(gl.Chart_of_Accounts__c, existingCredit + (gl.Amount__c != null ? gl.Amount__c : 0));

            }
        }
        //KK 11/Jun/25  If no ledger records found, return empty list
        // Step 1: Get all COAs from involved COA in Ledger 
        List<Chart_of_Accounts__c> coas = [
            SELECT Id, Name, Parent_Account__c, Parent_Account__r.Name, RecordType.Name
            FROM Chart_of_Accounts__c
            WHERE Id IN :coaIdsFromLedger WITH SECURITY_ENFORCED
        ];
        //Declare set String to store ledger involved COA RecordType names
        Set<String> coaRecordTypes = new Set<String>();
        for (Chart_of_Accounts__c coa : coas) {
            coaRecordTypes.add(coa.RecordType.Name);
        }
        Set<Id> allParentIds = new Set<Id>();
        //Get all parent COA Ids from the COAs that are not GL COA RecordTypes
        for (Chart_of_Accounts__c coa : [
            SELECT Id, Parent_Account__c, RecordType.Name
            FROM Chart_of_Accounts__c
            WHERE Parent_Account__c != null AND RecordType.Name NOT IN :coaRecordTypes WITH SECURITY_ENFORCED
        ]) {
            allParentIds.add(coa.Parent_Account__c);
        }

        // Step 2: Get all COAs whose Id is NOT used as a parent (i.e., leaf nodes)
        List<Chart_of_Accounts__c> leafCoas = [
            SELECT Id, Name, Parent_Account__c, RecordType.Name
            FROM Chart_of_Accounts__c
            WHERE Id NOT IN :allParentIds WITH SECURITY_ENFORCED
        ];
        Set<Id> emptyIds = new Set<Id>();
        for (Chart_of_Accounts__c coa : leafCoas) {
            emptyIds.add(coa.Id);
        }

        // Combine GL COA Ids and empty COA Ids
        Set<Id> allCoaIdsToUse = new Set<Id>();
        allCoaIdsToUse.addAll(coaIdsFromLedger);  // From GL
        allCoaIdsToUse.addAll(emptyIds);          // From non-GL but valid leaf COAs

        // Step 2: Build Full COA Hierarchy Recursively
        Map<Id, Chart_of_Accounts__c> fullCoaMap = buildFullCoaHierarchy(allCoaIdsToUse);

        // Step 3: Aggregate Balances Bottom-Up
        Map<Id, Map<String, Object>> resultMap = new Map<Id, Map<String, Object>>();

        for (Id coaId : allCoaIdsToUse) {
            aggregateToTop(coaId, coaDebitMap, coaCreditMap, fullCoaMap, resultMap);
        }


        // Step 4: Separate by RecordType
        List<Map<String, Object>> assetsList = new List<Map<String, Object>>();
        List<Map<String, Object>> liabilitiesList = new List<Map<String, Object>>();
        List<Map<String, Object>> revenueList = new List<Map<String, Object>>();
        List<Map<String, Object>> expensesList = new List<Map<String, Object>>();
        List<Map<String, Object>> equityList = new List<Map<String, Object>>();

        for (Map<String, Object> record : resultMap.values()) {
            String recordType = (String)record.get('recordType');
            if (recordType == 'Assets') {
                assetsList.add(record);
            } else if (recordType == 'Liabilities') {
                liabilitiesList.add(record);
            } else if (recordType == 'Revenue') {
                revenueList.add(record);
            }
            else if (recordType == 'Expenses') {
                expensesList.add(record);
            }
            else if (recordType == 'Equity') {
                equityList.add(record);
            }
        }

        // Step 5: Combine and Return
        List<Map<String, Object>> finalResult = new List<Map<String, Object>>();
        finalResult.addAll(assetsList);
        finalResult.addAll(liabilitiesList);
        finalResult.addAll(revenueList);
        finalResult.addAll(expensesList);
        finalResult.addAll(equityList);

        return finalResult;
    }

    // Recursively builds full COA hierarchy from a given set of IDs
    private static Map<Id, Chart_of_Accounts__c> buildFullCoaHierarchy(Set<Id> initialCoaIds) {
        Map<Id, Chart_of_Accounts__c> fullMap = new Map<Id, Chart_of_Accounts__c>();
        Set<Id> idsToQuery = new Set<Id>(initialCoaIds);

        while (!idsToQuery.isEmpty()) {
            List<Chart_of_Accounts__c> coaList = [
                SELECT Id, Name, Parent_Account__c, Parent_Account__r.Name, RecordType.Name
                FROM Chart_of_Accounts__c
                WHERE Id IN :idsToQuery WITH SECURITY_ENFORCED
            ];

            idsToQuery.clear();

            for (Chart_of_Accounts__c coa : coaList) {
                if (!fullMap.containsKey(coa.Id)) {
                    fullMap.put(coa.Id, coa);

                    if (coa.Parent_Account__c != null && !fullMap.containsKey(coa.Parent_Account__c)) {
                        idsToQuery.add(coa.Parent_Account__c);
                    }
                }
            }
        }

        return fullMap;
    }

    // Aggregates values up the hierarchy chain for a COA
    private static void aggregateToTop(
        Id coaId,
        Map<Id, Decimal> debitMap,
        Map<Id, Decimal> creditMap,
        Map<Id, Chart_of_Accounts__c> fullCoaMap,
        Map<Id, Map<String, Object>> resultMap
    ) {
        while (coaId != null && fullCoaMap.containsKey(coaId)) {
            Chart_of_Accounts__c coa = fullCoaMap.get(coaId);
            Decimal debitAmount = debitMap.get(coaId) != null ? debitMap.get(coaId) : 0;
            Decimal creditAmount = creditMap.get(coaId) != null ? creditMap.get(coaId) : 0;
    
            Decimal finalAmount = 0;
            String finalType = '';

            if (debitAmount > creditAmount) {
                finalAmount = debitAmount - creditAmount;
                debitAmount = finalAmount;
                creditAmount = 0;
            } else if (creditAmount > debitAmount) {
                finalAmount = creditAmount - debitAmount;
                debitAmount = 0;
                creditAmount = finalAmount;
            } else {
                debitAmount = 0;
                creditAmount = 0;
            }

            if (!resultMap.containsKey(coa.Id)) {
                resultMap.put(coa.Id, new Map<String, Object>{
                    'id' => coa.Id,
                    'name' => coa.Name,
                    'recordType' => coa.RecordType != null ? coa.RecordType.Name : '',
                    'debit' => debitAmount,
                    'credit' => creditAmount,
                    'parentId' => coa.Parent_Account__c,
                    'parentName' => coa.Parent_Account__r != null ? coa.Parent_Account__r.Name : null
                });
            }

            // Map<String, Object> record = resultMap.get(coa.Id);
            // Decimal currentDebit = (Decimal)record.get('debit');
            // Decimal currentCredit = (Decimal)record.get('credit');

            // Decimal addDebit = debitMap.get(coaId) != null ? debitMap.get(coaId) : 0;
            // Decimal addCredit = creditMap.get(coaId) != null ? creditMap.get(coaId) : 0;

            // record.put('debit', currentDebit + addDebit);
            // record.put('credit', currentCredit + addCredit);

            // // After pushing to this level, zero out values for the child so that parent doesn't double-count
            // debitMap.put(coaId, 0);
            // creditMap.put(coaId, 0);

            coaId = coa.Parent_Account__c;
        }
    }
}