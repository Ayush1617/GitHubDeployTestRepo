@IsTest
private class InternalTaskAssignmentControllerTest {

    static User testUser;

    @TestSetup
    static void setupData() {

        Profile p = [
            SELECT Id
            FROM Profile
            WHERE Name = 'System Administrator'
            LIMIT 1
        ];

        testUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@example.com',
            Username = 'testuser' + System.currentTimeMillis() + '@example.com',
            Alias = 'tuser',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US',
            IsActive = true
        );

        insert testUser;
    }

    // ===============================
    // Test getUsers()
    // ===============================
    @IsTest
    static void testGetUsers() {

        User u = [SELECT Id FROM User LIMIT 1];

        System.runAs(u) {
            Test.startTest();
            List<User> users =
                InternalTaskAssignmentController.getUsers();
            Test.stopTest();

            System.assertNotEquals(0, users.size());
        }
    }

    // ===============================
    // Test getTaskPicklistValues()
    // ===============================
    @IsTest
    static void testGetTaskPicklistValues() {

        User u = [SELECT Id FROM User LIMIT 1];

        System.runAs(u) {
            Test.startTest();
            Map<String, List<String>> picklists =
                InternalTaskAssignmentController.getTaskPicklistValues();
            Test.stopTest();

            System.assert(picklists.containsKey('Priority'));
            System.assert(picklists.containsKey('Status'));
            System.assert(picklists.containsKey('Subject'));

            System.assert(picklists.get('Priority').size() > 0);
            System.assert(picklists.get('Status').size() > 0);
            System.assert(picklists.get('Subject').size() > 0);
        }
    }

    // ===============================
    // Test saveTasks() - Valid Data
    // ===============================
    @IsTest
    static void testSaveTasksValidData() {

        User u = [SELECT Id FROM User LIMIT 1];

        System.runAs(u) {

            Date today = Date.today();

            InternalTaskAssignmentController.TaskWrapper wrapper =
                new InternalTaskAssignmentController.TaskWrapper();

            wrapper.subject = 'Follow-up Call';
            wrapper.priority = 'Normal';
            wrapper.status = 'Not Started';
            wrapper.assignedTo = u.Id;
            wrapper.dueDate = String.valueOf(today);

            String rowsJson = JSON.serialize(
                new List<InternalTaskAssignmentController.TaskWrapper>{ wrapper }
            );

            Test.startTest();
            Integer insertedCount =
                InternalTaskAssignmentController.saveTasks(rowsJson);
            Test.stopTest();

            System.assertEquals(1, insertedCount);

            Task t = [
                SELECT Subject, Priority, Status, OwnerId, ActivityDate
                FROM Task
                WHERE OwnerId = :u.Id
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];

            System.assertEquals('Follow-up Call', t.Subject);
            System.assertEquals('Normal', t.Priority);
            System.assertEquals('Not Started', t.Status);
            System.assertEquals(today, t.ActivityDate);
        }
    }

    // ===============================
    // Test saveTasks() - Empty JSON
    // ===============================
    @IsTest
    static void testSaveTasksEmptyJson() {

        User u = [SELECT Id FROM User LIMIT 1];

        System.runAs(u) {

            Test.startTest();
            Integer count =
                InternalTaskAssignmentController.saveTasks('');
            Test.stopTest();

            System.assertEquals(0, count);
        }
    }

    // ===============================
    // Test saveTasks() - Invalid Row
    // ===============================
    @IsTest
    static void testSaveTasksInvalidRow() {

        User u = [SELECT Id FROM User LIMIT 1];

        System.runAs(u) {

            InternalTaskAssignmentController.TaskWrapper wrapper =
                new InternalTaskAssignmentController.TaskWrapper();

            // Missing required fields
            wrapper.subject = 'test';
            wrapper.priority = 'High';
            
            wrapper.status = 'Completed';

            String rowsJson = JSON.serialize(
                new List<InternalTaskAssignmentController.TaskWrapper>{ wrapper }
            );

            Test.startTest();
            Integer count =
                InternalTaskAssignmentController.saveTasks(rowsJson);
            Test.stopTest();

            System.assertEquals(0, count);
        }
    }
}