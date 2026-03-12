/**
 * @description Trigger handler for Interview__c.
 *              Delegates trigger logic to InterviewTriggerHelper.
 * @author Admin
 * @since 26-Aug-2025
 */
public class InterviewTriggerHandler {

    /**
     * @description Handles after-insert logic for Interview__c records.
     * @param newList List of newly inserted Interview__c records (Trigger.new)
     */
    public static void handleAfterInsert(List<Interview__c> newList) {
    InterviewTriggerHelper.handleInterviewEvents(newList, null);
    }
    
    /**
     * @description Handles after-update logic for Interview__c records.
     *              Manages status changes, work order creation,
     *              and interview-related events.
     *
     * @param newList List of updated Interview__c records (Trigger.new)
     * @param oldMap  Map of Interview__c records before update (Trigger.oldMap)
     */
    public static void handleAfterUpdate(
        List<Interview__c> newList,
        Map<Id, Interview__c> oldMap
    ) {
        InterviewTriggerHelper.handleStatusChange(newList, oldMap);
        InterviewTriggerHelper.createWorkOrder(newList, oldMap);
        InterviewTriggerHelper.handleInterviewEvents(newList, oldMap);
    }
 }