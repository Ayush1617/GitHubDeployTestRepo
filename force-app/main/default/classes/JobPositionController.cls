/**
* @File Name : JobPositionController.cls
* @Description : Controller for the Child Component of Candidate Card joppositionCard
* @Author :
* @Last Modified By :
* @Last Modified On : August 19, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | August 19, 2025 |   | Initial Version
**/
public with sharing class JobPositionController {
    @AuraEnabled(cacheable=true)
    public static List<Job_Position__c> getOpenJobPositions(String searchKey) {
    String key = '%' + searchKey + '%';

    return [
        SELECT Id, Name, Job_Title__c, Status__c, Total_Openings__c, Required_Experience_Range__c, CreatedDate
        FROM Job_Position__c
        WHERE Status__c = 'Open'
        AND (
            Name LIKE :key
            OR Job_Title__c LIKE :key
        )
        ORDER BY CreatedDate DESC
    ];
}

// no record found message

 
    @AuraEnabled
    public static void assignCandidatesToJobs(List<Id> candidateIds, List<Id> jobPositionIds) {
        List<Interview__c> interviews = new List<Interview__c>();

        for (Id jobId : jobPositionIds) {
            for (Id candidateId : candidateIds) {
                interviews.add(new Interview__c(
                    Candidate_Name__c = candidateId,
                    Job_Position__c = jobId,
                    Interview_Status__c = 'New'
                ));
            }
        }

        if (!interviews.isEmpty()) {
            insert interviews;
        }
    }

}