@isTest
public class PaymentMultipleBillTest {
    // Remove inner wrapper classes as we'll use the standalone ones
    
    @TestSetup
    static void setupTestData() {
        // Create test account (vendor)
        Account vendor = new Account(Name = 'Test Vendor');
        insert vendor;

        // Create a payment record with valid Payment Type
        Payment__c payment = new Payment__c(
            Name = 'Test Payment',
            Account__c = vendor.Id,
            Payment_Type__c = 'Cash'  // Changed from 'Credit' to 'Cash'
        );
        insert payment;

        // Create bill records
        List<Bill__c> bills = new List<Bill__c>{
            new Bill__c(
                Name = 'Bill1',
                Vendor__c = vendor.Id,
                Total_Amount__c = 500,
                Paid_Amount__c = 0
            ),
            new Bill__c(
                Name = 'Bill2',
                Vendor__c = vendor.Id,
                Total_Amount__c = 700,
                Paid_Amount__c = 0
            )
        };
        insert bills;
    }

    @isTest
    static void testGetBillList() {
        Payment__c payment = [SELECT Id FROM Payment__c LIMIT 1];
        Test.startTest();
        Map<String, Object> result = PaymentMultipleBill.getBillList(payment.Id);
        Test.stopTest();

        System.assert(result != null, 'Result should not be null');
        System.assert(result.containsKey('payment'), 'Result should contain payment');
        System.assert(result.containsKey('bills'), 'Result should contain bills');
        List<Object> bills = (List<Object>) result.get('bills');
        System.assert(bills.size() > 0, 'Bills list should not be empty');
    }

    @isTest
    static void testUpdateBills() {
        Payment__c payment = [SELECT Id FROM Payment__c LIMIT 1];
        List<Bill__c> bills = [SELECT Id, Name, Paid_Amount__c FROM Bill__c];

        List<BillWrapper> wrappers = new List<BillWrapper>();
        for (Bill__c bill : bills) {
            BillWrapper bw = new BillWrapper();
            bw.billId = bill.Id;
            bw.billNumber = bill.Name;
            bw.paymentAmount = 100;
            bw.paidCost = bill.Paid_Amount__c;
            wrappers.add(bw);
        }

        Test.startTest();
        PaymentWrapper result = PaymentMultipleBill.updateBills(wrappers, payment.Id, 200);
        Test.stopTest();

        System.assert(result != null, 'PaymentWrapper should not be null');

        // Verify updated data
        Payment__c updatedPayment = [SELECT Invoiced_Amount__c FROM Payment__c WHERE Id = :payment.Id];
        System.assertEquals(200, updatedPayment.Invoiced_Amount__c, 'Invoiced Amount should be updated');
    }
}
