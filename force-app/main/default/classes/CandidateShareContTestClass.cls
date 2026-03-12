@isTest
public class CandidateShareContTestClass {

    @testSetup
    static void createTestData() {

        // Create Client Account
        Account acc = new Account(
            Name = 'Test Client',
            Email__c = 'client@test.com'
        );
        insert acc;

        // Create Contact (Candidate)
        Contact c = new Contact(
    LastName = 'Test Candidate',
    Email = 'candidate@test.com',
    Phone = '9999999999',
    Current_Location__c = 'Delhi',
    Source__c = 'LinkedIn',
    Skills__c = 'Apex, LWC',
    Notice_Period__c = '30'
);
insert c;

        // Create Job Position
        Job_Position__c job = new Job_Position__c(
    Job_Title__c = 'Salesforce Developer',
    Employment_Type__c = 'Full-Time'
);
insert job;

        // Create Interview Record
        Interview__c interview = new Interview__c(
            Candidate_Name__c = c.Id,
            Job_Position__c = job.Id,
            Interview_Status__c = 'New',
            Rate__c = 1000
        );
        insert interview;
    }

    @isTest
    static void testGetCandidatesForDisplay() {

        Contact c = [SELECT Id FROM Contact LIMIT 1];
        Job_Position__c job = [SELECT Id FROM Job_Position__c LIMIT 1];

        String encodedIds = EncodingUtil.urlEncode(c.Id, 'UTF-8');

        Test.startTest();

        List<Map<String,Object>> result =
            CandidateShareController.getCandidatesForDisplay(encodedIds, job.Id);

        Test.stopTest();

        System.assert(result != null);
    }

    @isTest
static void testCreateInterviewsAndGetCandidates() {

    Contact c = [SELECT Id FROM Contact LIMIT 1];
    Job_Position__c job = [SELECT Id FROM Job_Position__c LIMIT 1];

    // Existing interview will be deleted
    delete [SELECT Id FROM Interview__c 
            WHERE Candidate_Name__c = :c.Id 
            AND Job_Position__c = :job.Id];

    String encodedIds = EncodingUtil.urlEncode(c.Id, 'UTF-8');

    Test.startTest();

    List<Map<String,Object>> result =
        CandidateShareController.createInterviewsAndGetCandidates(encodedIds, job.Id);

    Test.stopTest();

    System.assert(result != null);
}
    @isTest
    static void testGenerateAndSendShareLink() {

        Contact c = [SELECT Id FROM Contact LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Job_Position__c job = [SELECT Id FROM Job_Position__c LIMIT 1];

        List<Id> candidateIds = new List<Id>{c.Id};

        Test.startTest();

        Map<String,Object> result =
            CandidateShareController.generateAndSendShareLink(
                candidateIds,
                acc.Id,
                job.Id
            );

        Test.stopTest();

        System.assertEquals(true, result.get('success'));
    }

    @isTest
    static void testGetJobDetails() {

        Job_Position__c job = [SELECT Id FROM Job_Position__c LIMIT 1];

        Test.startTest();

        Job_Position__c result =
            CandidateShareController.getJobDetails(job.Id);

        Test.stopTest();

        System.assertEquals(job.Id, result.Id);
    }

    @isTest
    static void testUpdateInterviewStatusToShortlisted() {

        Contact c = [SELECT Id FROM Contact LIMIT 1];
        Job_Position__c job = [SELECT Id FROM Job_Position__c LIMIT 1];

        Test.startTest();

        CandidateShareController.updateInterviewStatusToShortlisted(
            new List<Id>{c.Id},
            job.Id
        );

        Test.stopTest();

        Interview__c updatedInterview = [
            SELECT Interview_Status__c
            FROM Interview__c
            WHERE Candidate_Name__c = :c.Id
            LIMIT 1
        ];

        System.assertEquals('Shortlisted', updatedInterview.Interview_Status__c);
    }

    @isTest
    static void testSaveCandidateFeedback() {

        Contact c = [SELECT Id FROM Contact LIMIT 1];
        Job_Position__c job = [SELECT Id FROM Job_Position__c LIMIT 1];

        Map<Id,List<String>> feedbackMap = new Map<Id,List<String>>();
        feedbackMap.put(c.Id, new List<String>{'Good communication','Strong Apex knowledge'});

        Test.startTest();

        CandidateShareController.saveCandidateFeedback(
            feedbackMap,
            job.Id
        );

        Test.stopTest();

        Interview__c interview = [
            SELECT Feedback__c
            FROM Interview__c
            WHERE Candidate_Name__c = :c.Id
            LIMIT 1
        ];

        System.assert(interview.Feedback__c != null);
    }

    @isTest
    static void testGetShortlistedCandidates() {

        Contact c = [SELECT Id FROM Contact LIMIT 1];
        Job_Position__c job = [SELECT Id FROM Job_Position__c LIMIT 1];

        Test.startTest();

        List<Id> ids =
            CandidateShareController.getShortlistedCandidates(job.Id);

        Test.stopTest();

        System.assert(ids != null);
    }
}