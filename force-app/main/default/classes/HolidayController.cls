/**
* @File Name : HolidayController.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : December 16, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | December 16, 2025 |   | Initial Version
**/
public with sharing class HolidayController {

    /**
     * @description
     * Returns current year holidays from Salesforce org
     */
    @AuraEnabled(cacheable=true)
    public static List<HolidayDTO> getCurrentYearHolidays() {

        Integer currentYear = Date.today().year();
        Date startDate = Date.newInstance(currentYear, 1, 1);
        Date endDate   = Date.newInstance(currentYear, 12, 31);

        List<Holiday> holidays = [
            SELECT Id, Name, ActivityDate
            FROM Holiday
            WHERE ActivityDate >= :startDate
            AND ActivityDate <= :endDate
            
            ORDER BY ActivityDate ASC
        ];

        List<HolidayDTO> result = new List<HolidayDTO>();

        for (Holiday h : holidays) {
            result.add(new HolidayDTO(h));
        }

        return result;
    }

    /**
     * DTO for LWC (best practice)
     */
   public class HolidayDTO {
    @AuraEnabled public Id id;
    @AuraEnabled public String name;
    @AuraEnabled public Date holidayDate;
    @AuraEnabled public String month;
    @AuraEnabled public Integer day;
    @AuraEnabled public String weekday;

    public HolidayDTO(Holiday h) {
        id = h.Id;
        name = h.Name;
        holidayDate = h.ActivityDate;

        // ✅ Convert Date → Datetime
        Datetime holidayDt = Datetime.newInstance(
            h.ActivityDate,
            Time.newInstance(0, 0, 0, 0)
        );

        month = holidayDt.format('MMM').toUpperCase();
        day = h.ActivityDate.day();
        weekday = holidayDt.format('EEEE');
    }
}

}