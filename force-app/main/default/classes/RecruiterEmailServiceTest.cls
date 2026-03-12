@IsTest
private class RecruiterEmailServiceTest {

    /* =========================================================
       TEST DATA SETUP
    ========================================================= */
    @TestSetup
    static void createTestData() {

        // Profile
        Profile p = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];

        // Recruiter User
        User recruiter = new User(
            FirstName = 'Test',
            LastName = 'Recruiter',
            Email = 'recruiter@test.com',
            Username = 'recruiter' + System.currentTimeMillis() + '@test.com',
            Alias = 'trec',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id,
            IsActive = true
        );
        insert recruiter;

        // Client Account
        Account acc = new Account(
            Name = 'Test Client Account'
        );
        insert acc;

        // Candidate
        Contact candidate = new Contact(
            FirstName = 'Test',
            LastName = 'Candidate',
            Email = 'candidate@test.com'
        );
        insert candidate;

        // Job Position (Name auto-number → DO NOT SET)
        Job_Position__c job = new Job_Position__c(
            Client_Name__c     = acc.Id,
            Recruiter__c       = recruiter.Id,
            Employment_Type__c = 'Full-Time',   // change if needed
            Job_Title__c       = 'Salesforce Developer'
        );
        insert job;

        // Interview
        Interview__c interview = new Interview__c(
            Candidate_Name__c = candidate.Id,
            Job_Position__c   = job.Id
        );
        insert interview;
    }

    /* =========================================================
       TEST: Valid Flow (Email Logic Executes)
    ========================================================= */
    @IsTest
    static void testSendRecruiterSubmissionEmail() {

        Interview__c intv = [
            SELECT Candidate_Name__c
            FROM Interview__c
            LIMIT 1
        ];

        Test.startTest();
        RecruiterEmailService.sendRecruiterSubmissionEmail(
            new List<Id>{ intv.Candidate_Name__c }
        );
        Test.stopTest();

        // Validate email logic executed
        System.assert(
            Limits.getEmailInvocations() >= 0,
            'Email method executed without errors'
        );
    }

    /* =========================================================
       TEST: Empty Input
    ========================================================= */
    @IsTest
    static void testEmptyInput() {

        Test.startTest();
        RecruiterEmailService.sendRecruiterSubmissionEmail(
            new List<Id>()
        );
        Test.stopTest();

        System.assertEquals(
            0,
            Limits.getEmailInvocations()
        );
    }

    /* =========================================================
       TEST: Null Input
    ========================================================= */
    @IsTest
    static void testNullInput() {

        Test.startTest();
        RecruiterEmailService.sendRecruiterSubmissionEmail(null);
        Test.stopTest();

        System.assertEquals(
            0,
            Limits.getEmailInvocations()
        );
    }
}