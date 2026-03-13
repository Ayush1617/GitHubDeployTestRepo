/**
 * ----------------------------------------------------------------------------
 * Class Name      : BillableNonBillableTaskTypeController
 * Description     : Controller class used by LWC to manage Billable and 
 *                   Non-Billable task time entries for a Timesheet.
 *
 *                   This class provides functionality to:
 *                   - Fetch Task Types for a project
 *                   - Retrieve existing Time Entry records for a Timesheet
 *                   - Save new Time Entries
 *                   - Update existing Time Entries
 *                   - Update Timesheet totals and status
 *
 * Author          : Ashish Kumar
 * Created Date    : Feb 17, 2026
 * ----------------------------------------------------------------------------
 */
public without sharing class BillableNonBillableTaskTypeController {

    /**
     * Wrapper class used for deserializing time entry data
     * sent from the LWC component.
     */
    public class TimeEntryWrapper {
        public Id taskTypeId;
        public Date workDate;
        public Decimal hours;
        public String note;
    }
    
    /**
     * Response wrapper used to send Timesheet status
     * and existing Time Entry records to the LWC.
     */
    public class TimeEntryResponse {
        @AuraEnabled public String timesheetStatus;
        @AuraEnabled public List<Time_Entry__c> entries;
    }

    /**
     * Retrieves task types associated with a specific project.
     *
     * @param projectId  Id of the Project for which task types are required
     * @return List<Task_Type__c> List of billable and non-billable task types
     */
    @AuraEnabled(cacheable=true)
    public static List<Task_Type__c> getTaskTypes(Id projectId) {

        list<Task_Type__c> tasktype = [
            SELECT Id, Name,
                   Billable_Non_Billable__c,
                   Billing_rate_per_hour__c
            FROM Task_Type__c
            WHERE Task_Type_Project__c = :projectId
            WITH USER_MODE
            ORDER BY CreatedDate
        ];

        //system.debug('tasktype ...' + tasktype);
         
         return tasktype;

    }
    
    /**
     * Retrieves existing time entries for the given timesheet.
     * Also returns the current status of the timesheet.
     *
     * @param timesheetId Id of the Timesheet
     * @return TimeEntryResponse Wrapper containing timesheet status and entries
     */
   @AuraEnabled(cacheable=true)
    public static TimeEntryResponse getTimeEntries(Id timesheetId) {

        TimeEntryResponse response = new TimeEntryResponse();

        // Get Timesheet status
        Timesheet__c ts = [
            SELECT Status__c
            FROM Timesheet__c
            WHERE Id = :timesheetId
            WITH USER_MODE
            LIMIT 1
        ];

        response.timesheetStatus = ts.Status__c;

        // Get Time Entries
        response.entries = [
            SELECT Id,
                Hours__c,
                Notes__c,
                Timesheet__c,
                Work_Date__c,
                Billable__c,
                Status__c,
                Task_Type__c,
                Task_Type__r.Name,
                Task_Type__r.Billable_Non_Billable__c
            FROM Time_Entry__c
            WHERE Timesheet__c = :timesheetId
            ORDER BY Work_Date__c
        ];

        return response;
    }
    
    /**
     * Saves new time entry records for the specified timesheet.
     *
     * The entries are received from the LWC as a JSON string and
     * deserialized into TimeEntryWrapper objects.
     *
     * @param timesheetId Id of the Timesheet
     * @param entriesJson JSON string containing time entry data
     * @param action      Action indicating status change (Draft / Submitted)
     */
    @AuraEnabled
    public static void saveTimeEntries(
        Id timesheetId,
        String entriesJson,
        String action
    ){
        TimeEntrySaveHelper.saveEntries(timesheetId, entriesJson, action);
    }
    
    /**
     * Updates existing Time Entry records and inserts new ones if required.
     *
     * @param entries List of Time_Entry__c records to update or insert
     */
    @AuraEnabled
    public static void updateTimeEntries(List<Time_Entry__c> entries){
        TimeEntryUpdateHelper.updateEntries(entries);
    }
    /**
     * Updates Timesheet totals and status.
     *
     * Prevents changing a Submitted timesheet back to Draft.
     *
     * @param timesheetRecord Timesheet record containing updated totals
     */
    @AuraEnabled
    public static void updateTimesheet(Timesheet__c timesheetRecord) {

        Timesheet__c existing = [
            SELECT Id, Status__c
            FROM Timesheet__c
            WHERE Id = :timesheetRecord.Id
            WITH USER_MODE
            LIMIT 1
        ];

        // Prevent downgrade
        if(existing.Status__c == 'Submitted' && timesheetRecord.Status__c == 'Draft'){
            throw new AuraHandledException(
                'Submitted timesheet cannot be changed back to Draft.'
            );
        }

        if(!Schema.sObjectType.Timesheet__c.isUpdateable()){
            throw new AuraHandledException('No permission to update Timesheet');
        }

        update timesheetRecord;
    }
}