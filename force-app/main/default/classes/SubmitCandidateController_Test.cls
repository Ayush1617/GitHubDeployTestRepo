/*
##################################################### 
# Created By (Date)   : Shivam Shivhare (7 Oct, 2025)
# Description         : Test class for SubmitCandidateController Apex class.
# Modifications Log   : 
* Ver    Date              Author                   Modification
* 1.0    7 Oct, 2025      Shivam Shivhare          Initial Version
#####################################################
*/

@IsTest
private class SubmitCandidateController_Test {

    // ------------------ Test Setup ------------------
    /*
    * @description : Creates reusable test data (Candidates, Client, Job Position) for all tests.
    */
    @TestSetup
    static void setupTestData() {

		// Insert test user
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
        // Project
        Project__c proj = Recruitment_TestDataFactory.createProject('Project for Testing');
        insert proj;

        // Clients
        Account client = Recruitment_TestDataFactory.createClient('Test Client', 'testclient1@example.com');
        client.Candidate_Fields__c = 'Name,Email__c,Phone__c';
        insert client;

        Account clientNoFields = Recruitment_TestDataFactory.createClient('Client No Fields', 'nofields1@example.com');
        insert clientNoFields;

        // Candidates
        Contact cand1 = Recruitment_TestDataFactory.createCandidate('John Doe', 'john1@example.com');
        cand1.Phone = '9000000001';
        Contact cand2 = Recruitment_TestDataFactory.createCandidate('Jane Smith', 'jane2@example.com');
        cand2.Phone = '9000000002';
        insert new List<Contact>{ cand1, cand2 };

        // Job Position
        Job_Position__c job = Recruitment_TestDataFactory.createJobPosition(client, proj);
        job.Job_description__c = 'Responsible for Salesforce development';
        job.Work_Location__c = 'New York';
        job.Status__c='Open';
        insert job;
    }

    // ------------------ getAllClients Tests ------------------
    /*
    * @description : Positive test for getAllClients. Ensures clients with non-null email are returned.
    */
    @IsTest
    static void testGetAllClientsPositive() {
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        Test.startTest();
        List<Account> clients = SubmitCandidateController.getAllClients();
        Test.stopTest();

        System.assertNotEquals(0, clients.size(), 'Clients should be returned');
        System.assertNotEquals(null, clients[0].Email__c, 'Client email should not be null');
    }
    }

    /*
    * @description : Negative test for getAllClients. Ensures clients with null email do not appear.
    */
    @IsTest
    static void testGetAllClientsNegative() {
        Integer initialCount = SubmitCandidateController.getAllClients().size();

        Account validClient = Recruitment_TestDataFactory.createClient('Valid Client', 'valid3@example.com');
        insert validClient;
		User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        Test.startTest();
        List<Account> clients = SubmitCandidateController.getAllClients();
        Test.stopTest();

        for (Account c : clients) {
            System.assertNotEquals(null, c.Email__c, 'Client email should not be null');
        }
        System.assert(clients.size() > initialCount, 'Client count should increase after inserting a valid client');
    }
    }

    // ------------------ getJobPositionsByClient Tests ------------------
    /*
    * @description : Positive test for getJobPositionsByClient. Ensures job positions for a valid client are returned.
    */
    @IsTest
    static void testGetJobPositionsByClientPositive() {
        Account client = [SELECT Id FROM Account WHERE Name = 'Test Client' LIMIT 1];
		//system.debug('91'+jobs.size());
		User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        Test.startTest();
        List<Job_Position__c> jobs = SubmitCandidateController.getJobPositionsByClient(client.Id);
        Test.stopTest();
        System.assertNotEquals(0, jobs.size(), 'Job positions should be returned for valid client');
    }
    }

    /*
    * @description : Negative test for getJobPositionsByClient. Ensures empty list returned for invalid client Id.
    */
    @IsTest
    static void testGetJobPositionsByClientNegative() {
		Account client = [SELECT Id FROM Account WHERE Name = 'Client No Fields' LIMIT 1];
		String idd = client.Id;
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        Test.startTest();
        List<Job_Position__c> jobs = SubmitCandidateController.getJobPositionsByClient(idd);
        Test.stopTest();

        System.assertEquals(true, jobs.isEmpty(), 'Should return empty list for invalid client');
    }
    }

    // ------------------ getCandidateForClient Tests ------------------
    /*
    * @description : Positive test for getCandidateForClient. Ensures correct candidate data returned.
    */
    @IsTest
    static void testGetCandidateForClientPositive() {
        Contact cand = [SELECT Id FROM Contact LIMIT 1];
        Account client = [SELECT Id FROM Account WHERE Name = 'Test Client' LIMIT 1];
		User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        Test.startTest();
        Map<String, Object> result = SubmitCandidateController.getCandidateForClient(cand.Id, client.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.containsKey('fieldOrder'), 'fieldOrder should be in response');
        System.assert(result.containsKey('values'), 'values should be in response');
    }
    }
    /*
    * @description : Negative test for getCandidateForClient. Ensures default fields used when Candidate_Fields__c is blank.
    */
    @IsTest
    static void testGetCandidateForClientBlankFields() {
        Contact cand = [SELECT Id FROM Contact LIMIT 1];
        Account clientNoFields = [SELECT Id FROM Account WHERE Name = 'Client No Fields' LIMIT 1];
		User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        Test.startTest();
        Map<String, Object> result = SubmitCandidateController.getCandidateForClient(cand.Id, clientNoFields.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should still return even if Candidate_Fields__c is blank');
    }
    }
    // ------------------ getMultipleCandidatesForClient Tests ------------------
    /*
    * @description : Positive test for getMultipleCandidatesForClient. Ensures multiple candidate data returned correctly.
    */
    @IsTest
    static void testGetMultipleCandidatesForClientPositive() {
        List<Contact> cands = [SELECT Id FROM Contact];
        Account client = [SELECT Id FROM Account WHERE Name = 'Test Client' LIMIT 1];
		User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        Test.startTest();
        List<Map<String, Object>> results = SubmitCandidateController.getMultipleCandidatesForClient(
            new List<Id>{ cands[0].Id, cands[1].Id }, client.Id
        );
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Should return data for 2 candidates');
    }
    }
    // ------------------ sendCandidateExcelEmail Tests ------------------
    /*
    * @description : Positive test for sendCandidateExcelEmail. Ensures email is sent successfully without exception.
    */
    @IsTest
    static void testSendCandidateExcelEmailPositive() {
        List<Contact> cands = [SELECT Id FROM Contact];
        Account client = [SELECT Id, Email__c FROM Account WHERE Name = 'Test Client' LIMIT 1];
        Job_Position__c job = [SELECT Id FROM Job_Position__c WHERE Client_Name__c = :client.Id LIMIT 1];        
		User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        Test.startTest();
        try {
            SubmitCandidateController.sendCandidateExcelEmail(
                new List<Id>{ cands[0].Id, cands[1].Id }, client.Id, job.Id
            );
        } catch (Exception e) {
            System.assert(false, 'sendCandidateExcelEmail should not throw exception: ' + e.getMessage());
        }
        Test.stopTest();
    }
    }
}