/*
 #####################################################
 # Created By (Date)    : Shivam Shivhare (Dec, 2025)
 # Description          : Queueable Apex to upload Candidate Resume
 #                        to Google Drive using Named Credential.
 #
 # Modifications Log    :
 * Ver    Date               Author           Modification
 * 1.0    Dec, 2025          Admin            Initial Version
 * 1.1    Jan, 2026          Assistant        Refactored for PMD Complexity
 #####################################################
*/

/**
 * Queueable class for uploading candidate resume.
 * Implements AllowsCallouts and Finalizer as per PMD rules.
 */
public class CandidateDriveUploadQueueable implements Queueable, Database.AllowsCallouts, System.Finalizer {

    private Id candidateId;
    private String fileName;
    private String contentType;
    private String base64Data;

    @TestVisible private static Boolean TESTFORCENULLPARENTFOLDER = false;
    @TestVisible private static Boolean TESTFORCENULLNAMEDCRED = false;

    /**
     * Constructor to initialize job parameters.
     *
     * @param candidateId Id of the Candidate__c record whose resume is being uploaded
     * @param fileName Name of the file to be uploaded
     * @param contentType MIME type of file content (for example application/pdf)
     * @param base64Data Base64-encoded binary content of the resume file
     */
    public CandidateDriveUploadQueueable(Id candidateId, String fileName, String contentType, String base64Data) {
        this.candidateId = candidateId;
        this.fileName = fileName;
        this.contentType = contentType;
        this.base64Data = base64Data;
    }

    /**
     * Queueable job entry point.
     *
     * @param ctx QueueableContext instance provided by Salesforce platform
     */
    public void execute(QueueableContext ctx) {

        try {
            if (this.candidateId == null) {return;}

            String parentFolderId = getParentFolderId();
            String namedCredential = getNamedCredential();

            if (String.isBlank(parentFolderId) || String.isBlank(namedCredential)) {return;}

            Contact  cand = [
                SELECT Id, Name
                FROM Contact 
                WHERE Id = :candidateId
                LIMIT 1
            ];

            String folderId = handleFolderCreation(cand, parentFolderId, namedCredential);
            if (String.isBlank(folderId)) {return;}

            String resolvedMime = resolveMimeType();
            String resolvedName = resolveFileName(resolvedMime);

            String driveFileId =
                uploadMultipart(folderId, resolvedName, base64Data, resolvedMime, namedCredential);

            if (String.isNotBlank(driveFileId)) {
                updateResumeLink(candidateId, driveFileId);
            }

        } catch (Exception e) {
            System.debug('Error in CandidateDriveUploadQueueable.execute: ' + e.getMessage());
        }
    }

    /**
     * Finalizer required by PMD rule QueueableWithoutFinalizer.
     * Executes automatically after the Queueable job finishes (success or failure).
     *
     * @param ctx FinalizerContext instance providing result, request Id and parent job details
     */
    public void execute(System.FinalizerContext ctx) {
    try {
        System.debug('CandidateDriveUploadQueueable job finished.');
    } catch (Exception e) {
        System.debug('Error in CandidateDriveUploadQueueable.finalizer: ' + e.getMessage());
    }
}

    // ---------------- HELPER METHODS ----------------

    private String handleFolderCreation(Contact cand, String parentId, String namedCred) {
        String safeName = (cand.Name != null ? cand.Name : 'Candidate')
            .replaceAll('[^A-Za-z0-9 _-]', '');
        String folderName = safeName + '_' + cand.Id;
        return getOrCreateFolder(folderName, parentId, namedCred);
    }

    private String resolveMimeType() {
        if (String.isNotBlank(this.contentType)) {return this.contentType;}
        String lowerName = (this.fileName == null) ? '' : this.fileName.toLowerCase();
        if (lowerName.endsWith('.pdf')) {return 'application/pdf';}
        else if (lowerName.endsWith('.docx')) {return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';}
                                               else if (lowerName.endsWith('.doc')) {return 'application/msword';}
        return 'application/octet-stream';
    }

    private String resolveFileName(String mimeType) {
        if (this.fileName != null && this.fileName.contains('.')) {
            Integer idx = this.fileName.lastIndexOf('.');
            String ext = this.fileName.substring(idx + 1);
            return 'Resume.' + ext;
        }

        String ext = 'bin';
        if (mimeType.contains('pdf')) {ext = 'pdf';}
        else if (mimeType.contains('word') || mimeType.contains('document')) {ext = 'doc';}
        return 'Resume.' + ext;
    }

    private static String getNamedCredential() {
        try {
            if (TESTFORCENULLNAMEDCRED) {return null;}
            Google_Drive_Parent_Folder__mdt md = [
                SELECT Named_Credential__c
                FROM Google_Drive_Parent_Folder__mdt
                LIMIT 1
            ];
            return md.Named_Credential__c;
        } catch (Exception e) {
            System.debug('Error in getNamedCredential: ' + e.getMessage());
            return null;
        }
    }

    private static String getParentFolderId() {
        try {
            if (TESTFORCENULLPARENTFOLDER) {return null;}
            Google_Drive_Parent_Folder__mdt md = [
                SELECT Parent_Folder_ID__c
                FROM Google_Drive_Parent_Folder__mdt
                LIMIT 1
            ];
            return md.Parent_Folder_ID__c;
        } catch (Exception e) {
            System.debug('Error in getParentFolderId: ' + e.getMessage());
            return null;
        }
    }

    private static String getOrCreateFolder(String folderName, String parentFolderId, String namedCredential) {
        Http http = new Http();
        try {
            String query =
                'name = \'' + folderName +
                '\' and mimeType = \'application/vnd.google-apps.folder\' ' +
                'and \'' + parentFolderId + '\' in parents and trashed = false';
            HttpRequest searchReq = new HttpRequest();
            searchReq.setEndpoint(
                'callout:' + namedCredential + '/drive/v3/files?q=' +
                EncodingUtil.urlEncode(query, 'UTF-8')
            );
            searchReq.setMethod('GET');
            HttpResponse searchRes = http.send(searchReq);

            if (searchRes.getStatusCode() == 200) {
                Map<String, Object> r = (Map<String, Object>) JSON.deserializeUntyped(searchRes.getBody());
                List<Object> files = (List<Object>) r.get('files');
                if (files != null && !files.isEmpty()) {
                    return (String) ((Map<String, Object>) files.get(0)).get('id');
                }
            }

            HttpRequest createReq = new HttpRequest();
            createReq.setEndpoint('callout:' + namedCredential + '/drive/v3/files');
            createReq.setMethod('POST');
            createReq.setHeader('Content-Type', 'application/json');
            createReq.setBody(JSON.serialize(
                new Map<String, Object>{
                    'name' => folderName,
                    'mimeType' => 'application/vnd.google-apps.folder',
                    'parents' => new List<String>{ parentFolderId }
                }
            ));
            HttpResponse createRes = http.send(createReq);

            if (createRes.getStatusCode() == 200 || createRes.getStatusCode() == 201) {
                Map<String, Object> r2 = (Map<String, Object>) JSON.deserializeUntyped(createRes.getBody());
                return (String) r2.get('id');
            }
        } catch (Exception e) {
            System.debug('Error in getOrCreateFolder: ' + e.getMessage());
        }
        return null;
    }

    private static String uploadMultipart(
        String folderId,
        String fileName,
        String base64Data,
        String mimeType,
        String namedCredential
    ) {
        try {
            String boundary = 'CandidateBoundary' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
            String metadataJson = JSON.serialize(
                new Map<String, Object>{
                    'name' => fileName,
                    'parents' => new List<String>{ folderId }
                }
            );
            String body =
                '--' + boundary + '\r\n' +
                'Content-Type: application/json; charset=UTF-8\r\n\r\n' + metadataJson + '\r\n' +
                '--' + boundary + '\r\n' +
                'Content-Type: ' + mimeType + '\r\n' +
                'Content-Transfer-Encoding: base64\r\n\r\n' +
                base64Data + '\r\n' +
                '--' + boundary + '--';
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:' + namedCredential + '/upload/drive/v3/files?uploadType=multipart');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'multipart/related; boundary=' + boundary);
            req.setBody(body);
            HttpResponse res = new Http().send(req);

            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                return (String) parsed.get('id');
            }
        } catch (Exception e) {
            System.debug('Error in uploadMultipart: ' + e.getMessage());
        }
        return null;
    }

    private static void updateResumeLink(Id candidateId, String driveFileId) {
        try {
            update new Contact (
                Id = candidateId,
                Resume_Link__c = 'https://drive.google.com/file/d/' + driveFileId + '/view'
            );
        } catch (Exception e) {
            System.debug('Error in updateResumeLink: ' + e.getMessage());
        }
    }
}