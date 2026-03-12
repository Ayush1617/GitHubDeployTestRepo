/**
 * Controller class for Candidate Timesheet operations.
 * Handles project retrieval, timesheet creation and validation.
 * Used by LWC component for candidate timesheet entry.
 */
public with sharing class TimesheetCandidateController {    
    // Get projects for logged in candidate via WorkOrder junction
    @AuraEnabled(cacheable=true)
    /**
 * Retrieves projects assigned to the logged-in candidate.
 * Projects are fetched through the Work Order junction object.
 *
 * @return List<Project__c> List of projects assigned to the candidate
 */
    public static List<Project__c> getProjectsForCandidate() {
        try {
            // Get the logged in user's contact
            User currentUser = [SELECT Id, ContactId, Contact.Email, Contact.AccountId 
                               FROM User WHERE Id = :UserInfo.getUserId()
                               WITH SYSTEM_MODE];
            
            if (currentUser.ContactId == null) {
                throw new AuraHandledException('No contact associated with current user');
            }
            
            // Verify contact has Candidate record type
            List<Contact> candidateContacts = [SELECT Id, Name, Email 
                                              FROM Contact 
                                              WHERE Id = :currentUser.ContactId 
                                              AND RecordType.DeveloperName = 'Candidate'
                                              WITH SYSTEM_MODE
                                              LIMIT 1];
            
            if (candidateContacts.isEmpty()) {
                throw new AuraHandledException('Current user is not associated with a Candidate contact');
            }
            
            Contact candidate = candidateContacts[0];
            
            // Get projects through WorkOrder junction object
            List<Project__c> projects = [SELECT Id, Name ,Project_Name__c, Start_Date__c, End_Date__c 
                                        FROM Project__c 
                                        WHERE Id IN (SELECT Project__c
                                                   FROM Work_Order__c 
                                            WHERE Candidate_Name__c = :candidate.Id)
                                            WITH SYSTEM_MODE
                                        ORDER BY Project_Name__c];
            
            return projects;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching projects: ' + e.getMessage());
        }
    }
    
    // Get current candidate contact ID
    /**
 * Returns the Contact Id of the currently logged-in candidate user.
 *
 * @return String Candidate Contact Id
 */
    @AuraEnabled
    public static String getCurrentCandidateId() {
        try {
            User currentUser = [SELECT Id, ContactId 
                               FROM User  WHERE Id = :UserInfo.getUserId()
                               WITH SYSTEM_MODE];
            
            if (currentUser.ContactId == null) {
                throw new AuraHandledException('No contact associated with current user');
            }
            
            // Verify contact has Candidate record type
            List<Contact> candidateContacts = [SELECT Id FROM Contact 
                                              WHERE Id = :currentUser.ContactId 
                                              AND RecordType.DeveloperName = 'Candidate'
                                              WITH SYSTEM_MODE
                                              LIMIT 1];
            
            if (candidateContacts.isEmpty()) {
                throw new AuraHandledException('Current user is not associated with a Candidate contact');
            }
            
            return candidateContacts[0].Id;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error getting candidate: ' + e.getMessage());
        }
    }
    
    // Create timesheet
    /**
 * Creates a new Timesheet record for the selected project and week.
 *
 * @param projectId Id of the selected project
 * @param weekStartDate Start date of the week for the timesheet
 * @return Timesheet__c Newly created timesheet record
 */
    @AuraEnabled
public static Timesheet__c createTimesheet(String projectId, String weekStartDate) {

    Savepoint sp = Database.setSavepoint();

    try {

        String candidateId = getCandidateId();

        String workOrderId = getWorkOrderId(projectId, candidateId);

        Date startDate = Date.valueOf(weekStartDate);
        Date endDate = startDate.addDays(6);

        validateExistingTimesheet(projectId, candidateId, startDate);

        Timesheet__c newTimesheet = new Timesheet__c(
            Project__c = projectId,
            Resource__c = candidateId,
            Work_Order__c = workOrderId,
            Week_Start_Date__c = startDate,
            Week_End_Date__c = endDate,
            Status__c = 'Draft'
        );

        insertTimesheet(newTimesheet);

        return newTimesheet;

    } catch (CustomException ce) {

        Database.rollback(sp);
        throw new AuraHandledException(ce.getMessage());

    } catch (Exception e) {

        Database.rollback(sp);
        throw new AuraHandledException('Error creating timesheet: ' + e.getMessage());
    }
}
private static String getCandidateId() {

    User currentUser = [
        SELECT Id, ContactId
        FROM User
        WHERE Id = :UserInfo.getUserId()
        WITH SYSTEM_MODE
    ];

    List<Contact> candidateContacts = [
        SELECT Id
        FROM Contact
        WHERE Id = :currentUser.ContactId
        AND RecordType.DeveloperName = 'Candidate'
        WITH USER_MODE
        LIMIT 1
    ];

    if (candidateContacts.isEmpty()) {
        throw new CustomException('No candidate contact found for current user');
    }

    return candidateContacts[0].Id;
}
private static String getWorkOrderId(String projectId, String candidateId) {

    List<Work_Order__c> workOrders = [
        SELECT Id
        FROM Work_Order__c
        WHERE Project__c = :projectId
        AND Candidate_Name__c = :candidateId
        WITH SYSTEM_MODE
        LIMIT 1
    ];

    if (workOrders.isEmpty()) {
        throw new CustomException('No work order found for this project and candidate');
    }

    return workOrders[0].Id;
}
private static void validateExistingTimesheet(String projectId, String candidateId, Date startDate) {

    List<Timesheet__c> existingTimesheets = [
        SELECT Id
        FROM Timesheet__c
        WHERE Project__c = :projectId
        AND Resource__c = :candidateId
        AND Week_Start_Date__c = :startDate
        WITH USER_MODE
        LIMIT 1
    ];

    if (!existingTimesheets.isEmpty()) {
        throw new CustomException('A timesheet already exists for this week');
    }
}
private static void insertTimesheet(Timesheet__c newTimesheet) {

    if (Schema.sObjectType.Timesheet__c.isCreateable()) {
        insert newTimesheet;
    } else {
        throw new AuraHandledException('You do not have permission to create Timesheets');
    }
}
    
    // Get week start date (Monday) for current week
    /**
 * Returns the start date (Monday) of the current week.
 *
 * @return Date Monday of the current week
 */
    @AuraEnabled
    public static Date getCurrentWeekStartDate() {
        Date today = Date.today();
        // toStartOfWeek returns Sunday, so add 1 for Monday
        Date sunday = today.toStartofWeek();
        return sunday.addDays(1); // This gives Monday
    }
    
    // Check if timesheet already exists for the week
    /**
 * Checks if a timesheet already exists for the candidate for the given week.
 *
 * @param projectId Id of the selected project
 * @param weekStartDate Week start date to check
 * @return Timesheet__c Existing timesheet if found, otherwise null
 */
@AuraEnabled
public static Timesheet__c checkExistingTimesheet(String projectId, String weekStartDate) {
    try {
        // Get current candidate contact ID
        User currentUser = [SELECT Id, ContactId 
                           FROM User WHERE Id = :UserInfo.getUserId()
                           WITH SYSTEM_MODE];
        
        List<Contact> candidateContacts = [SELECT Id FROM Contact 
                                          WHERE Id = :currentUser.ContactId 
                                          AND RecordType.DeveloperName = 'Candidate'
                                          WITH USER_MODE
                                          LIMIT 1];
        
        if (candidateContacts.isEmpty()) {
            return null;
        }
        
        String candidateId = candidateContacts[0].Id;
        Date startDate = Date.valueOf(weekStartDate);
        
        // Check if timesheet already exists for this week
        List<Timesheet__c> existingTimesheets = [SELECT Id, Name, Status__c 
                                                FROM Timesheet__c 
                                                WHERE Project__c = :projectId 
                                                AND Resource__c = :candidateId
                                                AND Week_Start_Date__c = :startDate
                                                LIMIT 1];
        
        if (!existingTimesheets.isEmpty()) {
            return existingTimesheets[0];
        }
        
        return null;
        
    } catch (Exception e) {
        throw new AuraHandledException('Error checking existing timesheet');
        
    }
}
    
    // Custom exception class
    /**
 * Custom exception used for handling business logic errors
 * in the TimesheetCandidateController.
 */
    public class CustomException extends Exception {}
}