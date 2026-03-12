/**
 * @File Name      : NewSupplierCandidateController.cls
 * @description   : Controller class responsible for handling supplier candidate submissions
 * from Lightning components. This includes candidate creation, duplicate
 * validation, optional interview creation, resume upload queueing, and
 * notification emails to job owners.
 * @Author        :
 * @Last Modified By :
 * @Last Modified On : December 4, 2025
 *
 * @Modification Log :
 * ==============================================================================
 * Ver   | Date              | Author | Modification
 * ==============================================================================
 * 1.0   | December 4, 2025  |        | Initial Version
 */
public without sharing class NewSupplierCandidateController {

    /**
     * @description
     * Wrapper class used to receive candidate data
     * from the Lightning Web Component.
     *
     * Represents the complete payload sent from
     * the client including personal, job, and resume data.
     */
    
    private static final String CANDIDATE_RECORD_TYPE_DEV_NAME = 'Candidate'; 
    private static final String Candidate_Object_NAME = 'Contact'; 
    private static final String Contact_Source = 'Supplier';
    public class CandidateRequest {
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
        @AuraEnabled public Decimal experienceYears;
        @AuraEnabled public String skills;
        @AuraEnabled public String currentCompany;
        @AuraEnabled public String jobTitle;
        @AuraEnabled public Decimal expectedSalary;
        @AuraEnabled public String noticePeriod;
        @AuraEnabled public String recaptchaToken;
        @AuraEnabled public String resumeFileName;
        @AuraEnabled public String resumeContentType;
        @AuraEnabled public String resumeBase64Body;
        @AuraEnabled public String jobPositionId;
    }

    /**
     * @description
     * Response wrapper returned to the Lightning Web Component
     * after processing the candidate submission.
     *
     * Contains success status, message, and candidate Id.
     */
    public class CandidateResponse {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Id contactId;
    }

    /* =========================
       EMAIL CONTEXT (PMD FIX)
       ========================= */

    private class EmailContext {
        Job_Position__c job;
        User owner;
        List<Contact> contacts;
        String jobUrl;
        String currentUser;
    }


    /**
     * @description
     * Submits a new supplier candidate from a Lightning Web Component.
     *
     * Accepts a JSON string payload, deserializes it into a
     * CandidateRequest object, validates input, creates
     * candidate and interview records, uploads resume data,
     * and sends notification emails.
     *
     * @param requestJson
     * JSON string containing candidate submission data
     *
     * @return
     * CandidateResponse indicating success or failure
     */
    @AuraEnabled(cacheable=false)
    public static CandidateResponse submitCandidateForm(String requestJson) {
        CandidateResponse resp = new CandidateResponse();
        resp.success = false;

        //System.debug('REQUEST JSON => ' + requestJson);

        CandidateRequest req;

        // Deserialize JSON string to CandidateRequest object
        try {
            req = (CandidateRequest) JSON.deserialize(requestJson, CandidateRequest.class);
           // System.debug('REQ PAYLOAD => ' + JSON.serializePretty(req));
        } catch (Exception e) {
           // System.debug('Deserialization Error => ' + e.getMessage());
            resp.message = 'Invalid request format. Please refresh and try again.';
            return resp;
        }

         // Defensive check (prevents NullPointerException)
        if (req == null || hasMissingRequiredFields(req)) {
            resp.message = 'Required fields are missing.';
            return resp;
        }

        if (emailAlreadyExists(req.email)) {
            resp.message = 'Email already exists. Please use a different email address.';
            return resp;
        }

        Contact contact = buildCandidateContact(req);

        try {
            insert as user contact;
        } catch (DmlException e) {

            resp.message =
                'Unable to create candidate. ' +
                e.getDmlMessage(0);

            return resp;
        }

        String interviewErr = handleInterview(req.jobPositionId, contact.Id);
        String resumeErr    = handleResumeUpload(req, contact.Id);

        resp.success = true;
        resp.contactId  = contact.Id;
        resp.message = buildFinalMessage(req, interviewErr, resumeErr);
        return resp;
    }

    /* =========================
       VALIDATION HELPERS
       ========================= */

    private static Boolean hasMissingRequiredFields(CandidateRequest req) {
        return String.isBlank(req.firstName) ||
               String.isBlank(req.lastName)  ||
               String.isBlank(req.email)     ||
               String.isBlank(req.phone);
    }

    private static Boolean emailAlreadyExists(String email) {
        return ![
            SELECT Id
            FROM Contact
            WHERE Email = :email
            AND RecordTypeId = :getCandidateContactRecordTypeId()
            WITH USER_MODE
            LIMIT 1
        ].isEmpty();
    }

    /* =========================
       CANDIDATE BUILDERS
       ========================= */

    private static Contact buildCandidateContact(CandidateRequest req) {
        Contact c = new Contact();
        c.FirstName = req.firstName;
        c.LastName  = req.lastName;
        c.Email     = req.email;
        c.Phone     = req.phone;
        c.Experience_Year__c = req.experienceYears;
        c.Skills__c          = req.skills;
        c.Current_Company__c = req.currentCompany;
        c.Job_Title__c       = req.jobTitle;
        c.Expected_CTC__c    = req.expectedSalary;
        c.Notice_Period__c   = req.noticePeriod;
        c.Source__c          = Contact_Source;
        c.RecordTypeId       = getCandidateContactRecordTypeId();
        return c;
    }

    private static Id getCandidateContactRecordTypeId() {
        List<RecordType> rts = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType =: Candidate_Object_NAME
            AND (DeveloperName =: CANDIDATE_RECORD_TYPE_DEV_NAME )
            WITH USER_MODE
            LIMIT 1
        ];
        return rts.isEmpty() ? null : rts[0].Id;
    }

    /* =========================
       INTERVIEW HANDLING
       ========================= */

    private static String handleInterview(String jobPositionId, Id contactId) {
        if (String.isBlank(jobPositionId)) {return null;}

        try {
            insert as user new Interview__c(
                Candidate_Name__c = contactId,
                Job_Position__c = jobPositionId
            );

            sendInterviewNotification(jobPositionId, new List<Id>{ contactId });
            return null;
        } catch (Exception e) {
            return e.getMessage();
        }
    }

    /* =========================
       RESUME UPLOAD
       ========================= */

    private static String handleResumeUpload(CandidateRequest req, Id contactId) {
        if (String.isBlank(req.resumeBase64Body)){ return null;}

        try {
            System.enqueueJob(
                new CandidateDriveUploadQueueable(
                    contactId,
                    req.resumeFileName,
                    req.resumeContentType,
                    req.resumeBase64Body
                )
            );
            return null;
        } catch (Exception e) {
            return e.getMessage();
        }
    }

    /* =========================
       RESPONSE BUILDER
       ========================= */

    private static String buildFinalMessage(
        CandidateRequest req,
        String interviewErr,
        String resumeErr
    ) {
        List<String> msgs = new List<String>{
            'Application submitted successfully.'
        };

        if (!String.isBlank(req.resumeBase64Body)) {
            msgs.add('Resume upload has been scheduled.');
        }
        if (interviewErr != null) {
            msgs.add('Interview creation failed.');
        }
        if (resumeErr != null) {
            msgs.add('Resume upload enqueue failed.');
        }
        return String.join(msgs, ' ');
    }

    /* =========================
       EMAIL
       ========================= */

    @TestVisible
    private static void sendInterviewNotification(Id jobPositionId, List<Id> contactIds) {

        Job_Position__c jp = [
            SELECT Id, Name, OwnerId
            FROM Job_Position__c
            WHERE Id = :jobPositionId
            WITH USER_MODE
            LIMIT 1
        ];

        User owner = [
            SELECT Id, Name, Email
            FROM User
            WHERE Id = :jp.OwnerId
            WITH USER_MODE
            LIMIT 1
        ];

        List<Contact> contacts = [
            SELECT Name
            FROM Contact
            WHERE Id IN :contactIds
            WITH USER_MODE
        ];

        EmailContext ctx = new EmailContext();
        ctx.job = jp;
        ctx.owner = owner;
        ctx.contacts = contacts;
        ctx.jobUrl = System.Url.getOrgDomainUrl().toExternalForm() + '/' + jp.Id;
        ctx.currentUser = UserInfo.getName();

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[]{ owner.Email });
        mail.setSubject('New interview(s) created for Job: ' + jp.Name);
        mail.setHtmlBody(buildHtmlBody(ctx));
        mail.setPlainTextBody(buildPlainTextBody(ctx));

        Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ mail });
    }

    private static String buildHtmlBody(EmailContext ctx) {
        List<String> lines = new List<String>();
        for (Contact c : ctx.contacts) {
            lines.add('<li>' + escapeHtml(c.Name) + '</li>');
        }

        return '<p>Hello ' + escapeHtml(ctx.owner.Name) + ',</p>' +
               '<p>' + ctx.contacts.size() + ' interview(s) created for <b>' +
               escapeHtml(ctx.job.Name) + '</b></p>' +
               '<p><a href="' + ctx.jobUrl + '">Open Job Position</a></p>' +
               '<ul>' + String.join(lines, '') + '</ul>';
    }

    private static String buildPlainTextBody(EmailContext ctx) {
        List<String> lines = new List<String>();
        for (Contact c : ctx.contacts) {
            lines.add(c.Name);
        }

        return 'Hello ' + ctx.owner.Name + '\n\n' +
               ctx.contacts.size() + ' interview(s) created for ' + ctx.job.Name +
               '\nLink: ' + ctx.jobUrl + '\n\nCandidates:\n' +
               String.join(lines, '\n');
    }

    private static String escapeHtml(String input) {
        return input == null ? '' :
            input.replace('&','&amp;')
                 .replace('<','&lt;')
                 .replace('>','&gt;')
                 .replace('"','&quot;')
                 .replace('\'','&#39;');
    }
}