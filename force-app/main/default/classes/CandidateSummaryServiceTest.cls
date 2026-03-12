@IsTest
public class CandidateSummaryServiceTest {

    /**
     * @description : Creates reusable test data once for all test methods
     */
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

        // Get Candidate RecordType dynamically
        Id candidateRtId = Schema.SObjectType.Contact
            .getRecordTypeInfosByDeveloperName()
            .get('Candidate')
            .getRecordTypeId();

        List<Contact> candidates = new List<Contact>();

        // Candidate with full data
        candidates.add(new Contact(
            LastName = 'Full Data Candidate',
            RecordTypeId = candidateRtId,
            Highest_Qualification__c = 'B.Tech',
            Designation__c = 'Salesforce Developer',
            Total_Experience__c = 6,
            Skills__c = 'Apex,LWC,SOQL',
            Soft_Skills__c = 'Communication,Leadership',
            Can_join_in__c = 30
        ));

        // Candidate with partial data (to test fallback logic)
        candidates.add(new Contact(
            LastName = 'Partial Candidate',
            RecordTypeId = candidateRtId
        ));

        insert candidates;
    }

    // ---------------------------------------------------
    // Test : Full data scenario
    // ---------------------------------------------------
    @IsTest
    static void testGenerateSummaryAllFields() {

        Contact c = [
            SELECT Id
            FROM Contact
            WHERE LastName = 'Full Data Candidate'
            LIMIT 1
        ];
		User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        Test.startTest();
        String result = CandidateSummaryService.generateSummary(c.Id);
        Test.stopTest();
		
        System.assertNotEquals(null, result);
        System.assert(result.contains('Salesforce Developer'));
        System.assert(result.contains('6+ years'));
        System.assert(result.contains('B.Tech'));
        System.assert(result.contains('Apex,LWC,SOQL'));
        System.assert(result.contains('Communication,Leadership'));
        System.assert(result.contains('30 days'));
    }
	}
    // ---------------------------------------------------
    // Test : Fallback logic scenario
    // ---------------------------------------------------
    @IsTest
    static void testGenerateSummaryFallback() {

        Contact c = [
            SELECT Id
            FROM Contact
            WHERE LastName = 'Partial Candidate'
            LIMIT 1
        ];
		User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        Test.startTest();
        String result = CandidateSummaryService.generateSummary(c.Id);
        Test.stopTest();
		
        System.assertNotEquals(null, result);

        // Should fallback to default role
        System.assert(result.contains('Professional'));
    }
	}

    // ---------------------------------------------------
    // Test : Null Id scenario
    // ---------------------------------------------------
    @IsTest
    static void testGenerateSummaryNullId() {
		User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        Test.startTest();
        String result = CandidateSummaryService.generateSummary(null);
        Test.stopTest();
		
        System.assertEquals('', result);
    }
	}
}