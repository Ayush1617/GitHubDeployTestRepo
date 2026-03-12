/**
 * @description
 * Test class for {@link CreateCandidateController}.
 *
 * This class validates all functional and exception paths for:
 *  - Interview creation for existing candidates
 *  - Interview creation for newly created candidates
 *  - Input validation and error handling
 *  - Object describe utility methods
 */
@IsTest
public class CreateCandidateControllerTest {

    /**
     * @description
     * Creates common test data required by all test methods.
     *
     * Test data includes:
     *  - System Administrator user
     *  - Client Account and Project
     *  - Multiple Candidate Contacts
     *  - Job Position
     *  - Interviews with varying dates and ownership
     *
     * This method runs once per test execution.
     */
    @TestSetup
    static void setupData() {

        Profile p = [
            SELECT Id
            FROM Profile
            WHERE Name = 'System Administrator'
            LIMIT 1
        ];

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

        Account client = Recruitment_TestDataFactory.createClient(
            'Test Client',
            'client@example.com'
        );

        Project__c project = Recruitment_TestDataFactory.createProject(
            'Test Project'
        );

        Contact cand  = Recruitment_TestDataFactory.createCandidate(
            'Test Candidate',
            'candidate@example.com'
        );
        Contact cand1 = Recruitment_TestDataFactory.createCandidate(
            'Test Candidate1',
            'candidate2@example.com'
        );
        Contact cand2 = Recruitment_TestDataFactory.createCandidate(
            'Test Candidate2',
            'candidate1@example.com'
        );

        insert new List<SObject>{ client, project, cand, cand1, cand2 };

        Job_Position__c job = Recruitment_TestDataFactory.createJobPosition(
            client,
            project
        );
        insert job;

        Interview__c inter = Recruitment_TestDataFactory.createInterview(cand, job);
        inter.Interview_Date__c = DateTime.now().addDays(1);
        inter.Interview_Mode__c = 'Online';
        insert inter;

        Interview__c todayInterview = Recruitment_TestDataFactory.createInterview(cand1, job);
        todayInterview.OwnerId = u.Id;
        todayInterview.Interview_Date__c = System.now().addDays(1);
        insert todayInterview;

        Interview__c oldInterview = Recruitment_TestDataFactory.createInterview(cand2, job);
        oldInterview.OwnerId = u.Id;
        insert oldInterview;

        Test.setCreatedDate(oldInterview.Id, System.now().addMonths(-4));
    }

	/**
     * @description
     * Verifies that {@link CreateCandidateController#createInterviewForNewCandidate}
     * throws an {@link AuraHandledException} when an invalid candidate name
     * (blank LastName) is provided.
     *
     * Expected behavior:
     *  - Contact insert fails due to missing LastName
     *  - Exception is caught and wrapped in AuraHandledException
     */
	@IsTest
    static void testCreateInterviewForNewCandidateInvalidCandidateName() {
        Boolean exceptionThrown = false;
    
        // Get valid Job Position
        Job_Position__c job = [SELECT Id FROM Job_Position__c LIMIT 1];
    
        // Run as a real user (required because of `insert as user`)
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    
        System.runAs(u) {
            try {
                Test.startTest();
    
                // Pass INVALID candidate name (LastName is mandatory)
                CreateCandidateController.createInterviewForNewCandidate(
                    '', // invalid candidate name
                    'invalidcandidate@example.com',
                    job.Id
                );
    
                Test.stopTest();
                System.assert(false, 'Exception should have been thrown');
    
            } catch (AuraHandledException e) {
                exceptionThrown = true; 
            }
    
            System.assert(exceptionThrown, 'Expected exception was not thrown');
        }
    }


    /**
     * @description
     * Verifies that {@link CreateCandidateController#createInterviewRecord}
     * throws an {@link AuraHandledException} when required input parameters
     * are missing.
     *
     * Expected behavior:
     *  - Method validates inputs
     *  - Exception is thrown for null candidateId and jobPositionId
     */
    @IsTest
    static void testCreateInterviewRecordMissingInputs() {
		Boolean exceptionThrown = false;
		User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        try {
            Test.startTest();
            CreateCandidateController.createInterviewRecord(null, null);
            Test.stopTest();
            System.assert(false, 'Exception should have been thrown');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
		System.assert(exceptionThrown, 'Expected Exception thrown');
        }
    }

    /**
     * @description
     * Verifies that {@link CreateCandidateController#createInterviewRecord}
     * throws an {@link AuraHandledException} when an invalid Candidate Id
     * is provided.
     *
     * Expected behavior:
     *  - Candidate lookup returns no records
     *  - Exception is thrown indicating candidate not found
     */
    @IsTest
    static void testCreateInterviewRecordInvalidCandidate() {
		Boolean exceptionThrown = false;
        Job_Position__c job = [SELECT Id FROM Job_Position__c LIMIT 1];
		User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        try {
            Test.startTest();
            CreateCandidateController.createInterviewRecord(
                '003000000000AAA', // fake Contact Id
                job.Id
            );
            Test.stopTest();
            System.assert(false, 'Exception should have been thrown');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
		System.assert(exceptionThrown, 'Expected Exception thrown');
        }
    }

    /**
     * @description
     * Verifies that {@link CreateCandidateController#createInterviewRecord}
     * throws an {@link AuraHandledException} when an invalid Job Position Id
     * is provided.
     *
     * Expected behavior:
     *  - Job Position lookup returns no records
     *  - Exception is thrown indicating job position not found
     */
    @IsTest
    static void testCreateInterviewRecordInvalidJobPosition() {
        Boolean exceptionThrown = false;
    
        Contact cand = [SELECT Id FROM Contact LIMIT 1];
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    
        System.runAs(u) {
            try {
                Test.startTest();
                CreateCandidateController.createInterviewRecord(
                    cand.Id,
                    'a0A000000000AAA' // fake Job_Position__c Id
                );
                Test.stopTest();
                System.assert(false, 'Exception should have been thrown');
            } catch (AuraHandledException e) {
                exceptionThrown = true;
            }
            System.assert(exceptionThrown, 'Expected Exception thrown');
        }
    }

    /**
     * @description
     * Verifies that {@link CreateCandidateController#getCandidateObjectName}
     * returns the correct API name for the Candidate object.
     *
     * Expected value:
     *  - {@code Contact}
     */
    @IsTest
    static void testGetCandidateObjectName() {
		User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        Test.startTest();
        String objectName = CreateCandidateController.getCandidateObjectName();
        Test.stopTest();

        System.assertEquals('Contact', objectName);
    }
    }

    /**
     * @description
     * Verifies that {@link CreateCandidateController#getInterviewObjectName}
     * returns the correct API name for the Interview object.
     *
     * Expected value:
     *  - {@code Interview__c}
     */
    @IsTest
    static void testGetInterviewObjectName() {
		User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        Test.startTest();
        String objectName = CreateCandidateController.getInterviewObjectName();
        Test.stopTest();

        System.assertEquals('Interview__c', objectName);
    }
    }

    /**
     * @description
     * Verifies successful execution of
     * {@link CreateCandidateController#createInterviewForNewCandidate}.
     *
     * Expected behavior:
     *  - New Candidate Contact is created
     *  - Interview record is created and linked to the candidate and job position
     *  - No exceptions are thrown
     */
    @IsTest
    static void testCreateInterviewForNewCandidateSuccess() {

        Job_Position__c job = [SELECT Id FROM Job_Position__c LIMIT 1];
		User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        Test.startTest();
        CreateCandidateController.createInterviewForNewCandidate(
            'New Candidate',
            'newcandidate@example.com',
            job.Id
        );
        Test.stopTest();

        Contact createdCandidate = [
            SELECT Id, Email
            FROM Contact
            WHERE Email = 'newcandidate@example.com'
            LIMIT 1
        ];

        System.assertNotEquals(null, createdCandidate);

        Interview__c createdInterview = [
            SELECT Id, Candidate_Name__c, Job_Position__c
            FROM Interview__c
            WHERE Candidate_Name__c = :createdCandidate.Id
            LIMIT 1
        ];

        System.assertEquals(job.Id, createdInterview.Job_Position__c);
    }
    }
}