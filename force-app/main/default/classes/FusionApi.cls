global class FusionApi {
    private static final String NAMED_CREDENTIAL_NAME = 'chat_service_credential';

    private static final String FUSION_API_URL = 'callout:' + NAMED_CREDENTIAL_NAME + '/dbops/crud/document?table=';

    global static String doPost(String id, String objectName, String methodType, String name) {
        HttpRequest request = new HttpRequest();
        String jsonStr = '';
        
        if (methodType == 'POST' || methodType == 'PATCH') {
            request.setEndpoint(FUSION_API_URL + objectName);
            if (objectName == 'employee' && methodType == 'PATCH') {
                request.setMethod('PATCH');
            } else {
                request.setMethod('POST');
            }
        } else if (methodType == 'DELETE') {
            if (objectName == 'asset') {
                request.setMethod('DELETE');
                request.setEndpoint(FUSION_API_URL + objectName + '&assetID=' + id);
            } else if (objectName == 'employee') {
                request.setMethod('PATCH');
                request.setEndpoint('callout:' + NAMED_CREDENTIAL_NAME + '/employee/basic');
                System.debug('Setting endpoint for employee deletion: ' + request.getEndpoint());
                // RFAB__Employee__c emp = [SELECT Id, Name FROM RFAB__Employee__c WHERE Id = :id];
                System.debug('Employee to delete: ' + id);
                JsonEmployeeDelete jsonData = new JsonEmployeeDelete();
                jsonData.employeeId = name;
                jsonData.isActive = false;

                jsonStr = JSON.serialize(jsonData, true);
                request.setBody(jsonStr);
            } else {
                request.setMethod('DELETE');
                request.setEndpoint(FUSION_API_URL + objectName + '&externalId=' + id);
            }
            
        }
        // request.setMethod('POST');
        System.debug('Request Method: ' + request.getMethod());

        request.setHeader('Content-Type', 'application/json');
        request.setHeader('token', System.Label.ValarHrToken);

        if (methodType == 'POST' || methodType == 'PATCH') {
            if (objectName == 'employee') {
                RFAB__Employee__c emp = [
                    SELECT Id, Name, RFAB__First_Name__c, RFAB__Last_Name__c, RFAB__Date_of_Birth__c,
                        RFAB__Gender__c, RFAB__Email_Address__c, RFAB__Job_Type__c, RFAB__Date_Of_Joining__c,
                        RFAB__Salesforce_Account__c
                    FROM RFAB__Employee__c WHERE Id = :id
                ];
                Map<String, User> userMap = new Map<String, User>([
                    SELECT Id, Username FROM User WHERE Id = :emp.RFAB__Salesforce_Account__c
                ]);

                JsonEmployee jsonData = new JsonEmployee();
                jsonData.externalId = emp.Id;
                jsonData.employeeId = emp.Name;
                jsonData.firstName = emp.RFAB__First_Name__c;
                jsonData.lastName = emp.RFAB__Last_Name__c;
                jsonData.personalinfo = new PersonalInfo(emp.RFAB__Date_of_Birth__c, emp.RFAB__Gender__c);
                jsonData.email = emp.RFAB__Email_Address__c;
                jsonData.basicinfo = new BasicInfo(emp.RFAB__Job_Type__c, emp.RFAB__Date_Of_Joining__c);
                if (methodType == 'POST') {
                    jsonData.userName = userMap.containsKey(emp.RFAB__Salesforce_Account__c) ? userMap.get(emp.RFAB__Salesforce_Account__c).Username : null;
                    jsonData.password = 'valarhr';
                }
                
                jsonStr = JSON.serialize(jsonData, true);

            } else if (objectName == 'salesorder') {
                System.debug('entering salesorder block with id: ' + id);
                RFAB__Sales_Order__c so = [
                    SELECT Id, Name, RFAB__Payment_Terms__c, RFAB__Customer_Po_Ref__c, RFAB__Shipping_Terms__c,
                        // Order_Date__c, 
                        RFAB__Status__c, RFAB__Sales__c, RFAB__Title__c
                    FROM RFAB__Sales_Order__c WHERE Id = :id
                ];

                JsonSalesOrder jsonData = new JsonSalesOrder();
                jsonData.externalId = so.Id;
                jsonData.name = so.Name;
                jsonData.paymentTerms = so.RFAB__Payment_Terms__c;
                jsonData.customerPORef = so.RFAB__Customer_Po_Ref__c;
                jsonData.shippingTerms = so.RFAB__Shipping_Terms__c;
                jsonData.status = so.RFAB__Status__c;
                jsonData.soType = so.RFAB__Sales__c;
                jsonData.title = so.RFAB__Title__c;
                //jsonData.orderDate = String.valueOf(so.Order_Date__c);

                System.debug('Serialized JSON Data: ' + JSON.serialize(jsonData, true));

                jsonStr = JSON.serialize(jsonData, true);

            } else if (objectName == 'asset') {
                Asset asset = [SELECT Id, Name, Status, Price, Quantity, PurchaseDate, Description FROM Asset WHERE Id = :id];

                JsonAsset jsonData = new JsonAsset();
                jsonData.assetID = asset.Id;
                jsonData.assetName = asset.Name;
                jsonData.status = asset.Status;
                jsonData.purchaseDate = String.valueOf(asset.PurchaseDate);
                jsonData.notes = asset.Description;
                // jsonData.price = asset.Price;
                // jsonData.quantity = asset.Quantity;

                jsonStr = JSON.serialize(jsonData, true);

            } else if (objectName == 'expense') {
                RFAB__Expense__c exp = [
                    SELECT Id, Name, RFAB__Employee__r.Name, RFAB__Date__c, RFAB__Total_Amount__c, 
                    // Tax_Treatment__c,Category__c, Expense_Account__c,Sales_Order__c,Paid_Thru__c,Vehicle__c,Tax_Amount__c,
                        RFAB__Description__c, RFAB__Status__c,  
                          RFAB__Comments__c
                    FROM RFAB__Expense__c WHERE Id = :id
                ];

                JsonExpense jsonData = new JsonExpense();
                jsonData.externalId = exp.Id;
                jsonData.name = exp.Name;
                jsonData.employeeId = exp.RFAB__Employee__r.Name;
                jsonData.expenseDate = String.valueOf(exp.RFAB__Date__c);
                jsonData.amount = exp.RFAB__Total_Amount__c;
                jsonData.description = exp.RFAB__Description__c;
                jsonData.status = exp.RFAB__Status__c;
                jsonData.comments = exp.RFAB__Comments__c;
                //jsonData.taxTreatment = exp.Tax_Treatment__c;
                //jsonData.category = exp.Category__c;
                //jsonData.chartOfAccountCode = exp.Expense_Account__c;
                //jsonData.salesOrderId = exp.Sales_Order__c;
                //jsonData.taxAmount = exp.Tax_Amount__c;
                //jsonData.paidThru = exp.Paid_Thru__c;
                //jsonData.assetID = exp.Vehicle__c;

                jsonStr = JSON.serialize(jsonData, true);
                System.debug('JSON String' + jsonStr);
            }
        }
        if (methodType == 'POST' || methodType == 'PATCH') {
            request.setBody(jsonStr);
        }
        System.debug('Request Body: ' + jsonStr);
        System.debug('Sending request to Fusion API...');
        HttpResponse response = new Http().send(request);
        System.debug('Response Status: ' + response.getStatus());
        System.debug('Response Body: ' + response.getBody());
        System.debug('Response Status Code: ' + response.getStatusCode());
        return response.getStatusCode() == 200 ? response.getStatus() : 'Error: ' + response.getStatusCode() + ' - ' + response.getStatus();
    }

    public class PersonalInfo {
        public String dateOfBirth;
        public String gender;
        public PersonalInfo(Date dob, String genderVal) {
            dateOfBirth = String.valueOf(dob);
            gender = genderVal;
        }
    }

    public class BasicInfo {
        public String employmentType;
        public String dateOfJoining;
        public BasicInfo(String jobType, Date doj) {
            employmentType = jobType;
            dateOfJoining = String.valueOf(doj);
        }
    }

    public class JsonEmployee {
        public String externalId;
        public String employeeId;
        public String firstName;
        public String lastName;
        public PersonalInfo personalinfo;
        public String email;
        public BasicInfo basicinfo;
        public String userName;
        public String password;
    }

    public class JsonEmployeeDelete {
        public String employeeId;
        public Boolean isActive;
    }

    public class JsonSalesOrder {
        public String externalId;
        public String name;
        public String paymentTerms;
        public String customerPORef;
        public String shippingTerms;
        public String orderDate;
        public String status;
        public String soType;
        public String title;
    }

    public class JsonAsset {
        public String assetID;
        public String assetName;
        public String status;
        // public Decimal price;
        // public Integer quantity;
        public String purchaseDate;
        public String notes;
    }

    public class JsonExpense {
        public String externalId;
        public String name;
        public String employeeId;
        public String expenseDate;
        public Decimal amount;
        public String taxTreatment;
        public String description;
        public String status;
        public String category;
        public String chartOfAccountCode;
        public String salesOrderId;
        public Decimal taxAmount;
        public String paidThru;
        public String comments;
        public String assetID;
    }
}