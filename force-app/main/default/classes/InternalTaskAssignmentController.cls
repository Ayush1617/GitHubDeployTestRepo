/**
 * @description
 * Controller used by Lightning Web Component to manage bulk internal
 * Task assignment. This class provides methods to:
 * 
 * 1. Fetch active Users for assignment
 * 2. Fetch dynamic Task picklist values (Priority, Status, Subject)
 * 3. Save multiple Task records in bulk
 *
 * The class enforces sharing rules and is intended for internal
 * and Experience Cloud usage.
 *
 * @author sara
 * @since API 65.0
 */
public with sharing class InternalTaskAssignmentController {

    /**
     * @description
     * Fetches a list of active Users from the org.
     * Used to populate the "Assigned To" dropdown in the LWC.
     *
     * @return List<User> A list of active Users (Id and Name only),
     *                    ordered alphabetically, limited to 200 records.
     */
    @AuraEnabled(cacheable=true)
    public static List<User> getUsers() {

        if (!Schema.sObjectType.User.isAccessible()) {
            return new List<User>();
        }

        return [
            SELECT Id, Name
            FROM User
            WHERE IsActive = true
            ORDER BY Name
            LIMIT 200
        ];
    }

    /**
     * @description
     * Retrieves Task picklist values dynamically using Schema Describe.
     * Fetches values for:
     *  - Priority
     *  - Status
     *  - Subject
     *
     * This ensures that UI automatically reflects any changes
     * made to Task picklist configurations in Setup.
     *
     * @return Map<String, List<String>>
     *         A map containing picklist field names as keys and
     *         corresponding picklist label values as lists.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getTaskPicklistValues() {
        Map<String, List<String>> picklists = new Map<String, List<String>>();

        // Priority
        List<String> priorities = new List<String>();
        for (Schema.PicklistEntry p : Task.Priority.getDescribe().getPicklistValues()) {
            priorities.add(p.getLabel());
        }

        // Status
        List<String> statuses = new List<String>();
        for (Schema.PicklistEntry s : Task.Status.getDescribe().getPicklistValues()) {
            statuses.add(s.getLabel());
        }

        // Subject
        List<String> subjects = new List<String>();
        for (Schema.PicklistEntry s : Task.Subject.getDescribe().getPicklistValues()) {
            subjects.add(s.getLabel());
        }

        picklists.put('Priority', priorities);
        picklists.put('Status', statuses);
        picklists.put('Subject', subjects);

        return picklists;
    }
    
    /**
     * @description
     * Saves multiple Task records in bulk.
     * Accepts JSON string from LWC representing rows entered by the user.
     *
     * Steps performed:
     * 1. Deserialize JSON into TaskWrapper list
     * 2. Validate mandatory fields (Subject, AssignedTo)
     * 3. Dynamically fetch RecordTypeId
     * 4. Create Task records
     * 5. Perform bulk insert
     *
     * @param rowsJson
     *        JSON string containing list of TaskWrapper objects.
     *
     * @return Integer
     *         Number of Task records successfully inserted.
     *
     * @throws AuraHandledException
     *         If user does not have permission to create Task records.
     *
     * @AuraEnabled
     */
    @AuraEnabled
    public static Integer saveTasks(String rowsJson) {
        if (String.isBlank(rowsJson)) {return 0;}

        List<TaskWrapper> rows =
            (List<TaskWrapper>) JSON.deserialize(rowsJson, List<TaskWrapper>.class);

        List<Task> tasks = new List<Task>();

        // Get RecordTypeId
        Id recordTypeId = Schema.SObjectType.Task
            .getRecordTypeInfosByDeveloperName()
            .get('Recruitment_Operations')  // <-- replace with your RT dev name
            .getRecordTypeId();

        for (TaskWrapper row : rows) {
            if (String.isBlank(row.subject) || String.isBlank(row.assignedTo)) {continue;}

            Date due = String.isBlank(row.dueDate) ? null : Date.valueOf(row.dueDate);

            tasks.add(new Task(
                Subject = row.subject,
                OwnerId = row.assignedTo,
                Priority = row.priority,
                Status = row.status,
                ActivityDate = due,
                RecordTypeId = recordTypeId
            ));
        }

        if (!tasks.isEmpty()){

            if (!Schema.sObjectType.Task.isCreateable()) {
                throw new AuraHandledException('You do not have permission to create Tasks');
            }

            insert tasks;
        }

        return tasks.size();
    }

    /**
     * @description
     * Wrapper class used for JSON serialization and deserialization
     * between Lightning Web Component and Apex.
     *
     * Represents a single Task row entered by the user in UI.
     */
    public class TaskWrapper {
        @AuraEnabled public String subject;
        @AuraEnabled public String priority;
        @AuraEnabled public String dueDate;
        @AuraEnabled public String status;
        @AuraEnabled public String assignedTo;
    }
}