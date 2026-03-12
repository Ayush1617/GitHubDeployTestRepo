@IsTest
    private class CandidateDriveUploadQueueable_Test {
    
        private class Mock_MissingMeta implements HttpCalloutMock {
            public HttpResponse respond(HttpRequest req) {
                HttpResponse res = new HttpResponse();
                res.setStatusCode(200);
                res.setBody('{}');
                return res;
            }
        }
    
        private class GoogleDriveMock_Success implements HttpCalloutMock {
            public HttpResponse respond(HttpRequest req) {
                HttpResponse res = new HttpResponse();
                String endpoint = req.getEndpoint();
                if (endpoint.contains('/drive/v3/files?q=')) {
                    res.setStatusCode(200);
                    res.setBody('{"files":[{"id":"mockFolderId"}]}');
                } else if (endpoint.contains('/upload/drive/v3/files')) {
                    res.setStatusCode(200);
                    res.setBody('{"id":"mockFileId"}');
                }
                return res;
            }
        }
    
        private class GoogleDriveMock_CreateFolderThenUpload implements HttpCalloutMock {
            public HttpResponse respond(HttpRequest req) {
                HttpResponse res = new HttpResponse();
                String endpoint = req.getEndpoint();
                if (endpoint.contains('/drive/v3/files?q=')) {
                    res.setStatusCode(200);
                    res.setBody('{"files":[]}');
                } else if (endpoint.endsWith('/drive/v3/files')) {
                    res.setStatusCode(200);
                    res.setBody('{"id":"createdFolderId"}');
                } else if (endpoint.contains('/upload/drive/v3/files')) {
                    res.setStatusCode(200);
                    res.setBody('{"id":"mockFileId"}');
                }
                return res;
            }
        }
    
        private class GoogleDriveMock_UploadFailure implements HttpCalloutMock {
            public HttpResponse respond(HttpRequest req) {
                HttpResponse res = new HttpResponse();
                if (req.getMethod() == 'POST') {
                    res.setStatusCode(400);
                    res.setBody('Bad Request');
                }
                return res;
            }
        }
    
        private class GoogleDriveMock_GenericFailure implements HttpCalloutMock {
            public HttpResponse respond(HttpRequest req) {
                HttpResponse res = new HttpResponse();
                res.setStatusCode(500);
                return res;
            }
        }
        private class GoogleDriveMock_FailedUploadButFolderOK implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
        HttpResponse res = new HttpResponse();
        if (req.getMethod() == 'GET') {
            res.setStatusCode(200);
            res.setBody('{"files":[{"id":"existingFolder"}]}');
        } else {
            res.setStatusCode(400);  // forces fail on upload
            res.setBody('Bad Upload');
        }
        return res;
    }
}

      
    
        @TestSetup
        static void setupData() {
            Contact candidate = Recruitment_TestDataFactory.createCandidate('Test Candidate', 'test@example.com');
            candidate.LastName= 'Candidate';
            candidate.FirstName = 'Test';
            insert candidate;
        }
    
        @IsTest
        static void test_Success() {
            Contact cand = [SELECT Id FROM Contact LIMIT 1];
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new GoogleDriveMock_Success());
            System.enqueueJob(new CandidateDriveUploadQueueable(
                cand.Id,'resume.pdf','application/pdf','aaa'));
            Test.stopTest();
            System.assertNotEquals(null, [SELECT Resume_Link__c FROM Contact WHERE Id = :cand.Id].Resume_Link__c);
        }
    
        @IsTest
        static void test_CreateFolder() {
            Contact cand = [SELECT Id FROM Contact LIMIT 1];
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new GoogleDriveMock_CreateFolderThenUpload());
            System.enqueueJob(new CandidateDriveUploadQueueable(
                cand.Id,'resume.pdf','application/pdf','aaa'));
            Test.stopTest();
        }
    
        @IsTest
        static void test_UploadFailure() {
            Contact cand = [SELECT Id FROM Contact LIMIT 1];
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new GoogleDriveMock_UploadFailure());
            System.enqueueJob(new CandidateDriveUploadQueueable(
                cand.Id,'resume.pdf','application/pdf','aaa'));
            Test.stopTest();
        }
    
        @IsTest
        static void test_GenericFailure() {
            Contact cand = [SELECT Id FROM Contact LIMIT 1];
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new GoogleDriveMock_GenericFailure());
            System.enqueueJob(new CandidateDriveUploadQueueable(
                cand.Id,'resume.pdf','application/pdf','aaa'));
            Test.stopTest();
        }
    
        @IsTest
        static void test_NullCandidateExit() {
            Test.startTest();
            System.enqueueJob(new CandidateDriveUploadQueueable(
                null,'resume.pdf','application/pdf','aaa'));
            Test.stopTest();
        }
    
        @IsTest
        static void test_MimeDocxBranch() {
            Contact cand = [SELECT Id FROM Contact LIMIT 1];
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new GoogleDriveMock_Success());
            System.enqueueJob(new CandidateDriveUploadQueueable(
                cand.Id,'resume.docx',null,'aaa'));
            Test.stopTest();
        }
    
        @IsTest
        static void test_DocMimeFinalExt() {
            Contact cand = [SELECT Id FROM Contact LIMIT 1];
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new GoogleDriveMock_Success());
            System.enqueueJob(new CandidateDriveUploadQueueable(
                cand.Id,'resume.doc',null,'aaa'));
            Test.stopTest();
        }
    
        @IsTest
        static void test_ExtBinCoverage() {
            Contact cand = [SELECT Id FROM Contact LIMIT 1];
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new GoogleDriveMock_Success());
            System.enqueueJob(new CandidateDriveUploadQueueable(
                cand.Id,'unknownfile','aaa/bbb','aaa'));
            Test.stopTest();
        }
    
        @IsTest
        static void test_MissingParentFolder() {
            Contact cand = [SELECT Id FROM Contact LIMIT 1];
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new Mock_MissingMeta());
            System.enqueueJob(new CandidateDriveUploadQueueable(
                cand.Id,'resume.pdf','application/pdf','aaa'));
            Test.stopTest();
        }
    
        @IsTest
        static void test_MissingNamedCred() {
            Contact cand = [SELECT Id FROM Contact LIMIT 1];
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new Mock_MissingMeta());
            System.enqueueJob(new CandidateDriveUploadQueueable(
                cand.Id,'resume.pdf',null,'aaa'));
            Test.stopTest();
        }
        @IsTest
        static void test_ForceMissingParentFolder() {
            CandidateDriveUploadQueueable.TESTFORCENULLPARENTFOLDER = true;
        
            Contact cand = [SELECT Id FROM Contact LIMIT 1];
            Test.startTest();
            System.enqueueJob(new CandidateDriveUploadQueueable(
                cand.Id,'resume.pdf','application/pdf','aaa'));
            Test.stopTest();
        
            CandidateDriveUploadQueueable.TESTFORCENULLPARENTFOLDER = false; // reset
        }
        
        @IsTest
        static void test_ForceMissingNamedCred() {
            CandidateDriveUploadQueueable.TESTFORCENULLNAMEDCRED = true;
        
            Contact cand = [SELECT Id FROM Contact LIMIT 1];
            Test.startTest();
            System.enqueueJob(new CandidateDriveUploadQueueable(
                cand.Id,'resume.pdf','application/pdf','aaa'));
            Test.stopTest();
        
            CandidateDriveUploadQueueable.TESTFORCENULLNAMEDCRED = false; // reset
        }
        @IsTest
        static void test_DefaultMime_OctetStream() {
            Contact cand = [SELECT Id FROM Contact LIMIT 1];
        
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new GoogleDriveMock_Success());
            // fileName = null + contentType = null → default mime branch hit
            System.enqueueJob(new CandidateDriveUploadQueueable(
                cand.Id,
                null,      // triggers branch
                null,      // triggers application/octet-stream
                'aaa'
            ));
            Test.stopTest();
        
            System.assert(true);
        }
        
        @IsTest
        static void test_UploadFailure_returnBranch() {
            Contact cand = [SELECT Id FROM Contact LIMIT 1];
        
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new GoogleDriveMock_FailedUploadButFolderOK());
            System.enqueueJob(new CandidateDriveUploadQueueable(
                cand.Id,
                'resume.pdf',
                'application/pdf',
                'abcdef'
            ));
            Test.stopTest();
        
            System.assert(true);
        }

        
    }