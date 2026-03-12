/*
 #####################################################
 # Created By (Date)   : Shivam Shivhare (Dec, 2025)
 # Description         : Apex Controller for Public Career Site.
 #                       - Job search with filters & pagination
 #                       - Fetch job details
 #                       - Candidate creation / update
 #                       - Duplicate candidate prevention
 #                       - Interview creation
 #                       - Resume upload via Queueable (Google Drive)
 #
 # Modifications Log   :
 * Ver    Date              Author         Modification
 * 1.0    Dec, 2025         Admin          Initial Version
 #####################################################
*/
/**
 * @description Apex Controller for Public Career Site.
 * Handles job search, job details, candidate submission and interview creation.
 * @author Shivam
 * @since Dec 2025
 */
public without sharing class CandidatePublicController {

    /* ==================================================================================
     * Inner Class: CandidateResponse
     * Purpose    : Wrapper class to send candidate submission response
     *              back to LWC / Aura components.
     * ==================================================================================
     */
/**
 * @description Wrapper to return job search results with pagination.
 */
/**
 * @description Searches job positions with filters and pagination.
 * @param req JobSearchRequest wrapper containing filters
 * @return JobSearchResponse paged job results
 */
    public class CandidateResponse {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Id candidateId;
        @AuraEnabled public Boolean interviewCreated;
        @AuraEnabled public Id interviewId;
    }

     /* ==================================================================================
     * Inner Class: JobSearchResponse
     * Purpose    : Wrapper class for Job search results with pagination info.
     * ==================================================================================
     */
/**
 * @description Wrapper class for job search filters and pagination.
 */
    public class JobSearchResponse {
        @AuraEnabled public Integer totalRecords;
        @AuraEnabled public Integer pageNumber;
        @AuraEnabled public Integer pageSize;
        @AuraEnabled public List<Job_Position__c> jobs;
    }

   
  /*  @AuraEnabled(cacheable=true)
    public static List<Job_Position__c> getOpenJobPositions() {
        return [
            SELECT Id, Name, Job_Title__c, Job_Location__City__s,
                   Skills_Required__c, Pay_Rate_Salary_range__c,
                   Status__c, Job_Description__c, Experience_Required__c
            FROM Job_Position__c
            WHERE Status__c = 'Open'
            ORDER BY CreatedDate DESC
            LIMIT 200
        ];
    }*/

    /* ==================================================================================
     * Method: getJobDetails
     * Purpose: Fetch detailed information of a Job Position.
     * Params : jobId - Job_Position__c record Id
     * Returns: Job_Position__c record
     * ==================================================================================
     */
    @AuraEnabled(cacheable=true)
/**
 * Retrieves job position details based on the provided Job Id.
 *
 * @param jobId  The Id of the Job_Position__c record to fetch.
 * @return Job_Position__c  The Job Position record if found, otherwise null.
 */
    public static Job_Position__c getJobDetails(Id jobId) {
        if (jobId == null) {
            return null;
           }
        return [
            SELECT Id, Name, Job_Title__c, Job_Location__City__s, Open_Date__c,
                   Skills_Required__c, Pay_Rate_Salary_range__c, Status__c,
                   Job_Description__c, Required_Experience_Range__c, OwnerId
            FROM Job_Position__c
            WHERE Id = :jobId
            LIMIT 1
        ];
    }

     /* ==================================================================================
     * Method: searchJobPositions
     * Purpose: Search Job Positions with filters & pagination.
     *          - Job Title search
     *          - City filter
     *          - Experience range
     * Params :
     *  - pageNumber     : Current page
     *  - pageSize       : Records per page
     *  - searchKey      : Job title keyword
     *  - cityFilter     : Job location city
     *  - minExperience  : Minimum experience
     *  - maxExperience  : Maximum experience
     * Returns: JobSearchResponse wrapper
     * ==================================================================================
     */
    @AuraEnabled
/**
 * Searches Job Position records with pagination and filter criteria.
 *
 * This method supports keyword search, city-based filtering, and
 * experience range filtering. Results are returned in a wrapper
 * including both records and total count for pagination.
 *
 * @param pageNumber   The page index to fetch (1-based).
 * @param pageSize     The number of records to return per page.
 * @param searchKey    Text used to match against job title or description.
 * @param cityFilter   The city value used to filter job positions (optional).
 * @param minExperience Minimum experience (in years) used for filtering (optional).
 * @param maxExperience Maximum experience (in years) used for filtering (optional).
 *
 * @return JobSearchResponse Wrapper containing list of Job_Position__c records
 *         and pagination metadata. Returns empty result when no matches found.
 */
    public static JobSearchResponse searchJobPositions(
        Integer pageNumber,
        Integer pageSize,
        String searchKey,
        String cityFilter,
        Decimal minExperience,
        Decimal maxExperience
    ) {
        if (pageNumber == null || pageNumber < 1) {pageNumber = 1;}
        if (pageSize == null || pageSize < 1) {pageSize = 10;}

        Integer offsetVal = (pageNumber - 1) * pageSize;

        // ---- Base WHERE clause ----
        String whereClause = ' FROM Job_Position__c WHERE Status__c = \'Open\' ' + 
        ' AND Available_for_Website__c = true ';

        // ---- Search (Job title OR skills) ----
        // ---- Search ONLY IN Job Title ----
// ---- Search ONLY in Job Title (case insensitive by default) ----
if (!String.isBlank(searchKey)) {
    String key = '%' + String.escapeSingleQuotes(searchKey.trim()) + '%';
    whereClause += ' AND Job_Title__c LIKE \'' + key + '\' ';
}

        // ---- City filter ----
        if (!String.isBlank(cityFilter)) {
            String cityKey = '%' + String.escapeSingleQuotes(cityFilter.trim()) + '%';
            whereClause += ' AND Job_Location__City__s LIKE \'' + cityKey + '\' ';
        }

        // ---- Experience range (assumes Experience_Required__c is numeric) ----

// ---- Experience Filter using Min & Max fields ----
if (minExperience != null && maxExperience != null) {
    whereClause += 
        ' AND (Minimum_Experience_Required__c <= ' + maxExperience +
        ' AND Maximum_Experience_Required__c >= ' + minExperience + ') ';
}
else if (minExperience != null && maxExperience == null) {
    // 10+ years case
    whereClause += 
        ' AND Maximum_Experience_Required__c >= ' + minExperience + ' ';
}


        // ---- Count query ----
        String countQuery = 'SELECT COUNT() ' + whereClause;
        Integer total = Database.countQuery(countQuery);

        // ---- Data query (paged) ----
        String dataQuery =
    'SELECT Id, Name, Job_Title__c, Job_Location__City__s, ' +
    ' Skills_Required__c, Pay_Rate_Salary_range__c, ' +
    ' Status__c, Job_Description__c, Required_Experience_Range__c, ' +
    ' Open_Date__c ' +
    whereClause +
    ' ORDER BY Open_Date__c DESC ' +
    ' LIMIT :pageSize ' +
    ' OFFSET :offsetVal';

List<Job_Position__c> jobs = Database.query(dataQuery);

        JobSearchResponse resp = new JobSearchResponse();
        resp.totalRecords = total;
        resp.pageNumber  = pageNumber;
        resp.pageSize    = pageSize;
        resp.jobs        = jobs;

        return resp;
    }

    /* ==================================================================================
     * Method: checkExistingCandidate
     * Purpose: Check if Candidate already exists using Email or Phone.
     * Params :
     *  - email : Candidate email
     *  - phone : Candidate phone
     * Returns: Existing contact record or null
     * ==================================================================================
     */

/**
 * Checks whether a Contact record already exists based on email or phone.
 *
 * This method searches for an existing candidate using the provided
 * email address and/or phone number. If both parameters are blank,
 * the method returns null. If multiple records are matched, the first
 * found record is returned.
 *
 * @param email  Email address of the candidate to search for (optional).
 * @param phone  Phone number of the candidate to search for (optional).
 *
 * @return contact  Existing matching candidate record,
 *         or null if no record is found or no criteria provided.
 */
    @AuraEnabled
    public static Contact checkExistingCandidate(String email, String phone) {
        if (String.isBlank(email) && String.isBlank(phone)) return null;

        Id candidateRtId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('Candidate').getRecordTypeId();

        if (!String.isBlank(email)) {
            List<Contact> found = [
                SELECT Id, FirstName, LastName, Email, Phone,
                    Experience_Year__c, Skills__c, Industrial_Knowledge__c,
                    Current_Company__c, Current_Location__c, Current_CTC__c, Designation__c,
                    Expected_CTC__c, Notice_Period__c
                FROM Contact
                WHERE Email = :email
                AND RecordTypeId = :candidateRtId
                LIMIT 1
            ];
            if (!found.isEmpty()) return found[0];
        }

        if (!String.isBlank(phone)) {
            List<Contact> found = [
                SELECT Id, FirstName, LastName, Email, Phone,
                    Experience_Year__c, Skills__c, Industrial_Knowledge__c,
                    Current_Company__c, Current_Location__c, Current_CTC__c, Designation__c,
                    Expected_CTC__c, Notice_Period__c
                FROM Contact
                WHERE Phone = :phone
                AND RecordTypeId = :candidateRtId
                LIMIT 1
            ];
            if (!found.isEmpty()) return found[0];
        }
        return null;
    }


    /* ==================================================================================
     * Method: submitCandidateForm
     * Purpose: Handles complete Candidate Application flow.
     *          - Create / Update Candidate
     *          - Create Interview record
     *          - Upload Resume asynchronously
     * ==================================================================================
     */
    @AuraEnabled
/**
 * Submits a candidate application form and creates related records.
 *
 * This method validates the provided candidate details, processes the resume
 * file, and associates the candidate with a selected job position. It may
 * also perform reCAPTCHA verification and duplicate candidate checks based
 * on email or phone number. When the submission succeeds, a wrapper response
 * object containing status information is returned.
 *
 * @param firstName          Candidate's first name.
 * @param lastName           Candidate's last name.
 * @param email              Candidate's email address.
 * @param phone              Candidate's phone number.
 * @param experienceYears    Total years of professional experience.
 * @param skills             List or comma-separated skills provided by the candidate.
 * @param currentCompany     Current employer name (optional).
 * @param jobTitle           Current or last held job title (optional).
 * @param expectedSalary     Candidate's expected salary.
 * @param noticePeriod       Current notice period information.
 * @param recaptchaToken     reCAPTCHA token used for bot validation.
 * @param resumeFileName     Name of the uploaded resume file.
 * @param resumeContentType  MIME type of the uploaded resume.
 * @param resumeBase64Body   Base64-encoded resume content.
 * @param jobId              Id of the Job_Position__c record being applied to.
 *
 * @return CandidateResponse Wrapper containing success flag, messages,
 *         and created/updated record details for the candidate.
 */

    public static CandidateResponse submitCandidateForm(
    String firstName,
    String lastName,
    String email,
    String phone,
    Decimal experienceYears,
    String skills,
    String softSkills,
    String currentCompany,
    String jobTitle,
    String currentLocation,
    Decimal expectedSalary,
    String noticePeriod,
    String recaptchaToken,
    String resumeFileName,
    String resumeContentType,
    String resumeBase64Body,
    Id jobId,
    Decimal currentCTC
) {
    system.debug('skills'+skills);
    system.debug('skills'+skills);
    CandidateResponse resp = new CandidateResponse();
    resp.success = false;
     system.debug('resp'+resp);

    // ---------- Validation ----------
    if (String.isBlank(firstName) || String.isBlank(lastName) ||
        String.isBlank(email) || String.isBlank(phone)) {
        resp.message = 'Required fields are missing.';
        return resp;
    }

    // ---------- Candidate Record Type ----------
    Id candidateRtId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('Candidate').getRecordTypeId();

    // ---------- Contact Lookup ----------
    Contact cand;
    List<Contact> existing = [
        SELECT Id
        FROM Contact
        WHERE Email = :email
        AND RecordTypeId = :candidateRtId
        LIMIT 1
    ];

    Boolean isExisting = !existing.isEmpty();
    if (isExisting) {
        cand = existing[0];
    } else {
        cand = new Contact(
            RecordTypeId = candidateRtId,
            Source__c   = 'Company Website'
        );
    }

    // ---------- Update Fields ----------
    cand.FirstName            = firstName;
    cand.LastName             = lastName;
    cand.Email                = email;
    cand.Phone                = phone;
    cand.Experience_Year__c   = experienceYears;
    cand.Skills__c =
    String.isNotBlank(skills)
            ? skills.trim().toUpperCase()
            : null;

    cand.Industrial_Knowledge__c =
        String.isNotBlank(softSkills)
            ? softSkills.trim().toUpperCase()
            : null;
    cand.Current_Company__c   = currentCompany;
    cand.Designation__c       = jobTitle;
    cand.Expected_CTC__c      = expectedSalary;
    cand.Notice_Period__c     = noticePeriod;
    cand.Current_Location__c = currentLocation;
    cand.Current_CTC__c = currentCTC;

    system.debug('cand'+cand);
    try {
        if (isExisting) {
            update cand;
        } else {
            insert cand;
        }
    } catch (Exception e) {
        resp.message = 'Error saving candidate — ' + e.getMessage();
        return resp;
    }

    resp.candidateId = cand.Id;

    // ---------- Interview Section ----------
    if (jobId != null) {

        List<Interview__c> existList = [
            SELECT Id
            FROM Interview__c
            WHERE Candidate_Name__c = :cand.Id
            AND Job_Position__c = :jobId
            LIMIT 1
        ];

        if (!existList.isEmpty()) {

            resp.success = true;
            resp.interviewCreated = false;
            resp.interviewId = existList[0].Id;
            resp.message = 'You have already applied for this job earlier.';

        } else {

            Interview__c newInterview = new Interview__c();
            newInterview.Candidate_Name__c       = cand.Id;
            newInterview.Job_Position__c  = jobId;
            newInterview.Interview_Status__c = 'New';

            // Assign owner from Job Position
            try {
                Job_Position__c jp = [
                    SELECT OwnerId
                    FROM Job_Position__c
                    WHERE Id = :jobId
                    LIMIT 1
                ];
                newInterview.OwnerId = jp.OwnerId;
            } catch (Exception ignore) {}

            insert newInterview;

            resp.success = true;
            resp.interviewCreated = true;
            resp.interviewId = newInterview.Id;
            resp.message = 'Application submitted successfully.';
        }

    } else {
        resp.success = true;
        resp.message = 'Candidate saved successfully.';
    }

    // ---------- Resume Upload ----------
    if (!String.isBlank(resumeBase64Body)) {
        try {
            System.enqueueJob(
                new CandidateDriveUploadQueueable(
                    cand.Id,
                    resumeFileName,
                    resumeContentType,
                    resumeBase64Body
                )
            );
        } catch (Exception e) {
            resp.message += ' but resume upload failed: ' + e.getMessage();
        }
    }

    return resp;
}
}