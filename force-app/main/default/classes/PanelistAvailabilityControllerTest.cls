@IsTest
public class PanelistAvailabilityControllerTest {

    /* ===============================
       TEST SETUP
       =============================== */
    @TestSetup
    static void setupData() {

        Contact candidate =
            Recruitment_TestDataFactory.createCandidate(
                'Test Candidate',
                'candidate@test.com'
            );
        insert candidate;

        // Fixed future date
        Date d = Date.today().addDays(1);

        // Existing event: 10:00–11:00
        insert new Event(
            WhoId = candidate.Id,
            Subject = 'Existing Event',
            StartDateTime = DateTime.newInstance(
                d, Time.newInstance(10, 0, 0, 0)
            ),
            EndDateTime = DateTime.newInstance(
                d, Time.newInstance(11, 0, 0, 0)
            ),
            IsAllDayEvent = false
        );
    }

    private static User createTestUser() {

        Profile p = [
            SELECT Id
            FROM Profile
            WHERE Name = 'System Administrator'
            LIMIT 1
        ];

        User u = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@example.com',
            Username = 'testuser' + System.currentTimeMillis() + '@example.com',
            Alias = 'tuser',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US'
        );

        insert u;
        return u;
    }

    /* ===============================
       HELPER
       =============================== */
    private static Contact getCandidate() {
        return [
            SELECT Id
            FROM Contact
            WHERE RecordType.DeveloperName = 'Candidate'
            LIMIT 1
        ];
    }

    private static String getDateString() {
        return String.valueOf(Date.today().addDays(1)); // yyyy-MM-dd
    }

    /* ===============================
       1️⃣ SUCCESS
       =============================== */
    @IsTest
    static void testSuccess() {
        
        User u = createTestUser();

        System.runAs(u) {

        Contact c = getCandidate();

        List<Map<String,String>> slots = new List<Map<String,String>>{
            new Map<String,String>{
                'availabilityDate' => getDateString(),
                'startTime' => '12:00',
                'endTime'   => '13:00'
            }
        };

        Test.startTest();
        PanelistAvailabilityController.createAvailability(c.Id, slots);
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT COUNT() FROM Event WHERE Subject='Interviewer Availability']
        );
    }
    }
    /* ===============================
       2️⃣ ALL OVERLAP
       =============================== */
    @IsTest
    static void testAllOverlap() {
        
        User u = createTestUser();

System.runAs(u) {

        Contact c = getCandidate();

        List<Map<String,String>> slots = new List<Map<String,String>>{
            new Map<String,String>{
                'availabilityDate' => getDateString(),
                'startTime' => '10:00',
                'endTime'   => '11:00'
            }
        };

        Test.startTest();
        try {
            PanelistAvailabilityController.createAvailability(c.Id, slots);
            System.assert(false);
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }
    }

    /* ===============================
       3️⃣ INVALID TIME RANGE
       =============================== */
    @IsTest
    static void testInvalidTimeRange() {
        
        User u = createTestUser();

System.runAs(u) {

        Contact c = getCandidate();

        List<Map<String,String>> slots = new List<Map<String,String>>{
            new Map<String,String>{
                'availabilityDate' => getDateString(),
                'startTime' => '15:00',
                'endTime'   => '14:00'
            }
        };

        Test.startTest();
        try {
            PanelistAvailabilityController.createAvailability(c.Id, slots);
            System.assert(false);
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }
    }

    /* ===============================
       4️⃣ INVALID INPUT
       =============================== */
    @IsTest
    static void testInvalidInput() {
        
        User u = createTestUser();

System.runAs(u) {

        Test.startTest();
        try {
            PanelistAvailabilityController.createAvailability(null, null);
            System.assert(false);
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }
    }
}