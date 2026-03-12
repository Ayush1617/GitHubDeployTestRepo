@IsTest
private class ExtendWorkOrderControllerTest {

    private static User createAdminUser() {

        Profile p = [
            SELECT Id
            FROM Profile
            WHERE Name = 'System Administrator'
            LIMIT 1
        ];

        User u = new User(
            Alias = 'tadmin',
            Email = 'testadmin@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Admin',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/New_York',
            UserName = 'testadmin' + System.currentTimeMillis() + '@test.com'
        );

        insert u;
        return u;
    }

    @TestSetup
    static void setupData() {

        Account acc = new Account(Name = 'Test Account');
        insert acc;

        String candidateRT =
            Schema.getGlobalDescribe().get('Contact')
                .getDescribe()
                .getRecordTypeInfosByName()
                .get('Candidate')
                .getRecordTypeId();

        Contact candidate = new Contact(
            FirstName = 'Test',
            LastName = 'Candidate',
            RecordTypeId = candidateRT,
            AccountId = acc.Id
        );
        insert candidate;

        String recruiterRT =
            Schema.getGlobalDescribe().get('Contact')
                .getDescribe()
                .getRecordTypeInfosByName()
                .get('Recruiter')
                .getRecordTypeId();

        Contact recruiter = new Contact(
            FirstName = 'Test',
            LastName = 'Recruiter',
            RecordTypeId = recruiterRT,
            AccountId = acc.Id
        );
        insert recruiter;

        Project__c proj = new Project__c(
            Project_Name__c = 'Test Project',
            Active__c = true
        );
        insert proj;

        Work_Order__c wo = new Work_Order__c(
            Status__c = 'Working',
            Project__c = proj.Id,
            Candidate_Name__c = candidate.Id,
            Recruiter_Name__c = recruiter.Id,
            Role_on_Project__c = 'Developer',
            Renewed__c = false,
            Salary_Offered__c = 50000
        );
        insert wo;
    }

    // ------------------------------------------------
    // Test getAllFieldsValue
    // ------------------------------------------------
    @IsTest
    static void testGetAllFieldsValue() {

        User adminUser = createAdminUser();

        System.runAs(adminUser) {

            Work_Order__c wo =
                [SELECT Id FROM Work_Order__c LIMIT 1];

            Test.startTest();
            Work_Order__c result =
                ExtendWorkOrderController.getAllFieldsValue(wo.Id);
            Test.stopTest();

            System.assertNotEquals(null, result);
            System.assertEquals('Working', result.Status__c);
        }
    }

    // ------------------------------------------------
    // Test createWorkOrder
    // ------------------------------------------------
@IsTest
static void testCreateWorkOrder() {

    User adminUser = createAdminUser();

    System.runAs(adminUser) {

        Work_Order__c parentWO = [
            SELECT Id, Project__c,
                   Candidate_Name__c,
                   Recruiter_Name__c
            FROM Work_Order__c
            LIMIT 1
        ];

        Map<String, Object> inputMap = new Map<String, Object>{
            'Parent_Work_OrderId__c' => parentWO.Id,
            'Project__c' => parentWO.Project__c,
            'Role_on_Project__c' => 'Senior Developer',
            'Candidate_Name__c' => parentWO.Candidate_Name__c,
            'Recruiter_Name__c' => parentWO.Recruiter_Name__c,
            'Start_Date__c' => String.valueOf(Date.today()),
            'End_Date__c' => String.valueOf(Date.today().addMonths(6)),
            'Status__c' => 'Working',
                'Renewed__c' => false,
            'Salary_Offered__c' => '65000'
        };

        String jsonInput = JSON.serialize(inputMap);

        Test.startTest();
        Id newId =
            ExtendWorkOrderController.createWorkOrder(jsonInput);
        Test.stopTest();

        System.assertNotEquals(null, newId);

        Work_Order__c newWO = [
            SELECT Parent_Work_OrderId__c,
                   Role_on_Project__c,
                   Salary_Offered__c,
                   Renewed__c
            FROM Work_Order__c
            WHERE Id = :newId
        ];

        System.assertEquals(parentWO.Id,
            newWO.Parent_Work_OrderId__c);

        System.assertEquals('Senior Developer',
            newWO.Role_on_Project__c);

        System.assertEquals(65000,
            newWO.Salary_Offered__c);
        
        System.assertEquals(false,
            newWO.Renewed__c);

    }
}


    // ------------------------------------------------
    // Exception Scenario - getAllFieldsValue
    // ------------------------------------------------
    @IsTest
    static void testGetAllFieldsValueException() {

        User adminUser = createAdminUser();

        System.runAs(adminUser) {

            Account acc = new Account(Name = 'Temp');
            insert acc;

            Test.startTest();
            try {
                ExtendWorkOrderController.getAllFieldsValue(acc.Id);
                System.assert(false,
                    'Expected AuraHandledException not thrown');
            } catch (AuraHandledException ex) {
                System.assertNotEquals(null, ex.getMessage());
            }
            Test.stopTest();
        }
    }

    // ------------------------------------------------
    // Exception Scenario - createWorkOrder
    // ------------------------------------------------
    @IsTest
    static void testCreateWorkOrderException() {

        User adminUser = createAdminUser();

        System.runAs(adminUser) {

            String badJsonInput = 'INVALID_JSON';

            Test.startTest();
            try {
                ExtendWorkOrderController.createWorkOrder(badJsonInput);
                System.assert(false,
                    'Expected AuraHandledException not thrown');
            } catch (AuraHandledException ex) {
                System.assertNotEquals(null, ex.getMessage()); 
            }
            Test.stopTest();
        }
    }
}