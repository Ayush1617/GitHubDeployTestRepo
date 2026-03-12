@IsTest
public class TaskAssignmentControllerTest {

    @TestSetup
    static void setupData() {

        Profile p = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];

        List<User> users = new List<User>();
        for (Integer i = 0; i < 2; i++) {
            users.add(new User(
                FirstName = 'Recruiter',
                LastName = 'User' + i,
                Email = 'recruiter' + i + '@test.com',
                Username = 'recruiter' + i + DateTime.now().getTime() + '@test.com',
                Alias = 'rec' + i,
                TimeZoneSidKey = 'Asia/Kolkata',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                ProfileId = p.Id
            ));
        }
        insert users;

        List<Task> tasks = new List<Task>();
        for (Integer i = 0; i < 5; i++) {
            tasks.add(new Task(
                Subject = 'Test Task ' + i,
                ActivityDate = Date.today().addDays(i),
                Priority = (Math.mod(i, 2) == 0) ? 'High' : 'Normal',
                Status = 'Not Started',
                OwnerId = users[0].Id
            ));
        }
        insert tasks;
    }

    // ================== FILTER TEST ==================
    @IsTest
    static void testGetTasksWithFilters() {

        User runUser = [
            SELECT Id FROM User WHERE Alias = 'rec0' LIMIT 1
        ];

        System.runAs(runUser) {

            TaskAssignmentController.TaskFilterRequest req =
                new TaskAssignmentController.TaskFilterRequest();

            req.priorityFilter = 'High';
            req.recruiterId = runUser.Id;
            req.pageSize = 10;
            req.pageNumber = 1;
            req.refreshTime = System.currentTimeMillis();
            req.startDate = String.valueOf(Date.today().addDays(-1));
            req.endDate = String.valueOf(Date.today().addDays(1));

            String requestJson = JSON.serialize(req);

            Test.startTest();
            TaskAssignmentController.TaskWrapper result =
                TaskAssignmentController.getTasks(requestJson);
            Test.stopTest();

            System.assertNotEquals(null, result);
            System.assert(result.tasks.size() > 0);

            for (Task t : result.tasks) {
                System.assertEquals('High', t.Priority);
                System.assertEquals(runUser.Id, t.OwnerId);
            }
        }
    }

    // ================== PAGINATION TEST ==================
    @IsTest
    static void testPaginationLogic() {

        User runUser = [
            SELECT Id FROM User WHERE Alias = 'rec0' LIMIT 1
        ];

        System.runAs(runUser) {

            TaskAssignmentController.TaskFilterRequest req =
                new TaskAssignmentController.TaskFilterRequest();

            req.priorityFilter = 'All';
            req.pageSize = 2;
            req.pageNumber = 1;
            req.startDate = String.valueOf(Date.today().addDays(-1));
            req.endDate = String.valueOf(Date.today().addDays(1));

            Test.startTest();

            String requestJson1 = JSON.serialize(req);
            TaskAssignmentController.TaskWrapper page1 =
                TaskAssignmentController.getTasks(requestJson1);

            req.pageNumber = 2;
            String requestJson2 = JSON.serialize(req);
            TaskAssignmentController.TaskWrapper page2 =
                TaskAssignmentController.getTasks(requestJson2);

            Test.stopTest();

            System.assert(page1.tasks.size() > 0);
            System.assert(page2.tasks.size() > 0);
            System.assertNotEquals(
                page1.tasks[0].Id,
                page2.tasks[0].Id
            );
        }
    }

    // ================== GET RECRUITERS TEST ==================
    @IsTest
    static void testGetRecruiters() {

        User runUser = [
            SELECT Id FROM User WHERE Alias = 'rec0' LIMIT 1
        ];

        System.runAs(runUser) {

            Test.startTest();
            List<User> recruiters =
                TaskAssignmentController.getRecruiters();
            Test.stopTest();

            System.assertNotEquals(null, recruiters);
            System.assert(
                recruiters.size() > 0,
                'Should return active users'
            );
        }
    }
}