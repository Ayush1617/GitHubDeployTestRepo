/**
 * ----------------------------------------------------------------------------
 * Class Name      : TimeEntrySaveHelper
 * Description     : Helper class responsible for saving new Time Entry records
 *                   for a Timesheet.
 *
 *                   Responsibilities:
 *                   - Deserialize time entry JSON
 *                   - Fetch Task Type metadata
 *                   - Construct Time Entry records
 *                   - Insert records
 *                   - Update Timesheet status
 *
 * Author          : Ashish Kumar
 * ----------------------------------------------------------------------------
 */
public without sharing class TimeEntrySaveHelper {
    
    /**
     * Saves time entry records for a Timesheet.
     *
     * @param timesheetId Id of the Timesheet
     * @param entriesJson JSON string containing time entry data
     * @param action      Action to update Timesheet status (Draft / Submitted)
     */
    public static void saveEntries(Id timesheetId, String entriesJson, String action) {

        validateTimesheet(timesheetId, action);

        List<BillableNonBillableTaskTypeController.TimeEntryWrapper> entries =
            parseEntries(entriesJson);

        if(entries.isEmpty()){
            return;
        }

        Map<Id, Task_Type__c> taskTypeMap = getTaskTypes(entries);

        List<Time_Entry__c> records =
            buildTimeEntries(entries, taskTypeMap, timesheetId);

        insertTimeEntries(records);

        updateTimesheetStatus(timesheetId, action);
    }

    /* ---------- VALIDATE TIMESHEET ---------- */

    private static void validateTimesheet(Id timesheetId, String action){

        if(timesheetId == null){
            throw new AuraHandledException('Timesheet Id is required.');
        }

        Timesheet__c ts = [
            SELECT Status__c
            FROM Timesheet__c
            WHERE Id = :timesheetId
            WITH USER_MODE
            LIMIT 1
        ];

        if(ts.Status__c == 'Submitted' && action == 'Draft'){
            throw new AuraHandledException('Submitted timesheet cannot be changed to Draft');
        }
    }

    /* ---------- PARSE JSON ---------- */

    private static List<BillableNonBillableTaskTypeController.TimeEntryWrapper>
    parseEntries(String entriesJson){

        if(String.isBlank(entriesJson)){
            return new List<BillableNonBillableTaskTypeController.TimeEntryWrapper>();
        }

        return (List<BillableNonBillableTaskTypeController.TimeEntryWrapper>)
            JSON.deserialize(
                entriesJson,
                List<BillableNonBillableTaskTypeController.TimeEntryWrapper>.class
            );
    }

    /* ---------- GET TASK TYPES ---------- */

    private static Map<Id, Task_Type__c> getTaskTypes(
        List<BillableNonBillableTaskTypeController.TimeEntryWrapper> entries
    ){

        Set<Id> taskTypeIds = new Set<Id>();

        for(BillableNonBillableTaskTypeController.TimeEntryWrapper w : entries){
            if(w.taskTypeId != null){
                taskTypeIds.add(w.taskTypeId);
            }
        }

        return new Map<Id, Task_Type__c>([
            SELECT Id, Billable_Non_Billable__c
            FROM Task_Type__c
            WHERE Id IN :taskTypeIds
            WITH USER_MODE
        ]);
    }

    /* ---------- BUILD RECORDS ---------- */

    private static List<Time_Entry__c> buildTimeEntries(
        List<BillableNonBillableTaskTypeController.TimeEntryWrapper> entries,
        Map<Id, Task_Type__c> taskTypeMap,
        Id timesheetId
    ){

        List<Time_Entry__c> records = new List<Time_Entry__c>();

        Timesheet__c ts = [
            SELECT Project__c, Resource__c
            FROM Timesheet__c
            WHERE Id = :timesheetId
            WITH USER_MODE
            LIMIT 1
        ];

        for(BillableNonBillableTaskTypeController.TimeEntryWrapper wrapper : entries){

            Task_Type__c tt = taskTypeMap.get(wrapper.taskTypeId);

            if(tt == null){
                continue;
            }

            Time_Entry__c te = new Time_Entry__c();

            te.Timesheet__c = timesheetId;
            te.Project__c = ts.Project__c;
            te.Resource__c = ts.Resource__c;
            te.Task_Type__c = wrapper.taskTypeId;
            te.Work_Date__c = wrapper.workDate;
            te.Hours__c = wrapper.hours;
            te.Notes__c = wrapper.note;
            te.Billable__c = tt.Billable_Non_Billable__c;

            records.add(te);
        }

        return records;
    }

    /* ---------- INSERT ---------- */

    private static void insertTimeEntries(List<Time_Entry__c> records){

        if(records.isEmpty()){
            return;
        }

        if(!Schema.sObjectType.Time_Entry__c.isCreateable()){
            throw new AuraHandledException('No permission to create Time Entry');
        }

        insert records;
    }

    /* ---------- UPDATE TIMESHEET ---------- */

    private static void updateTimesheetStatus(Id timesheetId, String action){

        if(!Schema.sObjectType.Timesheet__c.isUpdateable()){
            throw new AuraHandledException('No permission to update Timesheet');
        }

        update new Timesheet__c(
            Id = timesheetId,
            Status__c = action
        );
    }
}