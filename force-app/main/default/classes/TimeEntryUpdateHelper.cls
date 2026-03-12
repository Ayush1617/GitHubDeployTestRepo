/**
 * ----------------------------------------------------------------------------
 * Class Name      : TimeEntryUpdateHelper
 * Description     : Helper class responsible for updating existing
 *                   Time Entry records and inserting new ones.
 *
 *                   Responsibilities:
 *                   - Separate insert and update records
 *                   - Fetch Timesheet metadata
 *                   - Populate Project and Resource fields
 *                   - Perform database operations
 *
 * Author          : Ashish Kumar
 * ----------------------------------------------------------------------------
 */
public without sharing class TimeEntryUpdateHelper {

    private class EntrySplitResult {
        List<Time_Entry__c> toInsert = new List<Time_Entry__c>();
        List<Time_Entry__c> toUpdate = new List<Time_Entry__c>();
    }
    
	/**
	 * Updates existing Time Entry records and inserts new ones.
	 *
	 * @param entries List of Time_Entry__c records to be processed
	 */
    public static void updateEntries(List<Time_Entry__c> entries){

        if(entries == null || entries.isEmpty()){
            return;
        }

        Map<Id, Timesheet__c> tsMap = getTimesheets(entries);

        EntrySplitResult result = prepareRecords(entries, tsMap);

        updateExisting(result.toUpdate);
        insertNew(result.toInsert);
    }

    /* ---------- GET TIMESHEETS ---------- */

    private static Map<Id, Timesheet__c> getTimesheets(List<Time_Entry__c> entries){

        Set<Id> timesheetIds = new Set<Id>();

        for(Time_Entry__c te : entries){
            if(te.Timesheet__c != null){
                timesheetIds.add(te.Timesheet__c);
            }
        }

        return new Map<Id, Timesheet__c>([
            SELECT Id, Project__c, Resource__c
            FROM Timesheet__c
            WHERE Id IN :timesheetIds
            WITH SYSTEM_MODE
        ]);
    }

    /* ---------- PREPARE RECORDS ---------- */

    private static EntrySplitResult prepareRecords(
        List<Time_Entry__c> entries,
        Map<Id, Timesheet__c> tsMap
    ){

        EntrySplitResult result = new EntrySplitResult();

        for(Time_Entry__c te : entries){

            if(te.Id == null){

                Timesheet__c ts = tsMap.get(te.Timesheet__c);

                if(ts != null){
                    te.Project__c = ts.Project__c;
                    te.Resource__c = ts.Resource__c;
                }

                result.toInsert.add(te);

            } else {

                result.toUpdate.add(te);
            }
        }

        return result;
    }

    /* ---------- UPDATE EXISTING ---------- */

    private static void updateExisting(List<Time_Entry__c> records){

        if(records.isEmpty()){
            return;
        }

        if(!Schema.sObjectType.Time_Entry__c.isUpdateable()){
            throw new AuraHandledException('No permission to update Time Entry');
        }

        update records;
    }

    /* ---------- INSERT NEW ---------- */

    private static void insertNew(List<Time_Entry__c> records){

        if(records.isEmpty()){
            return;
        }

        if(!Schema.sObjectType.Time_Entry__c.isCreateable()){
            throw new AuraHandledException('No permission to create Time Entry');
        }

        insert records;
    }
}