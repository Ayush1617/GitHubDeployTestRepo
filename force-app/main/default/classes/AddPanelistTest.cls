@IsTest
private class AddPanelistTest {

    /* =========================================================
       Test Data Setup
       ========================================================= */
    @testSetup
    static void setupTestData() {

        // 🔹 Get Candidate Record Type
        RecordType candidateRT = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Contact'
            AND DeveloperName = 'Candidate'
            LIMIT 1
        ];

        // 🔹 Create Panelist Contacts
        List<Contact> panelists = new List<Contact>{
            new Contact(
                FirstName = 'Amit',
                LastName  = 'Sharma',
                Email = 'amit@test.com',
                Designation__c = 'Senior Interviewer',
                Skills__c = 'Salesforce, Apex',
                Panelist__c = true,
                RecordTypeId = candidateRT.Id
            ),
            new Contact(
                FirstName = 'Ravi',
                LastName  = 'Kumar',
                Email = 'ravi@test.com',
                Designation__c = 'Tech Lead',
                Skills__c = 'LWC, Admin',
                Panelist__c = true,
                RecordTypeId = candidateRT.Id
            )
        };
        insert panelists;

        // 🔹 Create Events for First Panelist
        List<Event> events = new List<Event>{
            new Event(
                WhoId = panelists[0].Id,
                Subject = 'Interviewer Availability',
                StartDateTime = System.now().addDays(1),
                EndDateTime   = System.now().addDays(1).addHours(1)
            ),
            new Event(
                WhoId = panelists[0].Id,
                Subject = 'Interviewer Availability',
                StartDateTime = System.now().addDays(2),
                EndDateTime   = System.now().addDays(2).addHours(1)
            )
        };
        insert events;
    }

    /* =========================================================
       Test: getPanelistsWithEventCount
       ========================================================= */
    @IsTest
    static void testGetPanelistsWithEventCount() {

        Test.startTest();
        List<AddPanelist.PanelistWrapper> result =
            AddPanelist.getPanelistsWithEventCount();
        Test.stopTest();

        System.assertNotEquals(
            null,
            result,
            'Result should not be null'
        );

        System.assertEquals(
            2,
            result.size(),
            'Two panelists should be returned'
        );

        Boolean eventCountVerified = false;

        for (AddPanelist.PanelistWrapper pw : result) {
            System.assertNotEquals(
                null,
                pw.id,
                'Panelist Id should not be null'
            );

            System.assertNotEquals(
                null,
                pw.name,
                'Panelist name should not be null'
            );

            if (pw.eventCount == 2) {
                eventCountVerified = true;
            }
        }

        System.assertEquals(
            true,
            eventCountVerified,
            'One panelist should have 2 events'
        );
    }

    /* =========================================================
       Test: getEventsByPanelist
       ========================================================= */
    @IsTest
    static void testGetEventsByPanelist() {

        Contact panelist = [
            SELECT Id
            FROM Contact
            WHERE Panelist__c = true
            LIMIT 1
        ];

        Test.startTest();
        List<Event> events =
            AddPanelist.getEventsByPanelist(panelist.Id);
        Test.stopTest();

        System.assertNotEquals(
            null,
            events,
            'Events list should not be null'
        );

        System.assertEquals(
            2,
            events.size(),
            'Panelist should have 2 events'
        );

        for (Event e : events) {
            System.assertEquals(
                'Interviewer Availability',
                e.Subject,
                'Event subject should match'
            );
        }
    }
}