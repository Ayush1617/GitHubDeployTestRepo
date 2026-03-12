/**
 * @description
 * Test class for CandidateDocumentService (Contact-based Candidate).
 */
@IsTest
private class CandidateDocumentServiceTest {

    /* =========================================================
     * MOCK CLASSES
     * ========================================================= */

    private class GoogleDriveSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();

            if (req.getEndpoint().contains('/drive/v3/files?q=') &&
                !req.getEndpoint().contains('&fields=files')) {

                res.setStatusCode(200);
                res.setBody('{"files":[{"id":"mockFolderId"}]}');

            } else if (req.getEndpoint().endsWith('/drive/v3/files')) {

                res.setStatusCode(200);
                res.setBody('{"id":"createdFolderId"}');

            } else if (req.getEndpoint().contains('/upload/drive/v3/files')) {

                res.setStatusCode(200);
                res.setBody('{"id":"mockFileId"}');

            } else if (req.getEndpoint().contains('&fields=files')) {

                res.setStatusCode(200);
                res.setBody('{"files":[{"id":"file1","name":"Resume.pdf","size":1024,"createdTime":"2025-01-01T10:00:00Z"}]}');

            } else if (req.getMethod() == 'DELETE') {
                res.setStatusCode(204);
            }

            return res;
        }
    }

    private class GoogleDriveFailureMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Error');
            return res;
        }
    }

    private class FileFetchFailureMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();

            if (req.getEndpoint().contains('/drive/v3/files?q=') &&
                !req.getEndpoint().contains('&fields=files')) {

                res.setStatusCode(200);
                res.setBody('{"files":[{"id":"mockFolderId"}]}');

            } else if (req.getEndpoint().contains('&fields=files')) {

                res.setStatusCode(500);
                res.setBody('File fetch failed');
            }

            return res;
        }
    }
   
    /* =========================================================
     * TEST SETUP
     * ========================================================= */

    @TestSetup
    static void setupData() {
        Contact candidate =
            Recruitment_TestDataFactory.createCandidate(
                'Test Candidate',
                'test@gmail.com'
            );
        insert candidate;
    }

    /* =========================================================
     * HELPER
     * ========================================================= */

    private static CandidateDocumentService.FileUploadRequest buildRequest(Id contactId) {
        CandidateDocumentService.FileUploadRequest req =
            new CandidateDocumentService.FileUploadRequest();

        req.fileName   = 'Resume.pdf';
        req.base64Data = EncodingUtil.base64Encode(Blob.valueOf('dummy'));
        req.mimeType   = 'application/pdf';
        req.recordId   = contactId;

        return req;
    }
    
    private static User getRunAsUser() {
        return [
            SELECT Id
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
    }


    /* =========================================================
     * TEST METHODS
     * ========================================================= */

    @IsTest
    static void testUploadFileSuccess() {
        
         User u = getRunAsUser();

    System.runAs(u) {
        Contact c = [SELECT Id FROM Contact LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new GoogleDriveSuccessMock());
        CandidateDocumentService.testParentFolderId = 'parent123';

        Test.startTest();
        String fileId =
            CandidateDocumentService.uploadFileToDrive(buildRequest(c.Id));
        Test.stopTest();

        System.assertEquals('mockFileId', fileId);
        CandidateDocumentService.testParentFolderId = null;
    }
    }

    @IsTest
    static void testUploadFileWithMetadataParentFolder() {
        
         User u = getRunAsUser();

    System.runAs(u) {
        Contact c = [SELECT Id FROM Contact LIMIT 1];
    
        // Force metadata path
        CandidateDocumentService.testParentFolderId = null;
    
        // Callout mock is mandatory
        Test.setMock(HttpCalloutMock.class, new GoogleDriveSuccessMock());
    
        Test.startTest();
        String fileId =
            CandidateDocumentService.uploadFileToDrive(buildRequest(c.Id));
        Test.stopTest();
    
        // Assert SUCCESS, not failure
        System.assertEquals('mockFileId', fileId);
    }
    }


    @IsTest
    static void testUploadMultipartFailure() {
        
         User u = getRunAsUser();

    System.runAs(u) {
        Contact c = [SELECT Id FROM Contact LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new GoogleDriveFailureMock());
        CandidateDocumentService.testParentFolderId = 'parent123';

        Boolean thrown = false;
        try {
            Test.startTest();
            CandidateDocumentService.uploadFileToDrive(buildRequest(c.Id));
            Test.stopTest();
        } catch (AuraHandledException e) {
            thrown = true;
        }

        System.assert(thrown);
        CandidateDocumentService.testParentFolderId = null;
    }
    }

    @IsTest
    static void testGetFilesSuccess() {
        
         User u = getRunAsUser();

    System.runAs(u) {
        Contact c = [SELECT Id FROM Contact LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new GoogleDriveSuccessMock());
        CandidateDocumentService.testParentFolderId = 'parent123';

        Test.startTest();
        List<Map<String, Object>> files =
            CandidateDocumentService.getFiles(c.Id);
        Test.stopTest();

        System.assertEquals(1, files.size());
        CandidateDocumentService.testParentFolderId = null;
    }
    }

    @IsTest
    static void testGetFilesFileFetchFailure() {
        
         User u = getRunAsUser();

    System.runAs(u) {
        Contact c = [SELECT Id FROM Contact LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new FileFetchFailureMock());
        CandidateDocumentService.testParentFolderId = 'parent123';

        Boolean thrown = false;
        try {
            Test.startTest();
            CandidateDocumentService.getFiles(c.Id);
            Test.stopTest();
        } catch (AuraHandledException e) {
            thrown = true;
        }

        System.assert(thrown);
        CandidateDocumentService.testParentFolderId = null;
    }
    }
    
    @IsTest
    static void testDeleteFileSuccess() {
        
         User u = getRunAsUser();

    System.runAs(u) {
        Test.setMock(HttpCalloutMock.class, new GoogleDriveSuccessMock());

        Test.startTest();
        String result =
            CandidateDocumentService.deleteFileFromDrive('mockFileId');
        Test.stopTest();

        System.assertEquals('File deleted successfully', result);
    }
    }

    @IsTest
    static void testDeleteFileFailure() {
        
         User u = getRunAsUser();

    System.runAs(u) {
        Test.setMock(HttpCalloutMock.class, new GoogleDriveFailureMock());

        Boolean thrown = false;
        try {
            Test.startTest();
            CandidateDocumentService.deleteFileFromDrive('badId');
            Test.stopTest();
        } catch (AuraHandledException e) {
            thrown = true;
        }

        System.assert(thrown);
    }
    }
    @IsTest
    static void testUpdateResumeLink() {
        
         User u = getRunAsUser();

    System.runAs(u) {
        Contact c = [SELECT Id FROM Contact LIMIT 1];

        Test.startTest();
        CandidateDocumentService.updateResumeLink(c.Id, 'drive123');
        CandidateDocumentService.updateResumeLink(c.Id, null);
        Test.stopTest();

        Contact updated =
            [SELECT Resume_Link__c FROM Contact WHERE Id = :c.Id];

        System.assertEquals(null, updated.Resume_Link__c);
    }
    }

    @IsTest
    static void testGetLoggedInCandidateId() {
        // This test only verifies that the method executes safely
        // In internal user context, ContactId is usually null
        
         User u = getRunAsUser();

    System.runAs(u) {
    
        Test.startTest();
        Id result = CandidateDocumentService.getLoggedInCandidateId();
        Test.stopTest();
    
        // Internal users generally have no ContactId → null is expected
        System.assertEquals(null, result,
            'Expected null candidate Id for internal user context');
    }
    }
    
    @IsTest
    static void testGetRecordTypeIdNotFound() {
        
         User u = getRunAsUser();

    System.runAs(u) {
        Boolean thrown = false;
    
        try {
            Test.startTest();
            CandidateDocumentService.getRecordTypeId(
                'Contact',
                'Invalid_RT_Name'
            );
            Test.stopTest();
        } catch (AuraHandledException e) {
            thrown = true;
        }
    
        // ✅ This is the ONLY reliable assertion
        System.assert(thrown, 'Expected exception when record type does not exist');
    }
    }
}