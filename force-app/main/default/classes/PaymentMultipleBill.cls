public with sharing class PaymentMultipleBill {
 
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getBillList(Id payId) {
        if (!Payment__c.SObjectType.getDescribe().isAccessible() || !Bill__c.SObjectType.getDescribe().isAccessible()) {
            throw new AuraHandledException('Insufficient permissions.');
        }
    
        Payment__c payment = [
            SELECT Id, Name, Account__c, Total_Amount1__c,Invoiced_Amount__c,Payment_Amount1__c,Payment_Type__c
            FROM Payment__c WHERE Id = :payId WITH SECURITY_ENFORCED
        ];
        
        PaymentWrapper paymentWrap = new PaymentWrapper(payment);
    
        List<Bill__c> billList = [
            SELECT Id, Name, Vendor__r.Name, Vendor__c,
                Total_Amount__c, Balance_Due__c,
                Paid_Amount__c, LastModifiedDate
            FROM Bill__c
            WHERE Vendor__c = :payment.Account__c AND Balance_Due__c > 0 WITH SECURITY_ENFORCED
        ];
    
        List<BillWrapper> wrappedBills = new List<BillWrapper>();
        for(Bill__c inv : billList) {
            wrappedBills.add(new BillWrapper(inv));
        }
 
        Map<String, Object> result = new Map<String, Object>{
            'payment' => paymentWrap,
            'bills' => wrappedBills
        };
    
        return result;
    }
   
    @AuraEnabled
    public static PaymentWrapper updateBills(List<BillWrapper> billWrappers, Id paymentId, Decimal sumPayment) {
        if (!Schema.sObjectType.Bill__c.isUpdateable()) {
            throw new AuraHandledException('You do not have update access to bills.');
        }
        Payment__c payment = [
            SELECT Id, Name, Account__c, Total_Amount1__c, Invoiced_Amount__c, Payment_Amount1__c,Payment_Type__c
            FROM Payment__c
            WHERE Id = :paymentId WITH SECURITY_ENFORCED
        ];
 
        if(sumPayment != null) {
            payment.Invoiced_Amount__c = payment.Invoiced_Amount__c == null ? sumPayment : payment.Invoiced_Amount__c + sumPayment;
        }
        
        List<Bill__c> billsToSave = new List<Bill__c>();
        system.debug('Payment: ' + payment);
        system.debug('Bill Wrappers: ' + billWrappers);
        for(BillWrapper wrapper : BillWrappers) {
            Decimal paidAmount = wrapper.paidCost != null ? wrapper.paidCost : 0;
            if(wrapper.paymentAmount > 0) {
                Bill__c newBill = new Bill__c(
                    Id = wrapper.billId,
                    Paid_Amount__c = paidAmount + wrapper.paymentAmount
                    //Payment__c = paymentId
                );
                billsToSave.add(newBill);
            }
        }
        List<Payment_Reference__c> paymentRef = new List<Payment_Reference__c>();
        for(BillWrapper wrapper : billWrappers) {
           // Decimal paidAmount = wrapper.paidCost != null ? wrapper.paidCost : 0;
            if(wrapper.paymentAmount > 0) {
                Payment_Reference__c payRef = new Payment_Reference__c(
                    Name = 'Payment Reference for Bill ' + wrapper.billNumber,
                    Bill__c= wrapper.billId,
                    Payment__c = paymentId,
                    Total_Amount__c = wrapper.paymentAmount
                );
                paymentRef.add(payRef);
            }
        }
        
        try {
            update payment;
            insert paymentRef;
            if(!billsToSave.isEmpty()) {
                update billsToSave;
            }
            return new PaymentWrapper(payment);
        } catch(Exception e) {
            throw new AuraHandledException('Error updating bills: ' + e.getMessage());
        }
    }
 
}