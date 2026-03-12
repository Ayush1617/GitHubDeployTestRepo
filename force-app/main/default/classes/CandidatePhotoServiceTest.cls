/*
#####################################################
# Created By (Date)   : Shivam Shivhare (11 Nov, 2025)
# Description         : Test class for CandidatePhotoService Apex class.
#                       Covers positive and negative Google Drive callout scenarios.
# Modifications Log   :
* Ver    Date              Author              Modification
* 2.0    16 Jan, 2026      Refactor            PMD compliance fixes
#####################################################
*/

@IsTest
private class CandidatePhotoServiceTest {

    /* =========================================================
     * Mock Classes
     * ========================================================= */

    /**
     * @description
     * Mock implementation simulating successful Google Drive operations:
     * folder lookup, file lookup, and file download.
     */
    private class GoogleDrivePhotoMock implements HttpCalloutMock {
        /**
        * @description
        * Returns a mocked HTTP response for Google Drive API requests.
        *
        * @param req The HTTP request sent by the Apex callout framework.
        * @return Mocked HttpResponse based on the request endpoint.
        */
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            String endpoint = req.getEndpoint();

            if (endpoint.contains('mimeType%3D%27application%2Fvnd.google-apps.folder%27')) {
                res.setStatusCode(200);
                res.setBody('{"files":[{"id":"mockFolderId","name":"Folder_Test"}]}');
            } else if (endpoint.contains('in+parents')) {
                res.setStatusCode(200);
                res.setBody('{"files":[{"id":"mockFileId","name":"Candidate Photo"}]}');
            } else if (endpoint.contains('/drive/v3/files/mockFileId?alt=media')) {
                res.setStatusCode(200);
                res.setBody('This is dummy file content');
            } else {
                res.setStatusCode(404);
                res.setBody('{}');
            }
            return res;
        }
    }

    /**
     * @description
     * Mock implementation simulating a generic HTTP failure.
     */
    private class FailingMock implements HttpCalloutMock {
        /**
         * @description
         * Returns a failed HTTP response for error scenario testing.
         *
         * @param req The HTTP request sent by the Apex callout framework.
         * @return HttpResponse with HTTP 500 status.
         */
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Error');
            return res;
        }
    }

    /**
     * @description
     * Mock implementation simulating a folder without a candidate photo.
     */
    private class NoPhotoMock implements HttpCalloutMock {
        /**
         * @description
         * Returns a response where no candidate photo exists.
         *
         * @param req The HTTP request sent by the Apex callout framework.
         * @return HttpResponse without candidate photo file.
         */
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            String endpoint = req.getEndpoint();

            if (endpoint.contains('mimeType%3D%27application%2Fvnd.google-apps.folder%27')) {
                res.setStatusCode(200);
                res.setBody('{"files":[{"id":"mockFolderId","name":"Folder_Test"}]}');
            } else if (endpoint.contains('in+parents')) {
                res.setStatusCode(200);
                res.setBody('{"files":[{"id":"mockFileId","name":"Resume.pdf"}]}');
            } else {
                res.setStatusCode(200);
                res.setBody('Dummy');
            }
            return res;
        }
    }

    /**
     * @description
     * Mock implementation simulating failure while downloading the photo file.
     */
    private class FileDownloadFailMock implements HttpCalloutMock {
        /**
         * @description
         *  Returns an error response for photo download failure.
         *
         * @param req The HTTP request sent by the Apex callout framework.
         * @return HttpResponse indicating download failure.
         */
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            String endpoint = req.getEndpoint();

            if (endpoint.contains('mimeType%3D%27application%2Fvnd.google-apps.folder%27')) {
                res.setStatusCode(200);
                res.setBody('{"files":[{"id":"mockFolderId","name":"Folder_Test"}]}');
            } else if (endpoint.contains('in+parents')) {
                res.setStatusCode(200);
                res.setBody('{"files":[{"id":"mockFileId","name":"Candidate Photo"}]}');
            } else if (endpoint.contains('/drive/v3/files/mockFileId?alt=media')) {
                res.setStatusCode(404);
                res.setBody('{"error":"File not found"}');
            }
            return res;
        }
    }

    /* =========================================================
     * Test Setup
     * ========================================================= */

    @TestSetup
    static void setupData() {
        Contact c = Recruitment_TestDataFactory.createCandidate('Test', 'test@test.com');
        insert c;
    }

    /* =========================================================
     * Test Methods
     * ========================================================= */

    @IsTest
    static void testGetCandidateProfilePhotoBase64Success() {
        User u = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        Contact c = [SELECT Id FROM Contact LIMIT 1];

        System.runAs(u) {
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new GoogleDrivePhotoMock());
            String base64 = CandidatePhotoService.getCandidateProfilePhotoBase64(c.Id);
            Test.stopTest();

            System.assertNotEquals(null, base64);
            System.assertEquals(
                EncodingUtil.base64Encode(Blob.valueOf('This is dummy file content')),
                base64
            );
        }
    }

    @IsTest
    static void testGetCandidateProfilePhotoBase64Failure() {
        User u = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        Contact c = [SELECT Id FROM Contact LIMIT 1];

        System.runAs(u) {
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new FailingMock());
            String base64 = CandidatePhotoService.getCandidateProfilePhotoBase64(c.Id);
            Test.stopTest();
            System.assertEquals(null, base64);
        }
    }

    @IsTest
    static void testGetCandidateProfilePhotoBase64NoPhotoFound() {
        User u = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        Contact c = [SELECT Id FROM Contact LIMIT 1];

        System.runAs(u) {
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new NoPhotoMock());
            String base64 = CandidatePhotoService.getCandidateProfilePhotoBase64(c.Id);
            Test.stopTest();
            System.assertEquals(null, base64);
        }
    }

    @IsTest
    static void testGetCandidateProfilePhotoBase64FileDownloadFail() {
        User u = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        Contact c = [SELECT Id FROM Contact LIMIT 1];

        System.runAs(u) {
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new FileDownloadFailMock());
            String base64 = CandidatePhotoService.getCandidateProfilePhotoBase64(c.Id);
            Test.stopTest();
            System.assertEquals(null, base64);
        }
    }

    @IsTest
    static void testGetCandidateProfilePhotoBase64ExceptionCatch() {
        User u = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];

        // create and delete to avoid hardcoded Id
        Contact temp = new Contact(LastName = 'Temp');
        insert temp;
        Id deletedId = temp.Id;
        delete temp;

        System.runAs(u) {
            Test.startTest();
            String base64 = CandidatePhotoService.getCandidateProfilePhotoBase64(deletedId);
            Test.stopTest();
            System.assertEquals(null, base64);
        }
    }
}