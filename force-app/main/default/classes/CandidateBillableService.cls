public with sharing class CandidateBillableService {

    public static void handle(
        List<Work_Order__c> newList,
        Map<Id, Work_Order__c> oldMap
    ) {
        if (!isValidContext(newList, oldMap)) return;

        Set<Id> candidateIds = getCandidates(newList, oldMap);
        updateBillable(candidateIds);
    }

    private static Boolean isValidContext(
        List<Work_Order__c> newList,
        Map<Id, Work_Order__c> oldMap
    ) {
        return newList != null && oldMap != null &&
               Schema.sObjectType.Contact.isUpdateable();
    }

    private static Set<Id> getCandidates(
        List<Work_Order__c> newList,
        Map<Id, Work_Order__c> oldMap
    ) {
        Set<Id> ids = new Set<Id>();
        for (Work_Order__c wo : newList) {
            if (wo.Candidate_Name__c != null &&
                wo.Status__c == 'Completed' &&
                oldMap.get(wo.Id).Status__c != 'Completed') {
                ids.add(wo.Candidate_Name__c);
            }
        }
        return ids;
    }

    private static void updateBillable(Set<Id> candidateIds) {
        if (candidateIds.isEmpty()) return;

        Map<Id, Boolean> hasOpenWO = new Map<Id, Boolean>();
        for (Work_Order__c wo : [
            SELECT Candidate_Name__c, Status__c
            FROM Work_Order__c
            WHERE Candidate_Name__c IN :candidateIds
        ]) {
            if (wo.Status__c != 'Completed') {
                hasOpenWO.put(wo.Candidate_Name__c, true);
            }
        }

        List<Contact> updates = new List<Contact>();
        for (Id idVal : candidateIds) {
            updates.add(new Contact(
                Id = idVal,
                IsBillable__c = !hasOpenWO.containsKey(idVal)
            ));
        }
        if (!updates.isEmpty()) {
            update updates;
        }
    }
}