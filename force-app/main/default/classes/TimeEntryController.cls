public with sharing class TimeEntryController {

    @AuraEnabled(cacheable=true)
public static List<Task_Type__c> getTaskTypes(Id projectId) {
    return [
        SELECT Id, Name
        FROM Task_Type__c
        WHERE Task_Type_Project__c = :projectId
        ORDER BY Name
    ];
     
    }
}