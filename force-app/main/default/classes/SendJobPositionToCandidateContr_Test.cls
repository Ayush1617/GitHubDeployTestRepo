@IsTest
public class SendJobPositionToCandidateContr_Test {

    @TestSetup
    static void setupData() {
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

       
        Account client = Recruitment_TestDataFactory.createClient('Test Client', 'client@example.com');
        Project__c project = Recruitment_TestDataFactory.createProject('Test Project');

        Contact cand = Recruitment_TestDataFactory.createCandidate('Test Candidate', 'candidate6@example.com');
        Contact cand1 = Recruitment_TestDataFactory.createCandidate('Test Candidate1', 'candidate7@example.com');
        Contact cand2 = Recruitment_TestDataFactory.createCandidate('Test Candidate2', 'candidate8@example.com');

        insert new List<SObject>{ client, project, cand, cand1, cand2 };

       
        Job_Position__c job = Recruitment_TestDataFactory.createJobPosition(client, project);
        job.Client_Name__c = client.Id;
        job.Job_Title__c = 'Salesforce Developer';
        job.Skills_Required__c = 'Apex; Java';
        insert job;

        
        Interview__c inter = Recruitment_TestDataFactory.createInterview(cand, job);
        inter.Interview_Date__c = DateTime.now().addDays(1);
        inter.Interview_Mode__c = 'Online';
        insert inter;
    }

    @IsTest
    static void testGetJobAndCandidatesSuccess()
{
        // Fetch setup data
          User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        Job_Position__c job = [SELECT Id FROM Job_Position__c LIMIT 1];
        Interview__c inter = [SELECT Id FROM Interview__c LIMIT 1];
         System.runAs(u) {
        Test.startTest();
        Map<String, Object> result = SendJobPositionToCandidateController.getJobAndCandidates(job.Id, new List<Id>{inter.Id});
        Test.stopTest();

        System.assertNotEquals(null, result, 'Response should not be null');
        System.assert(result.containsKey('jobPosition'), 'Job data should be present');
        System.assert(result.containsKey('candidates'), 'Candidate list should be present');

        Job_Position__c fetchedJob = (Job_Position__c) result.get('jobPosition');
        List<Contact> fetchedCandidates = (List<Contact>) result.get('candidates');

        System.assertEquals('Salesforce Developer', fetchedJob.Job_Title__c, 'Job Title mismatch');
        System.assertEquals(1, fetchedCandidates.size(), 'Should return only one candidate linked to interview');
        System.assertEquals('candidate6@example.com', fetchedCandidates[0].Email, 'Email mismatch');
    }
}

    /*@isTest
    static void test_NoInterviewIds() {
        Job_Position__c job = [SELECT Id FROM Job_Position__c LIMIT 1];

        Test.startTest();
        Map<String, Object> result = SendJobPositionToCandidateController.getJobAndCandidates(job.Id, new List<Id>());
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(true, result.containsKey('jobPosition'));
        System.assertEquals(true, result.containsKey('candidates'));
    }

    @isTest
    static void test_JobId_Null() {
        Test.startTest();
        Map<String, Object> result = SendJobPositionToCandidateController.getJobAndCandidates(null, new List<Id>());
        Test.stopTest();

        System.assertEquals(0, result.size(), 'Null job id should return empty map');
    }*/
}