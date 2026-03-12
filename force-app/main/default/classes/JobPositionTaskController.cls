/**
 * @description Controller class to fetch Tasks related to a Job Position.
 * Provides a secure, read-only, cacheable method for Lightning components.
 *
 * @author Amit
 */
public with sharing class JobPositionTaskController {

    /**
     * @description Returns a list of Tasks associated with the given Job Position.
     * Performs null checks and field-level security validation
     * before executing the SOQL query.
     *
     * @param jobPositionId  Id of the Job_Position__c record
     * @return List<Task>    List of related Task records
     */
    @AuraEnabled(cacheable=true)
    public static List<Task> getTasks(Id jobPositionId) {

        if (jobPositionId == null) {
            return new List<Task>();
        }

        if (!Schema.sObjectType.Task.isAccessible()) {
            return new List<Task>();
        }

        if (!Schema.sObjectType.Task.fields.Subject.isAccessible() ||
            !Schema.sObjectType.Task.fields.Status.isAccessible() ||
            !Schema.sObjectType.Task.fields.Priority.isAccessible() ||
            !Schema.sObjectType.Task.fields.ActivityDate.isAccessible() ||
            !Schema.sObjectType.Task.fields.OwnerId.isAccessible() ||
            !Schema.sObjectType.Task.fields.WhatId.isAccessible()) {

            return new List<Task>();
        }

        return [
            SELECT Id,
                   Subject,
                   Status,
                   Priority,
                   ActivityDate,
                   WhatId,
                   Owner.Name
            FROM Task
            WHERE WhatId = :jobPositionId
            ORDER BY ActivityDate ASC
            LIMIT 200
        ];
    }
}