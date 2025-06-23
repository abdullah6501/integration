public with sharing class ExpenseApiHandler { 
    // public class JsonEmployeeRequest {
    //     public String employeeId;
    //     public String externalId;
    //     public String firstName;
    //     public String lastName;
    //     public String email;
    //     public String userName;
    //     public String password;
    //     public PersonalInfo personalinfo;
    //     public BasicInfo basicinfo;
    // }

    // public class PersonalInfo {
    //     public String dateOfBirth;
    //     public String gender;
    // }

    // public class BasicInfo {
    //     public String employmentType;
    //     public String dateOfJoining;
    // }

    // public class JsonSalesOrderRequest {
    //     public String externalId;
    //     public String name;
    //     public String paymentTerms;
    //     public String customerPORef;
    //     public String shippingTerms;
    //     public String orderDate;
    //     public String status;
    //     public String soType;
    //     public String title;
    // }

    // public class JsonAssetRequest {
    //     public String assetName;
    //     public String status;
    //     public Decimal price;
    //     public Integer quantity;
    //     public String purchaseDate;
    //     public String description;
    // }

    // // public class JsonExpenseRequest {
    // //     public String expenseName;
    // //     public String employeeId;
    // //     public String date;
    // //     public Decimal totalAmount;
    // //     public String taxTreatment;
    // //     public String description;
    // //     public String status;
    // //     public String expenseCategory;
    // //     public String expenseAccount;
    // //     public String jobOrder;
    // //     public Decimal taxAmount;
    // //     public String paidThru;
    // //     public String comments;
    // //     public String vehicle;
    // // }

    // private static final String NAMED_CREDENTIAL_NAME = 'FusionApi';

    // @future(callout=true)
    // public static void sendEmployeesToValarHr(List<Id> empIds) {
    //     List<RFAB__Employee__c> empList = [SELECT Id, Name, RFAB__First_Name__c, RFAB__Last_Name__c, 
    //                                        RFAB__Date_of_Birth__c, RFAB__Gender__c, RFAB__Email_Address__c, 
    //                                        RFAB__Job_Type__c, RFAB__Date_Of_Joining__c, RFAB__Salesforce_Account__c 
    //                                        FROM RFAB__Employee__c WHERE Id IN :empIds];

    //     Map<Id, RFAB__Employee__c> empMap = new Map<Id, RFAB__Employee__c>();
    //     Set<Id> userIds = new Set<Id>();
    //     for (RFAB__Employee__c emp : empList) {
    //         empMap.put(emp.Id, emp);
    //         if (emp.RFAB__Salesforce_Account__c != null) {
    //             userIds.add(emp.RFAB__Salesforce_Account__c);
    //         }
    //     }

    //     Map<Id, String> usernameMap = new Map<Id, String>();
    //     if (!userIds.isEmpty()) {
    //         List<User> users = [SELECT Id, Username FROM User WHERE Id IN :userIds];
    //         for (User user : users) {
    //             usernameMap.put(user.Id, user.Username);
    //         }
    //     }
    //     System.debug('Username Map: ' + usernameMap);

    //     for (RFAB__Employee__c emp : empList) {
    //         JsonEmployeeRequest payload = new JsonEmployeeRequest();
    //         payload.employeeId = emp.Name;
    //         payload.externalId = emp.Id;
    //         payload.firstName = emp.RFAB__First_Name__c;
    //         payload.lastName = emp.RFAB__Last_Name__c;
    //         payload.email = emp.RFAB__Email_Address__c;

    //         payload.personalinfo = new PersonalInfo();
    //         payload.personalinfo.dateOfBirth = emp.RFAB__Date_of_Birth__c != null ? String.valueOf(emp.RFAB__Date_of_Birth__c) : null;
    //         payload.personalinfo.gender = emp.RFAB__Gender__c;

    //         payload.basicinfo = new BasicInfo();
    //         payload.basicinfo.employmentType = emp.RFAB__Job_Type__c;
    //         payload.basicinfo.dateOfJoining = emp.RFAB__Date_Of_Joining__c != null ? String.valueOf(emp.RFAB__Date_Of_Joining__c) : null;

    //         payload.userName = emp.RFAB__Salesforce_Account__c != null ? 
    //                          usernameMap.get(emp.RFAB__Salesforce_Account__c) : null;
    //         System.debug('Username: ' + payload.userName);
    //         payload.password = 'valarhr';
    //         System.debug('Payload: ' + JSON.serialize(payload));

    //         sendPostRequest('https://api.valarhr.com/dbops/crud/document?table=employee', JSON.serialize(payload));
    //     }
    // }

    // @future(callout=true)
    // public static void sendSalesOrdersToValarHr(List<Id> orderIds) {
    //     List<RFAB__Sales_Order__c> orders = [SELECT Id, Name, Payment_Terms__c, Customer_Po_Ref__c, Shipping_Terms__c, 
    //                                                 Order_Date__c, RFAB__Status__c, RFAB__Sales__c, RFAB__Title__c 
    //                                          FROM RFAB__Sales_Order__c WHERE Id IN :orderIds];

    //     for (RFAB__Sales_Order__c order : orders) {
    //         JsonSalesOrderRequest payload = new JsonSalesOrderRequest();
    //         payload.externalId = order.Id;
    //         payload.name = order.Name;
    //         payload.paymentTerms = order.Payment_Terms__c;
    //         payload.customerPORef = order.Customer_Po_Ref__c;
    //         payload.shippingTerms = order.Shipping_Terms__c;
    //         payload.orderDate = order.Order_Date__c != null ? String.valueOf(order.Order_Date__c) : null;
    //         payload.status = order.RFAB__Status__c;
    //         payload.soType = order.RFAB__Sales__c;
    //         payload.title = order.RFAB__Title__c;

    //         sendPostRequest('https://api.valarhr.com/dbops/crud/document?table=salesorder', JSON.serialize(payload));
    //     }
    // }

    // @future(callout=true)
    // public static void sendAssetsToValarHr(List<Id> assetIds) {
    //     List<Asset> assetList = [SELECT Name, Status, Price, Quantity, PurchaseDate, Description FROM Asset WHERE Id IN :assetIds];

    //     for (Asset asset : assetList) {
    //         JsonAssetRequest payload = new JsonAssetRequest();
    //         payload.assetName = asset.Name;
    //         payload.status = asset.Status;
    //         payload.price = asset.Price;
    //         payload.quantity = asset.Quantity != null ? Integer.valueOf(asset.Quantity) : null;
    //         payload.purchaseDate = asset.PurchaseDate != null ? String.valueOf(asset.PurchaseDate) : null;
    //         payload.description = asset.Description;

    //         sendPostRequest('', JSON.serialize(payload));
    //     }
    // }

    // // @future(callout=true)
    // // public static void sendExpensesToValarHr(List<Id> expenseIds) {
    // //     List<RFAB__Expense__c> expenses = [
    // //         SELECT Name, RFAB__Employee__c, RFAB__Date__c, RFAB__Total_Amount__c, Tax_Treatment__c,
    // //             RFAB__Description__c, RFAB__Status__c, Category__c, Expense_Account__c,
    // //             Sales_Order__c, Tax_Amount__c, Paid_Thru__c, RFAB__Comments__c, Vehicle__c
    // //         FROM RFAB__Expense__c
    // //         WHERE Id IN :expenseIds
    // //     ];

    // //     for (RFAB__Expense__c exp : expenses) {
    // //         JsonExpenseRequest payload = new JsonExpenseRequest();
    // //         payload.expenseName = exp.Name;
    // //         payload.employeeId = exp.RFAB__Employee__c;
    // //         payload.date = exp.RFAB__Date__c != null ? String.valueOf(exp.RFAB__Date__c) : null;
    // //         payload.totalAmount = exp.RFAB__Total_Amount__c;
    // //         payload.taxTreatment = exp.Tax_Treatment__c;
    // //         payload.description = exp.RFAB__Description__c;
    // //         payload.status = exp.RFAB__Status__c;
    // //         payload.expenseCategory = exp.Category__c;
    // //         payload.expenseAccount = exp.Expense_Account__c;
    // //         payload.jobOrder = exp.Sales_Order__c;
    // //         payload.taxAmount = exp.Tax_Amount__c;
    // //         payload.paidThru = exp.Paid_Thru__c;
    // //         payload.comments = exp.RFAB__Comments__c;
    // //         payload.vehicle = exp.Vehicle__c;

    // //         sendPostRequest('', JSON.serialize(payload));
    // //     }
    // // }

    // private static void sendPostRequest(String endpoint, String jsonBody) {
    //     HttpRequest req = new HttpRequest();
    //     req.setEndpoint(endpoint);
    //     req.setMethod('POST');
    //     req.setHeader('Content-Type', 'application/json');
    //     req.setHeader('token', System.Label.ValarHrToken);
    //     req.setBody(jsonBody);

    //     Http http = new Http();
    //     try {
    //         HttpResponse res = http.send(req);
    //         System.debug('Response: ' + res.getBody());
    //     } catch (Exception ex) {
    //         System.debug('Error sending API request: ' + ex.getMessage());
    //     }
    // }
}