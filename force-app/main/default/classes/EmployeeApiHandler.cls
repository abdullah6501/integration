public with sharing class EmployeeApiHandler {
    public class JsonEmployeeRequest {
        public String employeeId;
        public String externalId;
        public String firstName;
        public String lastName;
        public String email;
        public PersonalInfo personalinfo;
        public BasicInfo basicinfo;
    }

    public class PersonalInfo {
        public String dateOfBirth;
        public String gender;
    }

    public class BasicInfo {
        public String employmentType;
        public String dateOfJoining;
    }

    @future(callout=true)
    public static void sendEmployeesToExternalApi(List<Id> empIds) {
        List<RFAB__Employee__c> empList = [SELECT Id, Name, RFAB__First_Name__c, RFAB__Last_Name__c, 
                                           RFAB__Date_of_Birth__c, RFAB__Gender__c, RFAB__Email_Address__c, 
                                           RFAB__Job_Type__c, RFAB__Date_Of_Joining__c 
                                           FROM RFAB__Employee__c WHERE Id IN :empIds];

        for (RFAB__Employee__c emp : empList) {
            JsonEmployeeRequest payload = new JsonEmployeeRequest();
            payload.employeeId = emp.Name;
            payload.externalId = emp.Id;
            payload.firstName = emp.RFAB__First_Name__c;
            payload.lastName = emp.RFAB__Last_Name__c;
            payload.email = emp.RFAB__Email_Address__c;

            payload.personalinfo = new PersonalInfo();
            payload.personalinfo.dateOfBirth = emp.RFAB__Date_of_Birth__c != null ? String.valueOf(emp.RFAB__Date_of_Birth__c) : null;
            payload.personalinfo.gender = emp.RFAB__Gender__c;

            payload.basicinfo = new BasicInfo();
            payload.basicinfo.employmentType = emp.RFAB__Job_Type__c;
            payload.basicinfo.dateOfJoining = emp.RFAB__Date_Of_Joining__c != null ? String.valueOf(emp.RFAB__Date_Of_Joining__c) : null;

            String jsonBody = JSON.serialize(payload);

            HttpRequest req = new HttpRequest();
            req.setEndpoint('');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(jsonBody);

            Http http = new Http();
            try {
                HttpResponse res = http.send(req);
                System.debug('Response: ' + res.getBody());
            } catch (Exception ex) {
                System.debug('Error sending Employee data: ' + ex.getMessage());
            }
        }
    }
}
