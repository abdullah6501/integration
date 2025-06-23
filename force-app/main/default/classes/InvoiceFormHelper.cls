public with sharing class InvoiceFormHelper {
    public InvoiceFormHelper() {
        System.debug('Inside the InvoiceFormHelper constr');
    }
    
    @AuraEnabled
    public static Invoice__c convertWrapperToInv(InvoiceFormWrapper invWrapObj){
        Invoice__c inv = new Invoice__c();
        if(invWrapObj.invId != null && invWrapObj.invId != ''){
            inv = new Invoice__c(Id=invWrapObj.invId);
        }else{
            inv.Invoice_status__c = invWrapObj.invStatus; //Always passing Draft as value incase of creation
        }
        //inv.Name = invWrapObj.name; //Need to know the naming convention
        inv.Account__c = invWrapObj.accId;
        inv.Contact__c = invWrapObj.conId;
        inv.To_Email_Addresses__c = invWrapObj.primaryConEmailAddresses; //NewlyCreated - Need to create a field for this
        inv.Email_CC__c = invWrapObj.ccEmailAddresses;
        inv.Email_Bcc__c = invWrapObj.bccEmailAddresses;
        inv.Billing_Address__c = invWrapObj.billingAddress;
        inv.Term__c = invWrapObj.termLabel; //term ==> Not use
        inv.Invoice_Date__c = invWrapObj.invoiceDate;
        inv.Due_Date__c = invWrapObj.dueDate;
        inv.PlaceOfSupply__c = invWrapObj.placeOfSupply; //NewlyCreated - Need to create a field for this
        inv.Authorized_Sign__c= invWrapObj.authSign;
        inv.Invoice_Type__c=invWrapObj.invoiceType;

        inv.Invoice_Indicator__c=invWrapObj.invoiceIndicator;
        inv.Payment_Type__c=invWrapObj.paymentType;
        inv.Latest_Delivery_Date__c=invWrapObj.latestDeliveryDate;
        inv.Discount_Reason__c= invWrapObj.lumpsumDiscountReason;
        inv.Invoice_Name_Type__c=invWrapObj.invoiceNameType;
        inv.Currency__c= invWrapObj.selectedCurrency;   
        inv.Exchange_rate__c= invWrapObj.exchangeRate != null ? Decimal.valueOf(invWrapObj.exchangeRate) : null;
        inv.Amounts_are__c = invWrapObj.parentTaxSelectedOption;
        inv.Message_Of_Invoice__c = invWrapObj.msgOnInv;
        inv.Terms_And_Condition__c = invWrapObj.termsAndCond;
        inv.Discount_Type__c = invWrapObj.selectedDiscountType;
        inv.Discount_Mode__c = invWrapObj.selectedDiscountMode;
        inv.Lumpsum_Discount_Percentage__c = invWrapObj.lumpsumDiscountPercentage;
        inv.Lumpsum_Discount_Amount__c = invWrapObj.lumpsumDiscountAmount;
        Decimal totalBeforeDiscount = 0;
        Decimal totalAfterDiscount = 0;

        // First calculate total amount before discount
        for(InvoiceItemWrapper item : invWrapObj.invoiceItemList) {
            if(item.qty != null && item.rate != null) {
                totalBeforeDiscount += (item.qty * item.rate);
            }
        }

        // Apply discount based on type
        if(invWrapObj.selectedDiscountMode == 'Lumpsum Discount') {
            if(invWrapObj.selectedDiscountType == 'Percentage' && invWrapObj.lumpsumDiscountPercentage != null) {
                // Calculate discount using percentage
                Decimal discountAmount = totalBeforeDiscount * (invWrapObj.lumpsumDiscountPercentage / 100);
                totalAfterDiscount = totalBeforeDiscount - discountAmount;
            } 
            else if(invWrapObj.selectedDiscountType == 'Amount' && invWrapObj.lumpsumDiscountAmount != null) {
                // Apply direct discount amount
                totalAfterDiscount = totalBeforeDiscount - invWrapObj.lumpsumDiscountAmount;
            }
        } 
       
        inv.Amount_After_Discount__c = totalAfterDiscount;
        Decimal strToDec = invWrapObj.total != null ? decimal.valueOf(invWrapObj.total) : 0.0;
        inv.Amount_In_Words__c =  (invWrapObj.currencyCode != null ? invWrapObj.currencyCode + ' ' : '') +
                                  (invWrapObj.currencyCodeName != null ?  invWrapObj.currencyCodeName + ' ' : '') + 
                                    InvoiceFormController.getCurrencyInWords(strToDec) + ' Only';

        inv.Message_On_Statement__c = invWrapObj.msgOnStmt;
        inv.Company_Name__c = invWrapObj.companyName;
       
        return inv;
    }

    public class ConvertWrapperToInvItemResultant{
        public List<Invoice_Item__c> invList = new List<Invoice_Item__c>();
        public Set<Id> newInvItemIds = new Set<Id>();
        public ConvertWrapperToInvItemResultant(){
            invList = new List<Invoice_Item__c>();
            newInvItemIds = new Set<Id>();
        }
    }
    
    @AuraEnabled
    public static ConvertWrapperToInvItemResultant convertWrapperToInvItem(InvoiceFormWrapper invWrapObj, String invId){
        ConvertWrapperToInvItemResultant cwt = new ConvertWrapperToInvItemResultant();

        Integer tempKeyValue = 1;
        Map<String,String> invItemPdtMap = new Map<String,String>();
        Set<Id> pdtSuccessIds = new Set<Id>();
        List<Product__c> newPdtInsList = new List<Product__c>();
        for(InvoiceItemWrapper iiw : invWrapObj.invoiceItemList){
            if(iiw.pdtDraftName != null && !iiw.isKnownPdt && iiw.pdtId == '_new_'){ //pdtMap.get(iiw.pdtId) != null 
                Product__c pdtObj = new Product__c(Name = iiw.pdtDraftName);
                pdtObj.ProductCode__c = tempKeyValue+'&&&'+iiw.pdtDraftName+'&&&'+invId;
                newPdtInsList.add(pdtObj);
            }
            tempKeyValue++;
        }
        if(newPdtInsList.size() > 0 && Product__c.SObjectType.getDescribe().isCreateable() &&
            Schema.sObjectType.Product__c.fields.Name.isCreateable() &&
            Schema.sObjectType.Product__c.fields.ProductCode__c.isCreateable()){
                Database.SaveResult[] srList = Database.insert(newPdtInsList, false);
                for (Database.SaveResult sr : srList) {
                    if (sr.isSuccess()) {
                        pdtSuccessIds.add(sr.getId());
                    }
                }
        }
        if(pdtSuccessIds.size() > 0 ){
            for(Product__c pd : [SELECT Id,Name,ProductCode__c FROM Product__c WHERE Id IN: pdtSuccessIds WITH SECURITY_ENFORCED]){
                invItemPdtMap.put(pd.ProductCode__c,pd.Id);
            }
        }

        Map<String,String> invItemKeyPdtMap = new Map<String,String>();
        Integer keyValue = 1;
        for(InvoiceItemWrapper iiw : invWrapObj.invoiceItemList){
            Invoice_Item__c invItem = new Invoice_Item__c();
            if(iiw.invItemId != null && iiw.invItemId != ''){
                invItem = new Invoice_Item__c(Id=iiw.invItemId);
                cwt.newInvItemIds.add(iiw.invItemId);
            }else{
                invItem.Invoice__c = invId;
            }
            invItem.Key__c = String.ValueOf(keyValue);//invItem.Key__c = iiw.key; //NewlyCreated - Need to create a field for this
            invItem.Service_Date__c = iiw.serviceDate;
            invItem.IsKnownPdt__c = iiw.isKnownPdt; //NewlyCreated - Need to create a field for this

            if(iiw.pdtDraftName != null && !iiw.isKnownPdt && iiw.pdtId == '_new_'){ //pdtMap.get(iiw.pdtId) != null 
                String tempPdtCode = keyValue+'&&&'+iiw.pdtDraftName+'&&&'+invId;
                if(invItemPdtMap.get(tempPdtCode) != null) {
                    invItem.Product1__c = invItemPdtMap.get(tempPdtCode);
                }
            }else{
                invItem.Product1__c = iiw.pdtId;
            }
            
            invItem.HsnSac__c = iiw.hsn;
            if(iiw.description != null && iiw.description.length() > 500){
                iiw.description = iiw.description.SubString(0,499);
            }
            invItem.Description__c = iiw.description;
            invItem.Discount_Reason__c = iiw.discountReason;
            invItem.Quantity__c = iiw.qty;
            invItem.Rate__c = iiw.rate;
            // invItem.Amount__c = iiw.amt;
            invItem.Discount_Amount__c = iiw.discountAmount;
            invItem.Discount_Percentage__c = iiw.discountPercentage;
            invItem.Tax_Exemption_Reason__c = iiw.taxExemptionReason;
            invItem.Tax_ID__c = iiw.taxCategory;
            // invItem.Amount_Before_Discount__c = iiw.amt;
            
            Decimal finalAmount = iiw.amt;
        
            // Apply discount based on discount mode
            if(invWrapObj.selectedDiscountMode == 'Line Item Discount') {
                // Existing line item discount logic
                if(iiw.discountAmount != null && iiw.discountAmount > 0){
                        // finalAmount = iiw.amt - iiw.discountAmount;
                        finalAmount =( iiw.rate *  iiw.qty )- iiw.discountAmount;
                    } else if(iiw.discountPercentage != null && iiw.discountPercentage > 0){
                        // finalAmount = iiw.amt  - (iiw.amt * iiw.discountPercentage / 100);
                        finalAmount = (iiw.rate *  iiw.qty)  - ((iiw.rate *  iiw.qty) * iiw.discountPercentage / 100);
                    }
            } 
            
            invItem.Amount_Before_Discount__c = iiw.rate *  iiw.qty ;// iiw.amt;
            invItem.Amount__c = finalAmount;
            invItem.Tax_Amount__c = iiw.taxAmount;
            if(invWrapObj.parentTaxSelectedOption == 'Exclusive of Tax'){                           
                invItem.Tax__c = iiw.taxId; //taxLabel, tax ==> Not used
                // invItem.Amount_With_GST__c = iiw.amtWithTax;
                // invItem.GST_Amount__c = iiw.taxAmt;
                if(iiw.discountAmount != null || iiw.discountPercentage != null){
                    System.debug('finalAmount: '+finalAmount);
                    System.debug('iiw.taxAmount: '+iiw.taxAmount);
                invItem.Amount_With_GST__c = finalAmount + iiw.taxAmount;
                System.debug('invItem.Amount_With_GST__c: '+invItem.Amount_With_GST__c);
                invItem.GST_Amount__c = iiw.taxAmount;
                }
                if(invWrapObj.selectedDiscountMode == 'Lumpsum Discount') {
                        if(invWrapObj.selectedDiscountType == 'Percentage') {
                            Decimal itemDiscountAmount = invWrapObj.lumpsumDiscountPercentage;
                            invItem.Amount_With_GST__c = (iiw.amt - (iiw.amt * itemDiscountAmount /100)) +iiw.taxAmount;
                            invItem.GST_Amount__c = iiw.taxAmount;
                        } else if(invWrapObj.selectedDiscountType == 'Amount') {
                            // Distribute lumpsum amount proportionally
                            Decimal itemDiscountAmount =  invWrapObj.lumpsumDiscountAmount;
                            invItem.Amount_With_GST__c = (iiw.amt - itemDiscountAmount/(tempKeyValue-1) )+iiw.taxAmount;
                            invItem.GST_Amount__c = iiw.taxAmount;
                        }
                    }
                if(invWrapObj.selectedDiscountMode != 'Lumpsum Discount' && invWrapObj.selectedDiscountMode != 'Line Item Discount'){
                    invItem.Amount_With_GST__c = iiw.amt + iiw.taxAmount;
                    invItem.GST_Amount__c = iiw.taxAmount;
                }
            }
            else if(invWrapObj.parentTaxSelectedOption == 'Inclusive of Tax'){                           
                invItem.Tax__c = iiw.taxId; //taxLabel, tax ==> Not used
                // invItem.Amount_With_GST__c = iiw.amtWithTax;
                // invItem.GST_Amount__c = iiw.taxAmt;
                if(iiw.discountAmount != null || iiw.discountPercentage != null){
                    System.debug('finalAmount inclusive: '+finalAmount);
                    System.debug('iiw.taxAmount inclusive: '+iiw.taxAmount);
                invItem.Amount_With_GST__c = finalAmount ;
                invItem.GST_Amount__c = iiw.taxAmount;
                }
                if(invWrapObj.selectedDiscountMode == 'Lumpsum Discount') {
                    if(invWrapObj.selectedDiscountType == 'Percentage') {
                        Decimal itemDiscountAmount = invWrapObj.lumpsumDiscountPercentage;
                        invItem.Amount_With_GST__c = (iiw.amt - (iiw.amt * itemDiscountAmount /100));
                        invItem.GST_Amount__c = iiw.taxAmount;
                    } else if(invWrapObj.selectedDiscountType == 'Amount') {
                        // Distribute lumpsum amount proportionally
                        Decimal itemDiscountAmount =  invWrapObj.lumpsumDiscountAmount;
                        System.debug('itemDiscountAmount: '+iiw.amt);
                        invItem.Amount_With_GST__c = (iiw.amt - itemDiscountAmount/(tempKeyValue-1));
                        invItem.GST_Amount__c = iiw.taxAmount;
                    }
                }
                if(invWrapObj.selectedDiscountMode != 'Lumpsum Discount' && invWrapObj.selectedDiscountMode != 'Line Item Discount'){
                    invItem.Amount_With_GST__c = iiw.amt ;
                    invItem.GST_Amount__c = iiw.taxAmount;
                }
            }
            else {                     
                invItem.Tax__c = null; //taxLabel, tax ==> Not used
                invItem.GST_Amount__c = 0;
                if(invWrapObj.selectedDiscountMode != 'Lumpsum Discount' && invWrapObj.selectedDiscountMode != 'Line Item Discount'){
                    invItem.Amount_With_GST__c = iiw.amt ;
                }
                if(iiw.discountAmount != null || iiw.discountPercentage != null){    
                invItem.Amount_With_GST__c = finalAmount;
                }
                if(invWrapObj.selectedDiscountMode == 'Lumpsum Discount') {
                    if(invWrapObj.selectedDiscountType == 'Percentage') {
                        Decimal itemDiscountAmount = invWrapObj.lumpsumDiscountPercentage;
                        invItem.Amount_With_GST__c = (iiw.amt - (iiw.amt * itemDiscountAmount /100));
                    } else if(invWrapObj.selectedDiscountType == 'Amount') {
                        // Distribute lumpsum amount proportionally
                        Decimal itemDiscountAmount =  invWrapObj.lumpsumDiscountAmount;
                        System.debug('itemDiscountAmount: '+iiw.amt);
                        invItem.Amount_With_GST__c = (iiw.amt - itemDiscountAmount/(tempKeyValue-1));
                    }
                }
            }

            //Not Used field:==> Name
            cwt.invList.add(invItem);
            keyValue++;
        }
        return cwt;
    }


    @AuraEnabled
    public static Boolean invItemPermissionCheck(){
        if (Invoice_Item__c.SObjectType.getDescribe().isCreateable() &&
            Schema.sObjectType.Invoice_Item__c.fields.Invoice__c.isCreateable() &&
            Schema.sObjectType.Invoice_Item__c.fields.Key__c.isCreateable() &&

            Schema.sObjectType.Invoice_Item__c.fields.Service_Date__c.isCreateable() &&
            Schema.sObjectType.Invoice_Item__c.fields.IsKnownPdt__c.isCreateable() &&
            Schema.sObjectType.Invoice_Item__c.fields.Product1__c.isCreateable() &&
            Schema.sObjectType.Invoice_Item__c.fields.HsnSac__c.isCreateable() &&
            Schema.sObjectType.Invoice_Item__c.fields.Description__c.isCreateable() &&
            Schema.sObjectType.Invoice_Item__c.fields.Quantity__c.isCreateable() &&
            Schema.sObjectType.Invoice_Item__c.fields.Rate__c.isCreateable() &&
            Schema.sObjectType.Invoice_Item__c.fields.Amount__c.isCreateable() &&
            Schema.sObjectType.Invoice_Item__c.fields.Tax__c.isCreateable() &&
            Schema.sObjectType.Invoice_Item__c.fields.Amount_With_GST__c.isCreateable() &&
            Schema.sObjectType.Invoice_Item__c.fields.GST_Amount__c.isCreateable() &&
            
            Invoice_Item__c.SObjectType.getDescribe().isUpdateable() &&
            Schema.sObjectType.Invoice_Item__c.fields.Key__c.isUpdateable() &&
            Schema.sObjectType.Invoice_Item__c.fields.Service_Date__c.isUpdateable() &&
            Schema.sObjectType.Invoice_Item__c.fields.IsKnownPdt__c.isUpdateable() &&
            Schema.sObjectType.Invoice_Item__c.fields.Product1__c.isUpdateable() &&
            Schema.sObjectType.Invoice_Item__c.fields.HsnSac__c.isUpdateable() &&
            Schema.sObjectType.Invoice_Item__c.fields.Description__c.isUpdateable() &&
            Schema.sObjectType.Invoice_Item__c.fields.Quantity__c.isUpdateable() &&
            Schema.sObjectType.Invoice_Item__c.fields.Rate__c.isUpdateable() &&
            Schema.sObjectType.Invoice_Item__c.fields.Amount__c.isUpdateable() &&
            Schema.sObjectType.Invoice_Item__c.fields.Tax__c.isUpdateable() &&
            Schema.sObjectType.Invoice_Item__c.fields.Amount_With_GST__c.isUpdateable() &&
            
            Schema.sObjectType.Invoice_Item__c.fields.GST_Amount__c.isUpdateable()
        ) {
            return true;
        }else{
            return false;
        }
    }


    @AuraEnabled
    public static Invoice__c invUpsertPermissionCheck(List<Invoice__c> invList){
        // Save the updated record
        //update invoiceRecord;
        if (Invoice__c.SObjectType.getDescribe().isCreateable() &&
            
            Schema.sObjectType.Invoice__c.fields.Invoice_status__c.isCreateable() &&
            Schema.sObjectType.Invoice__c.fields.Account__c.isCreateable() &&
            Schema.sObjectType.Invoice__c.fields.Contact__c.isCreateable() &&
            Schema.sObjectType.Invoice__c.fields.To_Email_Addresses__c.isCreateable() &&
            Schema.sObjectType.Invoice__c.fields.Email_CC__c.isCreateable() &&
            Schema.sObjectType.Invoice__c.fields.Email_Bcc__c.isCreateable() &&
            Schema.sObjectType.Invoice__c.fields.Billing_Address__c.isCreateable() &&
            Schema.sObjectType.Invoice__c.fields.Term__c.isCreateable() &&
            Schema.sObjectType.Invoice__c.fields.Invoice_Date__c.isCreateable() &&
            Schema.sObjectType.Invoice__c.fields.Due_Date__c.isCreateable() &&
            Schema.sObjectType.Invoice__c.fields.PlaceOfSupply__c.isCreateable() &&
            Schema.sObjectType.Invoice__c.fields.Authorized_Sign__c.isCreateable() &&
            Schema.sObjectType.Invoice__c.fields.Amounts_are__c.isCreateable() &&
            Schema.sObjectType.Invoice__c.fields.Message_Of_Invoice__c.isCreateable() &&
            Schema.sObjectType.Invoice__c.fields.Message_On_Statement__c.isCreateable() &&
            Schema.sObjectType.Invoice__c.fields.Terms_And_Condition__c.isCreateable() &&
            Schema.sObjectType.Invoice__c.fields.Amount_In_Words__c.isCreateable() &&
            Schema.sObjectType.Invoice__c.fields.Company_Name__c.isCreateable() &&
            
            Invoice__c.SObjectType.getDescribe().isUpdateable() &&
            Schema.sObjectType.Invoice__c.fields.Invoice_status__c.isUpdateable() &&
            Schema.sObjectType.Invoice__c.fields.Account__c.isUpdateable() &&
            Schema.sObjectType.Invoice__c.fields.Contact__c.isUpdateable() &&
            Schema.sObjectType.Invoice__c.fields.To_Email_Addresses__c.isUpdateable() &&
            Schema.sObjectType.Invoice__c.fields.Email_CC__c.isUpdateable() &&
            Schema.sObjectType.Invoice__c.fields.Email_Bcc__c.isUpdateable() &&
            Schema.sObjectType.Invoice__c.fields.Billing_Address__c.isUpdateable() &&
            Schema.sObjectType.Invoice__c.fields.Term__c.isUpdateable() &&
            Schema.sObjectType.Invoice__c.fields.Invoice_Date__c.isUpdateable() &&
            Schema.sObjectType.Invoice__c.fields.Due_Date__c.isUpdateable() &&
            Schema.sObjectType.Invoice__c.fields.PlaceOfSupply__c.isUpdateable() && 
            Schema.sObjectType.Invoice__c.fields.Authorized_Sign__c.isUpdateable() &&
            Schema.sObjectType.Invoice__c.fields.Amounts_are__c.isUpdateable() &&
            Schema.sObjectType.Invoice__c.fields.Message_Of_Invoice__c.isUpdateable() &&
            Schema.sObjectType.Invoice__c.fields.Message_On_Statement__c.isUpdateable() &&
            Schema.sObjectType.Invoice__c.fields.Terms_And_Condition__c.isUpdateable() &&
            Schema.sObjectType.Invoice__c.fields.Amount_In_Words__c.isUpdateable() &&
            Schema.sObjectType.Invoice__c.fields.Company_Name__c.isUpdateable()
            
        ) {
            upsert invList[0];
            return invList[0];
        }else{
            return null;
        }
    }
     
}