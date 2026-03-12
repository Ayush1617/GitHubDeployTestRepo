/**
 * @description
 * Test class for SkillQuickActionController
 * Covers Candidate and Job Position skill fetch and update scenarios
 */
@IsTest
public class SkillQuickActionControllerTest {

    /* ================= TEST SETUP ================= */

    @TestSetup
    static void setupTestData() {

        Contact cand1 = Recruitment_TestDataFactory.createCandidate( 
            'John Doe',
            'johndoe@email.com'
        );
        cand1.Phone = '1111111111';
        cand1.Skills__c = 'Salesforce, Apex, LWC';
        cand1.Soft_Skills__c = 'Communication, Teamwork';
        insert cand1;

        Contact cand2 = Recruitment_TestDataFactory.createCandidate(
            'Jane Smith',
            'jane.smith@test.com'
        );
        cand2.Phone = '2222222222';
        cand2.Skills__c = 'Java, SQL, Salesforce';
        cand2.Soft_Skills__c = 'Problem Solving, Adaptability';
        insert cand2;

        Account client = Recruitment_TestDataFactory.createClient(
            'Test Client',
            'client@email.com'
        );
        insert client;

        Job_Position__c jp = Recruitment_TestDataFactory.createFlexJobPosition();
        jp.Client_Name__c = client.Id;
        jp.Skills_Required__c = 'Salesforce, JavaScript';
        jp.Soft_Skills__c = 'Leadership, Problem Solving';
        insert jp;
    }

    /* ================= POSITIVE TESTS ================= */

    @IsTest
static void testGetCandidateSkillsCandidate() {

    // Create a test user
    Profile p = [
        SELECT Id
        FROM Profile
        WHERE Name = 'System Administrator'
        LIMIT 1
    ];

    User testUser = new User(
        Alias = 'tuser',
        Email = 'testuser@test.com',
        EmailEncodingKey = 'UTF-8',
        LastName = 'User',
        LanguageLocaleKey = 'en_US',
        LocaleSidKey = 'en_US',
        ProfileId = p.Id,
        TimeZoneSidKey = 'Asia/Kolkata',
        UserName = 'testuser' + System.currentTimeMillis() + '@test.com'
    );

    insert testUser;

    System.runAs(testUser) {

        Contact cand = [
            SELECT Id
            FROM Contact
            WHERE Name = 'John Doe'
            LIMIT 1
        ];

        Test.startTest();
        Map<String, List<String>> result =
            SkillQuickActionController.getCandidateSkills(cand.Id, 'Candidate');
        Test.stopTest();

        System.assertEquals(3, result.get('skills').size(),
            'Expected 3 technical skills');
        System.assertEquals(2, result.get('softSkills').size(),
            'Expected 2 soft skills');
    }
}


   @IsTest
static void testGetCandidateSkillsJobPosition() {

    // Create a test user
    Profile p = [
        SELECT Id
        FROM Profile
        WHERE Name = 'System Administrator'
        LIMIT 1
    ];

    User testUser = new User(
        Alias = 'tuser2',
        Email = 'testuser2@test.com',
        EmailEncodingKey = 'UTF-8',
        LastName = 'User',
        LanguageLocaleKey = 'en_US',
        LocaleSidKey = 'en_US',
        ProfileId = p.Id,
        TimeZoneSidKey = 'Asia/Kolkata',
        UserName = 'testuser2' + System.currentTimeMillis() + '@test.com'
    );

    insert testUser;

    System.runAs(testUser) {

        Job_Position__c jp = [
            SELECT Id
            FROM Job_Position__c
            LIMIT 1
        ];

        Test.startTest();
        Map<String, List<String>> result =
            SkillQuickActionController.getCandidateSkills(jp.Id, 'Job Position');
        Test.stopTest();

        System.assertEquals(
            2,
            result.get('skills').size(),
            'Expected 2 technical skills'
        );
        System.assertEquals(
            2,
            result.get('softSkills').size(),
            'Expected 2 soft skills'
        );
    }
}

    @IsTest
static void testUpdateSkillsCandidate() {

    // Create a test user
    Profile p = [
        SELECT Id
        FROM Profile
        WHERE Name = 'System Administrator'
        LIMIT 1
    ];

    User testUser = new User(
        Alias = 'tuser3',
        Email = 'testuser3@test.com',
        EmailEncodingKey = 'UTF-8',
        LastName = 'User',
        LanguageLocaleKey = 'en_US',
        LocaleSidKey = 'en_US',
        ProfileId = p.Id,
        TimeZoneSidKey = 'Asia/Kolkata',
        UserName = 'testuser3' + System.currentTimeMillis() + '@test.com'
    );

    insert testUser;

    System.runAs(testUser) {

        Contact cand = [
            SELECT Id
            FROM Contact
            WHERE Name = 'John Doe'
            LIMIT 1
        ];

        SkillQuickActionController.SkillUpdateWrapper req =
            new SkillQuickActionController.SkillUpdateWrapper();
        req.recordId = cand.Id;
        req.objName = 'Contact';
        req.skills = new List<String>{ 'Python', 'SOQL' };
        req.softSkills = new List<String>{ 'Adaptability' };

        Test.startTest();
        SkillQuickActionController.updateCandidateSkills(req);
        Test.stopTest();

        Contact updated = [
            SELECT Skills__c, Soft_Skills__c
            FROM Contact
            WHERE Id = :cand.Id
        ];

        System.assertEquals(
            'Python, SOQL',
            updated.Skills__c,
            'Skills should be updated correctly'
        );
        System.assertEquals(
            'Adaptability',
            updated.Soft_Skills__c,
            'Soft skills should be updated correctly'
        );
    }
}

    @IsTest
static void testUpdateSkillsJobPosition() {

    // Create test user
    Profile p = [
        SELECT Id
        FROM Profile
        WHERE Name = 'System Administrator'
        LIMIT 1
    ];

    User testUser = new User(
        Alias = 'tuser4',
        Email = 'testuser4@test.com',
        EmailEncodingKey = 'UTF-8',
        LastName = 'User',
        LanguageLocaleKey = 'en_US',
        LocaleSidKey = 'en_US',
        ProfileId = p.Id,
        TimeZoneSidKey = 'Asia/Kolkata',
        UserName = 'testuser4' + System.currentTimeMillis() + '@test.com'
    );

    insert testUser;

    System.runAs(testUser) {

        Job_Position__c jp = [
            SELECT Id
            FROM Job_Position__c
            LIMIT 1
        ];

        SkillQuickActionController.SkillUpdateWrapper req =
            new SkillQuickActionController.SkillUpdateWrapper();
        req.recordId = jp.Id;
        req.objName = 'Job Position';
        req.skills = new List<String>{ 'FSL', 'CPQ' };
        req.softSkills = new List<String>{ 'Creativity' };

        Test.startTest();
        SkillQuickActionController.updateCandidateSkills(req);
        Test.stopTest();

        Job_Position__c updated = [
            SELECT Skills_Required__c, Soft_Skills__c
            FROM Job_Position__c
            WHERE Id = :jp.Id
        ];

        System.assertEquals(
            'FSL, CPQ',
            updated.Skills_Required__c,
            'Skills should be updated correctly'
        );
        System.assertEquals(
            'Creativity',
            updated.Soft_Skills__c,
            'Soft skills should be updated correctly'
        );
    }
}


    /* ================= NEGATIVE & EDGE TESTS ================= */

    @IsTest
static void testGetCandidateSkillsNullId() {

    // Create test user
    Profile p = [
        SELECT Id
        FROM Profile
        WHERE Name = 'System Administrator'
        LIMIT 1
    ];

    User testUser = new User(
        Alias = 'tuser5',
        Email = 'testuser5@test.com',
        EmailEncodingKey = 'UTF-8',
        LastName = 'User',
        LanguageLocaleKey = 'en_US',
        LocaleSidKey = 'en_US',
        ProfileId = p.Id,
        TimeZoneSidKey = 'Asia/Kolkata',
        UserName = 'testuser5' + System.currentTimeMillis() + '@test.com'
    );

    insert testUser;

    System.runAs(testUser) {

        Boolean didThrow = false;

        try {
            SkillQuickActionController.getCandidateSkills(null, 'Candidate');
        } catch (AuraHandledException e) {
            didThrow = true;
        }

        System.assert(
            didThrow,
            'Method should throw AuraHandledException when recordId is null'
        );
    }
}

    @IsTest
static void testUpdateSkillsInvalidObject() {

    // Create test user
    Profile p = [
        SELECT Id
        FROM Profile
        WHERE Name = 'System Administrator'
        LIMIT 1
    ];

    User testUser = new User(
        Alias = 'tuser6',
        Email = 'testuser6@test.com',
        EmailEncodingKey = 'UTF-8',
        LastName = 'User',
        LanguageLocaleKey = 'en_US',
        LocaleSidKey = 'en_US',
        ProfileId = p.Id,
        TimeZoneSidKey = 'Asia/Kolkata',
        UserName = 'testuser6' + System.currentTimeMillis() + '@test.com'
    );

    insert testUser;

    System.runAs(testUser) {

        Contact cand = [
            SELECT Id
            FROM Contact
            WHERE Name = 'Jane Smith'
            LIMIT 1
        ];

        SkillQuickActionController.SkillUpdateWrapper req =
            new SkillQuickActionController.SkillUpdateWrapper();
        req.recordId = cand.Id;
        req.objName = 'InvalidObject';

        Boolean didThrow = false;

        try {
            SkillQuickActionController.updateCandidateSkills(req);
        } catch (AuraHandledException e) {
            didThrow = true;
        }

        System.assert(
            didThrow,
            'Expected AuraHandledException for invalid object name'
        );
    }
}

 @IsTest
static void testUpdateSkillsEmptyLists() {

    // Create test user
    Profile p = [
        SELECT Id
        FROM Profile
        WHERE Name = 'System Administrator'
        LIMIT 1
    ];

    User testUser = new User(
        Alias = 'tuser7',
        Email = 'testuser7@test.com',
        EmailEncodingKey = 'UTF-8',
        LastName = 'User',
        LanguageLocaleKey = 'en_US',
        LocaleSidKey = 'en_US',
        ProfileId = p.Id,
        TimeZoneSidKey = 'Asia/Kolkata',
        UserName = 'testuser7' + System.currentTimeMillis() + '@test.com'
    );

    insert testUser;

    System.runAs(testUser) {

        Contact cand = [
            SELECT Id
            FROM Contact
            WHERE Name = 'Jane Smith'
            LIMIT 1
        ];

        SkillQuickActionController.SkillUpdateWrapper req =
            new SkillQuickActionController.SkillUpdateWrapper();
        req.recordId = cand.Id;
        req.objName = 'Contact';
        req.skills = new List<String>();
        req.softSkills = new List<String>();

        Test.startTest();
        SkillQuickActionController.updateCandidateSkills(req);
        Test.stopTest();

        Contact updated = [
            SELECT Skills__c, Soft_Skills__c
            FROM Contact
            WHERE Id = :cand.Id
        ];

        System.assertEquals(
            null,
            updated.Skills__c,
            'Skills should be cleared when empty list is provided'
        );
        System.assertEquals(
            null,
            updated.Soft_Skills__c,
            'Soft skills should be cleared when empty list is provided'
        );
    }
}

}