// Utility class for retrieving tax options and their hierarchy for LWC and Apex use.
public with sharing class TaxUtility {
    @AuraEnabled(cacheable=true)
    public static List<TaxWrapper> getParentTaxes() {
        List<RFAB__Tax__c> allTaxes = [
            SELECT Id, Name, RFAB__Tax_Percentage__c, RFAB__Country__c,
                   RFAB__Tax_Code__c, RFAB__Tax__c, RFAB__Is_RCM__c
            FROM RFAB__Tax__c
        ];

        Map<Id, TaxWrapper> taxMap = new Map<Id, TaxWrapper>();

        for (RFAB__Tax__c tax : allTaxes) {
            if (tax.RFAB__Tax__c == null) {
                TaxWrapper tw = new TaxWrapper();
                tw.parentTaxId = tax.Id;
                tw.parentTaxName = tax.Name;
                tw.parentTaxPercentage = tax.RFAB__Tax_Percentage__c;
                tw.parentTaxCode = tax.RFAB__Tax_Code__c;
                tw.parentCountry = tax.RFAB__Country__c;
                tw.isRCM = tax.RFAB__Is_RCM__c;
                tw.childTaxes = new List<ChildTax>();
                taxMap.put(tax.Id, tw);
            }
        }

        for (RFAB__Tax__c tax : allTaxes) {
            if (tax.RFAB__Tax__c != null && taxMap.containsKey(tax.RFAB__Tax__c)) {
                ChildTax ct = new ChildTax();
                ct.childTaxId = tax.Id;
                ct.childTaxName = tax.Name;
                ct.childTaxPercentage = tax.RFAB__Tax_Percentage__c;
                ct.childTaxCode = tax.RFAB__Tax_Code__c;
                ct.childCountry = tax.RFAB__Country__c;

                taxMap.get(tax.RFAB__Tax__c).childTaxes.add(ct);
            }
        }

        return taxMap.values();
    }

    public class TaxWrapper {
        @AuraEnabled public String parentTaxId;
        @AuraEnabled public String parentTaxName;
        @AuraEnabled public Decimal parentTaxPercentage;
        @AuraEnabled public String parentTaxCode;
        @AuraEnabled public String parentCountry;
        @AuraEnabled public Boolean isRCM;
        @AuraEnabled public List<ChildTax> childTaxes;
    }

    public class ChildTax {
        @AuraEnabled public String childTaxId;
        @AuraEnabled public String childTaxName;
        @AuraEnabled public Decimal childTaxPercentage;
        @AuraEnabled public String childTaxCode;
        @AuraEnabled public String childCountry;
    }
}