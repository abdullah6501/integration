trigger AccountTrigger on Account (before update, before insert) {//acc.external_id__c=='' && !AccountTriggerHelper.recurrance
if(Trigger.isInsert){
    Account[] account_to_insert = new List<Account>();
    for(Account acc : Trigger.new){
        if(acc.Order_Status__c=='Approved'){
               acc.Order_Status__c.addError('you must create line items to approve this account');
        }
        else{
        account_to_insert.add(acc);
        }
    }
    // insert account_to_insert;
}
    if(Trigger.isUpdate && !AccountTriggerHelper.recurrance){
        AccountTriggerHelper.recurrance=true;
        list<Sale_order_wrapper> sales = new list<Sale_order_wrapper>();
        list<Account> account_to_update = new list<Account>();
        for(Account acc : Trigger.new){
            if(acc.Order_Status__c=='Approved'){
                Order_line_item__c[] opps = [SELECT Id, Line_No__c, Product2Id__c, Description__c, Quantity__c, UnitOfMeasure__c, UnitPrice__c, SalesPrice__c, TotalPrice__c, RequestShipDate__c, Line_Status__c FROM Order_line_item__c where Account_Id__c=:acc.Id];     
                if(opps.size()==0){
                   acc.Order_Status__c.addError('you must create line items to approve this account');
                }
                else{
                    Sale_order_wrapper sale = new Sale_order_wrapper(acc,opps);
                    sales.add(sale);
                    account_to_update.add(acc);
                }
            }
        }
        String json = JSON.serialize(sales);
        String[] external_ids=Callout.sale_order_post(json);
        for (Integer i = 0; i < account_to_update.size(); i++) {
            if (i < external_ids.size()) {
                account_to_update[i].external_Id__c = external_ids[i];
            } else {
                account_to_update[i].External_Id__c = null;
            }
        }
        // update account_to_update;
        AccountTriggerHelper.recurrance=false;
    }

}