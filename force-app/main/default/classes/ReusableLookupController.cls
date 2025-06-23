public with sharing class ReusableLookupController {
    @AuraEnabled
public static List<ResultWrapper> fetchRecords(String inputJSON){
    SearchWrapper inpWrapper = (SearchWrapper) JSON.deserialize( inputJSON, SearchWrapper.class);
    try {
        String fieldsToQuery = '';
       
        if (string.isNotBlank(inpWrapper.fieldApiName)) {
            fieldsToQuery += ', ' + inpWrapper.fieldApiName;
        }
       
        if (string.isNotBlank(inpWrapper.otherFieldApiName)) {
            fieldsToQuery += ', ' + inpWrapper.otherFieldApiName;
        }
       
        if (string.isNotBlank(inpWrapper.additionalFieldApiName)) {
            fieldsToQuery += ', ' + inpWrapper.additionalFieldApiName;
        }
        String query ='';
        query = String.escapeSingleQuotes(fieldsToQuery) + ' FROM ' + String.escapeSingleQuotes(inpWrapper.objectApiName);
        if (String.isNotBlank(inpWrapper.selectedRecordId)) {
            query += ' WHERE Id = \'' + String.escapeSingleQuotes(inpWrapper.selectedRecordId) + '\'';
        } else if (String.isNotBlank(inpWrapper.parentFieldApiName) && String.isNotBlank(inpWrapper.parentRecordId)) {
            query += ' WHERE ' + String.escapeSingleQuotes(inpWrapper.parentFieldApiName) + ' = \'' + String.escapeSingleQuotes(inpWrapper.parentRecordId) + '\'';
            query += ' AND ' + String.escapeSingleQuotes(inpWrapper.fieldApiName) + ' LIKE \'' + String.escapeSingleQuotes(inpWrapper.searchString.trim()) + '%\' ';
        } else {
            query += ' WHERE ' + String.escapeSingleQuotes(inpWrapper.fieldApiName) + ' LIKE \'' + String.escapeSingleQuotes(inpWrapper.searchString.trim()) + '%\' ';
        }
        query += ' WITH SECURITY_ENFORCED LIMIT 10';
            List<ResultWrapper> returnWrapperList = new List<ResultWrapper>();
            for(SObject s : Database.query('SELECT Id'+query)) {
                ResultWrapper wrap = new ResultWrapper();
                wrap.mainField = (String)s.get(inpWrapper.fieldApiName);
                wrap.subField = (String)s.get(inpWrapper.otherFieldApiName);
                wrap.additionalField = (String)s.get(inpWrapper.additionalFieldApiName);
                wrap.id = (String)s.get('id');
                returnWrapperList.add(wrap);
            }
            return returnWrapperList;
        //}
        //return null;
    } catch (Exception err) {
        throw new AuraHandledException(err.getMessage());
    }
}
 
    public class ResultWrapper{
        @AuraEnabled public String mainField{get;set;}
        @AuraEnabled public String subField{get;set;}
        @AuraEnabled public String additionalField{get;set;}
        @AuraEnabled public String id{get;set;}
    }
 
    public class SearchWrapper {
        @AuraEnabled public String objectApiName{get;set;}
        @AuraEnabled public String fieldApiName{get;set;}
        @AuraEnabled public String otherFieldApiName{get;set;}
        @AuraEnabled public String additionalFieldApiName{get;set;}
        @AuraEnabled public String searchString{get;set;}
        @AuraEnabled public String selectedRecordId{get;set;}
        @AuraEnabled public String parentRecordId{get;set;}
        @AuraEnabled public String parentFieldApiName{get;set;}
    }
}