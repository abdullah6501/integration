public with sharing class RChilliIntegration {
    
    @AuraEnabled
    public static String uploadResumeToRChilli(String contentDocumentId) {
        try {
            System.debug('Entering uploadResumeToRChilli method');

            if (!Schema.sObjectType.ContentVersion.isAccessible()) {
                throw new SecurityException('No access to ContentVersion object');
            }

            ContentVersion fileRecord = [
                SELECT Id, VersionData, Title 
                FROM ContentVersion 
                WHERE ContentDocumentId = :contentDocumentId 
                ORDER BY CreatedDate DESC 
                LIMIT 1
            ];
            System.debug('FileRecord: ' + fileRecord);

            String base64Resume = EncodingUtil.base64Encode(fileRecord.VersionData);
            System.debug('Base64 Resume: ' + base64Resume);

            Map<String, Object> requestBody = new Map<String, Object>{
                'filedata' => base64Resume,
                'filename' => fileRecord.Title,
                'userkey' => System.Label.USERKEY,
                'version' => '8.0.0',
                'subuserid' => System.Label.SUBUSERID
            };
            String jsonBody = JSON.serialize(requestBody);
            System.debug('Request Body: ' + jsonBody);

            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://rest.rchilli.com/RChilliParser/Rchilli/parseResumeBinary'); 
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(jsonBody);

            Http http = new Http();
            HTTPResponse res = http.send(req);
            System.debug('Response: ' + res.getBody());

            if (res.getStatusCode() == 200) {
                return processJsonResponse(res.getBody());
            } else {
                System.debug('Error: ' + res.getBody());
                return 'Error: ' + res.getBody();
            }
        } catch (QueryException e) {
            return 'Error: No file found for the given ID';
        } catch (Exception e) {
            return 'Error: ' + e.getMessage();
        }
    }

    private static String processJsonResponse(String jsonResponse) {
        try {
            Map<String, Object> rootJson = (Map<String, Object>) JSON.deserializeUntyped(jsonResponse);
            Map<String, Object> parsedJson = (Map<String, Object>) rootJson.get('ResumeParserData');

            Map<String, Object> nameData = (Map<String, Object>) parsedJson.get('Name');
            String firstName = nameData != null ? (String) nameData.get('FirstName') : null;
            String lastName = nameData != null ? (String) nameData.get('LastName') : 'Unknown';

            String gender = (String) parsedJson.get('Gender');
            if (gender == null || gender.trim() == '') {
                gender = 'Other';
            }
            String nationality = (String) parsedJson.get('Nationality');

            List<Object> emailList = (List<Object>) parsedJson.get('Email');
            String email = (emailList != null && !emailList.isEmpty()) 
                ? (String) ((Map<String, Object>) emailList.get(0)).get('EmailAddress') 
                : null;

            List<Object> phoneList = (List<Object>) parsedJson.get('PhoneNumber');
            String phone = (phoneList != null && !phoneList.isEmpty()) 
                ? (String) ((Map<String, Object>) phoneList.get(0)).get('FormattedNumber') 
                : null;

            Date dateOfBirth = safeDateConversion(parsedJson.get('DateOfBirth'));

            Contact newContact = new Contact(
                FirstName = firstName,
                LastName = lastName,
                Email = email,
                Phone = phone,
                Birthdate = dateOfBirth,
                RFAB__Gender__c = gender,
                Nationality__c = nationality
            );
            insert newContact;

            List<RFAB__Qualification__c> educationList = new List<RFAB__Qualification__c>();
            List<Object> educationData = (List<Object>) parsedJson.get('SegregatedQualification');

            if (educationData != null) {
                for (Object eduObj : educationData) {
                    Map<String, Object> eduMap = (Map<String, Object>) eduObj;
                    Map<String, Object> degreeMap = (Map<String, Object>) eduMap.get('Degree');
                    Map<String, Object> institutionMap = (Map<String, Object>) eduMap.get('Institution');

                    String institutionName = 'Unknown Institute';
                    if (institutionMap != null && institutionMap.containsKey('Name') && institutionMap.get('Name') != null && String.valueOf(institutionMap.get('Name')).trim() != '') {
                        institutionName = String.valueOf(institutionMap.get('Name'));
                    }

                    String degreeName = 'Unknown Degree';
                    if (degreeMap != null && degreeMap.containsKey('DegreeName') && degreeMap.get('DegreeName') != null && String.valueOf(degreeMap.get('DegreeName')).trim() != '') {
                        degreeName = String.valueOf(degreeMap.get('DegreeName'));
                    }

                    String specialization = 'General';
                    if (degreeMap != null && degreeMap.containsKey('Specialization')) {
                        List<Object> specializationList = (List<Object>) degreeMap.get('Specialization');
                        if (specializationList != null && !specializationList.isEmpty()) {
                            specialization = String.valueOf(specializationList.get(0));
                        }
                    }

                    educationList.add(new RFAB__Qualification__c(
                        RFAB__Contact_Name__c = newContact.Id,
                        Degree_Name__c = degreeName,  
                        RFAB__College_Name__c = institutionName, 
                        Specialization__c = specialization,
                        RFAB__Qualification_Start_Date__c = safeDateConversion(eduMap.get('StartDate')),
                        RFAB__Qualification_End_Date__c = safeDateConversion(eduMap.get('EndDate'))
                    ));
                }
                
                if (!educationList.isEmpty()) {
                    insert educationList;
                }
            }

            return 'Resume data successfully processed and stored in Salesforce!';
        } catch (Exception e) {
            System.debug('Error processing JSON: ' + e.getMessage());
            return 'Error processing JSON: ' + e.getMessage();
        }
    }

    private static Date safeDateConversion(Object dateValue) {
        if (dateValue == null || String.valueOf(dateValue).trim() == '') {
            return null;
        }
        try {
            return Date.valueOf(String.valueOf(dateValue));
        } catch (Exception e) {
            System.debug('Invalid Date Format: ' + dateValue);
            return null;
        }
    }
}


// private static String processJsonResponse(String jsonResponse) {
//         try {
//             Map<String, Object> rootJson = (Map<String, Object>) JSON.deserializeUntyped(jsonResponse);
//             Map<String, Object> parsedJson = (Map<String, Object>) rootJson.get('ResumeParserData');

//             // Extract Name Details
//             Map<String, Object> nameData = (Map<String, Object>) parsedJson.get('Name');
//             String firstName = nameData != null ? (String) nameData.get('FirstName') : null;
//             String lastName = nameData != null ? (String) nameData.get('LastName') : 'Unknown';

//             // Extract Gender & Nationality
//             String gender = (String) parsedJson.get('Gender');
//             if (gender == null || gender.trim() == '') {
//                 gender = 'Other';
//             }
//             String nationality = (String) parsedJson.get('Nationality');

//             // Extract Email
//             List<Object> emailList = (List<Object>) parsedJson.get('Email');
//             String email = (emailList != null && !emailList.isEmpty()) 
//                 ? (String) ((Map<String, Object>) emailList.get(0)).get('EmailAddress') 
//                 : null;

//             // Extract Phone
//             List<Object> phoneList = (List<Object>) parsedJson.get('PhoneNumber');
//             String phone = (phoneList != null && !phoneList.isEmpty()) 
//                 ? (String) ((Map<String, Object>) phoneList.get(0)).get('FormattedNumber') 
//                 : null;

//             // Convert Date
//             Date dateOfBirth = safeDateConversion(parsedJson.get('DateOfBirth'));

//             // **Check for Existing Contact**
//             Contact existingContact;
//             if (email != null) {
//                 List<Contact> contacts = [SELECT Id FROM Contact WHERE Email = :email LIMIT 1];
//                 if (!contacts.isEmpty()) {
//                     existingContact = contacts[0];
//                 }
//             } else if (phone != null) {
//                 List<Contact> contacts = [SELECT Id FROM Contact WHERE Phone = :phone LIMIT 1];
//                 if (!contacts.isEmpty()) {
//                     existingContact = contacts[0];
//                 }
//             }

//             // **Insert or Update Contact**
//             Contact newContact;
//             if (existingContact != null) {
//                 newContact = existingContact;
//                 newContact.FirstName = firstName;
//                 newContact.LastName = lastName;
//                 newContact.Birthdate = dateOfBirth;
//                 newContact.RFAB__Gender__c = gender;
//                 newContact.Nationality__c = nationality;
//                 update newContact;
//             } else {
//                 newContact = new Contact(
//                     FirstName = firstName,
//                     LastName = lastName,
//                     Email = email,
//                     Phone = phone,
//                     Birthdate = dateOfBirth,
//                     RFAB__Gender__c = gender,
//                     Nationality__c = nationality
//                 );
//                 insert newContact;
//             }

//             // **Insert Education Records**
//             List<RFAB__Qualification__c> educationList = new List<RFAB__Qualification__c>();
//             List<Object> educationData = (List<Object>) parsedJson.get('SegregatedQualification');

//             if (educationData != null) {
//                 for (Object eduObj : educationData) {
//                     Map<String, Object> eduMap = (Map<String, Object>) eduObj;
//                     Map<String, Object> degreeMap = (Map<String, Object>) eduMap.get('Degree');
//                     Map<String, Object> institutionMap = (Map<String, Object>) eduMap.get('Institution');

//                     // **Extract Institute Name**
//                     String institutionName = (institutionMap != null && institutionMap.containsKey('Name')) 
//                         ? (String) institutionMap.get('Name') 
//                         : 'Unknown Institute';

//                     // Extract Specialization
//                     List<Object> specializationList = (List<Object>) degreeMap.get('Specialization');
//                     String specialization = (specializationList != null && !specializationList.isEmpty()) 
//                         ? String.valueOf(specializationList.get(0)) 
//                         : null;

//                     educationList.add(new RFAB__Qualification__c(
//                         RFAB__Contact_Name__c = newContact.Id,
//                         Degree_Name__c = (String) degreeMap.get('DegreeName'),
//                         RFAB__College_Name__c = institutionName,
//                         Specialization__c = specialization,
//                         RFAB__Qualification_Start_Date__c = safeDateConversion(eduMap.get('StartDate')),
//                         RFAB__Qualification_End_Date__c = safeDateConversion(eduMap.get('EndDate'))
//                     ));
//                 }
//                 if (!educationList.isEmpty()) {
//                     insert educationList;
//                 }
//             }

//             return 'Resume data successfully processed and stored in Salesforce!';
//         } catch (Exception e) {
//             System.debug('Error processing JSON: ' + e.getMessage());
//             return 'Error processing JSON: ' + e.getMessage();
//         }
//     }

//     // **Safe Date Conversion Method**
//     private static Date safeDateConversion(Object dateValue) {
//         if (dateValue == null || String.valueOf(dateValue).trim() == '') {
//             return null;
//         }
//         try {
//             return Date.valueOf(String.valueOf(dateValue));
//         } catch (Exception e) {
//             System.debug('Invalid Date Format: ' + dateValue);
//             return null;
//         }
//     }




// public with sharing class RChilliIntegration {
//     @AuraEnabled
//     public static String uploadResumeToRChilli(String contentDocumentId) {
//         try {
//             System.debug('enter try block');
//             if (!Schema.sObjectType.ContentVersion.isAccessible()) {
//                 throw new SecurityException('No access to ContentVersion object');
//             }

//             ContentVersion fileRecord = [
//                 SELECT Id, VersionData, Title 
//                 FROM ContentVersion 
//                 WHERE ContentDocumentId = :contentDocumentId 
//                 ORDER BY CreatedDate DESC 
//                 LIMIT 1
//             ];
//             System.debug('fileRecord: ' + fileRecord);

//             String base64Resume = EncodingUtil.base64Encode(fileRecord.VersionData);
//             System.debug('base64Resume: ' + base64Resume);

//             Map<String, Object> requestBody = new Map<String, Object>{
//                 'filedata' => base64Resume,
//                 'filename' => fileRecord.Title,
//                 'userkey' => System.Label.USERKEY,
//                 'version' => '8.0.0',
//                 'subuserid' => System.Label.subuserid
//             };
//             System.debug('requestBody: ' + requestBody);
//             String jsonBody = JSON.serialize(requestBody);
//             System.debug('jsonBody: ' + jsonBody);

//             HttpRequest req = new HttpRequest();
//             req.setEndpoint('https://rest.rchilli.com/RChilliParser/Rchilli/parseResumeBinary'); 
//             req.setMethod('POST');
//             req.setHeader('Content-Type', 'application/json');
//             req.setBody(jsonBody);

//             Http http = new Http();
//             HTTPResponse res = http.send(req);
//             System.debug('Response: ' + res.getBody());

//             if (res.getStatusCode() == 200) {
//                 return processJsonResponse(res.getBody());
//             } else {
//                 System.debug('Error: ' + res.getBody());
//                 return 'Error: ' + res.getBody();
//             }
//         } catch (QueryException e) {
//             return 'Error: No file found for the given ID';
//         } catch (Exception e) {
//             return 'Error: ' + e.getMessage();
//         }
//     }

//     private static String processJsonResponse(String jsonResponse) {
//         try {
//             Map<String, Object> rootJson = (Map<String, Object>) JSON.deserializeUntyped(jsonResponse);
//             Map<String, Object> parsedJson = (Map<String, Object>) rootJson.get('ResumeParserData');

//             // Extract Name Details
//             Map<String, Object> nameData = (Map<String, Object>) parsedJson.get('Name');
//             String firstName = nameData != null ? (String) nameData.get('FirstName') : null;
//             String lastName = nameData != null ? (String) nameData.get('LastName') : 'Unknown';

//             // Extract Gender & Nationality
//             String gender = (String) parsedJson.get('Gender');

//             if (gender == null || gender.trim() == '') {
//                 gender = 'Other';
//             }

//             String nationality = (String) parsedJson.get('Nationality');

//             // Extract Email
//             List<Object> emailList = (List<Object>) parsedJson.get('Email');
//             String email = (emailList != null && !emailList.isEmpty()) 
//                 ? (String) ((Map<String, Object>) emailList.get(0)).get('EmailAddress') 
//                 : null;

//             // Extract Phone
//             List<Object> phoneList = (List<Object>) parsedJson.get('PhoneNumber');
//             String phone = (phoneList != null && !phoneList.isEmpty()) 
//                 ? (String) ((Map<String, Object>) phoneList.get(0)).get('FormattedNumber') 
//                 : null;

//             // Convert Date
//             Date dateOfBirth = safeDateConversion(parsedJson.get('DateOfBirth'));

//             // Insert Contact Record
//             Contact newContact = new Contact(
//                 FirstName = firstName,
//                 LastName = lastName,
//                 Email = email,
//                 Phone = phone,
//                 Birthdate = dateOfBirth,
//                 RFAB__Gender__c = gender,
//                 Nationality__c = nationality
//             );
//             System.debug('newContact: ' + newContact);
//             insert newContact;

//             // Insert Education Records
//             List<RFAB__Qualification__c> educationList = new List<RFAB__Qualification__c>();
//             List<Object> educationData = (List<Object>) parsedJson.get('SegregatedQualification');

//             if (educationData != null) {
//                 for (Object eduObj : educationData) {
//                     Map<String, Object> eduMap = (Map<String, Object>) eduObj;
//                     Map<String, Object> degreeMap = (Map<String, Object>) eduMap.get('Degree');
//                     Map<String, Object> institutionMap = (Map<String, Object>) eduMap.get('Institution');

//                     String institutionName = null;
//                     if (institutionMap != null && institutionMap.containsKey('Name')) {
//                         institutionName = (String) institutionMap.get('Name');
//                     }

//                     if (institutionName == null || institutionName.trim() == '') {
//                         System.debug('Skipping education record: Missing Institute Name');
//                         continue;
//                     }

//                     List<Object> specializationList = (List<Object>) degreeMap.get('Specialization');
//                     String specialization = (specializationList != null && !specializationList.isEmpty()) 
//                         ? String.valueOf(specializationList.get(0)) 
//                         : null;

//                     educationList.add(new RFAB__Qualification__c(
//                         RFAB__Contact_Name__c = newContact.Id,
//                         Degree_Name__c = (String) degreeMap.get('DegreeName'),
//                         RFAB__College_Name__c = institutionName,
//                         Specialization__c = specialization,
//                         RFAB__Qualification_Start_Date__c = safeDateConversion(eduMap.get('StartDate')),
//                         RFAB__Qualification_End_Date__c = safeDateConversion(eduMap.get('EndDate'))
//                     ));
//                 }
                
//                 if (!educationList.isEmpty()) {
//                     insert educationList;
//                 }
//             }

//             // Insert Skills
//             List<RFAB__Skill__c> skillList = new List<RFAB__Skill__c>();
//             List<Object> skillsData = (List<Object>) parsedJson.get('SegregatedSkill');

//             if (skillsData != null) {
//                 System.debug('enter skillsData if');
//                 for (Object skillObj : skillsData) {
//                     Map<String, Object> skillMap = (Map<String, Object>) skillObj;
//                     String experienceMonths = '0'; // Default to 0 if missing

//                     if (skillMap.get('ExperienceInMonths') != null) {
//                         experienceMonths = String.valueOf(skillMap.get('ExperienceInMonths'));
//                     }

//                     skillList.add(new RFAB__Skill__c(
//                         RFAB__Contact_Name__c = newContact.Id,
//                         RFAB__Title__c = (String) skillMap.get('FormattedName'),
//                         RFAB__Skill_Type__c = (String) skillMap.get('Type'),
//                         Experience_Month__c = experienceMonths 
//                     ));
//                 }
//                 if (!skillList.isEmpty()) {
//                     System.debug('insert skillList');
//                     insert skillList;
//                 }
//             }
//             return 'Resume data successfully processed and stored in Salesforce!';
//         } catch (Exception e) {
//             System.debug('Error processing JSON: ' + e.getMessage());
//             return 'Error processing JSON: ' + e.getMessage();
//         }
//     }

//     // Safe date conversion helper method
//     private static Date safeDateConversion(Object dateValue) {
//         if (dateValue == null || String.valueOf(dateValue).trim() == '') {
//             return null;
//         }
//         try {
//             return Date.valueOf(String.valueOf(dateValue));
//         } catch (Exception e) {
//             System.debug('Invalid Date Format: ' + dateValue);
//             return null;
//         }
//     }
// }


// // private static String processJsonResponse(String jsonResponse) {
//     //     try {
//     //         Map<String, Object> parsedJson = (Map<String, Object>) JSON.deserializeUntyped(jsonResponse);

//     //         Contact newContact = new Contact(
//     //             FirstName = (String) parsedJson.get('FirstName'),
//     //             LastName = (String) parsedJson.get('LastName'),
//     //             Email = (String) parsedJson.get('Email'),
//     //             Phone = (String) parsedJson.get('Phone'),
//     //             // MailingAddress = (String) parsedJson.get('Address'),
//     //             Birthdate = Date.valueOf((String) parsedJson.get('DateOfBirth')),
//     //             RFAB__Gender__c = (String) parsedJson.get('Gender'),
//     //             Nationality__c = (String) parsedJson.get('Nationality')
//     //         );
//     //         insert newContact;

//     //         List<RFAB__Qualification__c> educationList = new List<RFAB__Qualification__c>();
//     //         List<Object> educationData = (List<Object>) parsedJson.get('Education');
//     //         for (Object eduObj : educationData) {
//     //             Map<String, Object> eduMap = (Map<String, Object>) eduObj;
//     //             educationList.add(new RFAB__Qualification__c(
//     //                 RFAB__Contact_Name__c = newContact.Id,
//     //                 Degree_Name__c = (String) eduMap.get('Degree'),
//     //                 RFAB__College_Name__c = (String) eduMap.get('Institution'),
//     //                 Specialization__c = (String) eduMap.get('Specialization'),
//     //                 RFAB__Qualification_Start_Date__c = Date.valueOf((String) eduMap.get('StartDate')),
//     //                 RFAB__Qualification_End_Date__c = Date.valueOf((String) eduMap.get('EndDate'))
//     //             ));
//     //         }
//     //         insert educationList;

//     //         List<RFAB__Experience__c> experienceList = new List<RFAB__Experience__c>();
//     //         List<Object> experienceData = (List<Object>) parsedJson.get('WorkExperience');
//     //         for (Object expObj : experienceData) {
//     //             Map<String, Object> expMap = (Map<String, Object>) expObj;
//     //             experienceList.add(new RFAB__Experience__c(
//     //                 RFAB__Contact__c = newContact.Id,
//     //                 RFAB__Company_Name__c = (String) expMap.get('CompanyName'),
//     //                 Name = (String) expMap.get('JobTitle'),
//     //                 RFAB__Company_Place__c = (String) expMap.get('JobLocation'),
//     //                 RFAB__Experience_Start_Date__c = Date.valueOf((String) expMap.get('StartDate')),
//     //                 RFAB__Experience_End_Date__c = Date.valueOf((String) expMap.get('EndDate'))
//     //             ));
//     //         }
//     //         insert experienceList;

//     //         List<RFAB__Skill__c> skillList = new List<RFAB__Skill__c>();
//     //         List<Object> skillsData = (List<Object>) parsedJson.get('Skills');
//     //         for (Object skillObj : skillsData) {
//     //             Map<String, Object> skillMap = (Map<String, Object>) skillObj;
//     //             skillList.add(new RFAB__Skill__c(
//     //                 RFAB__Contact_Name__c = newContact.Id,
//     //                 RFAB__Title__c = (String) skillMap.get('SkillName'),
//     //                 RFAB__Skill_Type__c = (String) skillMap.get('SkillType'),
//     //                 Experience_Month__c = (String) skillMap.get('ExperienceMonths')
//     //             ));
//     //         }
//     //         insert skillList;

//     //         List<RFAB__Certification__c> certificationList = new List<RFAB__Certification__c>();
//     //         List<Object> certificationData = (List<Object>) parsedJson.get('Certifications');
//     //         for (Object certObj : certificationData) {
//     //             Map<String, Object> certMap = (Map<String, Object>) certObj;
//     //             certificationList.add(new RFAB__Certification__c(
//     //                 RFAB__Contact__c = newContact.Id,
//     //                 Name = (String) certMap.get('CertificateName'),
//     //                 RFAB__Issuing_Authority_Name__c = (String) certMap.get('IssuingAuthority'),
//     //                 Issue_Date__c = Date.valueOf((String) certMap.get('IssueDate'))
//     //             ));
//     //         }
//     //         insert certificationList;

//     //         return 'Resume data successfully processed and stored in Salesforce!';
//     //     } catch (Exception e) {
//     //         System.debug('Error processing JSON: ' + e.getMessage());
//     //         return 'Error processing JSON: ' + e.getMessage();
//     //     }
//     // }


this is the json i get from external endpoint
({
  "ResumeParserData": {
    "Name": {
      "FullName": “Name”,
      "TitleName": "",
      "FirstName": “FirstName”,
      "MiddleName": "",
      "LastName": “LastName”,
      "FormattedName": “Name”,
      "ConfidenceScore": 5
    },
    "DateOfBirth": "",
    "Gender": "",
    "FatherName": "",
    "MotherName": "",
    "MaritalStatus": "",
    "Nationality": "",
    "LanguageKnown": [
      {
        "Language": "English",
        "LanguageCode": "en"
      },
      {
        "Language": "Tamil",
        "LanguageCode": "ta"
      }
    ],
    "Email": [
      {
        "EmailAddress": "gmail.com",
        "ConfidenceScore": 10
      }
    ],
    "PhoneNumber": [
      {
        "Number": "+9143534534534”,
        "ISDCode": "+91",
        "OriginalNumber": “43534534534”,
        "FormattedNumber": "+91 43534534534”,
        "Type": "Phone",
        "ConfidenceScore": 10
      }
    ],
    "Address": [
      {
        "Street": “43534, Street,
        "City": “t”vl,
        "State": "Tamil Nadu",
        "StateIsoCode": "IN-TN",
        "Country": "India",
        "CountryCode": {
          "IsoAlpha2": "IN",
          "IsoAlpha3": "IND",
          "UNCode": "356"
        },
        "ZipCode": "",
        "FormattedAddress": "43534, Street",
        "Type": "Present",
        "ConfidenceScore": 7
      }
    ],
    "Category": "Information",
    "SubCategory": "Software Developers and Programmers",
    "CurrentSalary": {
      "Amount": ""
    },
    "ExpectedSalary": {
      "Amount": ""
    },
    "Qualification": “master of computer application",
    "SegregatedQualification": [
      {
        "Institution": {
          "Name": "",
          "Location": {
            "City": "",
            "State": "",
            "Country": "",
            "CountryCode": {
              "UNCode": ""
            }
          }
        },
        "Degree": {
          "DegreeName": "Bachelor of Business Administration",
          "Specialization": [
            "Logistics",
            "Marine Science"
          ]
        },
        "FormattedDegreePeriod": "2020 to 2023",
        "StartDate": "01/01/2020",
        "EndDate": "31/12/2023",
        "Aggregate": {
          "Value": "77.57",
          "MeasureType": "Percentage"
        }
      },
      {
        "Institution": {
          "Name": " Higher Secondary School",
          "Location": {
            "City": "Tirunelveli",
            "State": "Tamil Nadu",
            "Country": "India",
            "CountryCode": {
              "UNCode": "IND"
            }
          }
        },
        "Degree": {
          "DegreeName": "Higher Secondary",
          "Specialization": [],
        },
        "FormattedDegreePeriod": "2019",
        "StartDate": "",
        "EndDate": "31/12/2019",
        "Aggregate": {
          "Value": "69",
          "MeasureType": "Percentage"
        }
      },
      {
        "Institution": {
          "Name": "Higher Secondary School",
          "Type": "School",
          "Location": {
            "City": "",
            "State": "",
            "Country": "",
            "CountryCode": {
              "UNCode": ""
            }
          }
        },
        "Degree": {
          "DegreeName": "Secondary Education",
          "Specialization": [
            "Secondary Education"
          ]
        },
        "FormattedDegreePeriod": "2017",
        "StartDate": "",
        "EndDate": "31/12/2017",
        "Aggregate": {
          "Value": "83",
          "MeasureType": "Percentage"
        }
      }
    ],
    "SegregatedSkill": [
      {
        "Type": "BehaviorSkills",
        "Skill": "Enthusiastic",
        "FormattedName": "Energetic",
        "Evidence": "SummarySection",
        "ExperienceInMonths": 0
      },
      {
        "Type": "BehaviorSkills",
        "Skill": "Comprehensive",
        "FormattedName": "Comprehensive",
        "Evidence": "Others",
        "ExperienceInMonths": 0
      },
      {
        "Type": "SoftSkill",
        "Skill": "Problem-Solving",
        "FormattedName": "Problem Solving",
        "Evidence": "SummarySection",
        "ExperienceInMonths": 0
      },
      {
        "Type": "OperationalSkill",
        "Skill": "Software Development",
        "FormattedName": "Software Development",
        "Evidence": "SummarySection",
        "ExperienceInMonths": 0
      },
      {
        "Type": "OperationalSkill",
        "Skill": "Programming",
        "FormattedName": "Programming Language",
        "Evidence": "SkillSection",
        "ExperienceInMonths": 0
      }
    ],
    "Experience": "PROJECT\rPROJECTS \r \r Taxi management system \r Module developed a comprehensive taxi management \r system to streamline taxi operations by odoo. It includes \r models of booking,accounts,workers,customers with \r related functionalities. \r \r Bank management system \r The program demonstrates creating accounts, depositing \r and withdrawing money, transaction to other accounts, \r transaction history, and showing account details.",
    "SegregatedExperience": [
      {
        "Employer": {
          "EmployerName": "",
          "FormattedName": "",
          "ConfidenceScore": 0
        },
        "JobProfile": {
          "Title": "",
          "FormattedName": "",
          "Alias": "",
          "RelatedSkills": [],
          "ConfidenceScore": 0
        },
        "Location": {
          "City": "",
          "State": "",
          "Country": "",
          "CountryCode": {
            "UNCode": ""
          }
        },
        "JobPeriod": "",
        "FormattedJobPeriod": "",
        "StartDate": "",
        "EndDate": "",
        "IsCurrentEmployer": "false",
        "JobDescription": "",
        "Projects": [
          {
            "UsedSkills": "",
            "ProjectName": "",
            "TeamSize": ""
          }
        ]
      }
    ],
    "CurrentEmployer": "",
    "JobProfile": "",
    "WorkedPeriod": {
      "TotalExperienceInMonths": "",
      "TotalExperienceInYear": "",
      "TotalExperienceRange": ""
    },
    "GapPeriod": "",
    "AverageStay": "",
    "LongestStay": "",
    "Summary": "Enthusiastic Junior Software Developer with a passion for coding and \r problem-solving. Proficient in programming, web designing and managing \r databases. Eager to contribute to innovative projects. Seeking an \r opportunity to launch career in software development and grow within a \r supportive team environment.",
    "ExecutiveSummary": "",
    "ManagementSummary": "Al does not have any management level experience in the resume.",
    "Coverletter": "",
    "Publication": "",
    "SegregatedPublication": [],
    "CurrentLocation": [],
    "PreferredLocation": [],
    "Availability": "",
    "Hobbies": "Research and \r Development \r Problem-solving \r Chess \r Kabaddi",
    "Objectives": "",
    "Achievements": "",
    "SegregatedAchievement": [],
    "References": "",
    "CustomFields": "Parsing Time : 597ms",
    "EmailInfo": {
      "EmailTo": " ",
      "EmailBody": " ",
      "EmailReplyTo": " ",
      "EmailSignature": " ",
      "EmailFrom": " ",
      "EmailSubject": " ",
      "EmailCC": " "
    },
    "Recommendations": [
      {
        "PersonName": "",
        "CompanyName": "",
        "Relation": "",
        "PositionTitle": "",
        "Description": ""
      }
    ],
    "DetailResume": "details",
    "HtmlResume": "<html></html>",
    "CandidateImage": {
      "CandidateImageData": "",
      "CandidateImageFormat": ""
    },
    "TemplateOutput": {
      "TemplateOutputData": "",
      "TemplateOutputFileName": ""
    },
    "ApiInfo": {
      "Metered": "No",
      "CreditLeft": "4984.0",
      "AccountExpiryDate": "02/09/2025 12:31:11",
      "BuildVersion": "8.0.0.2025.03.10"
    }
  }
})