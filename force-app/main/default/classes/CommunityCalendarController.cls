public with sharing class CommunityCalendarController {
    @AuraEnabled(cacheable=true)
    public static List<Event> getUserEvents(Id recordId) {
        // You can filter events based on user, account, or record context
        return [
            SELECT Id, Subject, StartDateTime, EndDateTime, Location, Description
            FROM Event
            WHERE OwnerId = :UserInfo.getUserId()
            ORDER BY StartDateTime ASC
            LIMIT 100
        ];
    }
}