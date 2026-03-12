@IsTest
public class TimesheetCandidateControllerTest {

    @TestSetup
    static void setupData() {
        // 1. Get a Role and Admin Profile
        UserRole role = [SELECT Id FROM UserRole WHERE Name != null LIMIT 1];
        Profile adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];

        // 2. Create Internal User who will own the Account
        User internalUser = new User(
            FirstName = 'Internal',
            LastName = 'Owner',
            Alias = 'intusr',
            Email = 'internal@test.com',
            Username = 'internal' + System.currentTimeMillis() + '@test.com',
            ProfileId = adminProfile.Id,
            UserRoleId = role.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_IN',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert internalUser;

        // 3. Create Data as the Internal User to ensure correct ownership
        System.runAs(internalUser) {
            Account acc = new Account(
                Name = 'Test Portal Account',
                OwnerId = internalUser.Id
            );
            insert acc;

            // Get the Candidate Record Type Id
            Id candidateRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName()
                                        .get('Candidate').getRecordTypeId();

            Contact candidate = new Contact(
                FirstName = 'Test',
                LastName = 'Candidate',
                Email = 'candidate@test.com',
                AccountId = acc.Id,
                RecordTypeId = candidateRecordTypeId
            );
            insert candidate;

            Profile portalProfile = [SELECT Id FROM Profile WHERE Name = 'Customer Community User' LIMIT 1];

            User portalUser = new User(
                FirstName = 'Portal',
                LastName = 'User',
                Alias = 'ptusr',
                Email = 'candidate@test.com',
                Username = 'portal' + System.currentTimeMillis() + '@test.com',
                CommunityNickname = 'cand' + System.currentTimeMillis(),
                ProfileId = portalProfile.Id,
                ContactId = candidate.Id,
                TimeZoneSidKey = 'Asia/Kolkata',
                LocaleSidKey = 'en_IN',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US'
            );
            insert portalUser;

        // 5. Build the rest of the business data
        Contact recruiter = Recruitment_TestDataFactory.createRecruiter('Recruiter Test', 'recruiter@test.com');
        insert recruiter;

        Project__c project = Recruitment_TestDataFactory.createProject('Test Project');
        insert project;

        Work_Order__c workOrder = Recruitment_TestDataFactory.createWorkOrder(
            candidate.Id,
            project.Id,
            recruiter.Id
        );
        insert workOrder;
        }
    }

    @IsTest
    static void testGetProjectsForCandidate() {
        User u = [SELECT Id FROM User WHERE Email = 'candidate@test.com' LIMIT 1];

        System.runAs(u) {
            Test.startTest();
            List<Project__c> projects = TimesheetCandidateController.getProjectsForCandidate();
            Test.stopTest();

            System.assert(!projects.isEmpty(), 'Candidate should have assigned projects.');
            System.assertEquals('Test Project', projects[0].Project_Name__c);
        }
    }

    @IsTest
    static void testGetCurrentCandidateId() {
        User u = [SELECT Id, ContactId FROM User WHERE Email = 'candidate@test.com' LIMIT 1];

        System.runAs(u) {
            Test.startTest();
            String candidateId = TimesheetCandidateController.getCurrentCandidateId();
            Test.stopTest();

            System.assertEquals(u.ContactId, candidateId, 'Should return the logged-in user contact id.');
        }
    }

    @IsTest
    static void testCreateTimesheetSuccess() {
        User u = [SELECT Id, ContactId FROM User WHERE Email = 'candidate@test.com' LIMIT 1];
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];
        String mondayDate = String.valueOf(Date.today().toStartOfWeek().addDays(1));

        System.runAs(u) {
            Test.startTest();
            Timesheet__c ts = TimesheetCandidateController.createTimesheet(proj.Id, mondayDate);
            Test.stopTest();

            System.assertNotEquals(null, ts.Id);
            System.assertEquals('Draft', ts.Status__c);
        }
    }

    @IsTest
    static void testCheckExistingTimesheet() {
        User u = [SELECT Id, ContactId FROM User WHERE Email = 'candidate@test.com' LIMIT 1];
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];
        String mondayDate = String.valueOf(Date.today().toStartOfWeek().addDays(1));

        System.runAs(u) {
            // First create one
            TimesheetCandidateController.createTimesheet(proj.Id, mondayDate);

            Test.startTest();
            Timesheet__c existing = TimesheetCandidateController.checkExistingTimesheet(proj.Id, mondayDate);
            Test.stopTest();

            System.assertNotEquals(null, existing, 'Should find the timesheet created above.');
        }
    }

    @IsTest
    static void testDuplicateTimesheetError() {
        User u = [SELECT Id, ContactId FROM User WHERE Email = 'candidate@test.com' LIMIT 1];
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];
        String mondayDate = String.valueOf(Date.today().toStartOfWeek().addDays(1));

        System.runAs(u) {
            TimesheetCandidateController.createTimesheet(proj.Id, mondayDate);

            Test.startTest();
            try {
                TimesheetCandidateController.createTimesheet(proj.Id, mondayDate);
                System.assert(false, 'Exception should have been thrown');
            } catch (AuraHandledException e) {
                System.assert(e.getMessage().contains('already exists'), 'Error should mention existing timesheet');
            }
            Test.stopTest();
        }
    }
}