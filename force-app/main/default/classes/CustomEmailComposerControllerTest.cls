@IsTest
private class CustomEmailComposerControllerTest {

    /* ===========================
       TEST SETUP
       ========================================================= */
    @testSetup
    static void setupData() {
        // Create test user
       // User u = createTestUser();

        // Create Org Wide Email Address
      

        // Create related record (Account)
        Account acc = new Account(Name = 'Test Account');
        insert acc;
    }

    /* =========================================================
       TEST: getFromAddresses
       ========================================================= */
    @IsTest
    static void testGetFromAddresses() {
        Test.startTest();
        List<Map<String, String>> result =
            CustomEmailComposerController.getFromAddresses();
        Test.stopTest();

        System.assertNotEquals(
            0,
            result.size(),
            'Org-wide email addresses should be returned'
        );

        System.assertEquals(
            'OrgWide',
            result[0].get('type'),
            'Type should be OrgWide'
        );
    }

    /* =========================================================
       TEST: sendEmailNow - SUCCESS
       ========================================================= */
    @IsTest
    static void testSendEmailSuccess() {
        OrgWideEmailAddress owea = [
            SELECT Id
            FROM OrgWideEmailAddress
            LIMIT 1
        ];

        Account acc = [
            SELECT Id
            FROM Account
            LIMIT 1
        ];

        CustomEmailComposerController.EmailRequestDTO req =
            new CustomEmailComposerController.EmailRequestDTO();

        req.toAddresses = new List<String>{ 'recipient@example.com' };
        req.subject = 'Test Subject';
        req.htmlBody = '<p>Test Body</p>';
        req.fromType = 'OrgWide';
        req.fromId = owea.Id;
        req.relatedRecordId = acc.Id;
String payloadJson = JSON.serialize(req);
        Test.startTest();
        String response =
            CustomEmailComposerController.sendEmailNow(payloadJson);
        Test.stopTest();

        System.assertEquals(
            'Email sent successfully',
            response,
            'Email should be sent successfully'
        );
    }

    /* =========================================================
       TEST: Validation Error (No Recipients)
       ========================================================= */
    @IsTest
    static void testSendEmailNoRecipients() {
        OrgWideEmailAddress owea = [
            SELECT Id
            FROM OrgWideEmailAddress
            LIMIT 1
        ];

        CustomEmailComposerController.EmailRequestDTO req =
            new CustomEmailComposerController.EmailRequestDTO();

        req.subject = 'Test Subject';
        req.htmlBody = '<p>Body</p>';
        req.fromType = 'OrgWide';
        req.fromId = owea.Id;
String payloadJson = JSON.serialize(req);
        Test.startTest();
        try {
            CustomEmailComposerController.sendEmailNow(payloadJson);
            System.assert(false, 'Exception should have been thrown');
        } catch (AuraHandledException ex) {
            System.assertEquals(
                'Script-thrown exception',
                ex.getMessage()
            );
        }
        Test.stopTest();
    }

    /* =========================================================
       TEST: Invalid Sender Type
       ========================================================= */
   @IsTest
static void testInvalidSenderType() {

    // Build DTO
    CustomEmailComposerController.EmailRequestDTO req =
        new CustomEmailComposerController.EmailRequestDTO();

    req.toAddresses = new List<String>{ 'test@example.com' };
    req.subject = 'Test';
    req.htmlBody = '<p>Body</p>';
    req.fromType = 'User'; // ❌ Invalid on purpose
    req.fromId = UserInfo.getUserId();

    // Convert to JSON (IMPORTANT)
    String payloadJson = JSON.serialize(req);

    Test.startTest();
    try {
        CustomEmailComposerController.sendEmailNow(payloadJson);
        System.assert(false, 'Exception expected');
    } catch (AuraHandledException ex) {
        System.assertEquals(
            'Script-thrown exception',
            ex.getMessage()
        );
    }
    Test.stopTest();
}


    /* =========================================================
       HELPER: Create Test User
       ========================================================= */
    private static User createTestUser() {
        Profile p = [
            SELECT Id
            FROM Profile
            WHERE Name = 'System Administrator'
            LIMIT 1
        ];

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

        return u;
    }
}