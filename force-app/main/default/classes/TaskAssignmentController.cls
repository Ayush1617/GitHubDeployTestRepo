/**
 * -----------------------------------------------------------------------
 * Created by : Sara
 * Class Name  : TaskAssignmentController
 * Description :
 * Provides server-side support for Task Assignment Dashboard LWC.
 * Handles filtering, pagination, and recruiter retrieval.
 *
 * Design:
 *  - JSON-based request handling
 *  - Dynamic SOQL with safe bind variables
 *  - Helper methods to reduce cyclomatic complexity
 *  - Defensive default handling
 *
 * Security:
 *  - Enforced using 'with sharing'
 * -----------------------------------------------------------------------
 */
public with sharing class TaskAssignmentController {

    // ================= WRAPPER =================

    public class TaskFilterRequest {
        public String priorityFilter;
        public Id recruiterId;
        public Integer pageSize;
        public Integer pageNumber;
        public Long refreshTime;
        public String startDate;
        public String endDate;
        public String recordTypeName; 
    }

    public class TaskWrapper {
        @AuraEnabled public List<Task> tasks;
        @AuraEnabled public Integer totalRecords;

        public TaskWrapper(List<Task> tasks, Integer totalRecords) {
            this.tasks = tasks;
            this.totalRecords = totalRecords;
        }
    }

    // ================= MAIN METHOD =================

    @AuraEnabled(cacheable=true)
    public static TaskWrapper getTasks(String requestJson) {

        TaskFilterRequest request = parseRequest(requestJson);
        applyDefaults(request);

        String priorityFilter = request.priorityFilter;
        Id recruiterId = request.recruiterId;
        String recordTypeName = request.recordTypeName; // ✅ CORRECT PLACE
        Date startDateObj = parseDate(request.startDate);
        Date endDateObj = parseDate(request.endDate);
        Date endPlusOne;

        String baseQuery = ' FROM Task';
        List<String> conditions = new List<String>();

        // Priority Filter
        if (String.isNotBlank(priorityFilter) && priorityFilter != 'All') {
            conditions.add('Priority = :priorityFilter');
        }

        // Recruiter Filter
        if (recruiterId != null) {
            conditions.add('OwnerId = :recruiterId');
        }

        // ✅ Record Type Filter (DeveloperName Based)
        if (String.isNotBlank(recordTypeName) && recordTypeName != 'All') {
            conditions.add('RecordType.DeveloperName = :recordTypeName');
        }

        // Start Date Filter
        if (startDateObj != null) {
            conditions.add('CreatedDate >= :startDateObj');
        }

        // End Date Filter
        if (endDateObj != null) {
            endPlusOne = endDateObj.addDays(1);
            conditions.add('CreatedDate < :endPlusOne');
        }

        if (!conditions.isEmpty()) {
            baseQuery += ' WHERE ' + String.join(conditions, ' AND ');
        }

        Integer totalRecords =
            (Integer) Database.countQuery('SELECT COUNT()' + baseQuery);

        Integer pageSize = request.pageSize;
        Integer pageNumber = request.pageNumber;
        Integer offsetSize = (pageNumber - 1) * pageSize;

        List<Task> taskList = Database.query(
            'SELECT Id, Subject, ActivityDate, CreatedDate, ' +
            'Priority, Status, OwnerId, Owner.Name, ' +
            'Expected_Completion_Time__c, ' +
            'Actual_Working_Hours__c, ' +
            'Candidates_to_submit__c,' +
            'Actual_Candidate_submitted__c,'+
            'RecordType.Name ' +
            baseQuery +
            ' ORDER BY CreatedDate DESC ' +
            ' LIMIT :pageSize OFFSET :offsetSize'
        );

        return new TaskWrapper(taskList, totalRecords);
    }

    // ================= DROPDOWN DATA =================

    @AuraEnabled(cacheable=true)
    public static List<User> getRecruiters() {
        return [
            SELECT Id, Name
            FROM User
            WHERE IsActive = true
            WITH SYSTEM_MODE
            ORDER BY Name
        ];
    }

    // ✅ Dynamic Record Types
    @AuraEnabled(cacheable=true)
    public static List<RecordType> getTaskRecordTypes() {
        return [
            SELECT Name, DeveloperName
            FROM RecordType
            WHERE SObjectType = 'Task'
            AND IsActive = true
            ORDER BY Name
        ];
    }

    // ================= HELPERS =================

    private static TaskFilterRequest parseRequest(String requestJson) {
        if (String.isBlank(requestJson)) {
            return new TaskFilterRequest();
        }
        return (TaskFilterRequest)
            JSON.deserialize(requestJson, TaskFilterRequest.class);
    }

    private static void applyDefaults(TaskFilterRequest request) {
        if (request.pageSize == null || request.pageSize <= 0) {
            request.pageSize = 5;
        }
        if (request.pageNumber == null || request.pageNumber <= 0) {
            request.pageNumber = 1;
        }
    }

    private static Date parseDate(String dateStr) {
        return String.isNotBlank(dateStr)
            ? Date.valueOf(dateStr)
            : null;
    }
}