@IsTest
public class CandidatePicklistServiceTest {

    @IsTest
    static void testGetNoticePeriodPicklistValues() {

        // Create a test user
        Profile p = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];

        User u = new User(
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

        insert u;

        System.runAs(u) {

            Test.startTest();
            List<Map<String, String>> result =
                CandidatePicklistService.getNoticePeriodPicklistValues();
            Test.stopTest();

            // Assertions (metadata-safe)
            System.assertNotEquals(
                null,
                result,
                'Picklist result should not be null'
            );

            for (Map<String, String> entry : result) {
                System.assert(
                    entry.containsKey('label'),
                    'Each entry must have label'
                );
                System.assert(
                    entry.containsKey('value'),
                    'Each entry must have value'
                );
            }
        }
    }
}