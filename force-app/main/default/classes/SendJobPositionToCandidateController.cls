/**
 * @description  Aura-enabled controller used by LWC/Aura to fetch a Job Position 
 *               along with Candidate records based on Interview Ids.
 *               This method respects User Mode to enforce sharing and FLS.
 */
public with sharing class SendJobPositionToCandidateController {

    /**
     * @description  Returns Job Position details and related Candidate details 
     *               (via Interview__c) for the given Job Position.
     *
     * @param jobPositionId   The Id of the Job_Position__c record to fetch.
     * @param interviewIds    List of Interview__c Ids used to fetch Candidate records.
     *
     * @return Map<String, Object> 
     *         - jobPosition: Job_Position__c record
     *         - Contact: List<Contact> records
     */
    @AuraEnabled
    public static Map<String, Object> getJobAndCandidates(Id jobPositionId, List<Id> interviewIds) {
        
        Map<String, Object> response = new Map<String, Object>();

        // Early exit if no job position provided
        if (jobPositionId == null) {
            return response;
        }

        // ------------------------------
        // Fetch Job Position (USER MODE)
        // ------------------------------
        Job_Position__c job = [
            SELECT Id, Name, Job_Title__c, Job_Location__c, Client_Name__r.Name, Client_Name__r.Website,
                   Skills_Required__c, Shift_Time__c, ClientBillRateSalary__c,
                   Required_Experience_Range__c, Job_Description__c, Employment_Type__c
            FROM Job_Position__c
            WHERE Id = :jobPositionId
            WITH USER_MODE
            LIMIT 1
          
        ];

        // ----------------------------------------
        // Fetch candidates only if interviewIds exist
        // ----------------------------------------
        List<Contact> candidates = new List<Contact>();
        
        Map<String, Schema.RecordTypeInfo> rtMap =
            Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName();
        Id candidateRTId = rtMap.get('Candidate').getRecordTypeId();

        if (interviewIds != null && !interviewIds.isEmpty()) {
            candidates = [
                SELECT Id, Name, Email
                FROM Contact
                WHERE Id IN (
                    SELECT Candidate_Name__c
                    FROM Interview__c
                    WHERE Id IN :interviewIds
                    AND Candidate_Name__c != NULL
                ) AND RecordTypeId = :candidateRTId
                WITH USER_MODE
            ];
        }

        // Add values to response map
        response.put('jobPosition', job);
        response.put('candidates', candidates);

        return response;
    }
}