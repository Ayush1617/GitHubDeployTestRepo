@IsTest
private class LightcastSkillServiceTest {

    /* -------------------------------
     * Test Setup
     * ------------------------------- */
    @TestSetup
    static void setupTestData() {
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
    }

    /* -------------------------------
     * Mock Classes
     * ------------------------------- */
    private class LightcastSkillServiceMockSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            System.assertEquals('GET', req.getMethod());
            System.assert(
                req.getEndpoint().contains('callout:Lightcast/skills/versions/latest/skills')
            );

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"data":[{"name":"Java"},{"name":"Apex"},{"name":"LWC"}]}');
            return res;
        }
    }

    private class LightcastSkillServiceMockError implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error":"Internal Server Error"}');
            return res;
        }
    }

    private class LightcastSkillServiceMockThrows implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"invalid_json":'); // malformed JSON
            return res;
        }
    }

    /* -------------------------------
     * Test Methods
     * ------------------------------- */

    @IsTest
    static void testFetchSkillsSuccess() {
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

        System.runAs(u) {
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new LightcastSkillServiceMockSuccess());
            List<String> skills = LightcastSkillService.fetchSkills('apex');
            Test.stopTest();

            System.assertEquals(3, skills.size());
            System.assert(skills.contains('Java'));
            System.assert(skills.contains('Apex'));
            System.assert(skills.contains('LWC'));
        }
    }

    @IsTest
    static void testFetchSkillsErrorResponse() {
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

        System.runAs(u) {
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new LightcastSkillServiceMockError());
            List<String> skills = LightcastSkillService.fetchSkills('error');
            Test.stopTest();

            System.assertEquals(
                0,
                skills.size(),
                'Should return empty list when API returns non-200 response'
            );
        }
    }

    @IsTest
    static void testFetchSkillsExceptionHandling() {
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        Boolean exceptionThrown = false;

        System.runAs(u) {
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new LightcastSkillServiceMockThrows());

            try {
                LightcastSkillService.fetchSkills('exception'); 
            } catch (AuraHandledException ex) {
                exceptionThrown = true;
            }

            Test.stopTest();
        }

        System.assert(
            exceptionThrown,
            'AuraHandledException should be thrown for malformed JSON response'
        );
    }
}