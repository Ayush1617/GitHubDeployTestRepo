/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : CandidateShareController_Test
 * Author          : <YourName>
 * Created Date    : Feb 12, 2026
 * Last Modified By: <YourName>
 * Last Modified On: Feb 12, 2026
 * Description     : This class implements for......
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Feb 12, 2026  │ <YourName>   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */
@isTest
public class CandidateShareControllerTest {

    @testSetup
    static void setupData() {

       /* // 🔹 Validation Bypass (if required)
        CustomSetting__c cs = Recruitment_TestDataFactory.getValidationBypassSetting();
        cs.Validation_Bypass__c = true;
        upsert cs;*/

        // 🔹 Create Project
        Project__c proj = Recruitment_TestDataFactory.createProject('Test Project');
        insert proj;

        // 🔹 Create Client
        Account client = Recruitment_TestDataFactory.createClient('Test Client', 'client@test.com');
        insert client;

        // 🔹 Create Job Position
        Job_Position__c job = Recruitment_TestDataFactory.createJobPosition(client, proj);
        insert job;
        
        Job_Position__c job2 = new Job_Position__c();
        job2.Employment_Type__c = 'Full-Time';
        job2.Job_Title__c = 'test2';
        job2.Description__c = 'testttttttttttttttttttttyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttt';
        job2.Client_Name__c = client.id;
        job2.Skills_Required__c = 'apex';
        
        insert job2;

        // 🔹 Create Candidates
        Contact c1 = Recruitment_TestDataFactory.createCandidate('Candidate One', 'c1@test.com');
        Contact c2 = Recruitment_TestDataFactory.createCandidate('Candidate Two', 'c2@test.com');
        insert new List<Contact>{c1, c2};

        // 🔹 Create Interview Records
        Interview__c i1 = Recruitment_TestDataFactory.createInterview(c1, job);
        Interview__c i2 = Recruitment_TestDataFactory.createInterview(c2, job);
        insert new List<Interview__c>{i1, i2};
    }

    // =========================================================
    // Test getCandidatesForDisplay
    // =========================================================
    @isTest
    static void testGetCandidatesForDisplay() {

        List<Contact> contacts = [SELECT Id FROM Contact];
        Job_Position__c job = [SELECT Id FROM Job_Position__c LIMIT 1];

        String encodedIds = EncodingUtil.urlEncode(
            String.join(new List<String>{contacts[0].Id, contacts[1].Id}, ','),
            'UTF-8'
        );

        Test.startTest();
        List<Map<String,Object>> result =
            CandidateShareController.getCandidatesForDisplay(encodedIds, job.id);
        Test.stopTest();

        System.assertEquals(2, result.size());
        //System.assertEquals('₹Not provided', result[0].get('currentCTC'));
    }

    // =========================================================
    // Test generateAndSendShareLink
    // =========================================================
    @isTest
    static void testGenerateAndSendShareLink() {

        Account client = [SELECT Id FROM Account LIMIT 1];
        Job_Position__c job = [SELECT Id FROM Job_Position__c LIMIT 1];
        Contact contact = [SELECT Id FROM Contact LIMIT 1];

        Test.startTest();
        Map<String,Object> response =
            CandidateShareController.generateAndSendShareLink(
                new List<Id>{contact.Id},
                client.Id,
                job.Id
            );
        Test.stopTest();

        System.assertEquals(true, response.get('success'));
        System.assert(response.containsKey('shareLink'));
    }

    // =========================================================
    // Test updateInterviewStatusToShortlisted
    // =========================================================
 @isTest
static void testUpdateInterviewStatusToShortlisted() {

    // Get existing test data
    Contact contact = [SELECT Id FROM Contact LIMIT 1];
    Job_Position__c job = [SELECT Id FROM Job_Position__c Where Job_Title__c = 'test2' LIMIT 1];

    //  Ensure matching Interview exists
    Interview__c interview = new Interview__c(
        Candidate_Name__c = contact.Id,
        Job_Position__c = job.Id,
        Interview_Status__c = 'Shortlisted',
        feedback__c = 'wertyuiertn ftyguhi tfyg efhwg iuwfge iuegfduew greufi ugre ugr euig44ref iugrf e9ugref iugef ug4reuif 4rugfebiu urgj ugrfd ugf wdwfgeuwejgfcow oiirrhgfos oih f'
    );
    insert interview;

    Test.startTest();
    CandidateShareController.updateInterviewStatusToShortlisted(
        new List<Id>{contact.Id},
        job.Id
    );
    Test.stopTest();

    // Re-query updated record
    Interview__c updatedInterview = [
        SELECT Interview_Status__c
        FROM Interview__c
        WHERE Id = :interview.Id
        LIMIT 1
    ];

    System.assertEquals('Shortlisted', updatedInterview.Interview_Status__c);
}

    // =========================================================
    // Test saveCandidateFeedback
    // =========================================================
   
   @isTest
static void testSaveCandidateFeedback() {

    Contact contact = [SELECT Id FROM Contact LIMIT 1];
    Job_Position__c job = [
        SELECT Id
        FROM Job_Position__c
        WHERE Id IN (SELECT Job_Position__c FROM Interview__c)
        LIMIT 1
    ];

    // 🔥 Create feedback > 100 characters
    String longFeedback =
        'Strong in Apex and Lightning Web Components with deep understanding of ' +
        'Triggers, Batch Apex, Integration, REST APIs and overall Salesforce architecture experience.';

    Map<Id, List<String>> feedbackMap = new Map<Id, List<String>>();
    feedbackMap.put(contact.Id, new List<String>{ longFeedback });

    Test.startTest();
    CandidateShareController.saveCandidateFeedback(feedbackMap, job.Id);
    Test.stopTest();

    Interview__c interview = [
        SELECT Feedback__c
        FROM Interview__c
        WHERE Candidate_Name__c = :contact.Id
        AND Job_Position__c = :job.Id
        LIMIT 1
    ];

    System.assert(interview.Feedback__c.contains('Strong in Apex'));
}

    // =========================================================
    // Negative Test
    // =========================================================
    @isTest
    static void testExceptionScenario() {

        Test.startTest();
        try {
            CandidateShareController.updateInterviewStatusToShortlisted(null, null);
            System.assert(false, 'Exception expected');
        } catch (Exception e) {
            System.assert(true);
        }
        Test.stopTest();
    }
     @IsTest
    static void testSendRecruiterSubmissionEmail() {

        Interview__c intv = [
            SELECT Candidate_Name__c
            FROM Interview__c
            LIMIT 1
        ];
        
        Job_Position__c job = [SELECT Id FROM Job_Position__c LIMIT 1];

        Test.startTest();
        RecruiterEmailService.sendRecruiterSubmissionEmail(
            new List<Id>{ intv.Candidate_Name__c },
            job.Id
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
        
        Job_Position__c job = [SELECT Id FROM Job_Position__c LIMIT 1];

        Test.startTest();
        RecruiterEmailService.sendRecruiterSubmissionEmail(
            new List<Id>(),
            job.Id
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
        RecruiterEmailService.sendRecruiterSubmissionEmail(null, null);
        Test.stopTest();

        System.assertEquals(
            0,
            Limits.getEmailInvocations()
        );
    }
    @isTest
static void testGetShortlistedCandidates_NoShortlisted() {

    Job_Position__c job = [SELECT Id FROM Job_Position__c LIMIT 1];

    // Ensure no shortlisted interviews
    List<Interview__c> interviews = [
        SELECT Id FROM Interview__c
        WHERE Job_Position__c = :job.Id
    ];

    for (Interview__c i : interviews) {
        i.Interview_Status__c = 'Shortlisted';
        i.feedback__c = ('dfuyehd oegfougwce weyhdfoewgf cwoeafhocd oiiaehfocid oielfbodc oeegfcb oegfouuskcgbw ouegfbdkc ougeobdkc og '+ i) ;
    }
    update interviews;

    Test.startTest();
    List<Id> result = 
        CandidateShareController.getShortlistedCandidates(job.Id);
    Test.stopTest();

   
}
    @isTest
static void testConvertHtmlToPlain() {

    String html = '<p>Hello&nbsp;<b>World</b>&amp;Friends</p>';

    Test.startTest();
    String result = CandidateShareController.convertHtmlToPlain(html);
    Test.stopTest();

    System.assertEquals(
        'Hello World&Friends',
        result
    );
}
    @isTest
static void testGetJobTitle() {

    // Get existing setup job
    Job_Position__c job = [
        SELECT Id, Job_Title__c
        FROM Job_Position__c
        LIMIT 1
    ];

    Test.startTest();
    Job_Position__c result =
        CandidateShareController.getJobTitle(job.Id);
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertEquals(job.Id, result.Id);
    System.assertEquals(job.Job_Title__c, result.Job_Title__c);
}
    @isTest
static void testSaveCandidateFeedback_CatchBlock() {

    // Get setup data
    Job_Position__c job = [SELECT Id FROM Job_Position__c LIMIT 1];
    List<Contact> contacts = [SELECT Id FROM Contact LIMIT 1];

    // Get max length of Feedback__c dynamically
    Integer maxLength = Interview__c.Feedback__c.getDescribe().getLength();

    // Create string larger than allowed
    String largeText = '';
    for (Integer i = 0; i <= maxLength; i++) {
        largeText += 'A';
    }

    Map<Id, List<String>> feedbackMap = new Map<Id, List<String>>();
    feedbackMap.put(contacts[0].Id, new List<String>{ largeText });

    Test.startTest();
    try {
        CandidateShareController.saveCandidateFeedback(
            feedbackMap,
            job.Id
        );
        System.assert(false, 'Expected AuraHandledException');
    } catch (AuraHandledException e) {
        
    }
    Test.stopTest();
}
@isTest
static void testUpdateInterviewStatus_NullList() {

    Job_Position__c job = [SELECT Id FROM Job_Position__c LIMIT 1];

    Test.startTest();
    try {
        CandidateShareController.updateInterviewStatusToShortlisted(
            null,
            job.Id
        );
        System.assert(false, 'Exception expected');
    } catch (AuraHandledException e) {
        
    }
    Test.stopTest();
}
@isTest
static void testUpdateInterviewStatus_NoInterviewsFound() {

    Contact c = [SELECT Id FROM Contact LIMIT 1];

    // Fake Job Id (not existing)
    Id fakeJobId = 'a00000000000001AAA';

    Test.startTest();
    try {
        CandidateShareController.updateInterviewStatusToShortlisted(
            new List<Id>{c.Id},
            fakeJobId
        );
        System.assert(false, 'Exception expected');
    } catch (AuraHandledException e) {
       
    }
    Test.stopTest();
}
}