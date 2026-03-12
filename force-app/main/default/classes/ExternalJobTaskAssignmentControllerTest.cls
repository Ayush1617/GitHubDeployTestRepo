@IsTest
private class ExternalJobTaskAssignmentControllerTest {

    // ---------- Test Setup ----------
    @TestSetup
    static void setupData() {
        // Create Account for Job_Position__c
        Account acc = new Account(Name = 'Test Client');
        insert acc;

        // Create Job Positions
        List<Job_Position__c> jobs = new List<Job_Position__c>();
        for (Integer i = 1; i <= 3; i++) {
            jobs.add(new Job_Position__c(
                Job_Title__c = 'Job ' + i,
                Total_Openings__c = 5, // Number field
                Priority__c = 'High',
                Status__c = 'Open',
                Client_Name__c = acc.Id,
                Open_Date__c = Date.today(),
                Employment_Type__c = 'Full-Time'
            ));
        }
        insert jobs;

        // Create Users
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];
        List<User> users = new List<User>();
        for (Integer i = 1; i <= 3; i++) {
            users.add(new User(
                FirstName = 'Test',
                LastName = 'User' + i,
                Email = 'testuser' + i + '@example.com',
                Username = 'testuser' + i + '@example.com.' + System.currentTimeMillis(),
                Alias = 'tuser' + i,
                TimeZoneSidKey = 'America/Los_Angeles',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                ProfileId = p.Id,
                LanguageLocaleKey = 'en_US',
                IsActive = true
            ));
        }
        insert users;
    }

    // ---------- Helper Method ----------
    private static User getAdminUser() {
        return [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' LIMIT 1];
    }

    // ---------- Test getJobPositions ----------
    @IsTest
    static void testGetJobPositions() {
        User adminUser = getAdminUser();

        System.runAs(adminUser) {
            Test.startTest();
            List<ExternalJobTaskAssignmentController.JobWrapper> jobWrappers =
                ExternalJobTaskAssignmentController.getJobPositions();
            Test.stopTest();

            System.assertNotEquals(0, jobWrappers.size(), 'JobWrapper list should not be empty');
            System.assertNotEquals(null, jobWrappers[0].id, 'JobWrapper id should not be null');
            System.assertNotEquals(null, jobWrappers[0].totalOpenings, 'TotalOpenings should not be null');
        }
    }

    // ---------- Test getUsers ----------
    @IsTest
    static void testGetUsers() {
        User adminUser = getAdminUser();

        System.runAs(adminUser) {
            Test.startTest();
            List<User> users = ExternalJobTaskAssignmentController.getUsers();
            Test.stopTest();

            System.assertNotEquals(0, users.size(), 'User list should not be empty');
        }
    }

    // ---------- Test getTaskPriorityValues ----------
    @IsTest
    static void testGetTaskPriorityValues() {
        User adminUser = getAdminUser();

        System.runAs(adminUser) {
            Test.startTest();
            List<String> priorities = ExternalJobTaskAssignmentController.getTaskPriorityValues();
            Test.stopTest();

            System.assert(priorities.contains('High') || priorities.contains('Normal'),
                          'Task priorities should include standard Salesforce values');
        }
    }

    // ---------- Test saveAssignments with valid data ----------
    @IsTest
    static void testSaveAssignments() {
        Job_Position__c job = [SELECT Id, Job_Title__c, Client_Name__r.Name FROM Job_Position__c LIMIT 1];
        User adminUser = getAdminUser();

        // Prepare wrapper
        ExternalJobTaskAssignmentController.ExternalJobAssignmentWrapper row =
            new ExternalJobTaskAssignmentController.ExternalJobAssignmentWrapper();
        row.jobId = job.Id;
        row.jobTitle = job.Job_Title__c;
        row.client = job.Client_Name__r.Name;
        row.assignedTo = adminUser.Id;
        row.taskPriority = 'Normal';
        row.targetCount = 2;

        String rowsJson = JSON.serialize(new List<ExternalJobTaskAssignmentController.ExternalJobAssignmentWrapper>{ row });

        System.runAs(adminUser) {
            Test.startTest();
            ExternalJobTaskAssignmentController.saveAssignments(rowsJson);
            Test.stopTest();
        }

        List<Task> tasks = [SELECT Id, OwnerId, Priority, Candidates_to_submit__c
                            FROM Task
                            WHERE WhatId = :job.Id];

        System.assertEquals(1, tasks.size(), 'One task should have been inserted');
        System.assertEquals(row.assignedTo, tasks[0].OwnerId, 'OwnerId should match assignedTo');
        System.assertEquals(row.taskPriority, tasks[0].Priority, 'Task priority should match');
        System.assertEquals(row.targetCount, tasks[0].Candidates_to_submit__c, 'Target count should match');
    }

    // ---------- Test saveAssignments with invalid data ----------
    @IsTest
    static void testSaveAssignmentsWithInvalidData() {
        User adminUser = getAdminUser();

        ExternalJobTaskAssignmentController.ExternalJobAssignmentWrapper invalidRow =
            new ExternalJobTaskAssignmentController.ExternalJobAssignmentWrapper();
        invalidRow.jobId = null;
        invalidRow.assignedTo = null;
        invalidRow.taskPriority = null;
        invalidRow.targetCount = 0;

        String rowsJson = JSON.serialize(new List<ExternalJobTaskAssignmentController.ExternalJobAssignmentWrapper>{ invalidRow });

        System.runAs(adminUser) {
            Test.startTest();
            ExternalJobTaskAssignmentController.saveAssignments(rowsJson);
            Test.stopTest();
        }

        System.assertEquals(0, [SELECT COUNT() FROM Task], 'No tasks should be inserted for invalid data');
    }

    // ---------- Test saveAssignments with multiple rows (bulk) ----------
    @IsTest
    static void testSaveAssignmentsBulk() {
        List<Job_Position__c> jobs = [SELECT Id, Job_Title__c, Client_Name__r.Name FROM Job_Position__c LIMIT 3];
        User adminUser = getAdminUser();

        List<ExternalJobTaskAssignmentController.ExternalJobAssignmentWrapper> rows = new List<ExternalJobTaskAssignmentController.ExternalJobAssignmentWrapper>();

        for (Job_Position__c job : jobs) {
            ExternalJobTaskAssignmentController.ExternalJobAssignmentWrapper row =
                new ExternalJobTaskAssignmentController.ExternalJobAssignmentWrapper();
            row.jobId = job.Id;
            row.jobTitle = job.Job_Title__c;
            row.client = job.Client_Name__r.Name;
            row.assignedTo = adminUser.Id;
            row.taskPriority = 'High';
            row.targetCount = 1;
            rows.add(row);
        }

        String rowsJson = JSON.serialize(rows);

        System.runAs(adminUser) {
            Test.startTest();
            ExternalJobTaskAssignmentController.saveAssignments(rowsJson);
            Test.stopTest();
        }

        List<Task> tasks = [SELECT Id, OwnerId, Priority, Candidates_to_submit__c
                            FROM Task
                            WHERE OwnerId = :adminUser.Id];

        System.assertEquals(rows.size(), tasks.size(), 'All tasks should be inserted for multiple rows');
    }
}