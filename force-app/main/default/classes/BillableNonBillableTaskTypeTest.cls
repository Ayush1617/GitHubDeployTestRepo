/*
#####################################################
# @Created By (Date)   : Kshitiz (12 Mar, 2026)
# @Description         : Apex Test Class for BillableNonBillableTaskTypeController
#                       - Validates retrieval of Task Types for a Project.
# @Modifications Log   :
# Ver    Date              Author                 Modification
# 1.0    12 March, 2026    Kshitiz                Initial Version
#####################################################
*/
@IsTest
public class BillableNonBillableTaskTypeTest {

    /*
     * @description : @testSetup method used to create reusable test data
     *                shared across all test methods.
     **/
    @TestSetup
    static void setupData() {

        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];

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

        // Project
        Project__c project =
            Recruitment_TestDataFactory.createProject('Test Project');
        insert project;

        // Account + Resource
        Account acc = new Account(Name='Test Account');
        insert acc;

        Contact resource = new Contact(
            LastName = 'Resource User',
            AccountId = acc.Id
        );
        insert resource;

        Date today = Date.today();
        Date weekStart = today.toStartOfWeek().addDays(1);
        Date weekEnd = weekStart.addDays(6);

        // Timesheet
        Timesheet__c ts = Recruitment_TestDataFactory.createTimesheet('test');
        ts.Project__c = project.Id;
        ts.Resource__c = resource.Id;
        ts.Status__c = 'Draft';
        ts.Week_Start_Date__c = weekStart;
        ts.Week_End_Date__c = weekEnd;
        insert ts;

        // Task Type
        Task_Type__c taskType = new Task_Type__c(
            Name = 'Development',
            Task_Type_Project__c = project.Id,
            Billable_Non_Billable__c = true,
            Billing_rate_per_hour__c = 100
        );
        insert taskType;

        // Existing Time Entries
        List<Time_Entry__c> entries = new List<Time_Entry__c>();

        for(Integer i = 0; i < 3; i++){

            Time_Entry__c te = new Time_Entry__c(
                Timesheet__c = ts.Id,
                Task_Type__c = taskType.Id,
                Hours__c = 4,
                Resource__c = resource.Id,
                Project__c = project.Id,
                Work_Date__c = weekStart.addDays(i)
            );

            entries.add(te);
        }

        insert entries;
    }


    /**
      * @description : Tests retrieval of Task Types associated
 	  *                with a given Project Id.
     */
    @IsTest
    static void testGetTaskTypes(){

        Project__c project = [SELECT Id FROM Project__c LIMIT 1];
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        Test.startTest();

        List<Task_Type__c> taskTypes =
            BillableNonBillableTaskTypeController.getTaskTypes(project.Id);

        Test.stopTest();

        System.assert(!taskTypes.isEmpty(), 'Task types should be returned');
    }
    }

    /**
      * @description : Tests retrieval of existing Time Entry records
 	  *                for a Timesheet along with Timesheet status.
      */
    @IsTest
    static void testGetTimeEntries(){

        Timesheet__c ts = [SELECT Id FROM Timesheet__c LIMIT 1];
		User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        Test.startTest();

        BillableNonBillableTaskTypeController.TimeEntryResponse response =
            BillableNonBillableTaskTypeController.getTimeEntries(ts.Id);

        Test.stopTest();

        System.assertEquals('Draft', response.timesheetStatus);
        System.assert(response.entries.size() > 0);
    }
    }

    /**
      * @description : Tests saving new Time Entry records through
 	  *                the controller using JSON wrapper input.
      **/
    @IsTest
    static void testSaveTimeEntries(){

        Timesheet__c ts = [SELECT Id FROM Timesheet__c LIMIT 1];
        Task_Type__c tt = [SELECT Id FROM Task_Type__c LIMIT 1];

        BillableNonBillableTaskTypeController.TimeEntryWrapper wrapper =
            new BillableNonBillableTaskTypeController.TimeEntryWrapper();

        wrapper.taskTypeId = tt.Id;
        wrapper.workDate = Date.today();
        wrapper.hours = 6;
        wrapper.note = 'Worked on module';

        List<BillableNonBillableTaskTypeController.TimeEntryWrapper> listWrap =
            new List<BillableNonBillableTaskTypeController.TimeEntryWrapper>{wrapper};

        String jsonInput = JSON.serialize(listWrap);
		User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        Test.startTest();

        BillableNonBillableTaskTypeController.saveTimeEntries(
            ts.Id,
            jsonInput,
            'Draft'
        );

        Test.stopTest();

        List<Time_Entry__c> entries =
            [SELECT Id FROM Time_Entry__c WHERE Timesheet__c = :ts.Id];

        System.assert(entries.size() > 0);
    }
    }

    /**
     * @description : Tests updating existing Time Entry records.
     */
    @IsTest
    static void testUpdateTimeEntries(){

        Time_Entry__c entry =
            [SELECT Id, Hours__c, Timesheet__c FROM Time_Entry__c LIMIT 1];

        entry.Hours__c = 7;
		User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        Test.startTest();

        BillableNonBillableTaskTypeController.updateTimeEntries(
            new List<Time_Entry__c>{entry}
        );

        Test.stopTest();

        Time_Entry__c updated =
            [SELECT Hours__c FROM Time_Entry__c WHERE Id = :entry.Id];

        System.assertEquals(7, updated.Hours__c);
    }
    }

    /**
     * @description : Tests successful update of Timesheet status.
     */
    @IsTest
    static void testUpdateTimesheet(){

        Timesheet__c ts = [SELECT Id, Status__c FROM Timesheet__c LIMIT 1];

        ts.Status__c = 'Submitted';
		User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        Test.startTest();

        BillableNonBillableTaskTypeController.updateTimesheet(ts);

        Test.stopTest();

        Timesheet__c updated =
            [SELECT Status__c FROM Timesheet__c WHERE Id = :ts.Id];

        System.assertEquals('Submitted', updated.Status__c);
    }
    }

    /**
      * @description : Tests validation scenario where a Submitted
 	  *                Timesheet is attempted to be reverted back
 	  *                to Draft status.
      */
    @IsTest
    static void testUpdateTimesheetException(){

        Timesheet__c ts = [SELECT Id, Status__c FROM Timesheet__c LIMIT 1];

        ts.Status__c = 'Submitted';
        update ts;

        Boolean exceptionThrown = false;

        try{

            ts.Status__c = 'Draft';
			User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
       		System.runAs(u) {
            Test.startTest();
            BillableNonBillableTaskTypeController.updateTimesheet(ts);
            Test.stopTest();
            }

        }catch(AuraHandledException e){
            exceptionThrown = true;
        }

        System.assert(exceptionThrown,
            'Exception should be thrown when downgrading Submitted timesheet');
    }
	
}