/**
 * @description
 * Controller class for Applicant Tracking System (ATS).
 * Provides Aura-enabled methods to fetch interview data, update interview stages,
 * remove candidates from jobs, collect interview feedback, and perform
 * bulk interview updates.
 *
 * @author Ayush
 * @modifiedBy Kshitiz
 */
public with sharing class ATSController {
    
    // Record Type Developer Names - Use these for getRecordTypeInfosByDeveloperName()
    private static final String CANDIDATE_RECORD_TYPE_DEV_NAME = 'Candidate'; // Use actual Developer Name
    private static final String CLIENT_RECORD_TYPE_DEV_NAME = 'Client'; // Use actual Developer Name
    
    // Profile Name - use correct label or developer name
    private static final String SYSTEM_ADMIN_PROFILE_NAME = 'System Administrator'; // Or use Developer Name

    /**
     * @description
     * Retrieves interview records for a specific Job Position.
     * Used to populate ATS data tables in Lightning components.
     * Only includes Contacts with "Candidate" record type and Accounts with "Client" record type.
     *
     * @param jobPositionId
     *        Id of the Job_Position__c record for which interviews are required.
     *
     * @return List<Interview__c>
     *         List of interview records associated with the given job position.
     */
    @AuraEnabled(cacheable=true)
    public static List<Interview__c> getATSData(Id jobPositionId) {
        try {
            // Get the Contact record type ID for Candidate
            Id candidateRecordTypeId = getRecordTypeId('Contact', CANDIDATE_RECORD_TYPE_DEV_NAME);
            
            // Get the Account record type ID for Client
            
            // Id clientRecordTypeId = getRecordTypeId('Account', CLIENT_RECORD_TYPE_DEV_NAME);
            
            return [
                SELECT Id,
                       Interview_Status__c,
                       Round__c,
                       Feedback__c,
                       Candidate_Name__r.Resume_Link__c,
                       Candidate_Name__r.Name,
                       Candidate_Name__r.Email,
                       Candidate_Name__r.Phone,
                       Candidate_Name__r.Current_Location__c,
                       Candidate_Name__r.LastModifiedBy.Name,
                       Candidate_Name__r.Source__c,
                       CreatedDate,
                       Job_Position__r.Name,
                       Job_Position__c
                FROM Interview__c
                WHERE Candidate_Name__c != null
                  AND Job_Position__c = :jobPositionId
                  AND Candidate_Name__r.RecordTypeId = :candidateRecordTypeId
                WITH USER_MODE
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching ATS data: ' + e.getMessage());
        }
    }

    /**
     * @description
     * Removes candidate interview records from a job position.
     * Also deletes related Event records for the same candidates and job.
     * Validates that candidates are Contacts with "Candidate" record type.
     *
     * This operation is restricted to System Administrators only.
     *
     * @param interviewIds
     *        List of Interview__c record Ids to delete.
     *
     * @throws AuraHandledException
     *         If input is invalid or user is not authorized.
     */
    @AuraEnabled
    public static void removeCandidateFromJob(List<Id> interviewIds) {
        if (interviewIds == null || interviewIds.isEmpty()) {
            throw new AuraHandledException('Invalid input: Interview IDs are required.');
        }

        validateAdminAccess();
        
        try {
            // Get the Contact record type ID for Candidate
            Id candidateRecordTypeId = getRecordTypeId('Contact', CANDIDATE_RECORD_TYPE_DEV_NAME);

            List<Interview__c> interviewRecords = [
                SELECT Id, Job_Position__c, Candidate_Name__c, Candidate_Name__r.RecordTypeId
                FROM Interview__c
                WHERE Id IN :interviewIds
                  AND Candidate_Name__r.RecordTypeId = :candidateRecordTypeId
                WITH USER_MODE
            ];

            if (interviewRecords.isEmpty()) {
                throw new AuraHandledException('No valid candidate interviews found to delete. Ensure candidates have the correct record type.');
            }

            Set<Id> contactIds = new Set<Id>();
            Id jobId;

            for (Interview__c inter : interviewRecords) {
                if (inter.Candidate_Name__c != null) {
                    contactIds.add(inter.Candidate_Name__c);
                }
                jobId = inter.Job_Position__c;
            }

            // Delete related events
            List<Event> eventsToDelete = [
                SELECT Id
                FROM Event
                WHERE WhoId IN :contactIds
                  AND WhatId = :jobId
                WITH USER_MODE
            ];

            if (!eventsToDelete.isEmpty()) {
                Database.delete(eventsToDelete, AccessLevel.USER_MODE);
            }

            // Delete interview records
            Database.delete(interviewRecords, AccessLevel.USER_MODE);
        } catch (Exception e) {
            throw new AuraHandledException('Error removing candidates: ' + e.getMessage());
        }
    }

    /**
     * @description
     * Validates that the current user has System Administrator profile.
     * Used to restrict destructive operations.
     *
     * @throws AuraHandledException
     *         If the current user is not a System Administrator.
     */
    private static void validateAdminAccess() {
        try {
            // Get profile info - trim the name to avoid whitespace issues
            String profileName = [
                SELECT Name
                FROM Profile
                WHERE Id = :UserInfo.getProfileId()
                WITH USER_MODE
            ].Name.trim();

            // Check if profile name matches (case-insensitive)
            if (!profileName.equalsIgnoreCase(SYSTEM_ADMIN_PROFILE_NAME.trim())) {
                throw new AuraHandledException('Please contact admin. You cannot delete this record');
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error validating admin access: ' + e.getMessage());
        }
    }

    /**
     * @description
     * Sends feedback request emails to clients for selected interviews.
     * Email content is generated using EmailBody helper.
     * Validates that clients are Accounts with "Client" record type.
     *
     * @param interviewIds
     *        List of Interview__c record Ids for which feedback is requested.
     *
     * @throws AuraHandledException
     *         If no interview Ids are provided.
     */
    @AuraEnabled
    public static void collectFeedback(List<Id> interviewIds) {
        system.debug('interviewIds'+interviewIds);
        if (interviewIds == null || interviewIds.isEmpty()) {
            throw new AuraHandledException('Invalid input: Interview IDs are required.');
        }

        try {
            // Get record type IDs
            Id candidateRecordTypeId = getRecordTypeId('Contact', CANDIDATE_RECORD_TYPE_DEV_NAME);
            Id clientRecordTypeId = getRecordTypeId('Account', CLIENT_RECORD_TYPE_DEV_NAME);

            List<Interview__c> interviewRecords = [
                SELECT Id,
                       Round__c,
                       Candidate_Name__r.Name,
                       Candidate_Name__r.RecordTypeId,
                       Job_Position__r.Client_Name__r.Email__c,
                       Job_Position__r.Job_Title__c,
                       Job_Position__r.Client_Name__r.Name,
                       Job_Position__r.Client_Name__r.RecordTypeId
                FROM Interview__c
                WHERE Id IN :interviewIds
                  AND Candidate_Name__r.RecordTypeId = :candidateRecordTypeId
                  AND Job_Position__r.Client_Name__r.RecordTypeId = :clientRecordTypeId
                WITH USER_MODE
            ];
            system.debug('interviewRecords---'+interviewRecords);

            if (interviewRecords.isEmpty()) {
                throw new AuraHandledException('No valid interviews found. Ensure candidates and clients have correct record types.');
            }

            String orgName = UserInfo.getOrganizationName();
             system.debug('orgName@@@'+orgName);
            List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

            // 🔥 GROUP BY CLIENT EMAIL
Map<String, List<Interview__c>> clientMap = new Map<String, List<Interview__c>>();

for (Interview__c iv : interviewRecords) {
    String clientEmail = iv.Job_Position__r.Client_Name__r.Email__c;
     system.debug('clientEmail@@@'+clientEmail);
    if (String.isBlank(clientEmail)) continue;

    if (!clientMap.containsKey(clientEmail)) {
        clientMap.put(clientEmail, new List<Interview__c>());
         system.debug('clientMap111@@@'+clientMap);
    }
    clientMap.get(clientEmail).add(iv);
    system.debug('clientMap@@@'+clientMap);
}

// 🔥 ONE MAIL PER CLIENT
for (String clientEmail : clientMap.keySet()) {

    List<Interview__c> clientInterviews = clientMap.get(clientEmail);
     system.debug('clientInterviews@@@'+clientInterviews);

    String clientName = clientInterviews[0].Job_Position__r.Client_Name__r.Name;
     String jobPosition = clientInterviews[0].Job_Position__r.Job_Title__c;
      system.debug('iv.jobPosition@@@'+jobPosition);

    // table rows build
    String rows = '';
    for (Interview__c iv : clientInterviews) {
         system.debug('iv.Candidate_Name__r.Name@@@'+iv.Candidate_Name__r.Name);
          system.debug('iv.Round__c@@@'+iv.Round__c);
        rows += '<tr>'
            + '<td style="border:1px solid #ddd;padding:8px;">' + iv.Candidate_Name__r.Name + '</td>'
            + '<td style="border:1px solid #ddd;padding:8px;">' + iv.Round__c + '</td>'
            + '</tr>';

             system.debug('rows@@@'+rows);
    }

    Map<String, String> data = new Map<String, String>{
        'clientName' => clientName,
        'orgName'    => orgName,
        'tableRows'  => rows,
        'jobPosition' => jobPosition
    };

     system.debug('data@@@'+data);

    String emailBody = EmailBody.feedbackEmailBody(data);
    system.debug('emailBody'+emailBody);
    String subject = 'Feedback Request for Multiple Candidates';

    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
    mail.setToAddresses(new String[] { clientEmail });
    mail.setSubject(subject);
    mail.setHtmlBody(emailBody);
    mail.setOrgWideEmailAddressId(ATSControllerHelper.getOrgWideEmailIdForCurrentUser());
    system.debug('mail@@@'+mail);

    emails.add(mail);
     system.debug('emails@@@'+emails);
}


            if (!emails.isEmpty()) {
                Messaging.sendEmail(emails);
            }
        } catch (Exception e) {
            system.debug('Error sending feedback emails:---'+ e.getMessage());
            throw new AuraHandledException('Error sending feedback emails: ' + e.getMessage());
        }
    }

    /**
     * @description
     * Updates multiple Interview__c records with stage and feedback values.
     * Delegates validation and DML operations to InterviewService.
     * Validates that candidates are Contacts with "Candidate" record type.
     *
     * @param recordIds
     *        List of Interview__c record Ids to update.
     *
     * @param newStage
     *        New interview stage value.
     *
     * @param feedback
     *        Feedback text to be saved.
     */
    @AuraEnabled
    public static void updateInterviews(List<Id> recordIds, String newStage, String feedback) {
        try {
            // Get the Contact record type ID for Candidate
            Id candidateRecordTypeId = getRecordTypeId('Contact', CANDIDATE_RECORD_TYPE_DEV_NAME);
            
            // Validate that all interviews belong to candidates with correct record type
            List<Interview__c> existingInterviews = [
                SELECT Id, Candidate_Name__r.RecordTypeId
                FROM Interview__c
                WHERE Id IN :recordIds
                WITH USER_MODE
            ];
            
            for (Interview__c interview : existingInterviews) {
                if (interview.Candidate_Name__r.RecordTypeId != candidateRecordTypeId) {
                    throw new AuraHandledException('Interview ' + interview.Id + ' does not belong to a valid candidate.');
                }
            }
            
            InterviewService.validateInterviewInputs(recordIds, newStage, feedback);
            List<Interview__c> interviewsToUpdate =
                InterviewService.prepareInterviewUpdates(recordIds, newStage, feedback);
            InterviewService.saveInterviewRecords(interviewsToUpdate);
        } catch (Exception e) {
            throw new AuraHandledException('Error updating interviews: ' + e.getMessage());
        }
    }

    /**
     * @description
     * Retrieves unique Candidate_Name__c Ids from given Interview__c records.
     * Only returns Contacts with "Candidate" record type.
     *
     * @param interviewIds
     *        List of Interview__c record Ids.
     *
     * @return List<Id>
     *         List of unique Candidate_Name__c Ids.
     *
     * @throws AuraHandledException
     *         If no candidates are found for provided interviews.
     */
    @AuraEnabled(cacheable=true)
    public static List<Id> getCandidateIdsFromInterviews(List<Id> interviewIds) {
        if (interviewIds == null || interviewIds.isEmpty()) {
            throw new AuraHandledException('Interview IDs are required.');
        }

        try {
            // Get the Contact record type ID for Candidate
            Id candidateRecordTypeId = getRecordTypeId('Contact', CANDIDATE_RECORD_TYPE_DEV_NAME);

            Set<Id> candidateIds = new Set<Id>();
            for (Interview__c i : [
                SELECT Candidate_Name__c
                FROM Interview__c
                WHERE Id IN :interviewIds
                  AND Candidate_Name__c != null
                  AND Candidate_Name__r.RecordTypeId = :candidateRecordTypeId
                WITH USER_MODE
            ]) {
                candidateIds.add(i.Candidate_Name__c);
            }

            if (candidateIds.isEmpty()) {
                throw new AuraHandledException('No valid candidates found for selected interviews.');
            }

            return new List<Id>(candidateIds);
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching candidate IDs: ' + e.getMessage());
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
}