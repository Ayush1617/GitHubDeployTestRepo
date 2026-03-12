/*
##################################################### 
# Created By (Date)   : Admin (22 Jul, 2025)
# Description         : This is a Data Factory class for test classes.
# Modifications Log   : 
* Ver    Date              Author         Modification
* 1.0    22 Jul, 2025      Admin          Initial Version
#####################################################
*/

@isTest
public class Recruitment_TestDataFactory {
    
/**
* @description  : Return a Candidate record with Name and Email.
* @param name   - Candidate name
* @param email  - Candidate email
* @return Candidate instance (not inserted)
*/
    public static Contact createCandidate(String name, String email) {
        // 1️⃣ Candidate Record Type Id fetch karo
    Id candidateRtId = Schema.SObjectType.Contact
        .getRecordTypeInfosByDeveloperName()
        .get('Candidate')
        .getRecordTypeId();
        system.debug('candidateRtId'+candidateRtId);
		Long ts = System.currentTimeMillis();
        return new Contact(
            LastName = name,
            Email = email,
            Date_of_Birth__c = Date.newInstance(1990, 1, 1),
            Phone = '99999' + Math.mod(ts, 100000),
            Current_Location__c = 'New York',
            Total_Experience__c = 5,
            Highest_Qualification__c = 'B.Tech',
            IsBillable__c=true,
            RecordTypeId = candidateRtId
            
        );
    }
    
/**
* @description  : Return a Project__c record with Description.
* @param description - Project description
* @return Project__c instance (not inserted)
*/
    public static Project__c createProject(String description) {
        return new Project__c(
            Description__c = description,
            Project_Name__c = 'test project',
            No_of_employees__c = 10,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(30),
            Budget__c = 50000,
            Actual_Cost__c = 20000,
            Active__c = true
        );
    }
    
/**
* @description  : Return a Recruiter record with Name and Email.
* @param name   - Recruiter name
* @param email  - Recruiter email
* @return Recruiter instance (not inserted)
*/
    public static Contact createRecruiter(String lastName, String email) {
		Id recruiterRtId = Schema.SObjectType.Contact
        .getRecordTypeInfosByDeveloperName()
        .get('Recruiter')
        .getRecordTypeId();
        return new Contact(
            LastName = lastName,
            Email = email,
            Phone = '9000000000',
			RecordTypeId = recruiterRtId
        );
    }
    
/**
* @description  : Return a Work_Order__c record with related Candidate, Project, and Recruiter.
* @param Id   - candidate Id
* @param Id   - project Id
* @param Id   - recruiter Id
* @return Work_Order__c instance (not inserted)
*/
    
    public static Work_Order__c createWorkOrder(Id candidateId, Id projectId, Id recruiterId) {
        return new Work_Order__c(
            Candidate_Name__c = candidateId,
            Project__c = projectId,
            Role_on_Project__c = 'Developer', 
            Recruiter_Name__c = recruiterId,
            Renewed__c = false,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addMonths(6),
            Status__c = 'Working', 
            Salary_Offered__c = 50000
        );
    }
    
/**
* @author (date): Admin (20 Aug, 2025)
* @description  : Return a Client record with sample data.
* @param name: Name for Client.
* @param email: Email for Client.
* @return Client instance (not inserted).
*/
    public static Account createClient(String name, String email) {
        
        // 1️⃣ Client Record Type Id fetch karo
        Id clientRtId = Schema.SObjectType.Account
            .getRecordTypeInfosByDeveloperName()
            .get('Client')
            .getRecordTypeId();
        // 2️⃣ Account record create karo
        Account acc = new Account(
            Name = name,
            Phone = '9999999999',
            Email__c = email,        // agar Person Account hai
            IsActive__c = true,         // custom field
            RecordTypeId = clientRtId
        );
        
        return acc;
    }
    
/**
* @author (date): Admin (20 Aug, 2025)
* @description  : Return a Job_Position__c record with sample data.
* @param client   - Related Client record (required).
* @param Project  - Related Project__c record (required).
* @return Job_Position__c instance (not inserted).
*/
    public static Job_Position__c createJobPosition(Account client, Project__c proj) {
        return new Job_Position__c(
            Job_Title__c = 'Salesforce Developer',
            Client_Name__c = client.Id,
            Employment_Type__c = 'Full-Time',
            Skills_Required__c = 'Salesforce Developer',
            Project__c = proj.Id
       
        );
    }
    
/**
* @author (date): Admin (20 Aug, 2025)
* @description  : Return an Interview__c record with sample data.
* @param candidate - Related Candidate record (required).
* @param jobPos    - Related Job_Position__c record (required).
* @return Interview__c instance (not inserted).
*/
    public static Interview__c createInterview(Contact candidate, Job_Position__c jobPos) {
        return new Interview__c(
            Candidate_Name__c = candidate.Id,
            Job_Position__c = jobPos.Id,                   
            Interview_Status__c = 'New',
            Feedback__c = 'The candidate demonstrated a clear understanding of the role and articulated their past experience in a structured and coherent manner. They were able to explain core concepts relevant to the position and provided practical examples from previous projects, indicating hands-on exposure. Communication was generally effective, with responses that were relevant and appropriately detailed, although some answers could benefit from deeper technical or analytical elaboration.'
        );
    }
    
/**
* @author (date): Admin (20 Aug, 2025)
* @description  : Return an Interview__c record with sample data.
* @param candidate - Related Candidate record (required).
* @param jobPos    - Related Job_Position__c record (required).
* @return Interview__c instance (not inserted).
*/
    public static Interview__c createInterviewWithoutRound(Contact candidate, Job_Position__c jobPos) {
        return new Interview__c(
            Candidate_Name__c = candidate.Id,
            Job_Position__c = jobPos.Id,                    
            Interview_Status__c = 'New',
            Feedback__c = 'Initial feedback'
        );
    }

/** 
* @author (date): Admin (20 Aug, 2025)
* @description  : Return an Client record with sample data.
* @param candidate - Related Candidate record (required).
* @param jobPos    - Related Job_Position__c record (required).
* @return Client instance.
*/
    public static Account createFlexClient(String name, String email) {
        Id candidateRecordTypeId;
            try {
                candidateRecordTypeId = [
                    SELECT Id 
                    FROM RecordType 
                    WHERE SObjectType = 'Account' 
                    AND Name = 'Client' 
                    LIMIT 1
                ].Id;
            } catch (Exception e) {
                throw new AuraHandledException('Candidate Record Type not found for Contact');
            }
        return new Account(
            Name = name,
            Phone__c = '9999999999',
            Email__c = email,
            isActive__c = true,
            RecordtypeId = candidateRecordTypeId
        );
    }
 
/* @author (date): Admin (20 Aug, 2025)
* @description  : Return an Job_Position__c record with sample data.
* @return Job_Position__c instance.
*/     
    public static Job_Position__c createFlexJobPosition() {
        return new Job_Position__c(
            Job_Title__c = 'Salesforce Developer',        
            Employment_Type__c = 'Full-Time',
            Skills_Required__c = 'Salesforce, Admin',       
            Status__c = 'Open'          
        );
    }
      public static CustomSetting__c getValidationBypassSetting() {
        CustomSetting__c cs = CustomSetting__c.getOrgDefaults();
        if (cs == null) {
            cs = new CustomSetting__c(
                SetupOwnerId = UserInfo.getOrganizationId()
            );
        }
        return cs;
    }
    
    
     /**
     * @author (date): Admin (9 september, 2025)
     * @description  : Returns an Event record with sample data related to the given Candidate.
     * @param candidate - Related Candidate record (required).
     * @return Event instance.
     */
    
    public static Event createEvent(Contact candidate,Job_Position__c job) {
        return new Event(
            Subject = 'Team Meeting',
            StartDateTime = System.now().addDays(1),
            EndDateTime = System.now().addDays(1).addHours(1),
            	WhatId=job.id,
          
            DurationInMinutes = 60,
          	 WhoId = candidate.Id,
            Location = 'Conference Room',
            Description = 'Discussion about project status'
        );
    }

    /**
    * @description  : Create a Timesheet__c instance and Return.
    * @param Id   - name String
    * @return Timesheet__c instance (not inserted)
    */
	public static Timesheet__c createTimesheet(String name) {
          Timesheet__c ts = new Timesheet__c( Date__c = Date.today());
            return ts;
    }
}