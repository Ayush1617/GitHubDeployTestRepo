/**
 * @description
 * Service class to fetch a candidate’s profile photo from Google Drive
 * and return it as a Base64-encoded string for display in Lightning
 * Web Components.
 *
 * Uses Google Drive APIs via Named Credential and follows a
 * low-complexity, helper-based design.
 *
 * @author Shivam Shivhare
 * @since  Nov 2025
 */
public with sharing class CandidatePhotoService {

    private static final String NAMED_CREDENTIAL = 'GoogleDriveNC';
    private static final String CANDIDATE_RT = 'Candidate';
    private static final String PHOTO_NAME = 'Candidate Photo';

      /**
     * @description
     * Retrieves the candidate profile photo from Google Drive
     * and returns it as a Base64-encoded string.
     *
     * @param candidateId  Id of the Candidate Contact record.
     * @return Base64-encoded image string if found; otherwise null.
     */
    @AuraEnabled(cacheable=true)
    public static String getCandidateProfilePhotoBase64(Id candidateId) {
        try {
            Contact candidate = fetchCandidate(candidateId);
            if (!isValidCandidate(candidate)) {
                return null;
            }

            String folderId = fetchCandidateFolderId(candidate);
            if (folderId == null) {
                return null;
            }

            String photoFileId = fetchCandidatePhotoFileId(folderId);
            if (photoFileId == null) {
                return null;
            }

            return fetchFileAsBase64(photoFileId);

        } catch (Exception e) {
            return null;
        }
    }

    // ==================================================================================
    // Candidate helpers
    // ==================================================================================

    private static Contact fetchCandidate(Id candidateId) {
        return [
            SELECT Name, RecordType.DeveloperName
            FROM Contact
            WHERE Id = :candidateId
            WITH USER_MODE
            LIMIT 1
        ];
    }

    private static Boolean isValidCandidate(Contact candidate) {
        return candidate != null
            && candidate.RecordType != null
            && candidate.RecordType.DeveloperName == CANDIDATE_RT;
    }

    // ==================================================================================
    // Google Drive helpers
    // ==================================================================================

    private static String fetchCandidateFolderId(Contact candidate) {
        String folderName = candidate.Name + '_' + candidate.Id;
        String query =
            'mimeType=\'application/vnd.google-apps.folder\' and name=\'' + folderName + '\'';

        HttpResponse res = sendDriveRequest(
            '/drive/v3/files?q=' + EncodingUtil.urlEncode(query, 'UTF-8')
        );

        if (res == null) {
            return null;
        }

        Map<String, Object> result =
            (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> files = (List<Object>) result.get('files');

        return files.isEmpty()
            ? null
            : (String) ((Map<String, Object>) files[0]).get('id');
    }

    private static String fetchCandidatePhotoFileId(String folderId) {
        String query = '\'' + folderId + '\' in parents and trashed=false';

        HttpResponse res = sendDriveRequest(
            '/drive/v3/files?q=' + EncodingUtil.urlEncode(query, 'UTF-8')
        );

        if (res == null) {
            return null;
        }

        Map<String, Object> result =
            (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> files = (List<Object>) result.get('files');

        for (Object obj : files) {
            Map<String, Object> file = (Map<String, Object>) obj;
            if (((String) file.get('name')).contains(PHOTO_NAME)) {
                return (String) file.get('id');
            }
        }
        return null;
    }

    private static String fetchFileAsBase64(String fileId) {
        HttpResponse res = sendDriveRequest(
            '/drive/v3/files/' + fileId + '?alt=media'
        );

        return res != null && res.getStatusCode() == 200
            ? EncodingUtil.base64Encode(res.getBodyAsBlob())
            : null;
    }

    // ==================================================================================
    // HTTP utility
    // ==================================================================================

    private static HttpResponse sendDriveRequest(String endpoint) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + NAMED_CREDENTIAL + endpoint);
        req.setMethod('GET');

        HttpResponse res = new Http().send(req);
        return res != null && res.getStatusCode() == 200 ? res : null;
    }
}