public with sharing class CandidateProjectService {

    public static void handle(
        List<Work_Order__c> newList,
        Map<Id, Work_Order__c> oldMap
    ) {
        Set<Id> candidateIds = collectCandidates(newList, oldMap);
        Map<Id, Integer> counts = calculateCounts(candidateIds);
        updateCounts(candidateIds, counts);
    }

    private static Set<Id> collectCandidates(
    List<Work_Order__c> newList,
    Map<Id, Work_Order__c> oldMap
) {
    Set<Id> ids = new Set<Id>();

    // New records (Insert & Update)
    if (newList != null) {
        for (Work_Order__c wo : newList) {
            if (wo.Candidate_Name__c != null) {
                ids.add(wo.Candidate_Name__c);
            }
        }
    }

    // Old records (Update only)
    if (oldMap != null) {
        for (Work_Order__c wo : oldMap.values()) {
            if (wo.Candidate_Name__c != null) {
                ids.add(wo.Candidate_Name__c);
            }
        }
    }

    return ids;
}


    private static Map<Id, Integer> calculateCounts(Set<Id> candidateIds) {
    Map<Id, Set<Id>> temp = new Map<Id, Set<Id>>();

    for (Work_Order__c wo : [
        SELECT Candidate_Name__c, Project__c
        FROM Work_Order__c
        WHERE Candidate_Name__c IN :candidateIds
        AND Project__c != null
    ]) {
        if (!temp.containsKey(wo.Candidate_Name__c)) {
            temp.put(wo.Candidate_Name__c, new Set<Id>());
        }
        temp.get(wo.Candidate_Name__c).add(wo.Project__c);
    }

    Map<Id, Integer> result = new Map<Id, Integer>();
    for (Id cid : candidateIds) {
        result.put(
            cid,
            temp.containsKey(cid) ? temp.get(cid).size() : 0
        );
    }
    return result;
}


    private static void updateCounts(
        Set<Id> candidateIds,
        Map<Id, Integer> counts
    ) {
        List<Contact> updates = new List<Contact>();
        for (Id idVal : candidateIds) {
            updates.add(new Contact(
                Id = idVal,
                No_of_projects__c = counts.get(idVal)
            ));
        }
        update updates;
    }
}