/**
 * @description
 * Test class for LinkedInService.
 * Covers success scenarios, job detail retrieval,
 * company name fetch, LinkedIn post creation,
 * and callout exception handling.
 *
 * @author AJAY Kaurav
 * @since 2025-11-25
 */

@IsTest
public class LinkedInService_Test {

    @TestSetup
    static void setupTestData() {

         Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];

     User u = new User(
        Alias = 'tuser',
        Email = 'testuser@test.com',
        EmailEncodingKey = 'UTF-8',
        LastName = 'User',
        LanguageLocaleKey = 'en_US',
        LocaleSidKey = 'en_US',
        ProfileId = p.Id,
        TimeZoneSidKey = 'Asia/Kolkata',
        Username = 'testuser' + System.currentTimeMillis() + '@test.com'
    );
    insert u;

        Account client = Recruitment_TestDataFactory.createClient('Test Client', 'client@test.com');
        insert client;

        Project__c proj = Recruitment_TestDataFactory.createProject('Test Project');
        insert proj;

        Job_Position__c jobPos = Recruitment_TestDataFactory.createJobPosition(client, proj);
        jobPos.Skills_Required__c = 'Apex, LWC, Integration';
        jobPos.Employment_Type__c = 'Full-Time';
        jobPos.Mode__c = 'Online';
        jobPos.Work_Mode__c = 'Hybrid';
		jobPos.No_Of_Days__c = 3;
        jobPos.Shift_Time__c = 'Day';
        jobPos.Qualification__c = 'B.Tech';
		jobPos.Minimum_Experience_Required__c = 2;
        jobPos.Maximum_Experience_Required__c = 4;
        jobPos.Soft_skills__c = 'Communication';
        jobPos.Aditional_Skills__c = 'Git';
        insert jobPos;
    }

    // ----------------------------------------------------
    // SUCCESS: Get Job Details
    // ----------------------------------------------------
    @IsTest
    static void testGetJobDetailsForLinkedinSuccess() {
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        Job_Position__c jp = [SELECT Id FROM Job_Position__c LIMIT 1];
        
        System.runAs(u) {
        Test.startTest();
        Job_Position__c result = LinkedInService.getJobDetailsForLinkedin(jp.Id);
        Test.stopTest();

        System.assertNotEquals( null, result, 'Job details should not be null');
        System.assertEquals('Full-Time', result.Employment_Type__c, 'Employment type should be Full-Time');
        }

    }

    // ----------------------------------------------------
    // SUCCESS: Get Company Name
    // ----------------------------------------------------
    @IsTest
    static void testGetCompanyNameSuccess() {
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        Test.startTest();
        String cname = LinkedInService.getCompanyName();
        Test.stopTest();

        System.assertNotEquals('',cname, 'Company name should not be empty');
        System.assertNotEquals(null, cname, 'Company name should not be null');
        }

    }

/**
 * @description
 * Mock implementation for successful LinkedIn post callout.
 */
    private class LinkedInMockSuccess implements HttpCalloutMock {
/**
 * @description
 * Returns a mocked successful HTTP response
 * for LinkedIn post creation callout.
 *
 * @param req Incoming HTTP request
 * @return Mocked HTTP response with success status
 */
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(201);
            res.setBody('{"id":"urn:li:ugcPost:98765"}');
            return res;
        }
    }

    @IsTest
    static void testCreatePostSuccess() {
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new LinkedInMockSuccess());

    System.runAs(u) {
        Test.startTest();
        String res = LinkedInService.createPost('Test Hiring Post');
        Test.stopTest();

        System.assert(
            res.contains('urn:li:ugcPost'),
            'Response should contain LinkedIn post URN'
        );
    }
    }

/**
 * @description
 * Mock implementation for failed LinkedIn post callout.
 */
    private class LinkedInMockError implements HttpCalloutMock {
/**
 * @description
 * Simulates a callout exception for LinkedIn
 * post creation failure scenario.
 *
 * @param req Incoming HTTP request
 * @return Never returns a response (throws exception)
 */
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Mocked LinkedIn failure!');
        }
    }

    @IsTest
    static void testCreatePostCalloutException() {
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new LinkedInMockError());
        Boolean exceptionThrown = false;

        System.runAs(u) {
        try {
            Test.startTest();
            LinkedInService.createPost('Error Post');
            Test.stopTest();
        } catch (Exception ex) {
            exceptionThrown = true;
        }

        System.assertEquals(true, exceptionThrown, 'Exception must be thrown on callout failure');
    }
}
}