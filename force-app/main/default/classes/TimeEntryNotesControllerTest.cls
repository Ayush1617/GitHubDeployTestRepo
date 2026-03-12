@IsTest
private class TimeEntryNotesControllerTest {

    @TestSetup
    static void setupTestData() {

        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User testUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@example.com',
            Username = 'testuser' + System.currentTimeMillis() + '@example.com',
            Alias = 'tuser',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert testUser;

        System.runAs(testUser) {

            // ✅ Create Contact (Resource)
            Contact resource = new Contact(
                LastName = 'Test Resource'
            );
            insert resource;

            // ✅ Create Project
            Project__c project = new Project__c(
                Project_Name__c = 'Test Project'
            );
            insert project;

            // ✅ Create Timesheet
            Timesheet__c ts = new Timesheet__c(
                Status__c = 'Draft',
                Week_Start_Date__c = Date.today(),
                Week_End_Date__c = Date.today().addDays(4),
                Resource__c = resource.Id
            );
            insert ts;

            // ✅ Create Time Entry (ALL required fields populated)
            Time_Entry__c entry = new Time_Entry__c(
                Work_Date__c = Date.today(),
                Timesheet__c = ts.Id,
                Resource__c = resource.Id,   
                Project__c = project.Id     
            );
            insert entry;
        }
    }

    @IsTest
    static void testGetTimeEntries() {

        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

        System.runAs(u) {

            Timesheet__c ts = [SELECT Id FROM Timesheet__c LIMIT 1];

            Test.startTest();
            List<Time_Entry__c> result =
                TimeEntryNotesController.getTimeEntries(ts.Id);
            Test.stopTest();

            System.assertEquals(1, result.size());
        }
    }

    @IsTest
    static void testSaveNotes() {

        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

        System.runAs(u) {

            Time_Entry__c entry =
                [SELECT Id FROM Time_Entry__c LIMIT 1];

            Test.startTest();
            TimeEntryNotesController.saveNotes(entry.Id, 'Updated Notes');
            Test.stopTest();

            Time_Entry__c updated =
                [SELECT Notes__c FROM Time_Entry__c WHERE Id = :entry.Id];

            System.assertEquals('Updated Notes', updated.Notes__c);
        }
    }
}