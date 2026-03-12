/**
* @File Name : AddToJobPositionController.cls
* @Author : Dixit Anand arora ////////
* @Last Modified By :
* @Last Modified On :November 26, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | October 25, 2025 |   | Initial Version
**/
@IsTest
private class AddToJobPositionControllerTest {

    /* =========================================================
       Test Setup
       ========================================================= */
    @testSetup
    static void setupData() {

        /* -------------------------------
           Record Types
           ------------------------------- */
        Id candidateRT =
            Schema.SObjectType.Contact
                .getRecordTypeInfosByDeveloperName()
                .get('Candidate')
                .getRecordTypeId();

        Id clientRT =
            Schema.SObjectType.Account
                .getRecordTypeInfosByDeveloperName()
                .get('Client')
                .getRecordTypeId();

        /* -------------------------------
           Client (Account)
           ------------------------------- */
        Account client = new Account(
            Name = 'Test Client',
            RecordTypeId = clientRT
        );
        insert client;

        /* -------------------------------
           Candidates (Contacts)
           ------------------------------- */
        Contact cand = new Contact(
            LastName = 'Candidate One',
            Email = 'candidate6@example.com',
            RecordTypeId = candidateRT,
            Designation__c = 'Developer',
            Skills__c = 'Apex, Java'
        );

        Contact cand1 = new Contact(
            LastName = 'Candidate Two',
            Email = 'candidate7@example.com',
            RecordTypeId = candidateRT
        );

        Contact cand2 = new Contact(
            LastName = 'Candidate Three',
            Email = 'candidate8@example.com',
            RecordTypeId = candidateRT
        );

        insert new List<Contact>{ cand, cand1, cand2 };

        /* -------------------------------
           Job Position
           ------------------------------- */
        Project__c project =
            Recruitment_TestDataFactory.createProject('Test Project');
        insert project;

        Job_Position__c job =
            Recruitment_TestDataFactory.createJobPosition(client, project);
        job.Aditional_Skills__c = 'LWC';
        job.Job_Title__c = 'Salesforce Developer';
        job.Soft_skills__c = 'Communication';
        job.Skills_Required__c = 'Apex; Java';
        job.Minimum_Experience_Required__c = 3;
        job.Maximum_Experience_Required__c = 6;
        job.Work_Location__c = 'New York';
        insert job;

        /* -------------------------------
           Existing Interview (Duplicate Case)
           ------------------------------- */
        Interview__c interview = new Interview__c(
            Candidate_Name__c = cand.Id,
            Job_Position__c = job.Id,
            Interview_Date__c = DateTime.now().addDays(1),
            Interview_Mode__c = 'Online'
        );
        insert interview;
    }

    /* =========================================================
       Search Jobs
       ========================================================= */
    @IsTest
    static void testSearchJobs() {

        Contact c = [SELECT Id FROM Contact LIMIT 1];

        Test.startTest();
        List<Job_Position__c> results =
            AddToJobPositionController.getJobPositions(c.Id, 'Salesforce');
        Test.stopTest();

        System.assert(!results.isEmpty(),
            'Search should return matched job positions');
    }

    /* =========================================================
       No Candidate Scenario
       ========================================================= */
    @IsTest
    static void testWithoutSearch_NoCandidate() {

        Test.startTest();
        List<Job_Position__c> results =
            AddToJobPositionController.getJobPositions(null, null);
        Test.stopTest();

        System.assertEquals(1, results.size(),
            'Should return all available jobs');
    }

    /* =========================================================
       Smart Matching
       ========================================================= */
    @IsTest
    static void testSmartMatching() {

        Contact cand = [
            SELECT Id
            FROM Contact
            WHERE Designation__c = 'Developer'
            LIMIT 1
        ];

        Test.startTest();
        List<Job_Position__c> results =
            AddToJobPositionController.getJobPositions(cand.Id, null);
        Test.stopTest();

        System.assert(!results.isEmpty(),
            'Matching jobs must be returned');
    }

    /* =========================================================
       Add Candidate to Job
       ========================================================= */
    @IsTest
    static void testAddCandidateToJobs() {

        Contact freeCand = [
            SELECT Id
            FROM Contact
            WHERE Email = 'candidate7@example.com'
            LIMIT 1
        ];

        Job_Position__c job =
            [SELECT Id FROM Job_Position__c LIMIT 1];

        Test.startTest();
        AddToJobPositionController.addCandidateToJobs(
            freeCand.Id,
            new List<Id>{ job.Id }
        );
        Test.stopTest();

        Integer interviewCount = [
            SELECT COUNT()
            FROM Interview__c
            WHERE Candidate_Name__c = :freeCand.Id
        ];

        System.assertEquals(1, interviewCount,
            'Interview inserted successfully');
    }

    /* =========================================================
       Null Handling
       ========================================================= */
    @IsTest
    static void testAddCandidateToJobs_NullValues() {

        Test.startTest();
        AddToJobPositionController.addCandidateToJobs(null, null);
        Test.stopTest();

        System.assert(true,
            'Method should exit gracefully');
    }

    /* =========================================================
       Duplicate Assignment
       ========================================================= */
    @IsTest
    static void testDuplicateAssignmentHandling() {

        Contact assignedCand = [
            SELECT Id
            FROM Contact
            WHERE Email = 'candidate6@example.com'
            LIMIT 1
        ];

        Job_Position__c job =
            [SELECT Id FROM Job_Position__c LIMIT 1];

        Test.startTest();
        try {
            AddToJobPositionController.addCandidateToJobs(
                assignedCand.Id,
                new List<Id>{ job.Id }
            );
            System.assert(false,
                'Exception should be thrown');
        } catch (AuraHandledException ex) {
           
        }
        Test.stopTest();
    }

    /* =========================================================
       Partial Duplicate Assignment
       ========================================================= */
    @IsTest
    static void testPartialDuplicateAssignment() {

        Contact assignedCand = [
            SELECT Id
            FROM Contact
            WHERE Email = 'candidate6@example.com'
            LIMIT 1
        ];

        Account client = [SELECT Id FROM Account LIMIT 1];

        Project__c project =
            Recruitment_TestDataFactory.createProject('Test Project');
        insert project;

        Job_Position__c job =
            Recruitment_TestDataFactory.createJobPosition(client, project);
        job.Aditional_Skills__c = 'LWC';
        job.Job_Title__c = 'Salesforce Developer';
        job.Soft_skills__c = 'Communication';
        job.Skills_Required__c = 'Apex; Java';
        job.Minimum_Experience_Required__c = 3;
        job.Maximum_Experience_Required__c = 6;
        job.Work_Location__c = 'New York';
        insert job;

        Job_Position__c existingJob =
            [SELECT Id FROM Job_Position__c LIMIT 1];

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            AddToJobPositionController.addCandidateToJobs(
                assignedCand.Id,
                new List<Id>{ existingJob.Id, job.Id }
            );
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        
        Integer countNewInterview = [
            SELECT COUNT()
            FROM Interview__c
            WHERE Candidate_Name__c = :assignedCand.Id
            AND Job_Position__c = :job.Id
        ];

        System.assertEquals(1, countNewInterview,
            'New job must be assigned');
    }
}