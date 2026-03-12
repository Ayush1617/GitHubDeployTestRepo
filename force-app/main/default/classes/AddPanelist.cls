public without sharing class AddPanelist {

    public class PanelistWrapper {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String email;
        @AuraEnabled public String designation;
        @AuraEnabled public String skills;
        @AuraEnabled public Integer eventCount;

        public PanelistWrapper(Contact c, Integer count) {
            id = c.Id;
            name = c.Name;
            email = c.Email;
            designation = c.Designation__c;
            skills = c.Skills__c;
            eventCount = count != null ? count : 0;

            System.debug('🔹 Wrapper created for Contact => ' + id + 
                         ' | Event Count => ' + eventCount);
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<PanelistWrapper> getPanelistsWithEventCount() {

        System.debug('🚀 getPanelistsWithEventCount START');

        // 🔹 1. Get event count per panelist
        Map<Id, Integer> eventCountMap = new Map<Id, Integer>();

        for (AggregateResult ar : [
            SELECT WhoId whoId, COUNT(Id) total
            FROM Event
            WHERE WhoId != null 
              AND Subject = 'Interviewer Availability'
            GROUP BY WhoId
        ]) {
            Id whoId = (Id) ar.get('whoId');
            Integer total = (Integer) ar.get('total');

            eventCountMap.put(whoId, total);

            System.debug('📊 Event Count => WhoId: ' + whoId + 
                         ' | Total Events: ' + total);
        }

        System.debug('📌 EventCountMap => ' + eventCountMap);

        // 🔹 2. Get panelists
        List<PanelistWrapper> result = new List<PanelistWrapper>();

        List<Contact> contacts = [
            SELECT Id, Name, Email, Designation__c, Skills__c
            FROM Contact
            WHERE RecordType.DeveloperName = 'Candidate'
              AND Panelist__c = true
        ];

        System.debug('👥 Total Panelists Found => ' + contacts.size());

        for (Contact c : contacts) {
            System.debug('➡️ Processing Contact => ' + c.Id + ' | ' + c.Name);

            result.add(
                new PanelistWrapper(c, eventCountMap.get(c.Id))
            );
        }

        System.debug('✅ Final Result Size => ' + result.size());
        System.debug('🏁 getPanelistsWithEventCount END');

        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<Event> getEventsByPanelist(Id panelistId) {

        System.debug('🚀 getEventsByPanelist START');
        System.debug('🎯 panelistId => ' + panelistId);

        List<Event> events = [
            SELECT Id, Subject, ActivityDate, StartDateTime, EndDateTime
            FROM Event
            WHERE WhoId = :panelistId
            ORDER BY ActivityDate ASC
        ];
        for (Event e : events) {
        System.debug(
            '📅 Event => ' +
            'Date=' + e.ActivityDate +
            ' | Start=' + e.StartDateTime +
            ' | End=' + e.EndDateTime
        );
    }

        System.debug('📅 Total Events Found => ' + events.size());
        System.debug('📅 Events => ' + events);
        System.debug('🏁 getEventsByPanelist END');

        return events;
    }
}