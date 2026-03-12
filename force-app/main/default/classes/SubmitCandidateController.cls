/**
 * @description
 * Controller class for submitting candidate details to clients.
 * Provides Aura-enabled methods to:
 *  - Fetch active client accounts
 *  - Retrieve open job positions for a client
 *  - Fetch single or multiple candidate details dynamically
 *  - Generate a CSV file of candidate information based on client configuration
 *  - Send candidate details to the client via email with CSV attachment
 *
 * This controller is primarily used by the SubmitToClient Lightning Web Component.
 * @author Shivam Shivhare
 * @modifiedBy Kshitiz
 */

public with sharing class SubmitCandidateController {

    /**
     * @description
     * Retrieves all active client accounts that have an email address configured.
     * Only Accounts with Record Type "Client" and IsActive__c = true are returned.
     * Used to populate client selection dropdowns in the UI.
     *
     * @return List<Account>
     *         List of active client Account records with email and candidate field configuration.
     */
    @AuraEnabled(cacheable=true)
    public static List<Account> getAllClients() {
        return [
           SELECT Id, Name, Email__c, Candidate_Fields__c, RecordType.Name
            FROM Account
            WHERE Email__c != null AND IsActive__c = true AND RecordType.Name = 'Client' WITH USER_MODE
            ORDER BY Name
        ];
    }

     /**
     * @description
     * Retrieves all open job positions associated with a given client.
     * Only Job Positions with Status__c = 'Open' are included.
     *
     * @param clientId
     *        Id of the client Account for which job positions are required.
     *
     * @return List<Job_Position__c>
     *         List of open Job Position records for the specified client.
     */
    @AuraEnabled(cacheable=true)
    public static List<Job_Position__c> getJobPositionsByClient(Id clientId) {
        
        return [
            SELECT Id, Name, Job_Title__c, Job_Location__c, Job_Location__City__s, Employment_Type__c, Job_Description__c
            FROM Job_Position__c
            WHERE Client_Name__c = :clientId AND Status__c = 'Open' WITH USER_MODE
            ORDER BY Name
        ];
    }

    /**
     * @description
     * Retrieves candidate details for a single candidate based on client configuration.
     * Internally delegates to the shared candidate data builder.
     *
     * @param candidateId
     *        Id of the Contact (candidate) record.
     * @param clientId
     *        Id of the client Account used to determine required candidate fields.
     *
     * @return Map<String, Object>
     *         Map containing field order metadata and candidate field values.
     */
    @AuraEnabled
    public static Map<String, Object> getCandidateForClient(Id candidateId, Id clientId) {
        return buildCandidateData(new List<Id>{ candidateId }, clientId)[0];
    }

    /**
     * @description
     * Retrieves candidate details for multiple candidates based on client configuration.
     * Used for bulk candidate submission scenarios.
     *
     * @param candidateIds
     *        List of Contact (candidate) record Ids.
     * @param clientId
     *        Id of the client Account used to determine required candidate fields.
     *
     * @return List<Map<String, Object>>
     *         List of maps containing field order metadata and candidate field values.
     */
    @AuraEnabled
    public static List<Map<String, Object>> getMultipleCandidatesForClient(List<Id> candidateIds, Id clientId) {
        return buildCandidateData(candidateIds, clientId);
    }

     /**
     * @description
     * Core helper method that dynamically builds candidate data based on client-defined fields.
     * Ensures only valid Contact fields are queried by validating against schema metadata.
     * Returns both field display order and actual field values for UI rendering and CSV generation.
     *
     * @param candidateIds
     *        List of Contact (candidate) record Ids.
     * @param clientId
     *        Id of the client Account containing field configuration.
     *
     * @return List<Map<String, Object>>
     *         Structured candidate data including field labels, API names, and values.
     */
    private static List<Map<String, Object>> buildCandidateData(List<Id> candidateIds, Id clientId) {

        Account clientRec = [
            SELECT Candidate_Fields__c
            FROM Account
            WHERE Id = :clientId WITH USER_MODE
            LIMIT 1
        ];

        String fieldList = String.isBlank(clientRec.Candidate_Fields__c)
            ? 'Name,Email__c,Phone__c'
            : clientRec.Candidate_Fields__c;

        Map<String, Schema.SObjectField> allFieldMap =
            Schema.SObjectType.Contact.fields.getMap();

        List<String> requestedFields = fieldList.split(',');
        List<String> validated = new List<String>();

        for(String f : requestedFields){
            String clean = f.trim();
            if(allFieldMap.containsKey(clean)){
                validated.add(clean);
            }
        }

        if(validated.isEmpty()){
            validated.addAll(new List<String>{ 'Name', 'Email__c', 'Phone__c' });
        }

        List<String> queryParts = new List<String>{ 'SELECT ' + String.join(validated, ',') , ' FROM Contact WHERE Id IN :candidateIds' };
        String finalQuery = String.join(queryParts, ' ');

        List<Contact> candidates = Database.query(finalQuery);

        List<Map<String, Object>> results = new List<Map<String, Object>>();
        for (Contact c : candidates) {
            List<Map<String, String>> orderList = new List<Map<String, String>>();
            Map<String, Object> values = new Map<String, Object>();

            for (String api : validated) {
                Schema.DescribeFieldResult dfr = allFieldMap.get(api).getDescribe();
                orderList.add(new Map<String, String>{ 'label' => dfr.getLabel(), 'value' => api });
                values.put(api, c.get(api));
            }

            results.add(new Map<String, Object>{
                'fieldOrder' => orderList,
                'values' => values
            });
        }
        return results;
    }

   /**
     * @description
     * Sends candidate details to the client via email with a CSV attachment.
     * The CSV content is generated dynamically based on client field configuration.
     * Uses Org-Wide Email Address when available; otherwise falls back to the running user.
     *
     * @param candidateIds
     *        List of Contact (candidate) record Ids to be included in the CSV.
     * @param clientId
     *        Id of the client Account receiving the email.
     * @param jobId
     *        Id of the Job Position related to the candidate submission.
     *
     * @throws AuraHandledException
     *         Thrown when the email fails to send.
     */
    @AuraEnabled
    public static void sendCandidateExcelEmail(List<Id> candidateIds, Id clientId, Id jobId){

        Account clientRec = [
            SELECT Name, Email__c, Candidate_Fields__c
            FROM Account
            WHERE Id = :clientId WITH USER_MODE
            LIMIT 1
        ];

        List<Map<String, Object>> candidateData = buildCandidateData(candidateIds, clientId);

        List<String> headers = new List<String>();
        List<String> rows = new List<String>();

        if(!candidateData.isEmpty()){
            List<Map<String, String>> fieldOrder = (List<Map<String, String>>)candidateData[0].get('fieldOrder');
            for (Map<String, String> f : fieldOrder){
                headers.add('"' + f.get('label') + '"');
            }

            for (Map<String, Object> rowData : candidateData){
                Map<String, Object> vals = (Map<String, Object>)rowData.get('values');
                List<String> line = new List<String>();
                for(String api : vals.keySet()){
                    Object v = vals.get(api);
                    line.add('"' + (v != null ? String.valueOf(v).replace('"','""') : '') + '"');
                }
                rows.add(String.join(line, ','));
            }
        }

        Blob csvBlob = Blob.valueOf(String.join(headers, ',') + '\n' + String.join(rows, '\n'));

        Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
        efa.setFileName('Candidate_Details.csv');
        efa.setBody(csvBlob);
        efa.setContentType('text/csv');

        Job_Position__c job = [
            SELECT Name, Job_Title__c, Job_Location__City__s, Employment_Type__c, Job_Description__c
            FROM Job_Position__c
            WHERE Id = :jobId WITH USER_MODE
            LIMIT 1
        ];

        String emailBody = ''
            + 'Hi ' + clientRec.Name + ',\n\n'
            + 'Submitting candidate(s) details for ' + job.Job_Title__c + ' based in ' + job.Job_Location__City__s + '.\n'
            + 'Employment Type: ' + job.Employment_Type__c + '\n\n'
            + 'Job Description: ' + job.Job_Description__c + '\n\n'
            + 'Attached are the details.\n\nThanks,\nRecruitment Team';

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[]{ clientRec.Email__c });
        mail.setSubject('Candidate Details');
        mail.setPlainTextBody(emailBody);
        mail.setFileAttachments(new Messaging.EmailFileAttachment[]{ efa });
        Id oweaId = getOrgWideEmailIdForCurrentUser();
        if (oweaId != null) {
            mail.setOrgWideEmailAddressId(oweaId);
        }

        Messaging.SendEmailResult[] res = Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ mail });

        if(!res[0].isSuccess()){
            throw new AuraHandledException('Email failed to send');
        }
    }

    /**
     * @description
     * Retrieves the Org-Wide Email Address Id matching the current user's email address.
     * Returns null if no accessible Org-Wide Email Address is found.
     * Designed to be safely optional to prevent email send failures.
     *
     * @return Id
     *         Org-Wide Email Address Id, or null if unavailable.
     */
    private static Id getOrgWideEmailIdForCurrentUser(){
        list<OrgWideEmailAddress> owea = [
            SELECT Id
            FROM OrgWideEmailAddress
            WHERE Address = :UserInfo.getUserEmail() WITH USER_MODE
            LIMIT 1
        ];
        return owea.isEmpty() ? null : owea[0].Id;
    }
    @AuraEnabled(cacheable=true)
public static Job_Position__c getJobWithClient(Id jobId) {
    return [SELECT
            Id, Name, Client_Name__c, Client_Name__r.Name, Client_Name__r.Email__c,
            Job_Title__c, Job_Location__City__s, Employment_Type__c, Job_Description__c
        FROM Job_Position__c  WHERE Id = :jobId  WITH SYSTEM_MODE LIMIT 1
    ];
}

@AuraEnabled
public static List<String> validateCandidateInterviews(List<Id> candidateIds, Id jobId){

    List<Interview__c> interviews = [
        SELECT Id, Candidate_Name__c, Candidate_Name__r.Name, Interview_Status__c
        FROM Interview__c
        WHERE Candidate_Name__c IN :candidateIds
        AND Job_Position__c = :jobId
        AND Interview_Status__c NOT IN (
            'Shortlisted',
            'Internal Assessment',
            'Recruiter Screening',
            'New'
        )
    ];

    List<String> candidateNames = new List<String>();

    for(Interview__c interview : interviews){
        if(interview.Candidate_Name__r != null){
            candidateNames.add(interview.Candidate_Name__r.Name);
        }
    }

    return candidateNames;
}
}