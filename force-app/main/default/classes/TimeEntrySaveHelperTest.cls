@IsTest
public class TimeEntrySaveHelperTest {

    @TestSetup
    static void setupData() {

        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];

        // Insert test user
        User u = new User(
            FirstName = 'Test',
            LastName = 'Owner',
            Alias = 'tuser',
            Email = 'testuser@example.com',
            Username = 'testuser' + System.currentTimeMillis() + '@example.com',
            CommunityNickname = 'testuser' + System.currentTimeMillis(),
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_IN',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert u;

        // Create Project
        Project__c project =
            Recruitment_TestDataFactory.createProject('Test Project');
        insert project;

        // Create Account
        Account acc = new Account(Name='Test Account');
        insert acc;

        // Create Resource
        Contact resource = new Contact(
            LastName = 'Resource User',
            AccountId = acc.Id
        );
        insert resource;

        Date today = Date.today();
        Date weekStart = today.toStartOfWeek().addDays(1);
        Date weekEnd = weekStart.addDays(6);

        // Create Timesheet
        Timesheet__c ts = Recruitment_TestDataFactory.createTimesheet('test');
        ts.Project__c = project.Id;
        ts.Resource__c = resource.Id;
        ts.Status__c = 'Draft';
        ts.Week_Start_Date__c = weekStart;
        ts.Week_End_Date__c = weekEnd;
        insert ts;

        // Create Task Type
        Task_Type__c taskType = new Task_Type__c(
            Name = 'Development',
            Billable_Non_Billable__c = true
        );
        insert taskType;
    }

    /**
     * Test saving time entries
     */
    @IsTest
    static void testSaveEntries(){

        Timesheet__c ts = [SELECT Id FROM Timesheet__c LIMIT 1];
        Task_Type__c tt = [SELECT Id FROM Task_Type__c LIMIT 1];

        BillableNonBillableTaskTypeController.TimeEntryWrapper w =
            new BillableNonBillableTaskTypeController.TimeEntryWrapper();

        w.taskTypeId = tt.Id;
        w.workDate = Date.today();
        w.hours = 8;
        w.note = 'Worked on feature';

        List<BillableNonBillableTaskTypeController.TimeEntryWrapper> wrapperList =
            new List<BillableNonBillableTaskTypeController.TimeEntryWrapper>{ w };

        String jsonInput = JSON.serialize(wrapperList);

        Test.startTest();

        TimeEntrySaveHelper.saveEntries(ts.Id, jsonInput, 'Draft');

        Test.stopTest();

        List<Time_Entry__c> entries =
            [SELECT Id, Task_Type__c, Hours__c
             FROM Time_Entry__c
             WHERE Timesheet__c = :ts.Id];

        System.assertEquals(1, entries.size());
        System.assertEquals(8, entries[0].Hours__c);
    }

    /**
     * Test blank JSON input
     */
    @IsTest
    static void testBlankEntries(){

        Timesheet__c ts = [SELECT Id FROM Timesheet__c LIMIT 1];

        Test.startTest();

        TimeEntrySaveHelper.saveEntries(ts.Id, '', 'Draft');

        Test.stopTest();

        System.assert(true, 'Blank entries should safely exit');
    }

    /**
     * Test timesheet validation when submitted
     */
    @IsTest
    static void testSubmittedTimesheetValidation(){

        Timesheet__c ts = [SELECT Id, Status__c FROM Timesheet__c LIMIT 1];

        ts.Status__c = 'Submitted';
        update ts;

        Boolean exceptionThrown = false;

        try {

            TimeEntrySaveHelper.saveEntries(ts.Id, '', 'Draft');

        } catch (AuraHandledException e) {

            exceptionThrown = true;
        }

        System.assert(exceptionThrown,
            'Exception should be thrown for submitted timesheet');
    }

    /**
     * Test null timesheet validation
     */
    @IsTest
    static void testNullTimesheetId(){

        Boolean exceptionThrown = false;

        try {

            TimeEntrySaveHelper.saveEntries(null, '', 'Draft');

        } catch (AuraHandledException e) {

            exceptionThrown = true;
        }

        System.assert(exceptionThrown,
            'Exception should be thrown when timesheetId is null');
    }

	@IsTest
    static void testSaveEntriesWithInvalidTaskType(){
    
        Timesheet__c ts = [SELECT Id FROM Timesheet__c LIMIT 1];
    
        // wrapper with NULL taskTypeId so buildTimeEntries returns empty list
        BillableNonBillableTaskTypeController.TimeEntryWrapper w =
            new BillableNonBillableTaskTypeController.TimeEntryWrapper();
    
        w.taskTypeId = null;
        w.workDate = Date.today();
        w.hours = 5;
        w.note = 'Invalid task';
    
        List<BillableNonBillableTaskTypeController.TimeEntryWrapper> wrapperList =
            new List<BillableNonBillableTaskTypeController.TimeEntryWrapper>{ w };
    
        String jsonInput = JSON.serialize(wrapperList);
    
        Test.startTest();
    
        TimeEntrySaveHelper.saveEntries(ts.Id, jsonInput, 'Draft');
    
        Test.stopTest();
    
        // Since taskTypeId is null, no records should be inserted
        List<Time_Entry__c> entries =
            [SELECT Id FROM Time_Entry__c WHERE Timesheet__c = :ts.Id];
    
        System.assertEquals(0, entries.size(),
            'No time entries should be inserted when taskTypeId is null');
    }
}