public with sharing class RChilliIntegrationNew {
    
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
            System.debug('Base64 Resume length: ' + base64Resume.length());

            Map<String, Object> requestBody = new Map<String, Object>{
                'filedata' => base64Resume,
                'filename' => fileRecord.Title,
                'userkey' => System.Label.USERKEY,
                'version' => '8.0.0',
                'subuserid' => System.Label.SUBUSERID
            };
            String jsonBody = JSON.serialize(requestBody);
            System.debug('Request Body prepared');

            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://rest.rchilli.com/RChilliParser/Rchilli/parseResumeBinary'); 
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(jsonBody);
            req.setTimeout(120000);

            Http http = new Http();
            HTTPResponse res = http.send(req);
            System.debug('Response status code: ' + res.getStatusCode());

            if (res.getStatusCode() == 200) {
                return processJsonResponse(res.getBody());
            } else {
                System.debug('Error: ' + res.getBody());
                return 'Error: ' + res.getStatusCode() + ' - ' + res.getBody();
            }
        } catch (QueryException e) {
            System.debug('QueryException: ' + e.getMessage());
            return 'Error: No file found for the given ID';
        } catch (Exception e) {
            System.debug('Exception: ' + e.getMessage() + ' at line: ' + e.getLineNumber());
            return 'Error: ' + e.getMessage();
        }
    }

    private static String processJsonResponse(String jsonResponse) {
        try {
            jsonResponse = jsonResponse.replace('({', '{').replace('})', '}');
            
            Map<String, Object> rootJson = (Map<String, Object>) JSON.deserializeUntyped(jsonResponse);
            Map<String, Object> parsedJson = (Map<String, Object>) rootJson.get('ResumeParserData');
            
            Contact newContact = createContactFromJson(parsedJson);
            if (Schema.sObjectType.Contact.isCreateable()) {
                insert newContact;
            } else {
                throw new SecurityException('No create access to Contact object');
            }
            
            List<RFAB__Qualification__c> educationList = createEducationRecords(parsedJson, newContact.Id);
            if (!educationList.isEmpty()) {
                if (Schema.sObjectType.RFAB__Qualification__c.isCreateable()) {
                    insert educationList;
                } else {
                    throw new SecurityException('No create access to RFAB__Qualification__c object');
                }
            }
            
            List<RFAB__Skill__c> skillsList = createSkillRecords(parsedJson, newContact.Id);
            if (!skillsList.isEmpty()) {
                if (Schema.sObjectType.RFAB__Skill__c.isCreateable()) {
                    insert skillsList;
                } else {
                    throw new SecurityException('No create access to RFAB__Skill__c object');
                }
            }

            List<RFAB__Experience__c> experienceList = createExperienceRecords(parsedJson, newContact.Id);
            if (!experienceList.isEmpty()) {
                if (Schema.sObjectType.RFAB__Experience__c.isCreateable()) {
                    insert experienceList;
                } else {
                    throw new SecurityException('No create access to RFAB__Experience__c object');
                }
            }

            List<RFAB__Certification__c> certificationList = createCertificationRecords(parsedJson, newContact.Id);
            if (!certificationList.isEmpty()) {
                if (Schema.sObjectType.RFAB__Certification__c.isCreateable()) {
                    insert certificationList;
                } else {
                    throw new SecurityException('No create access to RFAB__Certification__c object');
                }
            }

            // For publication
            // List<RFAB__Publication__c> publicationList = createPublicationRecords(parsedJson, newContact.Id);
            // if (!publicationList.isEmpty()) {
            //     if (Schema.sObjectType.RFAB__Publication__c.isCreateable()) {
            //         insert publicationList;
            //     } else {
            //         throw new SecurityException('No create access to RFAB__Publication__c object');
            //     }
            // }

            // For achievement
            List<RFAB__Award__c> achievementList = createAchievementRecords(parsedJson, newContact.Id);
            if (!achievementList.isEmpty()) {
                if (Schema.sObjectType.RFAB__Award__c.isCreateable()) {
                    insert achievementList;
                } else {
                    throw new SecurityException('No create access to RFAB__Award__c object');
                }
            }
            
            String description = buildContactDescription(parsedJson);
            if (String.isNotBlank(description)) {
                newContact.Description = description;
                if (Schema.sObjectType.Contact.isUpdateable()) {
                    update newContact;
                } else {
                    throw new SecurityException('No update access to Contact object');
                }
            }
            
            return 'Resume data successfully processed and stored in Salesforce!';
        } catch (Exception e) {
            System.debug('Error processing JSON: ' + e.getMessage() + ' at line: ' + e.getLineNumber());
            return 'Error processing JSON: ' + e.getMessage();
        }
    }
    
    private static Contact createContactFromJson(Map<String, Object> parsedJson) {
        Map<String, Object> nameData = (Map<String, Object>) parsedJson.get('Name');
        String firstName = nameData != null ? (String) nameData.get('FirstName') : '';
        String middle = nameData != null ? (String) nameData.get('MiddleName') : '';
        String last = nameData != null ? (String) nameData.get('LastName') : 'Unknown';
        String lastName = middle + ' ' + last;
        
        String gender = (String) parsedJson.get('Gender');
        if (String.isBlank(gender)) {
            gender = 'Not Specified';
        }

        // fathername and mothername
        String fatherName = (String) parsedJson.get('FatherName');
        String motherName = (String) parsedJson.get('MotherName');
        if (String.isBlank(fatherName)) {
            fatherName = '';
        }

        if (String.isBlank(motherName)) {
            motherName = '';
        }
        
        String nationality = (String) parsedJson.get('Nationality');
        
        List<Object> emailList = (List<Object>) parsedJson.get('Email');
        String email = (emailList != null && !emailList.isEmpty()) 
            ? (String) ((Map<String, Object>) emailList.get(0)).get('EmailAddress') : '';
        
        List<Object> phoneList = (List<Object>) parsedJson.get('PhoneNumber');
        String phone = (phoneList != null && !phoneList.isEmpty()) 
            ? (String) ((Map<String, Object>) phoneList.get(0)).get('FormattedNumber') : '';
        
        Date dateOfBirth = safeDateConversion(parsedJson.get('DateOfBirth'));
        
        List<Object> addressList = (List<Object>) parsedJson.get('Address');
        String street = '';
        String city = '';
        String state = '';
        String country = '';
        String postalCode = '';
        
        if (addressList != null && !addressList.isEmpty()) {
            Map<String, Object> addressData = (Map<String, Object>) addressList.get(0);
            street = (String) addressData.get('Street');
            city = (String) addressData.get('City');
            state = (String) addressData.get('State');
            country = (String) addressData.get('Country');
            postalCode = (String) addressData.get('ZipCode');
        }
        
        List<Object> languageList = (List<Object>) parsedJson.get('LanguageKnown');
        String languages = '';
        
        if (languageList != null && !languageList.isEmpty()) {
            List<String> langNames = new List<String>();
            for (Object langObj : languageList) {
                Map<String, Object> langMap = (Map<String, Object>) langObj;
                String langName = (String) langMap.get('Language');
                if (String.isNotBlank(langName)) {
                    langNames.add(langName);
                }
            }
            languages = String.join(langNames, ',');
        }
        
        String maritalStatus = (String) parsedJson.get('MaritalStatus');

        Decimal expectedSalary = 0;
        Decimal currentSalary = 0;

        if (parsedJson.containsKey('ExpectedSalary')) {
            Map<String, Object> expectedSalaryData = (Map<String, Object>) parsedJson.get('ExpectedSalary');
            if (expectedSalaryData != null && expectedSalaryData.containsKey('Amount')) {
                Object amountObj = expectedSalaryData.get('Amount');
                if (amountObj != null) {
                    String AmountValue = String.valueOf(amountObj);
                    Decimal amountDecimal = AmountValue != '' ? Decimal.valueOf(AmountValue) : 0;
                    expectedSalary = amountDecimal.setScale(0);
                }
            }
        }

        if (parsedJson.containsKey('CurrentSalary')) {
            Map<String, Object> currentSalaryData = (Map<String, Object>) parsedJson.get('CurrentSalary');
            if (currentSalaryData != null && currentSalaryData.containsKey('Amount')) {
                Object amountObj = currentSalaryData.get('Amount');
                if (amountObj != null) {
                    String AmountValue = String.valueOf(amountObj);
                    Decimal amountDecimal = AmountValue != '' ? Decimal.valueOf(AmountValue) : 0;
                    // Decimal amountDecimal = Decimal.valueOf(String.valueOf(amountObj));
                    currentSalary = amountDecimal.setScale(0);
                }
            }
        }

        Contact newContact = new Contact(
            FirstName = firstName,
            LastName = lastName,
            Email = email,
            Phone = phone,
            Birthdate = dateOfBirth,
            RFAB__Gender__c = gender,
            Nationality__c = nationality,
            MailingStreet = street,
            MailingCity = city,
            MailingState = state,
            MailingCountry = country,
            MailingPostalCode = postalCode,
            // RFAB__Marital_Status__c = maritalStatus,
            Languages__c = languages,
            RFAB__Expected_CTC__c = expectedSalary,
            RFAB__Current_CTC__c = currentSalary
        );
        
        return newContact;
    }
    
    private static List<RFAB__Qualification__c> createEducationRecords(Map<String, Object> parsedJson, Id contactId) {
        List<RFAB__Qualification__c> educationList = new List<RFAB__Qualification__c>();
        List<Object> educationData = (List<Object>) parsedJson.get('SegregatedQualification');
        
        if (educationData != null) {
            for (Object eduObj : educationData) {
                Map<String, Object> eduMap = (Map<String, Object>) eduObj;
                
                Map<String, Object> institutionMap = (Map<String, Object>) eduMap.get('Institution');
                String institutionName = 'Unknown Institute';
                if (institutionMap != null && institutionMap.containsKey('Name') && 
                    institutionMap.get('Name') != null && String.valueOf(institutionMap.get('Name')).trim() != '') {
                    institutionName = String.valueOf(institutionMap.get('Name'));
                }
                
                String institutionCity = '';
                String institutionState = '';
                String institutionCountry = '';
                
                if (institutionMap != null && institutionMap.containsKey('Location')) {
                    Map<String, Object> locationMap = (Map<String, Object>) institutionMap.get('Location');
                    if (locationMap != null) {
                        institutionCity = String.valueOf(locationMap.get('City'));
                        institutionState = String.valueOf(locationMap.get('State'));
                        institutionCountry = String.valueOf(locationMap.get('Country'));
                    }
                }
                
                Map<String, Object> degreeMap = (Map<String, Object>) eduMap.get('Degree');
                String degreeName = 'Unknown Degree';
                if (degreeMap != null && degreeMap.containsKey('DegreeName') && degreeMap.get('DegreeName') != null && 
                    String.valueOf(degreeMap.get('DegreeName')).trim() != '') {
                    degreeName = String.valueOf(degreeMap.get('DegreeName'));
                }
                
                String specialization = '';
                if (degreeMap != null && degreeMap.containsKey('Specialization')) {
                    List<Object> specializationList = (List<Object>) degreeMap.get('Specialization');
                    if (specializationList != null && !specializationList.isEmpty()) {
                        List<String> specNames = new List<String>();
                        for (Object spec : specializationList) {
                            if (spec != null && String.valueOf(spec).trim() != '') {
                                specNames.add(String.valueOf(spec));
                            }
                        }
                        specialization = String.join(specNames, ',');
                    }
                }
                
                String aggValue = '';
                String aggregateType = '';
                if (eduMap.containsKey('Aggregate')) {
                    Map<String, Object> aggregateMap = (Map<String, Object>) eduMap.get('Aggregate');
                    if (aggregateMap != null) {
                        aggValue = String.valueOf(aggregateMap.get('Value'));
                        // Decimal amountDecimal = AmountValue != '' ? Decimal.valueOf(AmountValue) : 0;
                        // Decimal aggregateValue = aggValue != '' ? Decimal.valueOf(aggValue) : 0;
                        // System.debug('Aggregate Value: ' + aggregateValue);
                        aggregateType = String.valueOf(aggregateMap.get('MeasureType'));
                    }
                }
                
                educationList.add(new RFAB__Qualification__c(
                    RFAB__Contact_Name__c = contactId,
                    Name = degreeName,
                    RFAB__College_Name__c = institutionName,
                    RFAB__Institute_Name__c = institutionName,
                    Specialization__c = specialization,
                    RFAB__Qualification_Start_Date__c = safeDateConversion(eduMap.get('StartDate')),
                    RFAB__Qualification_End_Date__c = safeDateConversion(eduMap.get('EndDate')),
                    RFAB__Institute_Place__c = institutionCity + ', ' + institutionState + ', ' + institutionCountry,
                    // GPA_Type__c = aggregateType
                    RFAB__CGPA_Mark__c = aggValue != null && aggValue != '' ? Decimal.valueOf(aggValue) : null
                ));
            }
        }
        
        return educationList;
    }

    private static List<RFAB__Experience__c> createExperienceRecords(Map<String, Object> parsedJson, Id contactId) {
        List<RFAB__Experience__c> experienceList = new List<RFAB__Experience__c>();
        List<Object> experienceData = (List<Object>) parsedJson.get('SegregatedExperience');

        Map<String, Object> workedPeriod = (Map<String, Object>) parsedJson.get('WorkedPeriod');
        Decimal totalExperienceInYear = 0;
        if (workedPeriod != null && workedPeriod.containsKey('TotalExperienceInYear') && workedPeriod.get('TotalExperienceInYear') != null) {
            String totalExperienceInYearStr = String.valueOf(workedPeriod.get('TotalExperienceInYear'));
            // Decimal amountDecimal = AmountValue != '' ? Decimal.valueOf(AmountValue) : 0;
            totalExperienceInYear = totalExperienceInYearStr != '' ? Decimal.valueOf(totalExperienceInYearStr) : 0;
        }

        if (experienceData != null) {
            for (Object expObj : experienceData) {
                Map<String, Object> expMap = (Map<String, Object>) expObj;
                
                Map<String, Object> employerMap = (Map<String, Object>) expMap.get('Employer');
                String companyName = 'Unknown Company';
                if (employerMap != null && employerMap.containsKey('EmployerName') && employerMap.get('EmployerName') != null) {
                    companyName = String.valueOf(employerMap.get('EmployerName'));
                }

                Map<String, Object> jobProfileMap = (Map<String, Object>) expMap.get('JobProfile');
                String jobTitle = 'Unknown Job Title';
                if (jobProfileMap != null && jobProfileMap.containsKey('Title') && jobProfileMap.get('Title') != null) {
                    jobTitle = String.valueOf(jobProfileMap.get('Title'));
                }

                Map<String, Object> locationMap = (Map<String, Object>) expMap.get('Location');
                String jobLocation = '';
                if (locationMap != null) {
                    jobLocation = String.valueOf(locationMap.get('City')) + ', ' +
                                String.valueOf(locationMap.get('State')) + ', ' +
                                String.valueOf(locationMap.get('Country'));
                }

                Date startDate = safeDateConversion(expMap.get('StartDate'));
                Date endDate = safeDateConversion(expMap.get('EndDate'));
                String isCurrent = String.valueOf(expMap.get('IsCurrentEmployer'));

                String jobDescription = String.valueOf(expMap.get('JobDescription'));

                experienceList.add(new RFAB__Experience__c(
                    RFAB__Contact__c = contactId,
                    RFAB__Company_Name__c = companyName,
                    Name = jobTitle,
                    RFAB__Company_Place__c = jobLocation,
                    RFAB__Experience_Start_Date__c = startDate,
                    RFAB__Experience_End_Date__c = endDate,
                    Current_Job__c = isCurrent,
                    RFAB__Project_Description__c = jobDescription,
                    RFAB__Experience_Year__c = totalExperienceInYear
                ));
            }
        }
        return experienceList;
    }

    private static List<RFAB__Certification__c> createCertificationRecords(Map<String, Object> parsedJson, Id contactId) {
        List<RFAB__Certification__c> certificationList = new List<RFAB__Certification__c>();
        List<Object> certificationData = (List<Object>) parsedJson.get('SegregatedCertification');
        
        if (certificationData != null) {
            for (Object certObj : certificationData) {
                Map<String, Object> certMap = (Map<String, Object>) certObj;
                
                String certName = (String) certMap.get('CertificationTitle');
                String certAuthority = (String) certMap.get('Authority');
                String certCode = (String) certMap.get('CertificationCode');
                String isExpiryStr = (String) certMap.get('IsExpiry');
                String certUrl = (String) certMap.get('CertificationUrl');
                Date startDate = safeDateConversion(certMap.get('StartDate'));
                Date endDate = safeDateConversion(certMap.get('EndDate'));
                
                if (String.isBlank(certName)) {
                    continue;
                }

                Boolean noExpiry = isExpiryStr != null && isExpiryStr.toLowerCase() == 'false';
                
                certificationList.add(new RFAB__Certification__c(
                    RFAB__Contact__c = contactId,
                    Name = certName,
                    RFAB__Issuing_Authority_Name__c = certAuthority,
                    RFAB__Reference_Number__c = certCode,
                    RFAB__No_Expiry_Date__c = noExpiry,
                    RFAB__Start_Date__c = startDate,
                    RFAB__End_Date__c = endDate,
                    RFAB__Issuing_Authority_Website__c = certUrl
                ));
            }
        }
        
        return certificationList;
    }

    // private static List<RFAB__Publication__c> createPublicationRecords(Map<String, Object> parsedJson, Id contactId) {
    //     List<RFAB__Publication__c> publicationList = new List<RFAB__Publication__c>();
    //     List<Object> publicationData = (List<Object>) parsedJson.get('SegregatedPublication');
        
    //     if (publicationData != null) {
    //         for (Object pubObj : publicationData) {
    //             Map<String, Object> pubMap = (Map<String, Object>) pubObj;
                
    //             String title = (String) pubMap.get('PublicationTitle');
    //             String publisher = (String) pubMap.get('Publisher');
    //             String url = (String) pubMap.get('PublicationUrl');
                
    //             if (String.isBlank(title)) {
    //                 continue;
    //             }
                
    //             publicationList.add(new RFAB__Publication__c(
    //                 RFAB__Contact_Name__c = contactId,
    //                 Name = title,
    //                 RFAB__Publisher_Name__c = publisher,
    //                 RFAB__Publisher_Url__c = url
    //             ));
    //         }
    //     }
    //     return publicationList;
    // }

    private static List<RFAB__Award__c> createAchievementRecords(Map<String, Object> parsedJson, Id contactId) {
        List<RFAB__Award__c> achievementList = new List<RFAB__Award__c>();
        List<Object> achievementData = (List<Object>) parsedJson.get('SegregatedAchievement');
        
        if (achievementData != null) {
            for (Object achObj : achievementData) {
                Map<String, Object> achMap = (Map<String, Object>) achObj;
                
                String title = (String) achMap.get('AwardTitle');
                String description = (String) achMap.get('Description');
                String issuer = (String) achMap.get('Issuer');
                String issueDate = (String) achMap.get('IssuingDate');
                
                if (String.isBlank(title)) {
                    continue;
                }
                
                achievementList.add(new RFAB__Award__c(
                    RFAB__Contact__c = contactId,
                    Name = title,
                    Description__c = description,
                    Issuer_Name__c = issuer,
                    Issue_Date__c = issueDate
                ));
            }
        }
        return achievementList;
    }

    private static List<RFAB__Skill__c> createSkillRecords(Map<String, Object> parsedJson, Id contactId) {
        List<RFAB__Skill__c> skillsList = new List<RFAB__Skill__c>();
        List<Object> skillsData = (List<Object>) parsedJson.get('SegregatedSkill');
        
        if (skillsData != null) {
            for (Object skillObj : skillsData) {
                Map<String, Object> skillMap = (Map<String, Object>) skillObj;
                
                String skillName = (String) skillMap.get('Skill');
                String skillType = (String) skillMap.get('Type');
                String formattedName = (String) skillMap.get('FormattedName');
                // String experience = String.valueOf(skillMap.get('ExperienceInMonths')),
                
                if (String.isBlank(skillName)) {
                    continue;
                }
                
                String mappedSkillType = mapSkillType(skillType);
                
                skillsList.add(new RFAB__Skill__c(
                    RFAB__Contact_Name__c = contactId,
                    RFAB__Title__c = formattedName != null ? formattedName : skillName,
                    RFAB__Skill_Type__c = mappedSkillType,
                    Experience_Month__c = String.valueOf(skillMap.get('ExperienceInMonths')),
                    Skill_Name__c = skillName
                ));
            }
        }
        
        String hobbies = (String) parsedJson.get('Hobbies');
        if (String.isNotBlank(hobbies)) {
            List<String> hobbyList = hobbies.split('\r|\n');
            for (String hobby : hobbyList) {
                hobby = hobby.trim();
                if (String.isNotBlank(hobby)) {
                    skillsList.add(new RFAB__Skill__c(
                        RFAB__Contact_Name__c = contactId,
                        RFAB__Title__c = hobby,
                        RFAB__Skill_Type__c = 'Hobby'
                    ));
                }
            }
        }        
        return skillsList;
    }
    
    private static String mapSkillType(String rchilliSkillType) {
        switch on rchilliSkillType {
            when 'BehaviorSkills' {
                return 'Behavioral';
            }
            when 'SoftSkill' {
                return 'Soft';
            }
            when 'OperationalSkill' {
                return 'Technical';
            }
            when else {
                return 'Other';
            }
        }
    }
    
    private static String buildContactDescription(Map<String, Object> parsedJson) {
        List<String> sections = new List<String>();
        
        String summary = (String) parsedJson.get('Summary');
        if (String.isNotBlank(summary)) {
            sections.add('SUMMARY:\n' + summary.trim());
        }
        
        String experience = (String) parsedJson.get('Experience');
        if (String.isNotBlank(experience)) {
            sections.add('EXPERIENCE:\n' + experience.trim());
        }
        
        String hobbies = (String) parsedJson.get('Hobbies');
        if (String.isNotBlank(hobbies)) {
            sections.add('HOBBIES:\n' + hobbies.trim());
        }
        
        String objectives = (String) parsedJson.get('Objectives');
        if (String.isNotBlank(objectives)) {
            sections.add('OBJECTIVES:\n' + objectives.trim());
        }
        
        return String.join(sections, '\n\n');
    }

    private static Date safeDateConversion(Object dateValue) {
        if (dateValue == null || String.valueOf(dateValue).trim() == '') {
            return null;
        }
        try {
            String dateStr = String.valueOf(dateValue);
            if (dateStr.contains('/')) {
                List<String> parts = dateStr.split('/');
                if (parts.size() == 3) {
                    Integer day = Integer.valueOf(parts[0]);
                    Integer month = Integer.valueOf(parts[1]);
                    Integer year = Integer.valueOf(parts[2]);
                    return Date.newInstance(year, month, day);
                }
            }
            return Date.valueOf(dateStr);
        } catch (Exception e) {
            System.debug('Invalid Date Format: ' + dateValue);
            return null;
        }
    }
}