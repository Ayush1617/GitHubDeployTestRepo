/**
* @File Name : AddToJobPositionController.cls
* @Author : Dixit Anand arora ////////
* @Last Modified By :
* @Last Modified On :November 26, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | October 25, 2025 |   | Initial Version
**/


public without sharing class AddToJobPositionController {

    /* =========================================================
       Fetch Job Positions (Recommended + Search)
       ========================================================= */
    @AuraEnabled(cacheable=true)
    public static List<Job_Position__c> getJobPositions(Id candidateId, String searchKey) {

        List<Job_Position__c> resultJobs = new List<Job_Position__c>();

        /* -------------------------------
           1. Search-based fetch
           ------------------------------- */
        if (!String.isBlank(searchKey)) {
            String likeKey = '%' + searchKey + '%';

            return [
                SELECT Id, Name, Job_Title__c,
                       Client_Name__r.Name,
                       CreatedDate, Skills_Required__c
                FROM Job_Position__c
                WHERE Name LIKE :likeKey
                   OR Job_Title__c LIKE :likeKey
                WITH USER_MODE
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];
        }

        /* -------------------------------
           2. No candidate selected
           ------------------------------- */
        if (candidateId == null) {
            return [
                SELECT Id, Name, Job_Title__c,
                       Client_Name__r.Name,
                       CreatedDate, Skills_Required__c
                FROM Job_Position__c
                WITH USER_MODE
                ORDER BY CreatedDate DESC
            ];
        }

        /* -------------------------------
           3. Resolve Candidate RecordType
           ------------------------------- */
        Map<String, Schema.RecordTypeInfo> rtMap =
            Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName();

        Id candidateRTId = rtMap.get('Candidate').getRecordTypeId();

        /* -------------------------------
           4. Fetch Candidate (Contact)
           ------------------------------- */
        Contact cand;

        cand = [
                SELECT Id, Designation__c, Skills__c
                FROM Contact
                WHERE Id = :candidateId
                AND RecordTypeId = :candidateRTId
                WITH USER_MODE
                LIMIT 1
            ];


        /* -------------------------------
           5. Normalize Candidate Skills
           ------------------------------- */
        Set<String> candidateSkills = new Set<String>();
        if (!String.isBlank(cand.Skills__c)) {
            for (String skill : cand.Skills__c.split('[,;]')) {
                if (!String.isBlank(skill)) {
                    candidateSkills.add(skill.trim().toLowerCase());
                }
            }
        }

        /* -------------------------------
           6. Fetch All Jobs
           ------------------------------- */
        List<Job_Position__c> allJobs = [
            SELECT Id, Name, Job_Title__c,
                   CreatedDate,
                   Client_Name__r.Name,
                   Skills_Required__c
            FROM Job_Position__c
            WITH USER_MODE
            ORDER BY CreatedDate DESC
        ];

        /* -------------------------------
           7. Match Logic (Title + Skills)
           ------------------------------- */
        for (Job_Position__c job : allJobs) {

            Boolean titleMatch = false;
            Boolean skillMatch = false;

            // Title match
            if (!String.isBlank(job.Job_Title__c)
                && !String.isBlank(cand.Designation__c)) {

                String jobTitle =
                    job.Job_Title__c.toLowerCase().replaceAll('\\s+', ' ').trim();
                String candTitle =
                    cand.Designation__c.toLowerCase().replaceAll('\\s+', ' ').trim();

                titleMatch = jobTitle.contains(candTitle);
            }

            // Skill match
            if (!String.isBlank(job.Skills_Required__c)) {
                Set<String> jobSkills = new Set<String>();
                for (String skill : job.Skills_Required__c.split('[,;]')) {
                    if (!String.isBlank(skill)) {
                        jobSkills.add(skill.trim().toLowerCase());
                    }
                }

                for (String skill : candidateSkills) {
                    if (jobSkills.contains(skill)) {
                        skillMatch = true;
                        break;
                    }
                }
            }

            if (titleMatch || skillMatch) {
                resultJobs.add(job);
            }
        }

        /* -------------------------------
           8. Fallback if no matches
           ------------------------------- */
        return resultJobs.isEmpty() ? allJobs : resultJobs;
    }

    /* =========================================================
       Add Candidate to Job Positions
       ========================================================= */
    @AuraEnabled
    public static void addCandidateToJobs(Id candidateId, List<Id> jobIds) {

        if (candidateId == null || jobIds == null || jobIds.isEmpty()) {
            return;
        }

        /* -------------------------------
           1. Existing Interviews
           ------------------------------- */
        Map<Id, String> existingJobs = new Map<Id, String>();

        for (Interview__c intr : [
            SELECT Job_Position__c, Job_Position__r.Name
            FROM Interview__c
            WHERE Candidate_Name__c = :candidateId
            AND Job_Position__c IN :jobIds
            WITH USER_MODE
        ]) {
            existingJobs.put(intr.Job_Position__c, intr.Job_Position__r.Name);
        }

        /* -------------------------------
           2. Prepare Inserts
           ------------------------------- */
        List<Interview__c> toInsert = new List<Interview__c>();

        for (Id jobId : jobIds) {
            if (!existingJobs.containsKey(jobId)) {
                toInsert.add(new Interview__c(
                    Candidate_Name__c = candidateId,
                    Job_Position__c = jobId
                ));
            }
        }

        /* -------------------------------
           3. Block Full Duplicates
           ------------------------------- */
        if (toInsert.isEmpty() && !existingJobs.isEmpty()) {
            String msg = 'Candidate already assigned to: ' +
                String.join(new List<String>(existingJobs.values()), ', ');
            throw new AuraHandledException(msg);
        }

        /* -------------------------------
           4. Insert New Interviews
           ------------------------------- */
        if (!toInsert.isEmpty()) {
            insert toInsert;
        }

        /* -------------------------------
           5. Soft Warning (No Rollback)
           ------------------------------- */
        if (!existingJobs.isEmpty()) {
            String msg = 'Some Job Positions were already assigned: ' +
                String.join(new List<String>(existingJobs.values()), ', '); 
            AuraHandledException ex = new AuraHandledException(msg);
            ex.setMessage(msg);
            throw ex;
        }
    }
}