/*
*#################################################################
* Created By (Date) : Ayush Agrawal (05 Aug, 2025)
* Description       : WorkOrder Handler Class for WorkOrder__c Object.
* Modifications Log :
* Ver   Date          Author           Modification
* 1.0   05 Aug, 2025  Ayush Agrawal    Initial Version
#################################################################
*/
/**
 * @description WorkOrder Handler Class for WorkOrder__c Object. Handles all trigger logic for WorkOrder creation, updates, and deletion.
 */
public class WorkOrderHandler{
    /*
     * ==================================================================================
     * Method  : BeforeDelete
     * Purpose : Executes all required logic when Work_Order__c is Delete (before).
     * Params  : oldMap - Trigger.oldMap
     * ==================================================================================
	*/
     public static void BeforeDelete (Map<Id, Work_Order__c> oldMap) {
         // TODO: Implement delete validation logic if needed
         // Placeholder for future implementation
     }
    /*
     * ==================================================================================
     * Method  : beforeInsert
     * Purpose : Executes all required logic when Work_Order__c is Insert (before).
     * Params  : newList - Trigger.new
     * ==================================================================================
     */
    /**
     * @description Executes all required logic when Work_Order__c is inserted (before).
     * @param newList Trigger.new
     */
     public static void beforeInsert (List<Work_Order__c> newList) {
         // No logic required at this time
         // TODO: Implement insert validation logic if needed
     }
    /*
     * ==================================================================================
     * Method  : BeforeUpdate
     * Purpose : Executes all required logic when Work_Order__c is Update (before).
     * Params  : newList - Trigger.new, oldMap - Trigger.oldMap
     * ==================================================================================
	*/

    public static void BeforeUpdate(List<Work_Order__c> newList, Map<Id, Work_Order__c> oldMap) {
        // Update validation logic to be implemented in future iterations
    }
    /*
     * ==================================================================================
     * Method  : afterDelete
     * Purpose : Executes all required logic when Work_Order__c is deleted (after).
     * Params  : oldMap - Trigger.oldMap
     * ==================================================================================
    */
    /**
     * @description Executes all required logic when Work_Order__c is deleted (after).
     * @param oldMap Trigger.oldMap
     */
    public static void afterDelete(Map<Id, Work_Order__c> oldMap) {
         WorkOrderHelper.updateCandidateProjectCounts(null, oldMap);
    }

    /*
     * ==================================================================================
     * Method  : afterInsert
     * Purpose : Executes all required logic when Work_Order__c is inserted (after).
     * Params  : newList - Trigger.new
     * ==================================================================================
    */
    /**
     * @description Executes all required logic when Work_Order__c is inserted (after).
     * @param newList Trigger.new
     */
    public static void afterInsert(List<Work_Order__c> newList) {
        WorkOrderHelper.updateCandidateProjectCounts(newList, null);

    }
    /*
     * ==================================================================================
     * Method  : afterUpdate
     * Purpose : Executes all required logic when Work_Order__c is updated (after).
     * Params  : newList - Trigger.new, oldMap - Trigger.oldMap
     * ==================================================================================
    */
    /**
     * @description Executes all required logic when Work_Order__c is updated (after).
     * @param newList Trigger.new
     * @param oldMap Trigger.oldMap
     */
     public static void afterUpdate(List<Work_Order__c> newList, Map<Id, Work_Order__c> oldMap) {
        WorkOrderHelper.processWorkOrderCompletion(newList, oldMap);//Added By Dixit
        WorkOrderHelper.updateCandidateBillable(newList, oldMap);//Added By Dixit
        WorkOrderHelper.updateCandidateProjectCounts(newList, oldMap);
	}
}