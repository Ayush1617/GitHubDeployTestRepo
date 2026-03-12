public with sharing class WorkOrderCompletionService {

    public static void handle(
        List<Work_Order__c> newList,
        Map<Id, Work_Order__c> oldMap
    ) {
        if (!isValidContext(newList, oldMap)) return;

        Set<Id> completedIds = getNewlyCompleted(newList, oldMap);
        if (completedIds.isEmpty()) return;

        Set<Id> parentIds = getParentIds(completedIds);
        updateParents(parentIds);
    }

    private static Boolean isValidContext(
        List<Work_Order__c> newList,
        Map<Id, Work_Order__c> oldMap
    ) {
        return newList != null && oldMap != null &&
               Schema.sObjectType.Work_Order__c.isUpdateable();
    }

    private static Set<Id> getNewlyCompleted(
        List<Work_Order__c> newList,
        Map<Id, Work_Order__c> oldMap
    ) {
        Set<Id> ids = new Set<Id>();
        for (Work_Order__c wo : newList) {
            if (oldMap.get(wo.Id).Status__c != 'Completed'
                && wo.Status__c == 'Completed') {
                ids.add(wo.Id);
            }
        }
        return ids;
    }

    private static Set<Id> getParentIds(Set<Id> childIds) {
        Set<Id> parents = new Set<Id>();
        for (Work_Order__c wo : [
            SELECT Parent_Work_OrderID__c
            FROM Work_Order__c
            WHERE Id IN :childIds
        ]) {
            if (wo.Parent_Work_OrderID__c != null) {
                parents.add(wo.Parent_Work_OrderID__c);
            }
        }
        return parents;
    }

    private static void updateParents(Set<Id> parentIds) {
        if (parentIds.isEmpty()) return;

        List<Work_Order__c> updates = new List<Work_Order__c>();
        for (Work_Order__c wo : [
            SELECT Status__c FROM Work_Order__c WHERE Id IN :parentIds
        ]) {
            if (wo.Status__c != 'Completed') {
                wo.Status__c = 'Completed';
                updates.add(wo);
            }
        }
        if (!updates.isEmpty()) update updates;
    }
}