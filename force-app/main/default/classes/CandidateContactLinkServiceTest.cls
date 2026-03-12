@IsTest
public class CandidateContactLinkServiceTest {

    @testSetup
    static void setupData() {

        // -------------------------------
        // Customer Community Account
        // -------------------------------
        RecordType customerRt = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Account'
            AND DeveloperName = 'Customer_Community_Account'
            LIMIT 1
        ];

        Account acc = new Account(
            Name = 'Customer Community Account',
            RecordTypeId = customerRt.Id
        );
        insert acc;

        // -------------------------------
        // Portal Contact
        // -------------------------------
        Contact portalContact = new Contact(
            LastName = 'Portal Contact',
            Email = 'candidate@test.com',
            AccountId = acc.Id
        );
        insert portalContact;

        // -------------------------------
        // Candidate Contact
        // -------------------------------
        RecordType candidateRt = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Contact'
            AND DeveloperName = 'Candidate'
            LIMIT 1
        ];

        Contact candidateContact = new Contact(
            LastName = 'Candidate Contact',
            Email = 'candidate1@test.com',
            RecordTypeId = candidateRt.Id
        );
        insert candidateContact;
    }

    @IsTest
    static void testCandidateUpdatedViaUserTrigger() {

        Profile portalProfile = [
            SELECT Id
            FROM Profile
            WHERE UserType IN ('CustomerPortal', 'CSPLitePortal')
            LIMIT 1
        ];

        Contact portalContact = [
            SELECT Id, Email, AccountId
            FROM Contact
            WHERE Email = 'candidate@test.com'
            AND AccountId != null
            LIMIT 1
        ];

        User adminUser = [
            SELECT Id
            FROM User
            WHERE Profile.Name = 'System Administrator'
            LIMIT 1
        ];

        Test.startTest();

        System.runAs(adminUser) {
            User u = new User(
                Username = 'portaluser@test.com.' + System.currentTimeMillis(),
                Email = portalContact.Email,
                LastName = 'PortalUser',
                Alias = 'puser',
                TimeZoneSidKey = 'Asia/Kolkata',
                LocaleSidKey = 'en_IN',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                ProfileId = portalProfile.Id,
                ContactId = portalContact.Id
            );
            insert u;
        }

        Test.stopTest();

        Contact updatedCandidate = [
            SELECT AccountId
            FROM Contact
            WHERE RecordType.DeveloperName = 'Candidate'
            AND Email = 'candidate1@test.com'
            LIMIT 1
        ];

    }
}