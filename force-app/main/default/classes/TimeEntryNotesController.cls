/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : TimeEntryNotesController
 * Author          : <YourName>
 * Created Date    : Feb 17, 2026
 * Last Modified By: <YourName>
 * Last Modified On: Feb 17, 2026
 * Description     : This class implements for......
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Feb 17, 2026  │ <YourName>   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */

public with sharing class TimeEntryNotesController {

    @AuraEnabled(cacheable=true)
    public static List<Time_Entry__c> getTimeEntries(Id timesheetId) {
        return [
            SELECT Id, Work_Date__c, Notes__c
            FROM Time_Entry__c
            WHERE Timesheet__c = :timesheetId
            ORDER BY Work_Date__c
        ];
    }

    @AuraEnabled
    public static void saveNotes(Id recordId, String notes) {
        System.debug('recordId: ' + recordId);
        System.debug('notes: ' + notes);
        Time_Entry__c entry = new Time_Entry__c(
            Id = recordId,
            Notes__c = notes
        );
        update entry;
    }
}