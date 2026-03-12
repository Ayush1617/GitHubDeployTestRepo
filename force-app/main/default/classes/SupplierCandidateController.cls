/**
 * @description Controller used by AddToExistingCandidate LWC for:
 *  - searching supplier-owned candidates (SOSL + pagination)
 *  - updating candidate fields + resume upload
 *  - creating Interview__c records
 *
 * PMD SAFE:
 *  - Low method complexity
 *  - Low class-level complexity
 *
 * @lastModifiedOn January 2026
 */
public with sharing class SupplierCandidateController {

    /* ======================================================
       WRAPPERS
       ====================================================== */
    
    /**
     * @description
     * Wrapper class used to return paginated Candidate records
     * along with the total record count to the UI.
     */
    public class CandidatePageResult {
        @AuraEnabled public List<Contact> records;
        @AuraEnabled public Integer totalRecords;
    }
    
    /**
     * @description
     * Data transfer object used to receive candidate update
     * details from the Lightning Web Component.
     *
     * Includes optional resume upload information.
     */
    public class CandidateUpdateRequest {
        @AuraEnabled public Id candidateId;
        @AuraEnabled public String noticePeriod;
        @AuraEnabled public Decimal expectedRate;
        @AuraEnabled public ResumeUploadRequest resume;
    }
    
    /**
     * @description
     * Wrapper class representing resume file data sent
     * from the client for upload processing.
     */
    public class ResumeUploadRequest {
        @AuraEnabled public String fileName;
        @AuraEnabled public String contentType;
        @AuraEnabled public String base64Body;
    }

    /* ======================================================
       SEARCH CONTEXT (PMD SAFE PARAM OBJECT)
       ====================================================== */

    private class SearchContext {
        CandidatePageResult result;
        Set<Id> supplierAccountIds;
        String searchKey;
        Integer pageSize;
        Integer offsetSize;
    }

    /* ======================================================
       1. SEARCH + PAGINATION
       ====================================================== */
    
    /**
     * @description
     * Retrieves supplier-owned Candidate records with
     * optional search and pagination support.
     *
     * @param searchKey   Search text entered by the user
     * @param pageSize    Number of records per page
     * @param pageNumber  Current page number
     * @return Paginated list of candidates and total count
     */
    @AuraEnabled(cacheable=true)
    public static CandidatePageResult getMyCandidatesBySearch(
        String searchKey,
        Integer pageSize,
        Integer pageNumber
    ) {
        CandidatePageResult result = initResult();
        Set<Id> supplierAccountIds = getSupplierAccountIdsForCurrentUser();

        pageSize   = (pageSize == null || pageSize <= 0) ? 5 : pageSize;
        pageNumber = (pageNumber == null || pageNumber <= 0) ? 1 : pageNumber;

        SearchContext ctx = new SearchContext();
        ctx.result = result;
        ctx.supplierAccountIds = supplierAccountIds;
        ctx.searchKey = searchKey;
        ctx.pageSize = pageSize;
        ctx.offsetSize = (pageNumber - 1) * pageSize;

        if (supplierAccountIds.isEmpty()) {
            return result;
        }

        if (String.isBlank(searchKey)) {
            loadCandidatesWithoutSearch(ctx);
        } else {
            loadCandidatesWithSearch(ctx);
        }

        return result;
    }

    /* ======================================================
       SEARCH HELPERS
       ====================================================== */

    private static CandidatePageResult initResult() {
        CandidatePageResult res = new CandidatePageResult();
        res.records = new List<Contact>();
        res.totalRecords = 0;
        return res;
    }

    private static Set<Id> getSupplierAccountIdsForCurrentUser() {
        Set<Id> accountIds = new Set<Id>();

        for (Account acc : [
            SELECT Id
            FROM Account
            WHERE OwnerId = :UserInfo.getUserId()
            AND RecordType.DeveloperName = 'Partner_Community_Supplier'
            WITH USER_MODE
        ]) {
            accountIds.add(acc.Id);
        }
        return accountIds;
    }

    private static void loadCandidatesWithoutSearch(SearchContext ctx) {
        ctx.result.totalRecords = [
            SELECT COUNT()
            FROM Contact
            WHERE Supplier__c IN :ctx.supplierAccountIds
            AND RecordType.DeveloperName = 'Candidate'
        ];

        ctx.result.records = [
            SELECT Id, Name, Email, Phone,
                   Notice_Period__c,
                   Supplier_Expected_Rate__c,
                   Designation__c,
                   Experience_Year__c
            FROM Contact
            WHERE Supplier__c IN :ctx.supplierAccountIds
            AND RecordType.DeveloperName = 'Candidate'
            ORDER BY Name
            LIMIT :ctx.pageSize OFFSET :ctx.offsetSize
        ];
    }

    private static void loadCandidatesWithSearch(SearchContext ctx) {
        Set<Id> contactIds = searchContactIds(ctx.searchKey);

        if (contactIds.isEmpty()) {
            ctx.result.totalRecords = 0;
            return;
        }

        ctx.result.totalRecords = [
            SELECT COUNT()
            FROM Contact
            WHERE Id IN :contactIds
            AND Supplier__c IN :ctx.supplierAccountIds
            AND RecordType.DeveloperName = 'Candidate'
        ];

        ctx.result.records = [
            SELECT Id, Name, Email, Phone,
                   Notice_Period__c,
                   Supplier_Expected_Rate__c,
                   Designation__c,
                   Experience_Year__c
            FROM Contact
            WHERE Id IN :contactIds
            AND Supplier__c IN :ctx.supplierAccountIds
            AND RecordType.DeveloperName = 'Candidate'
            ORDER BY Name
            LIMIT :ctx.pageSize OFFSET :ctx.offsetSize
        ];
    }

    private static Set<Id> searchContactIds(String searchKey) {
        Set<Id> ids = new Set<Id>();
        String term = '*' + searchKey.replace('*', '') + '*';

        List<List<SObject>> results = [
            FIND :term IN ALL FIELDS
            RETURNING Contact(
                Id
                WHERE RecordType.DeveloperName = 'Candidate'
                LIMIT 200
            )
        ];

        if (!results.isEmpty()) {
            for (SObject sob : results[0]) {
                ids.add((Id)sob.get('Id'));
            }
        }
        return ids;
    }

    /* ======================================================
       2. UPDATE CANDIDATE (CONTACT)
       ====================================================== */
    
    /**
     * @description
     * Updates editable fields on a Candidate record and
     * optionally triggers resume upload processing.
     *
     * @param payloadJson JSON string containing candidate
     *                    update details
     * @return Updated Candidate record
     * @throws AuraHandledException
     *         When payload is invalid or update fails
     */
    @AuraEnabled
    public static Contact updateCandidateFields(String payloadJson) {
        CandidateUpdateRequest req = parseUpdateRequest(payloadJson);

        Contact c = new Contact(Id = req.candidateId);

        if (req.noticePeriod != null) {
            c.Notice_Period__c = req.noticePeriod;
        }
        if (req.expectedRate != null) {
            c.Supplier_Expected_Rate__c = req.expectedRate;
        }

        Database.update(c, AccessLevel.USER_MODE);
        enqueueResumeUpload(req);

        return fetchContact(req.candidateId);
    }

    private static CandidateUpdateRequest parseUpdateRequest(String payloadJson) {
        if (String.isBlank(payloadJson)) {
            throw new AuraHandledException('Payload missing.');
        }

        CandidateUpdateRequest req =
            (CandidateUpdateRequest) JSON.deserialize(
                payloadJson,
                CandidateUpdateRequest.class
            );

        if (req == null || req.candidateId == null) {
            throw new AuraHandledException('Candidate Id missing.');
        }

        return req;
    }

    private static void enqueueResumeUpload(CandidateUpdateRequest req) {
        if (req.resume == null || String.isBlank(req.resume.base64Body)) {
            return;
        }

        System.enqueueJob(
            new CandidateDriveUploadQueueable(
                req.candidateId,
                req.resume.fileName,
                req.resume.contentType,
                req.resume.base64Body
            )
        );
    }

    private static Contact fetchContact(Id contactId) {
        return [
            SELECT Id, Name,
                   Notice_Period__c,
                   Supplier_Expected_Rate__c
            FROM Contact
            WHERE Id = :contactId AND RecordType.DeveloperName = 'Candidate'
            WITH USER_MODE
        ];
    }

    /* ======================================================
       3. CREATE INTERVIEWS
       ====================================================== */
    
    /**
     * @description
     * Creates Interview__c records for the selected
     * candidates against a Job Position.
     *
     * Prevents duplicate interviews and triggers
     * email notification after successful creation.
     *
     * @param candidateIds   List of Candidate record Ids
     * @param jobPositionId Job Position Id
     * @return List of newly created Interview records
     * @throws AuraHandledException
     *         When validation fails or duplicate interviews exist
     */
    @AuraEnabled
    public static List<Interview__c> createInterviews(
        List<Id> candidateIds,
        Id jobPositionId
    ) {
        if (candidateIds == null || candidateIds.isEmpty()) {
            throw new AuraHandledException('No candidates passed.');
        }
        if (jobPositionId == null) {
            throw new AuraHandledException('Job Position Id missing.');
        }

        InterviewDuplicateService.throwIfDuplicateExists(
            candidateIds,
            jobPositionId
        );

        List<Interview__c> interviews = new List<Interview__c>();
        for (Id cid : candidateIds) {
            interviews.add(new Interview__c(
                Candidate_Name__c = cid,
                Job_Position__c = jobPositionId
            ));
        }

        Database.insert(interviews, AccessLevel.USER_MODE);

        InterviewEmailService.sendInterviewCreationEmail(
            candidateIds,
            jobPositionId
        );

        return interviews;
    }
}