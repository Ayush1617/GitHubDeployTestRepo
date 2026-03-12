/**
 * @description Test class to verify InterviewTriggerHelper logic.
 *              Covers status change handling, chatter post creation,
 *              work order creation, interview event creation/update,
 *              and conflict validation scenarios.
 *
 * @author Admin
 * @since 26-Aug-2025
 *
 * Modifications Log :
 * Ver   Date         Author     Modification
 * 1.0   26 Aug, 2025 Admin      Initial Version
 */
@IsTest
public class InterviewTriggerHelperTest {

    /**
     * @description Creates common test data used across all test methods.
     */
    @TestSetup
    static void setupData() {

        Profile p = [
            SELECT Id
            FROM Profile
            WHERE Name = 'System Administrator'
            LIMIT 1
        ];

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

        Account client = Recruitment_TestDataFactory.createClient(
            'Test Client',
            'client@example.com'
        );
        Project__c project = Recruitment_TestDataFactory.createProject(
            'Test Project'
        );
        Contact cand  = Recruitment_TestDataFactory.createCandidate(
            'Test Candidate',
            'candidate@example.com'
        );
        Contact cand1 = Recruitment_TestDataFactory.createCandidate(
            'Test Candidate1',
            'candidate2@example.com'
        );
        Contact cand2 = Recruitment_TestDataFactory.createCandidate(
            'Test Candidate2',
            'candidate1@example.com'
        );

        insert new List<SObject>{ client, project, cand, cand1, cand2 };

        Job_Position__c job = Recruitment_TestDataFactory.createJobPosition(
            client,
            project
        );
        insert job;

        Interview__c inter = Recruitment_TestDataFactory.createInterview(cand, job);
        inter.Interview_Date__c = DateTime.now().addDays(1);
        inter.Interview_Mode__c = 'Online';
        insert inter;

        Interview__c todayInterview = Recruitment_TestDataFactory.createInterview(cand1, job);
        todayInterview.OwnerId = u.Id;
        todayInterview.Interview_Date__c = System.now().addDays(1);
        insert todayInterview;

        Interview__c oldInterview = Recruitment_TestDataFactory.createInterview(cand2, job);
        oldInterview.OwnerId = u.Id;
        insert oldInterview;
        Test.setCreatedDate(oldInterview.Id, System.now().addMonths(-4));
    }

    /**
     * @description Verifies that no Chatter post is created
     *              when Interview status and round remain unchanged.
     */
    @IsTest
    static void testHandleStatusChangeNoChangeNoPost() {

        Interview__c interview = [
            SELECT Id, Candidate_Name__c, Feedback__c,
                   Round__c, Interview_Status__c
            FROM Interview__c
            LIMIT 1
        ];

        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

        System.runAs(u) {
            Test.startTest();
            interview.Feedback__c = 'Test Feedback No Change';
            update interview;
            Test.stopTest();
        }

        List<FeedItem> posts = [
            SELECT Id
            FROM FeedItem
            WHERE ParentId = :interview.Candidate_Name__c
        ];

        System.assertEquals(0, posts.size());
    }

    /**
     * @description Verifies that a Chatter post is created
     *              when Interview status changes and feedback is provided.
     */
    @IsTest
    static void testHandleStatusChangeChangeStatus() {

        Interview__c interview = [
            SELECT Id, Candidate_Name__c, Round__c,
                   Interview_Status__c
            FROM Interview__c
            LIMIT 1
        ];

        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

        System.runAs(u) {
            Test.startTest();
            interview.Interview_Status__c =
                RecruitmentApp_Constants.INTERVIEW_STATUS_INTERVIEWING;
            interview.Feedback__c =
                'Candidate_Name showed good communication skills. Candidate_Name showed good communication skills. Candidate_Name showed good communication skills. Candidate_Name showed good communication skills.';
            update interview;
            Test.stopTest();
        }

        List<FeedItem> posts = [
            SELECT Id, Body
            FROM FeedItem
            WHERE ParentId = :interview.Candidate_Name__c
        ];

        System.assertEquals(1, posts.size());
        System.assert(posts[0].Body.contains('Feedback:'));
}

    /**
     * @description Verifies that a Chatter post is created
     *              when Interview status changes and round value is null.
     */
    @IsTest
    static void testHandleStatusChangeroundvaluenull() {

        Job_Position__c jobpos = [
            SELECT Id
            FROM Job_Position__c
            LIMIT 1
        ];

        Contact newcand =
            Recruitment_TestDataFactory.createCandidate(
                'NewTestCandidate',
                'NewTestCandidate@example.com'
            );
        newcand.Phone = '9234567891';
        insert newcand;

        Interview__c rec =
            Recruitment_TestDataFactory.createInterviewWithoutRound(
                newcand,
                jobpos
            );
        insert rec;
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        Test.startTest();
        rec.Interview_Status__c =
            RecruitmentApp_Constants.INTERVIEW_STATUS_INTERVIEWING;
        rec.Feedback__c =
            'Candidate showed good communication skills, Candidate showed good communication skills, ' +
			'Candidate showed good communication skills, Candidate showed good communication skills,' +
			'Candidate showed good communication skills, Candidate showed good communication skills, ';
        update rec;
        Test.stopTest();

        List<FeedItem> posts = [
            SELECT Id, Body
            FROM FeedItem
            WHERE ParentId = :rec.Candidate_Name__c
        ];

        System.assertEquals(
            1,
            posts.size(),
            'Chatter post should be created when status changes.'
        );
        System.assert(
            posts[0].Body.contains('Feedback:'),
            'Chatter body should include Feedback text.'
        );
    	}
	}

    @IsTest
    static void testCommitEvents_CatchBlock_Insert() {
		Boolean exceptionThrown = false;
        // Deliberately invalid Event (missing required fields)
        Event invalidEvent = new Event();
        // No Subject, StartDateTime, EndDateTime

        List<Event> eventsToInsert = new List<Event>{ invalidEvent };
        List<Event> eventsToUpdate = new List<Event>();
		User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        Test.startTest();
        try {
            InterviewTriggerHelperAssist.commitEvents(
                eventsToInsert,
                eventsToUpdate
            );
            System.assert(
                false,
                'Expected AuraHandledException to be thrown'
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();
		System.assert(exceptionThrown, 'Expected Exception thrown');
        }
    }

    /**
     * @description Verifies that a Work Order is created
     *              when Interview status changes to Hired.
     */
    @IsTest
    static void testCreateWorkOrderSuccess() {

        User u = [
            SELECT Id
            FROM User
            WHERE Alias = 'tuser'
            LIMIT 1
        ];

        Interview__c interview = [
            SELECT Id, Candidate_Name__c
            FROM Interview__c
            LIMIT 1
        ];

        System.runAs(u) {
            Test.startTest();
            interview.Interview_Status__c =
                RecruitmentApp_Constants.INTERVIEW_STATUS_HIRED;
            interview.Feedback__c = 'Candidate showed good communication skills, Candidate showed good communication skills, ' +
			'Candidate showed good communication skills, Candidate showed good communication skills,' +
			'Candidate showed good communication skills, Candidate showed good communication skills, ';
            update interview;
            Test.stopTest();
        }

        List<Work_Order__c> workOrders = [
            SELECT Status__c
            FROM Work_Order__c
            WHERE Candidate_Name__c = :interview.Candidate_Name__c
        ];

        System.assertEquals(
            1,
            workOrders.size(),
            'One work order should be created upon hiring.'
        );
        System.assertEquals(
            RecruitmentApp_Constants.WORKORDER_STATUS_NEW,
            workOrders[0].Status__c,
            'Work Order status should be New.'
        );
    }

    /**
     * @description Verifies that no Work Order is created
     *              when Interview status changes to a value other than Hired.
     */
    @IsTest
    static void testCreateWorkOrderNoWorkOrder() {

        User u = [
            SELECT Id
            FROM User
            WHERE Alias = 'tuser'
            LIMIT 1
        ];

        Interview__c interview = [
            SELECT Id, Candidate_Name__c
            FROM Interview__c
            LIMIT 1
        ];

        System.runAs(u) {
            Test.startTest();
            interview.Interview_Status__c =
                RecruitmentApp_Constants.INTERVIEW_STATUS_OFFERED;
            interview.Feedback__c = 'Candidate showed good communication skills, Candidate showed good communication skills, ' +
			'Candidate showed good communication skills, Candidate showed good communication skills,' +
			'Candidate showed good communication skills, Candidate showed good communication skills, ';
            update interview;
            Test.stopTest();
        }

        List<Work_Order__c> workOrders = [
            SELECT Id
            FROM Work_Order__c
            WHERE Candidate_Name__c = :interview.Candidate_Name__c
        ];

        System.assertEquals(
            0,
            workOrders.size(),
            'No work order should be created upon offering.'
        );
    }

    /**
     * @description Verifies that updating Interview date or mode
     *              updates the related Event record accordingly.
     */
    @IsTest
    static void testEventUpdated() {

        Interview__c interview = [
            SELECT Id, Candidate_Name__c, Interview_Date__c, Interview_Mode__c
            FROM Interview__c
            LIMIT 1
        ];
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        Test.startTest();
        DateTime newDate =
            interview.Interview_Date__c != null
                ? interview.Interview_Date__c.addDays(2)
                : DateTime.now().addDays(2);
        interview.Interview_Date__c = newDate;
        interview.Interview_Mode__c = 'Online';
        update interview;

        Event updated = [
            SELECT StartDateTime, EndDateTime, Location
            FROM Event
            WHERE Candidate_Name__c = :interview.Candidate_Name__c
            LIMIT 1
        ];
        Test.stopTest();

        System.assertEquals(
            newDate,
            updated.StartDateTime,
            'Event StartDateTime should be updated.'
        );
        System.assertEquals(
            newDate.addHours(1),
            updated.EndDateTime,
            'Event EndDateTime should be updated.'
        );
        System.assertEquals(
            'Online',
            updated.Location,
            'Event Location should be updated.'
        );
    }
}

    /**
     * @description Verifies that Interview update fails
     *              when a scheduling conflict exists.
     */
    @IsTest
    static void testInterviewConflictCoverage() {

        Boolean exceptionThrown = false;

        Interview__c existingInterview = [
            SELECT Id,
                   Candidate_Name__c,
                   Job_Position__c,
                   Job_Position__r.Client_Name__c,
                   Job_Position__r.Client_Name__r.Id,
                   Job_Position__r.Project__c,
                   Job_Position__r.Project__r.Id
            FROM Interview__c
            LIMIT 1
        ];

        Job_Position__c anotherJob =
            Recruitment_TestDataFactory.createJobPosition(
                existingInterview.Job_Position__r.Client_Name__r,
                existingInterview.Job_Position__r.Project__r
            );
        insert anotherJob;

        DateTime startDT = DateTime.now().addDays(1).addHours(10);

        Event conflictingEvent = new Event(
            WhatId = anotherJob.Id,
            Candidate_Name__c = existingInterview.Candidate_Name__c,
            Subject = 'Conflicting Interview',
            StartDateTime = startDT,
            EndDateTime = startDT.addHours(1)
        );
        insert conflictingEvent;

        existingInterview.Interview_Date__c = startDT;
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        Test.startTest();
        try {
            update existingInterview;
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(
            true,
            exceptionThrown,
            'Interview update should fail due to scheduling conflict.'
        );
    }
}
}