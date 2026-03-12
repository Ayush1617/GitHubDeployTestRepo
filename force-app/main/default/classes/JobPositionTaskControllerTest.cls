@IsTest
public class JobPositionTaskControllerTest {

    /* =======================
       TEST SETUP (YOUR DATA)
       ======================= */
    @TestSetup
    static void setupTestData() {

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

        Contact cand1 = Recruitment_TestDataFactory.createCandidate(
            'John Doe',
            'johndoe@email.com'
        );
        cand1.Skills__c = 'Salesforce, Apex, LWC';
        cand1.Gender__c = 'Male';
        cand1.Notice_Period__c = '1 Month';
        cand1.Current_CTC__c = 60000;
        cand1.Expected_CTC__c = 70000;
        cand1.Highest_Qualification__c = 'B.Tech';
        cand1.Institute_Name__c = 'Test College';
        cand1.Current_Location__c = 'Delhi';
        cand1.Phone = '1111111111';
        cand1.Total_Experience__c = 3;
        insert cand1;

        Contact cand2 = Recruitment_TestDataFactory.createCandidate(
            'Jane Smith',
            'jane.smith@test.com'
        );
        cand2.Skills__c = 'Java, SQL, Salesforce';
        cand2.Gender__c = 'Female';
        cand2.Notice_Period__c = 'Immediate';
        cand2.Can_join_in__c = 30;
        cand2.Total_Experience__c = 3;
        cand2.Current_Location__c = 'Delhi';
        cand2.Language_Known__c = 'Hindi, English';
        cand2.Current_CTC__c = 40000;
        cand2.Preferred_Location__c = 'Pune';
        insert cand2;

        Account client = Recruitment_TestDataFactory.createClient(
            'Client Name',
            'client@email.com'
        );
        client.Phone__c = '1111111111';
        insert client;

        Job_Position__c jp = Recruitment_TestDataFactory.createFlexJobPosition();
        jp.Client_Name__c = client.Id;
        jp.Employment_Type__c = 'Full-Time';
        jp.Job_Title__c = 'Salesforce Developer';
        insert jp;

        Task t = new Task(
            Subject = 'Interview Task',
            Status = 'Not Started',
            Priority = 'Normal',
            ActivityDate = Date.today(),
            WhatId = jp.Id
        );
        insert t;
    }

    /* =======================
       TEST : VALID JOB POSITION
       ======================= */
    @IsTest
    static void testGetTasksWithValidJobPosition() {
User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        Job_Position__c jobPos = [
            SELECT Id
            FROM Job_Position__c
            LIMIT 1
        ];
System.runAs(u) {
        Test.startTest();
        List<Task> tasks =
            JobPositionTaskController.getTasks(jobPos.Id);
        Test.stopTest();

        System.assertNotEquals(
            null,
            tasks,
            'Task list should not be null'  );
        System.assertEquals(
            1,
            tasks.size(),
            'Exactly one task should be returned'
        );


        Task result = tasks[0];
        System.assertEquals('Interview Task', result.Subject);
        System.assertEquals('Not Started', result.Status);
        System.assertEquals('Normal', result.Priority);
        System.assertEquals(jobPos.Id, result.WhatId);
    }
    }
        /* =======================
       TEST : NULL JOB POSITION
       ======================= */
    @IsTest
    static void testGetTasksWithNullJobPositionId() {
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
System.runAs(u) {
        Test.startTest();
        List<Task> tasks =
            JobPositionTaskController.getTasks(null);
        Test.stopTest();

        System.assertNotEquals(
            null,
            tasks,
            'Result should not be null'
        );
        System.assertEquals(
            0,
            tasks.size(),
            'No tasks should be returned'
        );
    }
    }
}