/**
 * @description Handles job task assignment from LWC
 * @author Sara
 */
public with sharing class ExternalJobTaskAssignmentController {

    /**
     * @description Fetches all open job positions for UI
     * @return List of JobWrapper objects
     */
    @AuraEnabled(cacheable=true)
    public static List<JobWrapper> getJobPositions() {

        if (!Schema.sObjectType.Job_Position__c.isAccessible()) {
            return new List<JobWrapper>();
        }

        List<Job_Position__c> jobs = [
            SELECT Id, Job_Title__c, Total_Openings__c, Priority__c, Client_Name__r.Name, Open_Date__c
            FROM Job_Position__c
            WHERE Status__c = 'Open'
            WITH USER_MODE
             ORDER BY CreatedDate DESC
        ];

        List<JobWrapper> wrappers = new List<JobWrapper>();
        for (Job_Position__c job : jobs) {
            wrappers.add(new JobWrapper(job));
        }

        return wrappers;
    }

    /**
     * @description Fetches active users for assignment
     * @return List of User records
     */
    @AuraEnabled(cacheable=true)
    public static List<User> getUsers() {

        if (!Schema.sObjectType.User.isAccessible()) {
            return new List<User>();
        }

        return [
            SELECT Id, Name
            FROM User
            WHERE IsActive = true
            WITH USER_MODE
            LIMIT 200
        ];
    }


    /**
     * @description Fetches Task Priority picklist values
     * @return List of picklist labels
     */
    @AuraEnabled(cacheable=true)
    public static List<String> getTaskPriorityValues() {
        List<String> values = new List<String>();

        for (Schema.PicklistEntry pe : Task.Priority.getDescribe().getPicklistValues()) {
            values.add(pe.getLabel());
        }

        return values;
    }

    /**
     * @description Saves task assignments created in LWC
     * @param rowsJson JSON string containing assignment rows from UI
     */
    @AuraEnabled
    public static void saveAssignments(String rowsJson) {

        if (String.isBlank(rowsJson) || !Schema.sObjectType.Task.isCreateable()) {
            return;
        }
        system.debug('JSON values : '+ rowsJson);
        Id recordTypeId = Schema.SObjectType.Task
            .getRecordTypeInfosByDeveloperName()
            .get('Candidate_Submission')
            .getRecordTypeId();

        List<ExternalJobAssignmentWrapper> rows =
            (List<ExternalJobAssignmentWrapper>)
            JSON.deserialize(rowsJson, List<ExternalJobAssignmentWrapper>.class);

        List<Task> tasksToInsert = new List<Task>();

        for (ExternalJobAssignmentWrapper row : rows) {
            if (!isValidAssignment(row)) {
                continue;
            }

            tasksToInsert.add(buildTask(row, recordTypeId));
        }

        if (!tasksToInsert.isEmpty()) {
            insert tasksToInsert;
        }
    }

    /**
     * @description Validates assignment wrapper
     * @param row Assignment wrapper row
     * @return true if valid
     */
    private static Boolean isValidAssignment(ExternalJobAssignmentWrapper row) {
        return !String.isBlank(row.jobId)
            && !String.isBlank(row.assignedTo)
            && !String.isBlank(row.taskPriority)
            && row.targetCount != null
            && row.targetCount > 0;
    }

    /**
     * @description Builds Task record from wrapper
     * @param row Assignment wrapper
     * @param recordTypeId Task RecordType Id
     * @return Task record
     */
    private static Task buildTask(ExternalJobAssignmentWrapper row, Id recordTypeId) {
        return new Task(
            Subject = row.jobTitle + ' – Client: ' + row.client,
            OwnerId = row.assignedTo,
            WhatId  = row.jobId,
            Priority = row.taskPriority,
            Status = 'Not Started',
            ActivityDate = Date.today(),
            RecordTypeId = recordTypeId,
            Candidates_to_submit__c = row.targetCount,
            Expected_Completion_time__c = row.expectedtime
        );
    }

    /**
     * @description Wrapper for Job Position data sent to LWC
     */
    public class JobWrapper {
        @AuraEnabled public Id id;
        @AuraEnabled public String jobTitle;
        @AuraEnabled public Decimal totalOpenings;
        @AuraEnabled public String priority;
        @AuraEnabled public String client;
        @AuraEnabled public Date openDate;

        /**
         * @description Constructor for JobWrapper
         * @param job Job_Position__c record
         */
        public JobWrapper(Job_Position__c job) {
            id = job.Id;
            jobTitle = job.Job_Title__c;
            totalOpenings = job.Total_Openings__c;
            priority = job.Priority__c;
            client = job.Client_Name__r != null ? job.Client_Name__r.Name : null;
            openDate = job.Open_Date__c;
        }
    }

    /**
     * @description Wrapper for UI assignment payload from LWC
     */
    public class ExternalJobAssignmentWrapper {
        @AuraEnabled public String jobId;
        @AuraEnabled public String jobTitle;
        @AuraEnabled public Integer requirements;
        @AuraEnabled public String priority;       // Job Priority
        @AuraEnabled public String taskPriority;   // Task Priority
        @AuraEnabled public String client;
        @AuraEnabled public String assignedTo;
        @AuraEnabled public Integer targetCount;
        @AuraEnabled public Integer expectedtime;
    }
}