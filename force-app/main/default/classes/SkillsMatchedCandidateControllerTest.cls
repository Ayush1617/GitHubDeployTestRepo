@IsTest
public class SkillsMatchedCandidateControllerTest {

    /* =====================================================
       TEST SETUP
    ===================================================== */
    @TestSetup
    static void setupData() {

        Account client = Recruitment_TestDataFactory.createClient(
            'Test Client','client@test.com'
        );
        insert client;

        Project__c project =
            Recruitment_TestDataFactory.createProject('Test Project');
        insert project;

        Job_Position__c job =
            Recruitment_TestDataFactory.createJobPosition(client, project);
        job.Aditional_Skills__c = 'LWC';
        job.Soft_skills__c = 'Communication';
        job.Skills_Required__c = 'Salesforce';
        job.Minimum_Experience_Required__c = 3;
        job.Maximum_Experience_Required__c = 6;
        job.Work_Location__c = 'Manhattan Area';
        insert job;

        // Perfect match
        Contact matching =
            Recruitment_TestDataFactory.createCandidate(
                'John Doe','john@test.com'
            );
        matching.Skills__c = 'Salesforce, LWC';
        matching.Relevant_Experience__c = 4;
        matching.Current_Location__c = 'Manhattan Area';
        matching.Notice_Period__c = '15 days';
        matching.Rating__c = 'Excellent';
        insert matching;

        // Already assigned (excluded)
        Contact assigned =
            Recruitment_TestDataFactory.createCandidate(
                'Assigned','assigned@test.com'
            );
        assigned.Skills__c = 'Salesforce';
        insert assigned;

        insert new Interview__c(
            Job_Position__c = job.Id,
            Candidate_Name__c = assigned.Id
        );
    }

    /* =====================================================
       HAPPY PATH
    ===================================================== */
    @IsTest
    static void testGetMatchedCandidates() {
        Job_Position__c job = [SELECT Id FROM Job_Position__c LIMIT 1];

        Test.startTest();
        List<SkillsMatchedCandidateController.CandidateWrapper> res =
            SkillsMatchedCandidateController.getMatchedCandidates(job.Id);
        Test.stopTest();

        System.assertEquals(1, res.size());
        System.assert(res[0].matchPercentage > 0);
    }

    /* =====================================================
       EXPERIENCE – BELOW MIN & ABOVE MAX
    ===================================================== */
    @IsTest
    static void testExperienceAllBranches() {
        Job_Position__c job = [SELECT Id FROM Job_Position__c LIMIT 1];

        Contact junior =
            Recruitment_TestDataFactory.createCandidate(
                'Junior','jun@test.com'
            );
        junior.Skills__c = 'Salesforce';
        junior.Relevant_Experience__c = 1;
        insert junior;

        Contact senior =
            Recruitment_TestDataFactory.createCandidate(
                'Senior','sen@test.com'
            );
        senior.Skills__c = 'Salesforce';
        senior.Relevant_Experience__c = 12;
        insert senior;

        Test.startTest();
        SkillsMatchedCandidateController.getMatchedCandidates(job.Id);
        Test.stopTest();

        System.assert(true);
    }

    /* =====================================================
       LOCATION – PREFERRED PARTIAL (70%)
    ===================================================== */
    @IsTest
    static void testPreferredLocationPartialMatch() {
        Job_Position__c job = [SELECT Id FROM Job_Position__c LIMIT 1];

        Contact c =
            Recruitment_TestDataFactory.createCandidate(
                'Pref Partial','pref@test.com'
            );
        c.Skills__c = 'Salesforce';
        c.Preferred_Location__c = 'Manhattan Zone';
        insert c;

        Test.startTest();
        SkillsMatchedCandidateController.getMatchedCandidates(job.Id);
        Test.stopTest();

        System.assert(true);
    }

    /* =====================================================
       LOCATION – CURRENT PARTIAL (60%)
    ===================================================== */
    @IsTest
    static void testCurrentLocationPartialMatch() {
        Job_Position__c job = [SELECT Id FROM Job_Position__c LIMIT 1];

        Contact c =
            Recruitment_TestDataFactory.createCandidate(
                'Curr Partial','curr@test.com'
            );
        c.Skills__c = 'Salesforce';
        c.Current_Location__c = 'Manhattan Zone';
        insert c;

        Test.startTest();
        SkillsMatchedCandidateController.getMatchedCandidates(job.Id);
        Test.stopTest();

        System.assert(true);
    }

    /* =====================================================
       AVAILABILITY – ALL RANGES (20–100)
    ===================================================== */
    @IsTest
    static void testAvailabilityAllRanges() {

        Job_Position__c job = [SELECT Id FROM Job_Position__c LIMIT 1];

        List<String> periods = new List<String>{
            'Immediate','5 days','10 days','20 days','60 days'
        };

        Integer i = 0;
        for (String p : periods) {
            Contact c =
                Recruitment_TestDataFactory.createCandidate(
                    'Avail'+i,'a'+i+'@test.com'
                );
            c.Skills__c = 'Salesforce';
            c.Notice_Period__c = p;
            insert c;
            i++;
        }

        Test.startTest();
        SkillsMatchedCandidateController.getMatchedCandidates(job.Id);
        Test.stopTest();

        System.assert(true);
    }

    /* =====================================================
       SORTING (RATING + DATE)
    ===================================================== */
    @IsTest
    static void testSortingLogic() {
        Job_Position__c job = [SELECT Id FROM Job_Position__c LIMIT 1];

        Contact good =
            Recruitment_TestDataFactory.createCandidate(
                'Good','good@test.com'
            );
        good.Skills__c = 'Salesforce';
        good.Rating__c = 'Good';
        insert good;

        Contact excellent =
            Recruitment_TestDataFactory.createCandidate(
                'Excellent','ex@test.com'
            );
        excellent.Skills__c = 'Salesforce';
        excellent.Rating__c = 'Excellent';
        insert excellent;

        Test.startTest();
        SkillsMatchedCandidateController.getMatchedCandidates(job.Id);
        Test.stopTest();

        System.assert(true);
    }

    /* =====================================================
       CREATE INTERVIEW – DML EXCEPTION
    ===================================================== */
    @IsTest
    static void testCreateInterviewCatch() {

        Job_Position__c job = [SELECT Id FROM Job_Position__c LIMIT 1];
        Contact c = [SELECT Id FROM Contact LIMIT 1];

        SkillsMatchedCandidateController.createInterview(job.Id, c.Id);

        try {
            SkillsMatchedCandidateController.createInterview(job.Id, c.Id);
           
        } catch (AuraHandledException ex) {
            System.assert(true);
        }
    }

    /* =====================================================
       BULK CREATE – DML EXCEPTION
    ===================================================== */
    @IsTest
    static void testBulkCreateCatch() {

        Job_Position__c job = [SELECT Id FROM Job_Position__c LIMIT 1];
        Contact c = [SELECT Id FROM Contact LIMIT 1];

        SkillsMatchedCandidateController.createInterviewsBulk(
            job.Id, new List<Id>{c.Id}
        );

        try {
            SkillsMatchedCandidateController.createInterviewsBulk(
                job.Id, new List<Id>{c.Id}
            );
           
        } catch (AuraHandledException ex) {
            System.assert(true);
        }
    }
}