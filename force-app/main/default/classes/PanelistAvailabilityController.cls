public without sharing class PanelistAvailabilityController {

    /* =====================================================
       FETCH LOGGED-IN CONTACT (PORTAL SAFE)
       ===================================================== */
    @AuraEnabled(cacheable=true)
    public static Id getLoggedInContactId() {

        User u = [
            SELECT ContactId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        return u.ContactId;
    }

    /* =====================================================
       CREATE AVAILABILITY
       ===================================================== */
    @AuraEnabled
    public static void createAvailability(
        Id contactId,
        List<Map<String, String>> slots
    ) {

        validateInput(contactId, slots);

        Set<Date> slotDates = collectSlotDates(slots);

        List<Event> existingEvents =
            getExistingEvents(contactId, slotDates);

        Id internalOwnerId = getInternalOwnerId();

        AvailabilityContext ctx = new AvailabilityContext();
        ctx.contactId = contactId;
        ctx.slots = slots;
        ctx.existingEvents = existingEvents;
        ctx.internalOwnerId = internalOwnerId;

        List<Event> eventsToInsert = buildEvents(ctx);

        if (eventsToInsert.isEmpty()) {
            throw new AuraHandledException(
                'All selected slots already exist or overlap with existing availability.'
            );
        }

        //if (!Schema.sObjectType.Event.isCreateable()) {
           // throw new AuraHandledException(
              //  'You do not have permission to create availability.'
           // );
       // }

        insert eventsToInsert;
    }

    /* =====================================================
       VALIDATION
       ===================================================== */
    private static void validateInput(
        Id contactId,
        List<Map<String, String>> slots
    ) {
        if (contactId == null || slots == null || slots.isEmpty()) {
            throw new AuraHandledException(
                'Invalid input data. Contact not found.'
            );
        }
    }

    /* =====================================================
       COLLECT SLOT DATES
       ===================================================== */
    private static Set<Date> collectSlotDates(
        List<Map<String, String>> slots
    ) {

        Set<Date> dates = new Set<Date>();

        for (Map<String, String> slot : slots) {

            if (String.isBlank(slot.get('availabilityDate'))) {
                continue;
            }

            dates.add(
                Date.valueOf(slot.get('availabilityDate'))
            );
        }

        return dates;
    }

    /* =====================================================
       FETCH EXISTING EVENTS
       ===================================================== */
    private static List<Event> getExistingEvents(
        Id contactId,
        Set<Date> slotDates
    ) {

        if (slotDates.isEmpty()) {
            return new List<Event>();
        }

        return [
            SELECT Id, StartDateTime, EndDateTime
            FROM Event
            WHERE WhoId = :contactId
            AND ActivityDate IN :slotDates
            WITH SECURITY_ENFORCED
        ];
    }

    /* =====================================================
       FETCH INTERNAL OWNER (NO LOOP QUERY)
       ===================================================== */
    private static Id getInternalOwnerId() {

        return [
            SELECT Id
            FROM User
            WHERE IsActive = true
            AND Profile.Name = 'System Administrator'
            WITH SYSTEM_MODE
            LIMIT 1
        ].Id;
    }

    /* =====================================================
       BUILD EVENTS
       ===================================================== */
    private static List<Event> buildEvents(
        AvailabilityContext ctx
    ) {

        List<Event> eventsToInsert = new List<Event>();

        for (Map<String, String> slot : ctx.slots) {

            if (!isValidSlot(slot)) {
                continue;
            }

            Datetime startDt =
                buildDateTime(
                    slot.get('availabilityDate'),
                    slot.get('startTime')
                );

            Datetime endDt =
                buildDateTime(
                    slot.get('availabilityDate'),
                    slot.get('endTime')
                );

            if (startDt >= endDt) {
                continue;
            }

            if (!isOverlapping(
                    startDt,
                    endDt,
                    ctx.existingEvents
                )) {

                eventsToInsert.add(
                    new Event(
                        OwnerId = ctx.internalOwnerId,
                        WhoId = ctx.contactId,
                        Subject = 'Interviewer Availability',
                        StartDateTime = startDt,
                        EndDateTime = endDt,
                        ShowAs = 'Free',
                        IsAllDayEvent = false
                    )
                );
            }
        }

        return eventsToInsert;
    }

    /* =====================================================
       SLOT VALIDATION
       ===================================================== */
    private static Boolean isValidSlot(
        Map<String, String> slot
    ) {

        return !String.isBlank(slot.get('availabilityDate')) &&
               !String.isBlank(slot.get('startTime')) &&
               !String.isBlank(slot.get('endTime'));
    }

    /* =====================================================
       OVERLAP CHECK
       ===================================================== */
    private static Boolean isOverlapping(
        Datetime startDt,
        Datetime endDt,
        List<Event> existingEvents
    ) {

        for (Event e : existingEvents) {

            if (startDt < e.EndDateTime &&
                endDt > e.StartDateTime) {

                return true;
            }
        }

        return false;
    }

    /* =====================================================
       DATETIME BUILDER
       ===================================================== */
    private static Datetime buildDateTime(
        String dateStr,
        String timeStr
    ) {

        Date d = Date.valueOf(dateStr);
        List<String> t = timeStr.split(':');

        return Datetime.newInstance(
            d,
            Time.newInstance(
                Integer.valueOf(t[0]),
                Integer.valueOf(t[1]),
                0,
                0
            )
        );
    }

    /* =====================================================
       CONTEXT WRAPPER (NO CONSTRUCTOR PARAMETERS)
       ===================================================== */
    private class AvailabilityContext {

        public Id contactId;
        public List<Map<String, String>> slots;
        public List<Event> existingEvents;
        public Id internalOwnerId;

    }
}