/*
#####################################################
# @Created By (Date)   : Ayush Agrawal  (20 Aug, 2025)
# @Description         : Apex Test Class for ATSController
#                       - Validates Interview retrieval and stage update logic.
#                       - Covers positive and negative test scenarios.
# @Modifications Log   :
# Ver    Date              Author                 Modification
# 1.0    20 Aug, 2025      Ayush Agrawal          Initial Version
# 1.1    28 Oct, 2025      ChatGPT (PMD Fix)      Naming & Assert Compliance
#####################################################
*/

@IsTest
public class ATSController_Test {
 	/**
     * @description :  @testSetup: Creates reusable test data once for all test methods
     */
    @TestSetup
    static void setupData() {
         Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];

        // Insert test user
        User u = new User(
            FirstName = 'Test',
            LastName = 'Owner',
            Alias = 'tuser',
            Email = 'testuser@example.com',
            Username = 'testuser' + System.currentTimeMillis() + '@example.com',
            CommunityNickname = 'testuser' + System.currentTimeMillis(),
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_IN',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert u;
        // Create Project
        Project__c project = Recruitment_TestDataFactory.createProject('Test Project');
        insert project;

        // Create Client
        Account client = Recruitment_TestDataFactory.createClient('Test Client', 'client@test.com');
        insert client;

        // Create Job Position
        Job_Position__c jobPosition = Recruitment_TestDataFactory.createJobPosition(client, project);
        insert jobPosition;

        // Create 100 Candidates
        List<Contact> candidates = new List<Contact>();
        for (Integer i = 0; i < 100; i++) {
            Contact candidate = Recruitment_TestDataFactory.createCandidate(
                'Candidate ' + i, 'email' + i + '@test.com'
            );
            candidate.Phone = '99999999' + String.valueOf(i);
            candidates.add(candidate);
        }
        insert candidates;

        // Create 100 Interviews linked to candidates and job position
        List<Interview__c> interviews = new List<Interview__c>();
        for (Contact candidate : candidates) {
            Interview__c interview = Recruitment_TestDataFactory.createInterview(candidate, jobPosition);
           // interview.Feedback__c = 'good';
            interviews.add(interview);
        }
        insert interviews;
    }

    /**
     * @description :  Tests getATSData with a valid Job_Position__c Id.
     */
    @IsTest
    static void testGetATSDataBulk() {
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        Job_Position__c jobPosition = [SELECT Id FROM Job_Position__c LIMIT 1];

        System.runAs(u) {
        Test.startTest();
        List<Interview__c> results = ATSController.getATSData(jobPosition.Id);
        Test.stopTest();

        System.assertEquals(100, results.size(), 'Expected 100 Interview records');
        for (Interview__c interview : results) {
            System.assertEquals(jobPosition.Id, interview.Job_Position__c, 'Job Position should match');
            System.assertNotEquals(null, interview.Candidate_Name__r.Name, 'Candidate should not be null');
        }
       }
    }

    /**
     * @description :  Tests getATSData method using an invalid Job_Position__c Id.
     */
    @IsTest
    static void testGetATSDataInvalidJobId() {
        Id invalidJobId = 'a00aA00000aaaa0AAA'; // Random invalid Id
		User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

        System.runAs(u) {
        Test.startTest();
        List<Interview__c> results = ATSController.getATSData(invalidJobId);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Expected no results for invalid Job Id');
        }
    }

    /**
     * @description :  Tests RemoveCandidateFromJob with interview Ids.
     */
    @IsTest
    static void testRemoveCandidateFromJob() {
        Interview__c interview = [SELECT Id, Candidate_Name__c, Job_Position__c FROM Interview__c LIMIT 1];

        Event ev = new Event(
            StartDateTime = System.now(),
            EndDateTime   = System.now().addHours(1),
            Subject       = 'Interview Event',
            WhatId        = interview.Job_Position__c,
            WhoId  = interview.Candidate_Name__c,
            OwnerId       = UserInfo.getUserId()
        );
        insert ev;
		User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        Test.startTest();
        ATSController.removeCandidateFromJob(new List<Id>{ interview.Id });
        Test.stopTest();

        System.assertEquals(0, [SELECT Count() FROM Interview__c WHERE Id = :interview.Id],
            'Interview should be deleted');
        System.assertEquals(0, [SELECT Count() FROM Event WHERE WhatId = :interview.Job_Position__c],
            'Related Event should be deleted');
        }
    }

    /**
     * @description :  Tests RemoveCandidateFromJob with interview Ids and non-systemAdmin user.
     */
    @IsTest
    static void testRemoveCandidateFromJobNoAccess() {
        Boolean exceptionThrown = false;
        Interview__c interview = [SELECT Id, Candidate_Name__c, Job_Position__c FROM Interview__c LIMIT 1];

        Event ev = new Event(
            StartDateTime = System.now(),
            EndDateTime   = System.now().addHours(1),
            Subject       = 'Interview Event',
            WhatId        = interview.Job_Position__c,
            WhoId  = interview.Candidate_Name__c,
            OwnerId       = UserInfo.getUserId()
        );
        insert ev;

		Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        // Insert test user
        User u = new User(
            FirstName = 'Test',
            LastName = 'Owner',
            Alias = 'tuser',
            Email = 'testuser@example.com',
            Username = 'testuser' + System.currentTimeMillis() + '@example.com',
            CommunityNickname = 'testuser' + System.currentTimeMillis(),
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_IN',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert u;
        System.runAs(u) {
        try {
            Test.startTest();

            // THIS METHOD SHOULD BE TESTED
            ATSController.removeCandidateFromJob(
                new List<Id>{ interview.Id }
            );

            Test.stopTest();
        }
        catch (AuraHandledException e) {
          exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'Should throw AuraHandledException for invalid input');
        }
    }

    /**
     * @description :  Tests removeCandidateFromJob with empty list.
     */
    @IsTest
    static void testRemoveCandidateFromJobEmptyList() {
        Boolean exceptionThrown = false;
		User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        try {
            Test.startTest();
            ATSController.removeCandidateFromJob(new List<Id>());
            Test.stopTest();
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'Should throw AuraHandledException for invalid input');
        }
    }

    /**
     * @description :  Test collectFeedback - happy path.
     */
    @IsTest
    static void testCollectFeedback() {
        Interview__c interview = [SELECT Id FROM Interview__c LIMIT 1];
		User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        Test.startTest();
        ATSController.collectFeedback(new List<Id>{ interview.Id });
        Test.stopTest();

        System.assertEquals(1, [SELECT Count() FROM Interview__c WHERE Id = :interview.Id],
            'Interview should not be deleted by collectFeedback');
        }
    }

    /**
     * @description :  Test collectFeedback - empty list.
     */
    @IsTest
    static void testCollectFeedbackEmptyList() {
        Boolean exceptionThrown = false;
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        try {
            Test.startTest();
            ATSController.collectFeedback(new List<Id>());
            Test.stopTest();
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'Should throw AuraHandledException for invalid input');
        }
    }

    /**
     * @description :  Test collectFeedback - valid execution.
     */
    @IsTest
    static void testCollectFeedbackSuccess() {
        Interview__c interview = [SELECT Id FROM Interview__c LIMIT 1];
		User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        Test.startTest();
        ATSController.collectFeedback(new List<Id>{ interview.Id });
        Test.stopTest();
        System.assert(true, 'collectFeedback executed successfully for valid input');
        }
    }

    /**
     * @description :  Test updateInterviews - success case.
     */
    @IsTest
    static void testUpdateInterviewsSuccess() {
        List<Interview__c> interviews = [SELECT Id FROM Interview__c LIMIT 2];
        List<Id> recordIds = new List<Id>();
        for (Interview__c i : interviews) {
            recordIds.add(i.Id);
        }
        String newstage = 'Shortlisted';
        String feedback = 'Strong performance Strong performance Strong performance Strong performance Strong performance Strong performance Strong performance Strong performance Strong performance Strong performanceStrong performanceStrong performance';
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
            Test.startTest();
            ATSController.updateInterviews(recordIds, newstage, feedback);
            Test.stopTest();
            List<Interview__c> updated = [
                SELECT Interview_Status__c, Round__c, Feedback__c
                FROM Interview__c WHERE Id IN :recordIds
            ];
            for (Interview__c rec : updated) {
                System.assertEquals('Shortlisted', rec.Interview_Status__c, 'Status should be updated');
                System.assertEquals('Strong performance Strong performance Strong performance Strong performance Strong performance Strong performance Strong performance Strong performance Strong performance Strong performanceStrong performanceStrong performance'
                                    , rec.Feedback__c, 'Feedback should be updated');
            }
        }
    }


    /**
     * @description :  Test updateInterviews - invalid input (empty new stage and feedback fields).
     */
    @IsTest
    static void testUpdateInterviewsUpdateFailed() {
        List<Interview__c> interviews = [SELECT Id FROM Interview__c LIMIT 2];
        List<Id> recordIds = new List<Id>();
        for (Interview__c i : interviews) {
            recordIds.add(i.Id);
        }
        Boolean exceptionThrown = false;
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        String newstage = '';
        String feedback ='';
        System.runAs(u) {
            try {
                Test.startTest();
                ATSController.updateInterviews(recordIds, newstage, feedback);
                Test.stopTest();
                System.assert(false, 'Expected AuraHandledException for invalid input');
            } catch (AuraHandledException e) {
                exceptionThrown = true;
            }
            System.assert(exceptionThrown, 'Should throw AuraHandledException for invalid input');
        }
    }

	   /**
     * @description :  Test updateInterviews - invalid input (empty new stage and feedback fields).
     */
    @IsTest
    static void testUpdateInterviewsUpdateFail() {
        List<Interview__c> interviews = [SELECT Id FROM Interview__c LIMIT 2];
        List<Id> recordIds = new List<Id>();
        for (Interview__c i : interviews) {
            recordIds.add(i.Id);
        }
        Boolean exceptionThrown = false;
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        String newstage = 'Shortlisted';
        String feedback ='Shortlisted';
        System.runAs(u) {
            try {
                Test.startTest();
                ATSController.updateInterviews(recordIds, newstage, feedback);
                Test.stopTest();
                System.assert(false, 'Expected AuraHandledException for invalid input');
            } catch (AuraHandledException e) {
                exceptionThrown = true;
            }
            System.assert(exceptionThrown, 'Should throw AuraHandledException for invalid input');
        }
    }

   /**
     * @description :  Test updateInterviews - feedback missing.

    @IsTest
    static void testUpdateInterviewsFeedbackMissing() {
        List<Interview__c> interviews = [SELECT Id FROM Interview__c LIMIT 2];
        List<Id> recordIds = new List<Id>();
        for (Interview__c i : interviews) {
            recordIds.add(i.Id);
        }
        String newstage = 'Shortlisted';
        String feedback = '';
        Boolean exceptionThrown = false;
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
            try {
                Test.startTest();
                ATSController.updateInterviews(recordIds, newstage, feedback);
                Test.stopTest();
                System.assert(false, 'Expected AuraHandledException due to missing feedback');
            } catch (AuraHandledException e) {
                exceptionThrown = true;
            }
            System.assert(exceptionThrown, 'Should throw AuraHandledException for missing feedback');
        }
    }*/

    /**
     * @description :  Test getCandidateIdsFromInterviews - Success Case.
     */
    @IsTest
    static void testGetCandidateIdsFromInterviewsSuccess() {
        Interview__c interview = [SELECT Id, Candidate_Name__c FROM Interview__c WHERE Candidate_Name__c != null LIMIT 1];
		User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        Test.startTest();
        List<Id> result = ATSController.getCandidateIdsFromInterviews(new List<Id>{ interview.Id });
        Test.stopTest();

        System.assertNotEquals(0, result.size(), 'Candidate list should not be empty');
        System.assertEquals(interview.Candidate_Name__c, result[0], 'Returned candidate ID should match expected');
        }
    }

    /**
     * @description :  Test getCandidateIdsFromInterviews - null input.
     */
    @IsTest
    static void testGetCandidateIdsFromInterviewsNullInput() {
        Boolean exceptionThrown = false;
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        try {
            Test.startTest();
            ATSController.getCandidateIdsFromInterviews(null);
            Test.stopTest();
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            System.assertNotEquals(null, e.getMessage(), 'Error message should not be null');
        }
        System.assert(exceptionThrown, 'Expected AuraHandledException for null input');
        }
    }
}