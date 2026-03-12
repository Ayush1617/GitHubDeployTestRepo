/**
* @file Name : InterviewTriggerHelperAssist.cls
* @description : This class assist InterviewTriggerHelper class
* @author : Kshitiz
* @Last Modified By : Kshitiz
* @Last Modified On : December 29, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | December 29, 2025 |   | Initial Version
**/

public with sharing class InterviewTriggerHelperAssist {
	/**
     * @description
     * Collects Interview__c Ids for insert context.
     *
     * @param newList
     * Trigger.new list of Interview__c records.
     * @return
     * Set of Interview__c Ids.
     */
    public static Set<Id> getInterviewIdsForInsert(List<Interview__c> newList) {
        Set<Id> ids = new Set<Id>();
        for (Interview__c i : newList) {
            ids.add(i.Id);
        }
        return ids;
    }

	/**
     * @description
     * Collects Interview__c Ids for update context
     * where interview date or mode has changed.
     *
     * @param newList
     * Trigger.new list of Interview__c records.
     * @param oldMap
     * Trigger.oldMap containing previous Interview__c values.
     * @return
     * Set of Interview__c Ids requiring processing.
     */
    public static Set<Id> getInterviewIdsForUpdate(
        List<Interview__c> newList,
        Map<Id, Interview__c> oldMap
    ) {
        Set<Id> ids = new Set<Id>();
        for (Interview__c i : newList) {
            Interview__c oldRec = oldMap.get(i.Id);
            if (i.Interview_Date__c != oldRec.Interview_Date__c ||
                i.Interview_Mode__c != oldRec.Interview_Mode__c) {
                ids.add(i.Id);
            }
        }
        return ids;
    }

	
    /**
     * @description
     * Creates Work_Order__c records for hired interviews
     * and triggers email notifications to interview owners.
     *
     * @param interviewIds
     * Set of Interview__c record Ids eligible for Work Order creation.
     */
    public static void processWorkOrderCreation(Set<Id> interviewIds) {

        List<Interview__c> interviewList = [
            SELECT Id, Candidate_Name__c,
                   Job_Position__r.Project__c,
                   Job_Position__r.Job_Title__c,
                   OwnerId
            FROM Interview__c
            WHERE Id IN :interviewIds
            WITH USER_MODE
        ];

        List<Work_Order__c> workOrders = new List<Work_Order__c>();
        Map<Integer, Id> indexToInterview = new Map<Integer, Id>();
        Integer index = 0;

        for (Interview__c rec : interviewList) {
            if (rec.Candidate_Name__c == null) {
                continue;
            }

            Work_Order__c wo = new Work_Order__c();
            wo.Candidate_Name__c = rec.Candidate_Name__c;
            wo.Project__c = rec.Job_Position__r.Project__c;
            wo.Start_Date__c = Date.today();
            wo.Status__c = RecruitmentApp_Constants.WORKORDER_STATUS_NEW;
            wo.Role_on_Project__c = rec.Job_Position__r.Job_Title__c;

            workOrders.add(wo);
            indexToInterview.put(index++, rec.Id);
        }

        if (workOrders.isEmpty()) {
            return;
        }

        Database.SaveResult[] results = InterviewTriggerHelper.insertrecord(workOrders);

        List<Id> workOrderIds = new List<Id>();
        List<Id> interviewIdsForEmail = new List<Id>();

        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) {
                workOrderIds.add(results[i].getId());
                interviewIdsForEmail.add(indexToInterview.get(i));
            }
        }

        if (!workOrderIds.isEmpty()) {
            InterviewTriggerHelper.emailToOwner(workOrderIds, interviewIdsForEmail);
        }
    }

	/**
     * @description
     * Commits Event record insertions and updates to the database
     * with centralized error handling.
     * @param eventsToInsert
     * List of newly created Event records to be inserted.
     *
     * @param eventsToUpdate
     * List of existing Event records to be updated.
     *
     * @throws AuraHandledException
     * Thrown when Event DML operations fail.
     */
    public static void commitEvents(
        List<Event> eventsToInsert,
        List<Event> eventsToUpdate
    ) { 
        try {
            if (!eventsToInsert.isEmpty()) {
                insert as User eventsToInsert;
            }
            if (!eventsToUpdate.isEmpty()) {
                update as User eventsToUpdate;
            }
        } catch (Exception e) {
            throw new AuraHandledException(
                'Unable to process interview events. Error: ' + e.getMessage()
                
            );
        }
    }
}