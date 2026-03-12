public with sharing class ProjectTaskTypeController {

    @AuraEnabled(cacheable=true)
    public static List<Task_Type__c> getTaskTypes(Id projectId) {
        return [
            SELECT Id, Name,
                   Billable_Non_Billable__c,
                   Billing_rate_per_hour__c
            FROM Task_Type__c
            WHERE Task_Type_Project__c = :projectId
            ORDER BY CreatedDate
        ];
    }

    @AuraEnabled
    public static void updateTaskType(Task_Type__c taskType) {
        update taskType;
    }

    @AuraEnabled
    public static Task_Type__c createTaskType(Id projectId) {
        Task_Type__c tt = new Task_Type__c(
            Name = 'New Task Type',
            Task_Type_Project__c = projectId,
            Billable_Non_Billable__c = false
        );
        insert tt;
        return tt;
    }
    
      @AuraEnabled(cacheable=true)
    public static String getProjectBillingRateType(Id projectId) {
        return [
            SELECT Billable_Rate__c
            FROM Project__c
            WHERE Id = :projectId
            LIMIT 1
        ].Billable_Rate__c;
    }
}