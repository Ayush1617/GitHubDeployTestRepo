/**
 * #####################################################
 * @description
 * Service class for handling Google Drive operations
 * (upload, fetch, delete, resume link update)
 * for Candidate documents.
 *
 * @author
 * Shivam Shivhare
 *
 * @since
 * 02-Sep-2025
 * #####################################################
 */
public without sharing class CandidateDocumentService {
    
    // Record Type Developer Names - Use these for getRecordTypeInfosByDeveloperName()
    private static final String CANDIDATE_RECORD_TYPE_DEV_NAME = 'Candidate'; // Use actual Developer Name

    /* =========================================================
     * CONSTANTS & TEST SUPPORT
     * ========================================================= */

    /** Named Credential used for Google Drive callouts */
    private static final String NAMED_CREDENTIAL = getNamedCredential();

    /** Test override for parent folder id */
    @TestVisible
    private static String testParentFolderId;

    /* =========================================================
     * NAMED CREDENTIAL RESOLUTION
     * ========================================================= */

    /**
     * @description
     * Fetch Google Drive Named Credential from custom metadata.
     * Falls back to default if lookup fails.
     *
     * @return Named Credential name
     */
    private static String getNamedCredential() {
        try {
            Google_Drive_Parent_Folder__mdt md =
                [SELECT Named_Credential__c FROM Google_Drive_Parent_Folder__mdt WITH USER_MODE LIMIT 1];
            return md.Named_Credential__c;
        } catch (Exception ex) {
            return 'GoogleDriveNC';
        }
    }

    /* =========================================================
     * FILE UPLOAD
     * ========================================================= */
 /**
 * @description
 * Wrapper class used to receive file upload data from Lightning components.
 */
public class FileUploadRequest {

    /** Name of the file to be uploaded 
     * @description
 * Wrapper class used to receive file upload data from Lightning components.
    */
    @AuraEnabled public String fileName { get; set; }

    /** Base64 encoded content of the file 
     * @description
 * Wrapper class used to receive file upload data from Lightning components.
    */
    @AuraEnabled public String base64Data { get; set; }

    /** MIME type of the uploaded file 
     * @description
 * Wrapper class used to receive file upload data from Lightning components.
    */
    @AuraEnabled public String mimeType { get; set; }

    /** Google Drive folder Id where file will be stored 
     * @description
 * Wrapper class used to receive file upload data from Lightning components.
    */
    @AuraEnabled public String folderId { get; set; }

    /** Salesforce record Id associated with the file 
     * @description
 * Wrapper class used to receive file upload data from Lightning components.
    */
    @AuraEnabled public Id recordId { get; set; }
}






    /**
     * @description
     * Upload a file to Google Drive under a Candidate-specific folder.
     *
     * @param fileName   Name of the file
     * @param base64Data Base64 encoded file content
     * @param mimeType   MIME type of the file
     * @param recordId   Candidate record Id
     * @return Google Drive file Id
     */
    
    /**
     *  @description
     * Upload a file to  Google Drive under a Candidate-specific folder.
     * @param req FileUploadRequest

     * @return uploadMultipart
     */
    @AuraEnabled
    public static String uploadFileToDrive(FileUploadRequest req) {

   // public static String uploadFileToDrive(
        //String fileName,
        //String base64Data,
       // String mimeType,
      //  Id recordId
    //) 
    
        Id candidateRecordTypeId = getRecordTypeId('Contact', CANDIDATE_RECORD_TYPE_DEV_NAME);
            validateCandidateCRUD();

        Contact candidate =
            [SELECT Id, Name FROM Contact WHERE Id = :req.recordId AND RecordTypeId = :candidateRecordTypeId LIMIT 1];

        String folderName = candidate.Name + '_' + candidate.Id;
        String parentFolderId = resolveParentFolderId();
        String folderId = getOrCreateFolder(folderName, parentFolderId);

       // return uploadMultipart(folderId, fileName, base64Data, mimeType);
           req.folderId = folderId;
               return uploadMultipart(req);


    }

    /* =========================================================
     * FOLDER HANDLING
     * ========================================================= */

    /**
     * @description
     * Resolve the configured parent Google Drive folder Id.
     *
     * @return Parent folder Id
     */
    private static String resolveParentFolderId() {
        if (testParentFolderId != null) {
            return testParentFolderId;
        }

        Google_Drive_Parent_Folder__mdt md =
            [SELECT Parent_Folder_ID__c FROM Google_Drive_Parent_Folder__mdt WITH USER_MODE LIMIT 1];

        if (String.isBlank(md.Parent_Folder_ID__c)) {
            throw new AuraHandledException('Parent Folder ID is not configured.');
        }
        return md.Parent_Folder_ID__c;
    }

    /**
     * @description
     * Fetch an existing Candidate folder or create a new one.
     *
     * @param folderName     Folder name
     * @param parentFolderId Parent folder Id
     * @return Folder Id
     */
    private static String getOrCreateFolder(String folderName, String parentFolderId) {
        Http http = new Http();

        String query =
            'name = \'' + folderName +
            '\' and mimeType = \'application/vnd.google-apps.folder\'' +
            ' and \'' + parentFolderId +
            '\' in parents and trashed = false';

        HttpRequest searchReq = new HttpRequest();
        searchReq.setEndpoint(
            'callout:' + NAMED_CREDENTIAL +
            '/drive/v3/files?q=' + EncodingUtil.urlEncode(query, 'UTF-8')
        );
        searchReq.setMethod('GET');

        HttpResponse searchRes = http.send(searchReq);

        if (searchRes.getStatusCode() == 200) {
            Map<String, Object> result =
                (Map<String, Object>) JSON.deserializeUntyped(searchRes.getBody());
            List<Object> files = (List<Object>) result.get('files');

            if (!files.isEmpty()) {
                return (String) ((Map<String, Object>) files[0]).get('id');
            }
        }

        return createFolder(folderName, parentFolderId);
    }

    /**
     * @description
     * Create a new folder in Google Drive.
     *
     * @param folderName     Folder name
     * @param parentFolderId Parent folder Id
     * @return Created folder Id
     */
    private static String createFolder(String folderName, String parentFolderId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + NAMED_CREDENTIAL + '/drive/v3/files');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');

        req.setBody(JSON.serialize(new Map<String, Object>{
            'name' => folderName,
            'mimeType' => 'application/vnd.google-apps.folder',
            'parents' => new List<String>{ parentFolderId }
        }));

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
            return (String)
                ((Map<String, Object>) JSON.deserializeUntyped(res.getBody())).get('id');
        }

        throw new AuraHandledException('Folder creation failed.');
    }

    /* =========================================================
     * FILE UPLOAD (MULTIPART)
     * ========================================================= */

    /**
     * @description
     * Upload file content to Google Drive using multipart request.
     *
     * @param folderId   Target folder Id
     * @param fileName   File name
     * @param base64Data Base64 encoded data
     * @param mimeType   MIME type
     * @return Uploaded file Id
     */
  /*  private static String uploadMultipart(
        String folderId,
        String fileName,
        String base64Data,
        String mimeType
    ) {*/


/**
 * @description
 * Upload file content to Google Drive using multipart request.
 * @param req FileUploadRequest
 * @return Google Drive file Id
 */
private static String uploadMultipart(FileUploadRequest req) {

    String boundary = 'CandidateDocBoundary';

    String body =
        '--' + boundary + '\r\n' +
        'Content-Type: application/json; charset=UTF-8\r\n\r\n' +
        JSON.serialize(new Map<String, Object>{
            'name' => req.fileName,
            'parents' => new List<String>{ req.folderId }
        }) + '\r\n--' + boundary + '\r\n' +
        'Content-Type: ' + req.mimeType + '\r\n' +
        'Content-Transfer-Encoding: base64\r\n\r\n' +
        req.base64Data + '\r\n--' + boundary + '--';

    HttpRequest httpReq = new HttpRequest();
    httpReq.setEndpoint(
        'callout:' + NAMED_CREDENTIAL +
        '/upload/drive/v3/files?uploadType=multipart'
    );
    httpReq.setMethod('POST');
    httpReq.setHeader('Content-Type', 'multipart/related; boundary=' + boundary);
    httpReq.setBody(body);

    HttpResponse res = new Http().send(httpReq);

    if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
        return (String)
            ((Map<String, Object>) JSON.deserializeUntyped(res.getBody())).get('id');
    }

    throw new AuraHandledException('File upload failed.');
}

    /* =========================================================
     * FETCH FILES
     * ========================================================= */

    /**
     * @description
     * Fetch all files uploaded for a Candidate from Google Drive.
     *
     * @param recordId Candidate Id
     * @return List of file metadata maps
     */
    @AuraEnabled
    public static List<Map<String, Object>> getFiles(Id recordId) {
        validateCandidateCRUD();
        
        Id candidateRecordTypeId = getRecordTypeId('Contact', CANDIDATE_RECORD_TYPE_DEV_NAME);

        Contact candidate =
            [SELECT Id, Name FROM Contact WHERE Id = :recordId AND RecordTypeId = :candidateRecordTypeId LIMIT 1];

        String folderName = candidate.Name + '_' + candidate.Id;
        String parentFolderId = resolveParentFolderId();

        Http http = new Http();

        String folderQuery =
            'mimeType = \'application/vnd.google-apps.folder\'' +
            ' and name = \'' + folderName +
            '\' and \'' + parentFolderId +
            '\' in parents and trashed = false';

        HttpRequest folderReq = new HttpRequest();
        folderReq.setEndpoint(
            'callout:' + NAMED_CREDENTIAL +
            '/drive/v3/files?q=' + EncodingUtil.urlEncode(folderQuery, 'UTF-8')
        );
        folderReq.setMethod('GET');

        HttpResponse folderRes = http.send(folderReq);

        if (folderRes.getStatusCode() != 200) {
            throw new AuraHandledException('Folder lookup failed.');
        }

        Map<String, Object> folderResult =
            (Map<String, Object>) JSON.deserializeUntyped(folderRes.getBody());
        List<Object> folders = (List<Object>) folderResult.get('files');

        if (folders.isEmpty()) {
            return new List<Map<String, Object>>();
        }

        String folderId = (String) ((Map<String, Object>) folders[0]).get('id');

        HttpRequest fileReq = new HttpRequest();
        fileReq.setEndpoint(
            'callout:' + NAMED_CREDENTIAL +
            '/drive/v3/files?q=' +
            EncodingUtil.urlEncode('\'' + folderId + '\' in parents and trashed = false', 'UTF-8') +
            '&fields=files(id,name,mimeType,size,createdTime,modifiedTime)'
        );
        fileReq.setMethod('GET');

        HttpResponse fileRes = http.send(fileReq);

        if (fileRes.getStatusCode() != 200) {
            throw new AuraHandledException('File fetch failed.');
        }

        Map<String, Object> fileResult =
            (Map<String, Object>) JSON.deserializeUntyped(fileRes.getBody());

        List<Map<String, Object>> response = new List<Map<String, Object>>();
        for (Object obj : (List<Object>) fileResult.get('files')) {
            response.add((Map<String, Object>) obj);
        }

        return response;
    }

    /* =========================================================
     * DELETE FILE
     * ========================================================= */

    /**
     * @description
     * Delete a file from Google Drive.
     *
     * @param fileId Google Drive file Id
     * @return Status message
     */
    @AuraEnabled
    public static String deleteFileFromDrive(String fileId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + NAMED_CREDENTIAL + '/drive/v3/files/' + fileId);
        req.setMethod('DELETE');

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() == 204) {
            return 'File deleted successfully';
        }

        throw new AuraHandledException('File delete failed.');
    }

    /* =========================================================
     * UPDATE RESUME LINK
     * ========================================================= */

    /**
     * @description
     * Update Candidate resume link with Google Drive file URL.
     *
     * @param candidateId  Candidate Id
     * @param driveFileId  Google Drive file Id
     */
    @AuraEnabled
    public static void updateResumeLink(Id candidateId, String driveFileId) {
        validateCandidateCRUD();

        Contact cand = new Contact(
            Id = candidateId,
            Resume_Link__c =
                driveFileId == null
                ? null
                : 'https://drive.google.com/file/d/' + driveFileId + '/view'
        );

        update cand;
    }

    /* =========================================================
     * LOGGED-IN CANDIDATE
     * ========================================================= */

    /**
     * @description
     * Fetch Candidate Id associated with logged-in user.
     *
     * @return Candidate Id or null
     */
    @AuraEnabled
    public static Id getLoggedInCandidateId() {
        User u = [
            SELECT ContactId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            WITH USER_MODE
            LIMIT 1
        ];

        if (u.ContactId == null) {
            return null;
        }

        Id candidateRecordTypeId =
            getRecordTypeId('Contact', CANDIDATE_RECORD_TYPE_DEV_NAME);

        Contact c = [
            SELECT Id
            FROM Contact
            WHERE Id = :u.ContactId
            AND RecordTypeId = :candidateRecordTypeId
            LIMIT 1
        ];

        return c.Id;
    }


    /* =========================================================
     * SECURITY
     * ========================================================= */
 	
    /**
     * @description
     * Validate CRUD access for Candidate object.
     */
    private static void validateCandidateCRUD() {
        if (!Schema.sObjectType.Contact.isAccessible() ||
            !Schema.sObjectType.Contact.isUpdateable()) {
            throw new AuraHandledException('Insufficient Candidate access.');
        }
    }
    
    
    /**
     * @description
     * Helper method to get record type ID by name for any object.
     * Tries Developer Name first, then falls back to Label.
     *
     * @param objectName
     *        API name of the object.
     *
     * @param recordTypeName
     *        Developer Name or Label of the record type.
     *
     * @return Id
     *         Record type ID.
     *
     * @throws AuraHandledException
     *         If record type is not found.
     */
    @TestVisible
    private static Id getRecordTypeId(String objectName, String recordTypeName) {
        try {
            SObjectType objType = Schema.getGlobalDescribe().get(objectName);
            if (objType == null) {
                throw new AuraHandledException('Object ' + objectName + ' not found.');
            }
            
            // First try to get by Developer Name
            Map<String, Schema.RecordTypeInfo> recordTypesByDevName = objType.getDescribe().getRecordTypeInfosByDeveloperName();
            if (recordTypesByDevName.containsKey(recordTypeName)) {
                return recordTypesByDevName.get(recordTypeName).getRecordTypeId();
            }
            
            // If not found by Developer Name, try by Label
            Map<String, Schema.RecordTypeInfo> recordTypesByLabel = objType.getDescribe().getRecordTypeInfosByName();
            if (recordTypesByLabel.containsKey(recordTypeName)) {
                return recordTypesByLabel.get(recordTypeName).getRecordTypeId();
            }
            
            throw new AuraHandledException('Record type "' + recordTypeName + '" not found for ' + objectName);
        } catch (Exception e) {
            throw new AuraHandledException('Error getting record type: ' + e.getMessage());
        }
    }
    @AuraEnabled
public static String getDriveAuthStartUrl() {
    return '/services/auth/oauth/GoogleDriveAuth';
}





@AuraEnabled
public static Boolean checkDriveAuthentication() {
    try {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + NAMED_CREDENTIAL + '/drive/v3/about?fields=user');
        req.setMethod('GET');
        req.setTimeout(5000);   // prevent hanging

        HttpResponse res = new Http().send(req);

        return res.getStatusCode() == 200;

    } catch (Exception e) {
        return false;
    }
}

}