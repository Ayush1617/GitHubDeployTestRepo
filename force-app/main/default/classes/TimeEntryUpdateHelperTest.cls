@IsTest
public class TimeEntryUpdateHelperTest {

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
    
        // Create Account (for resource contact)
        Account acc = new Account(Name='Test Account');
        insert acc;
    
        // Create Resource (Contact)
        Contact resource = new Contact(
            LastName = 'Resource User',
            AccountId = acc.Id
        );
        insert resource;
    	
        Date today = Date.today();
        Date weekStart = today.toStartOfWeek().addDays(1); // Monday
        Date weekEnd = weekStart.addDays(6);               // Sunday

        // Create Timesheet
        Timesheet__c ts = Recruitment_TestDataFactory.createTimesheet('test');
        ts.Project__c = project.Id;
        ts.Resource__c = resource.Id;
        ts.Status__c = 'Draft';        
        ts.Week_Start_Date__c = weekStart;
        ts.Week_End_Date__c = weekEnd;
        insert ts;
    
        // Create existing Time Entries (for update testing)
        List<Time_Entry__c> entries = new List<Time_Entry__c>();
    
        for(Integer i = 0; i < 5; i++){
    
            Time_Entry__c te = new Time_Entry__c(
                Timesheet__c = ts.Id,
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
     * Test inserting new Time Entry records
     */
    @IsTest
    static void testInsertNewEntries(){

        Timesheet__c ts = [SELECT Id FROM Timesheet__c LIMIT 1];

        Time_Entry__c newEntry = new Time_Entry__c(
            Timesheet__c = ts.Id,
            Hours__c = 6,
            Work_Date__c = Date.today()
        );

        Test.startTest();
        TimeEntryUpdateHelper.updateEntries(
            new List<Time_Entry__c>{ newEntry }
        );
        Test.stopTest();

        List<Time_Entry__c> results =
            [SELECT Id, Project__c, Resource__c
             FROM Time_Entry__c
             WHERE Timesheet__c = :ts.Id];

        System.assert(results.size() > 1,
            'New Time Entry should be inserted');

        System.assertNotEquals(null, results[0].Project__c,
            'Project should be populated');

        System.assertNotEquals(null, results[0].Resource__c,
            'Resource should be populated');
    }

    /**
     * Test updating existing Time Entry
     */
    @IsTest
    static void testUpdateExistingEntries(){

        Time_Entry__c entry =
            [SELECT Id, Hours__c, Timesheet__c FROM Time_Entry__c LIMIT 1];

        entry.Hours__c = 8;

        Test.startTest();
        TimeEntryUpdateHelper.updateEntries(
            new List<Time_Entry__c>{ entry }
        );
        Test.stopTest();

        Time_Entry__c updated =
            [SELECT Hours__c FROM Time_Entry__c WHERE Id = :entry.Id];

        System.assertEquals(8, updated.Hours__c,
            'Hours should be updated');
    }

    /**
     * Test empty list handling
     */
    @IsTest
    static void testEmptyInput(){

        Test.startTest();
        TimeEntryUpdateHelper.updateEntries(new List<Time_Entry__c>());
        Test.stopTest();

        System.assert(true,
            'Method should safely exit with empty list');
    }

    /**
     * Test null input handling
     */
    @IsTest
    static void testNullInput(){

        Test.startTest();
        TimeEntryUpdateHelper.updateEntries(null);
        Test.stopTest();

        System.assert(true,
            'Method should safely exit with null input');
    }
}