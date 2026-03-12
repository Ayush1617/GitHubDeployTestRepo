/**
 * @description Trigger helper for Work_Order__c related business logic.
 * @author Ayush Agrawal
 * @date 05 Aug 2025
 */
public with sharing class WorkOrderHelper {

    public static void processWorkOrderCompletion(
        List<Work_Order__c> newList,
        Map<Id, Work_Order__c> oldMap
    ) {
        WorkOrderCompletionService.handle(newList, oldMap);
    }

    public static void updateCandidateBillable(
        List<Work_Order__c> newList,
        Map<Id, Work_Order__c> oldMap
    ) {
        CandidateBillableService.handle(newList, oldMap);
    }

    public static void updateCandidateProjectCounts(
        List<Work_Order__c> newList,
        Map<Id, Work_Order__c> oldMap
    ) {
        CandidateProjectService.handle(newList, oldMap);
    }
}