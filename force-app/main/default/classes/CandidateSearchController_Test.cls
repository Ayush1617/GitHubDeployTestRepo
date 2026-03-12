/**
* @description   Test class for CandidateSearchController.
*                Covers candidate search functionality based on skills, experience, salary, phone,
*                location, gender, notice period, and skill combinations.
*                Also tests job position retrieval and candidate-job assignment logic.
*
* @author        Yuvraj Singh
* @createdDate   2025-08-26
* @testCoverage  Ensures coverage of CandidateSearchController methods.
*/

@IsTest
private class CandidateSearchController_Test {

    /**
* @description Creates test data for candidates, clients, and job positions.
*              This data is used by all test methods in this class.
*/
    @TestSetup
    static void setupTestData() {

         Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];

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



        Contact cand1 = Recruitment_TestDataFactory.createCandidate('John Doe', 'johndoe@email.com');
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

        Contact cand2 = Recruitment_TestDataFactory.createCandidate('Jane Smith', 'jane.smith@test.com');
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

        Account client = Recruitment_TestDataFactory.createClient('Client Name', 'Client@email.com');
        client.Phone__c = '1111111111';
        insert client;

        Job_Position__c jp = Recruitment_TestDataFactory.createFlexJobPosition();
        jp.Client_Name__c = client.Id;
        insert jp;

       // Job_Position__c jp = Recruitment_TestDataFactory.createJobPosition(client, null);
       // insert jp;


    }


    /**
    * @description - for searching candidates by only skills and experience.
    */
    @IsTest
    static void testSearchCandidatesSkillAndExperience()
 {
    User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

        CandidateSearchController.CandidateSearchParams params = new CandidateSearchController.CandidateSearchParams();
        params.skillQuery = 'Salesforce';
        params.minExperience = 2;
        params.maxExperience = 5;
          System.runAs(u) {
        Test.startTest();
        List<Contact> results = CandidateSearchController.searchCandidates(params);
        Test.stopTest();

        System.assert(!results.isEmpty(), 'Expected at least one candidate');
        System.assertEquals(2, results.size(), 'Expected Result Size');
    }
 }

    /**
* @description - for searching candidates by only Current CTC.
*/
    @IsTest
    static void testSearchCandidatesMinMaxSalary()
{
    User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        CandidateSearchController.CandidateSearchParams params = new CandidateSearchController.CandidateSearchParams();
        params.skillQuery = 'Salesforce';
        params.minSalary = 0;
        params.maxSalary = 1000000;
            System.runAs(u) {
        Test.startTest();
        List<Contact> results = CandidateSearchController.searchCandidates(params);
        Test.stopTest();

        System.assert(!results.isEmpty(), 'Expected at least one candidate');
        System.assertEquals(2, results.size(), 'Expected Result Size');
    }
}
    /**
* @description - for searching candidates by only phone.
*/
    @IsTest
    static void testSearchCandidatesPhone(){
        CandidateSearchController.CandidateSearchParams params = new CandidateSearchController.CandidateSearchParams();
        params.Phone = '1111111111';
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        Test.startTest();
        List<Contact> results = CandidateSearchController.searchCandidates(params);
        Test.stopTest();

        System.assert(!results.isEmpty(), 'Expected at least one candidate');
        System.assertEquals('John Doe', results[0].Name, 'Expected John Doe to match');
    }
    }


    /**
* @description - for searching candidates by only current location.
*/

    @IsTest
    static void testSearchCandidatesCurrentLocation(){
        CandidateSearchController.CandidateSearchParams params = new CandidateSearchController.CandidateSearchParams();
        params.currentLocation = 'Delhi';
         User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
          System.runAs(u) {
        Test.startTest();
        List<Contact> results = CandidateSearchController.searchCandidates(params);
        Test.stopTest();

        System.assert(!results.isEmpty(), 'Expected at least one candidate');
        System.assertEquals('John Doe', results[0].Name, 'Expected John Doe to match');
        System.assertEquals(2, results.size(), 'Expected Result Size');
    }
    }

    /**
* @description - for searching candidates by only gender.
*/

    @IsTest
    static void testSearchCandidatesGender(){
         User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        CandidateSearchController.CandidateSearchParams params = new CandidateSearchController.CandidateSearchParams();
        params.gender = 'Male';
        System.runAs(u) {
        Test.startTest();
        List<Contact> results = CandidateSearchController.searchCandidates(params);
        Test.stopTest();

        System.assert(!results.isEmpty(), 'Expected at least one candidate');
        System.assertEquals('John Doe', results[0].Name, 'Expected John Doe to match');
    }
    }

    /**
* @description - for searching candidates by only notice period.
*/
    @IsTest
    static void testSearchCandidatesNoticePeriod(){
         User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        CandidateSearchController.CandidateSearchParams params = new CandidateSearchController.CandidateSearchParams();
        params.noticePeriod = '1 Month';
         System.runAs(u) {
        Test.startTest();
        List<Contact> results = CandidateSearchController.searchCandidates(params);
        Test.stopTest();

        System.assert(!results.isEmpty(), 'Expected at least one candidate');
        System.assertEquals('John Doe', results[0].Name, 'Expected John Doe to match');
    }
    }

    /**
* @description - for testing highest qualification.
*/

    @IsTest
    static void testSearchCandidatesHighQual(){

        CandidateSearchController.CandidateSearchParams params = new CandidateSearchController.CandidateSearchParams();
        params.highestQualification = 'B.Tech';
         User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
          System.runAs(u) {
        Test.startTest();
        List<Contact> results = CandidateSearchController.searchCandidates(params);
        Test.stopTest();

        System.assert(!results.isEmpty(), 'Expected at least one candidate');
        System.assertEquals('John Doe', results[0].Name, 'Expected John Doe to match');

    }
    }
    /**
* @description - for testing Institute Name.
*/

    @IsTest
    static void testSearchCandidatesInstitute(){
        CandidateSearchController.CandidateSearchParams params = new CandidateSearchController.CandidateSearchParams();
        params.instituteName = 'Test College';
            User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
          System.runAs(u) {
        Test.startTest();
        List<Contact> results = CandidateSearchController.searchCandidates(params);
        Test.stopTest();

        System.assert(!results.isEmpty(), 'Expected at least one candidate');
        System.assertEquals('John Doe', results[0].Name, 'Expected John Doe to match');
          }
    }
    /**
* @description - for testing Language Known.
*/

    @IsTest
    static void testSearchCandidatesLanguageKnown(){
        CandidateSearchController.CandidateSearchParams params = new CandidateSearchController.CandidateSearchParams();
        params.languageKnown = 'Hindi';
            User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
          System.runAs(u) {
        Test.startTest();
        List<Contact> results = CandidateSearchController.searchCandidates(params);
        Test.stopTest();

        System.assert(!results.isEmpty(), 'Expected at least one candidate');
        System.assertEquals('Jane Smith', results[0].Name, 'Expected Jane Smith to match');
          }
    }
    /**
* @description - for testing preferred Location.
*/

    @IsTest
    static void testSearchCandidatesPreferredLocation(){
        CandidateSearchController.CandidateSearchParams params = new CandidateSearchController.CandidateSearchParams();
        params.preferredLocation = 'Pune';
            User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
          System.runAs(u) {
        Test.startTest();
        List<Contact> results = CandidateSearchController.searchCandidates(params);
        Test.stopTest();

        System.assert(!results.isEmpty(), 'Expected at least one candidate');
        System.assertEquals('Jane Smith', results[0].Name, 'Expected Jane Smith to match');
          }
    }
    /**
* @description - for testing expected ctc .
*/

    @IsTest
    static void testSearchCandidatesExpectedCTC(){
        CandidateSearchController.CandidateSearchParams params = new CandidateSearchController.CandidateSearchParams();
        params.expectedCTC = 70000;
            User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
          System.runAs(u) {
        Test.startTest();
        List<Contact> results = CandidateSearchController.searchCandidates(params);
        Test.stopTest();

        System.assert(!results.isEmpty(), 'Expected at least one candidate');
        System.assertEquals('John Doe', results[0].Name, 'Expected John Doe to match');
          }
    }
    /**
* @description - for testing can join in.
*/

    @IsTest
    static void testSearchCandidatesCanJoinIn(){
        CandidateSearchController.CandidateSearchParams params = new CandidateSearchController.CandidateSearchParams();
        params.canJoinIn = 30;
            User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
          System.runAs(u) {
        Test.startTest();
        List<Contact> results = CandidateSearchController.searchCandidates(params);
        Test.stopTest();

        System.assert(!results.isEmpty(), 'Expected at least one candidate');
        System.assertEquals('Jane Smith', results[0].Name, 'Expected Jane Smith to match');
          }
    }


    /**
* @description - for testing the multiple skill addition and using the "And" methodology in searching when only skills are present.
*/

    @IsTest
    static void testSearchCandidatesSkillBreak(){
        CandidateSearchController.CandidateSearchParams params = new CandidateSearchController.CandidateSearchParams();
        params.skillQuery = 'Salesforce, Java';
            User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
          System.runAs(u) {
        Test.startTest();
        List<Contact> results = CandidateSearchController.searchCandidates(params);
        Test.stopTest();

        System.assert(!results.isEmpty(), 'Expected at least one candidate');
        System.assertEquals(2, results.size(), 'Expected 2 matching candidates');
          }
    }

    /**
* @description - for returning open job positions.
*/

    @IsTest
    static void testgetOpenJobPositions(){
            User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
          System.runAs(u) {
        Test.startTest();
        List<Job_Position__c> results = CandidateSearchController.getOpenJobPositions('Salesforce');
        Test.stopTest();

        System.assert(!results.isEmpty(), 'Should return at least one open job');
        for (Job_Position__c job : results) {
            System.assertEquals('Open', job.Status__c, 'job with open status');
        }
          }
    }

    /**
* @description - for assigning candidates and job positions in a new interview record.
*/

    @IsTest
    static void testAssignCandidatesToJobs() {

        List<Contact> candidates = [SELECT Id FROM Contact];

        List<Job_Position__c> jobs = [SELECT Id FROM Job_Position__c WHERE Status__c = 'Open' LIMIT 1];

            User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
          System.runAs(u) {
        Test.startTest();
        CandidateSearchController.assignCandidatesToJobs(
            new List<Id>{candidates[0].Id, candidates[1].Id},
            new List<Id>{jobs[0].Id}
        );
        Test.stopTest();

        List<Interview__c> interviews = [
            SELECT Candidate_Name__c, Job_Position__c, Interview_Status__c
            FROM Interview__c
            WHERE Job_Position__c = :jobs[0].Id
        ];
        System.assertEquals(2, interviews.size(), 'Two interviews should be created');
        System.assertEquals('New', interviews[0].Interview_Status__c, 'Interview status should be New');
    }
    }

    //Negative Test Cases - Non Existent Skill
    @IsTest
    static void testSearchCandidatesNoResults() {
        CandidateSearchController.CandidateSearchParams params = new CandidateSearchController.CandidateSearchParams();
        params.skillQuery = 'NonExistentSkill';
            User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
          System.runAs(u) {
        Test.startTest();
        List<Contact> results = CandidateSearchController.searchCandidates(params);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Expected no candidates to be returned');
    }
    }

    //Negative Test Cases - Empty Parameter
    @IsTest
    static void testSearchCandidatesEmptyParams() {
        CandidateSearchController.CandidateSearchParams params = new CandidateSearchController.CandidateSearchParams();
            User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
          System.runAs(u) {
        Test.startTest();
        List<Contact> results = CandidateSearchController.searchCandidates(params);
        Test.stopTest();

        System.assert(!results.isEmpty(), 'Expected all candidates to be returned');
        System.assertEquals(2, results.size(), 'Should return all candidates created in setup');
    }
    }

    //Negative Test Cases - Assign Candidates with Empty Lists
    @IsTest
    static void testAssignCandidatesToJobsEmptyLists() {
            User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
          System.runAs(u) {
        Test.startTest();
        CandidateSearchController.assignCandidatesToJobs(new List<Id>(), new List<Id>());
        Test.stopTest();

        System.assertEquals(0, [SELECT Count() FROM Interview__c], 'No interviews should be created');
    }
    }


    //Negative Test Cases - getOpenJobPositions No Match
    @IsTest
    static void testGetOpenJobPositionsNoMatch() {
            User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
          System.runAs(u) {
        Test.startTest();
        List<Job_Position__c> results = CandidateSearchController.getOpenJobPositions('NonExistentJob');
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Expected no job positions to be returned');
    }
    }
}