/**
 * @description
 * Test class for JobDescriptionController.
 * Covers job detail retrieval, job description generation,
 * save functionality, and error handling.
 *
 * @author
 * AJay Kaurav
 */
@IsTest
public class JobDescriptionControllerTest {

    /**
     * @description
     * Mock implementation for OpenAI HTTP callout.
     */
    private class OpenAIMock implements HttpCalloutMock {

        /**
         * @description
         * Returns a mocked OpenAI response.
         *
         * @param req HTTPRequest
         * @return HTTPResponse
         */
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '{ "choices": [ { "message": { "content": "Mock AI Job Description" } } ] }'
            );
            return res;
        }
    }

    /**
     * @description
     * Creates a standard test user for System.runAs().
     *
     * @return User
     */
    private static User createTestUser() {
        Profile p = [
            SELECT Id
            FROM Profile
            WHERE Name = 'System Administrator'
            LIMIT 1
        ];

        return new User(
            Alias = 'tuser',
            Email = 'testuser@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            Username = 'testuser' + DateTime.now().getTime() + '@test.com'
        );
    }

    /**
     * @description
     * Test data setup executed once for all test methods.
     */
    @TestSetup
    static void setupData() {

        Account client =
            Recruitment_TestDataFactory.createClient(
                'Test Client',
                'client@example.com'
            );
        insert client;

        Project__c project =
            Recruitment_TestDataFactory.createProject('Test Project');

        Job_Position__c job =
            Recruitment_TestDataFactory.createJobPosition(client, project);

        job.Client_Name__c = client.Id;
        job.Job_Title__c = 'Salesforce Developer';
        job.Skills_Required__c = 'Apex; Java';
        job.Qualification__c = 'B.Tech';
        job.Maximum_Experience_Required__c = 3;
        job.Minimum_Experience_Required__c = 4;
        job.Soft_skills__c = 'Communication';

        insert job;
    }

    /**
     * @description
     * Tests retrieval of job details.
     */
    @IsTest
    static void testGetJobDetails() {

        User u = createTestUser();
        insert u;

        System.runAs(u) {

            Job_Position__c job =
                [SELECT Id, Skills_Required__c FROM Job_Position__c LIMIT 1];

            Test.startTest();
            Job_Position__c result =
                JobDescriptionController.getJobDetails(job.Id);
            Test.stopTest();

            System.assertNotEquals(
                null,
                result,
                'Job details should be returned'
            );

            System.assertEquals(
                'Apex; Java',
                result.Skills_Required__c,
                'Skills should match test data'
            );
        }
    }

    /**
     * @description
     * Tests job description generation using OpenAI mock response.
     */
    @IsTest
    static void testGenerateJobDescription() {

        User u = createTestUser();
        insert u;

        System.runAs(u) {

            Job_Position__c job =
                [
                    SELECT Id,
                           Skills_Required__c,
                           Aditional_Skills__c,
                           Qualification__c,
                           Required_Experience_Range__c,
                           Soft_skills__c
                    FROM Job_Position__c
                    LIMIT 1
                ];

            JobDescriptionController.JobDescriptionRequest req =
                new JobDescriptionController.JobDescriptionRequest();

            req.jobId = job.Id;
            req.skillsData = job.Skills_Required__c;
            req.additional = job.Aditional_Skills__c;
            req.qualification = job.Qualification__c;
            req.experience = job.Required_Experience_Range__c;
            req.soft = job.Soft_skills__c;
            req.tone = 'Professional';
            req.length = 'Medium';
            req.lengthsize = 'Short';

            String requestJson = JSON.serialize(req);

            Test.setMock(HttpCalloutMock.class, new OpenAIMock());

            Test.startTest();
            String response =
                JobDescriptionController.generateJobDescription(requestJson);
            Test.stopTest();

            System.assertNotEquals(
                null,
                response,
                'Generated job description response should not be null'
            );

            System.assert(
                response.contains('Mock AI Job Description'),
                'Expected mocked OpenAI response'
            );
        }
    }

    /**
     * @description
     * Tests successful save of job description.
     */
    @IsTest
    static void testSaveJobDescription() {

        User u = createTestUser();
        insert u;

        System.runAs(u) {

            Job_Position__c job =
                [SELECT Id FROM Job_Position__c LIMIT 1];

            Test.startTest();
            JobDescriptionController.saveJobDescription(
                job.Id,
                'Updated Description'
            );
            Test.stopTest();

            Job_Position__c updatedJob =
                [
                    SELECT Job_Description__c
                    FROM Job_Position__c
                    WHERE Id = :job.Id
                ];

            System.assertEquals(
                'Updated Description',
                updatedJob.Job_Description__c,
                'Job description should be updated successfully'
            );
        }
    }

    /**
     * @description
     * Tests error handling when Job Id is null.
     */
    @IsTest
    static void testSaveJobDescriptionError() {

        User u = createTestUser();
        insert u;

        System.runAs(u) {

            Test.startTest();
            try {
                JobDescriptionController.saveJobDescription(null, 'Desc');

                System.assertEquals(
                    true,
                    false,
                    'Expected AuraHandledException'
                );
            } catch (AuraHandledException ex) {

                System.assert(
                    ex.getMessage().contains('Script-thrown exception'),
                    'Expected AuraHandledException wrapper'
                );
            }
            Test.stopTest();
        }
    }
}