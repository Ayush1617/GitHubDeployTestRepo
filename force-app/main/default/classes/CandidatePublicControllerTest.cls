@IsTest
private class CandidatePublicControllerTest {

    /* ========================================================
       GLOBAL TEST DATA
       ======================================================== */
    static User testUser;
    static Contact recruiter;
    static Account client;
    static Project__c project;
    static List<Job_Position__c> jobList;
    static Contact existingCandidate;
    static Interview__c existingInterview;

    /* ========================================================
       TEST SETUP
       ======================================================== */
    @TestSetup
    static void setupData() {

        // -------- USER --------
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        testUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@test.com',
            Username = 'testuser' + System.currentTimeMillis() + '@test.com',
            Alias = 'tusr',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert testUser;

        // -------- RECRUITER (Contact: Recruiter RT) --------
        recruiter = Recruitment_TestDataFactory.createRecruiter('Recruiter', 'rec@test.com');
        recruiter.OwnerId = testUser.Id;
        insert recruiter;

        // -------- CLIENT (Account: Client RT) --------
        client = Recruitment_TestDataFactory.createClient('Test Client', 'client@test.com');
        insert client;

        // -------- PROJECT --------
        project = Recruitment_TestDataFactory.createProject('Test Project');
        insert project;

        // -------- JOB POSITIONS --------
        jobList = new List<Job_Position__c>();
        for (Integer i = 0; i < 5; i++) {
            Job_Position__c job = Recruitment_TestDataFactory.createJobPosition(client, project);
            job.Job_Title__c = 'Developer ' + i;
            job.Status__c = 'Open';
            job.Available_for_Website__c = true;
            job.Minimum_Experience_Required__c = i;
            job.Maximum_Experience_Required__c = i + 3;
            job.Job_Location__City__s = 'Mumbai';
            job.OwnerId = testUser.Id;
            jobList.add(job);
        }
        insert jobList;

        // -------- EXISTING CANDIDATE (Contact: Candidate RT) --------
        existingCandidate =
            Recruitment_TestDataFactory.createCandidate('Existing Tester', 'existing@test.com');
        existingCandidate.Phone = '9999999999';
        insert existingCandidate;

        // -------- EXISTING INTERVIEW --------
        existingInterview =
            Recruitment_TestDataFactory.createInterview(existingCandidate, jobList[0]);
        insert existingInterview;
    }

    /* ========================================================
       TESTS
       ======================================================== */

    @IsTest
    static void testGetJobDetails() {
        Job_Position__c jp = [SELECT Id FROM Job_Position__c LIMIT 1];
        Job_Position__c res = CandidatePublicController.getJobDetails(jp.Id);
        System.assertNotEquals(null, res);
    }

    @IsTest
    static void testSearchJobPositions() {
        CandidatePublicController.JobSearchResponse resp =
            CandidatePublicController.searchJobPositions(
                1, 10, 'Developer', 'Mumbai', 0, 3
            );

        System.assert(resp.totalRecords > 0);
        System.assert(resp.jobs.size() > 0);
    }

   /* @IsTest
    static void testSearchJobPositions_MinExpOnly() {
        CandidatePublicController.JobSearchResponse resp =
            CandidatePublicController.searchJobPositions(
                1, 10, 'Developer', 'Mumbai', 10, null
            );

        System.assert(resp.totalRecords > 0);
        system.debug('totaljobs...->' + resp.totalRecords);
        System.assert(resp.jobs.size() > 0);
    }*/

    @IsTest
    static void testCheckExistingCandidate() {

        Contact c1 =
            CandidatePublicController.checkExistingCandidate('existing@test.com', null);
        System.assertNotEquals(null, c1);

        Contact c2 =
            CandidatePublicController.checkExistingCandidate(null, '9999999999');
        System.assertNotEquals(null, c2);

        Contact none =
            CandidatePublicController.checkExistingCandidate('no@test.com', '111');
        System.assertEquals(null, none);
    }

    @IsTest
    static void testSubmitCandidate_New() {

        Job_Position__c jp = [
            SELECT Id
            FROM Job_Position__c
            WHERE Status__c = 'Open'
            LIMIT 1
        ];

        Test.startTest();
        CandidatePublicController.CandidateResponse resp =
            CandidatePublicController.submitCandidateForm(
                'John', 'Doe', 'john@test.com', '9000000001',
                3, 'Apex', 'telecommunication', 'Corp', 'Developer',
                'noida', 12, '30 Days',
                'token',
                'resume.pdf', 'application/pdf', 'BASE64',
                jp.Id, 10
            );
        Test.stopTest();

        System.assert(resp.success);
        System.assert(resp.interviewCreated);
        System.assertNotEquals(null, resp.candidateId);
        System.assertNotEquals(null, resp.interviewId);
    }

    @IsTest
    static void testSubmitCandidate_NoJobId() {

        Test.startTest();
        CandidatePublicController.CandidateResponse resp =
            CandidatePublicController.submitCandidateForm(
                'Ana', 'Singh', 'ana@test.com', '9000000002',
                2, 'Java', 'telecommunication', 'TechCo', 'Engineer',
                'noida', 10, '15 Days',
                null, null, null, null, null, null
            );
        Test.stopTest();

        System.assert(resp.success);
        System.assertEquals('Candidate saved successfully.', resp.message);
        System.assertEquals(null, resp.interviewId);
    }

    @IsTest
    static void testSubmitCandidate_RequiredFieldsMissing() {

        CandidatePublicController.CandidateResponse resp =
            CandidatePublicController.submitCandidateForm(
                '', 'Doe', 'test@test.com', '9000000001',
                3, 'Apex',  'telecommunication', 'Corp', 'Dev',
                 'noida', 10, '30 Days',
                null, null, null, null, null, null
            );

        System.assertEquals(false, resp.success);
        System.assertEquals('Required fields are missing.', resp.message);
    }

    @IsTest
    static void testExistingCandidateAssignmentPath() {

        CandidatePublicController.CandidateResponse resp =
            CandidatePublicController.submitCandidateForm(
                'Existing', 'Tester',
                'existing@test.com',
                '9999999999',
                5, 'Apex', 'telecommunication', 'Org', 'Dev',
                'noida', 15, '30 Days',
                null, null, null, null, null, null
            );

        System.assert(resp.success);
        System.assertNotEquals(null, resp.candidateId);
    }
}