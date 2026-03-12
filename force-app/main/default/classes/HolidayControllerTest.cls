@IsTest
public class HolidayControllerTest {

    /**
     * @description
     * Create test Holiday records once for all test methods
     */
    @testSetup
    static void setupTestData() {

        Integer currentYear = Date.today().year();

        List<Holiday> holidayList = new List<Holiday>{
            new Holiday(
                Name = 'New Year Holiday',
                ActivityDate = Date.newInstance(currentYear, 1, 1)
            ),
            new Holiday(
                Name = 'Independence Day',
                ActivityDate = Date.newInstance(currentYear, 8, 15)
            ),
            new Holiday(
                Name = 'Christmas',
                ActivityDate = Date.newInstance(currentYear, 12, 25)
            )
        };

        insert holidayList;
    }

    /**
     * @description
     * Test getCurrentYearHolidays method
     */
    @IsTest
    static void testGetCurrentYearHolidays() {

        Test.startTest();
        List<HolidayController.HolidayDTO> result =
            HolidayController.getCurrentYearHolidays();
        Test.stopTest();

        // Assertions
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(21, result.size(), '18+3 holidays should be returned');

        HolidayController.HolidayDTO first = result[0];

        System.assertNotEquals(null, first.id, 'Id should be populated');
        System.assertNotEquals(null, first.name, 'Name should be populated');
        System.assertNotEquals(null, first.holidayDate, 'Date should be populated');
        System.assertNotEquals(null, first.month, 'Month should be populated');
        System.assertNotEquals(null, first.day, 'Day should be populated');
        System.assertNotEquals(null, first.weekday, 'Weekday should be populated');
    }

}