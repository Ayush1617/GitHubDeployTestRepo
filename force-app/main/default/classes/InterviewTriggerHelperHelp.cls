/**
 * @description
 * Helper class responsible for handling Interview__c post-trigger logic.
 * This class manages:
 *  - Chatter feedback posts
 *  - Work Order creation
 *  - Interview Event creation & updates
 *
 * All logic is PMD-compliant and separated by responsibility.
 */
public with sharing class InterviewTriggerHelperHelp {

    /**
     * @description
     * Context wrapper holding all data required to process
     * a single Interview__c record for Event handling.
     */
    public class InterviewEventContext {
        public Interview__c interview;
        public Interview__c fullInterview;
        public Map<Id, List<Event>> candidateToEvents;
        public Boolean isInsert;
        public List<Event> eventsToInsert;
        public List<Event> eventsToUpdate;
    }

   /**
	* @description
	* Wrapper holding all data required to evaluate
	* interview time conflict against existing events.
	*/
	private class ConflictCheckContext {
		DateTime startDateTime;
		DateTime endDateTime;
		List<Event> existingEvents;
		Boolean isInsert;
		Id jobPositionId;
		EventHolder eventHolder;
	}

    /**
     * @description
     * Helper holder used to pass back an existing Event reference
     * when processing interview updates.
     */
    private class EventHolder {
        Event event;
    }

    /**
     * @description
     * Processes Interview Events for insert operations.
     *
     * @param newList
     * Trigger.new list of Interview__c records.
     * @param interviewIds
     * Interview Ids eligible for processing.
     */
    public static void processInterviewInsertEvents(
        List<Interview__c> newList,
        Set<Id> interviewIds
    ) {
        processInterviewEventsInternal(newList, interviewIds, true);
    }

    /**
     * @description
     * Processes Interview Events for update operations.
     *
     * @param newList
     * Trigger.new list of Interview__c records.
     * @param interviewIds
     * Interview Ids eligible for processing.
     */
    public static void processInterviewUpdateEvents(
        List<Interview__c> newList,
        Set<Id> interviewIds
    ) {
        processInterviewEventsInternal(newList, interviewIds, false);
    }

    /**
     * @description
     * Core processor that orchestrates interview event creation
     * and updates. Shared internally by insert and update flows.
     * @param newList List<Interview__c>
     * @param interviewIds Set<Id>
     * @param isInsert Boolean
     */
    private static void processInterviewEventsInternal(
        List<Interview__c> newList,
        Set<Id> interviewIds,
        Boolean isInsert
    ) {
        List<Event> eventsToInsert = new List<Event>();
        List<Event> eventsToUpdate = new List<Event>();

        Map<Id, Interview__c> interviewMap = fetchInterviewMap(interviewIds);
        Map<Id, List<Event>> candidateEvents =
            fetchCandidateEvents(extractCandidateIds(interviewMap));

        for (Interview__c interview : newList) {
            if (!interviewIds.contains(interview.Id) ||
                interview.Candidate_Name__c == null) {
                continue;
            }

            Interview__c full = interviewMap.get(interview.Id);
            if (full == null || full.Interview_Date__c == null) {
                continue;
            }

            InterviewEventContext ctx = new InterviewEventContext();
            ctx.interview = interview;
            ctx.fullInterview = full;
            ctx.candidateToEvents = candidateEvents;
            ctx.isInsert = isInsert;
            ctx.eventsToInsert = eventsToInsert;
            ctx.eventsToUpdate = eventsToUpdate;

            handleSingleInterview(ctx);
        }

        InterviewTriggerHelperAssist.commitEvents(eventsToInsert, eventsToUpdate);
    }
    /**
     * @description
     * Retrieves Interview__c records for the provided Interview Ids
     * with all fields required for downstream processing such as
     * event creation, updates, and notifications.
     *
     * @param interviewIds
     * Set of Interview__c record Ids to be queried.
     *
     * @return
     * Map of Interview__c records keyed by Interview Id.
     */
    private static Map<Id, Interview__c> fetchInterviewMap(Set<Id> interviewIds) {
        return new Map<Id, Interview__c>([
            SELECT Id, Interview_Date__c, Interview_Mode__c,
                   Candidate_Name__c, Candidate_Name__r.Name,
                   Job_Position__c,
                   Job_Position__r.Job_Title__c,
                   Job_Position__r.Client_Name__r.Name
            FROM Interview__c
            WHERE Id IN :interviewIds
            WITH USER_MODE
        ]);
    }

    /**
     * @description
     * Extracts Contact record Ids from the provided Interview__c
     * records, ignoring any interviews that do not have an associated
     * candidate.
     *
     * @param interviewMap
     * Map of Interview__c records keyed by Interview Id.
     *
     * @return
     * Set of unique Contact Ids referenced by the interviews.
     */
    private static Set<Id> extractCandidateIds(Map<Id, Interview__c> interviewMap) {
        Set<Id> ids = new Set<Id>();
        for (Interview__c i : interviewMap.values()) {
            if (i.Candidate_Name__c != null) {
                ids.add(i.Candidate_Name__c);
            }
        }
        return ids;
    }

    /**
     * @description
     * Fetches existing Event records associated with the provided
     * Candidate__c Ids and groups them by candidate for efficient
     * lookup and comparison during interview event processing.
     *
     * @param candidateIds
     * Set of Candidate__c record Ids for which Event records
     * need to be retrieved.
     *
     * @return
     * Map where the key is Candidate__c Id and the value is the
     * list of Event records associated with that candidate.
     */
    private static Map<Id, List<Event>> fetchCandidateEvents(Set<Id> candidateIds) {
        Map<Id, List<Event>> result = new Map<Id, List<Event>>();
        if (candidateIds.isEmpty()) {
            return result;
        }

        for (Event ev : [
            SELECT Id, Candidate_Name__c, StartDateTime, EndDateTime,
                   Location, Subject, WhatId
            FROM Event
            WHERE Candidate_Name__c IN :candidateIds
            WITH USER_MODE
        ]) {
            if (!result.containsKey(ev.Candidate_Name__c)) {
                result.put(ev.Candidate_Name__c, new List<Event>());
            }
            result.get(ev.Candidate_Name__c).add(ev);
        }
        return result;
    }

	/**
	* @description
	* Wrapper holding all data required to update an Interview Event.
	*/
	private class EventUpdateContext {
		Event event;
		InterviewEventContext interviewCtx;
		DateTime startDateTime;
		DateTime endDateTime;
	}

    /**
     * @description
     * Validates the interview schedule for a single Interview__c record
     * and creates or updates the corresponding Event record.
     * <p>
     * The method performs conflict detection to ensure that the candidate
     * does not have another interview scheduled within the same time slot.
     * If a conflict is detected, an error is added to the interview record
     * to prevent further processing.
     *
     * @param ctx
     * Wrapper containing all contextual information required to process
     * a single interview, including interview details, existing candidate
     * events, trigger context flags, and event tracking collections.
     */
    private static void handleSingleInterview(InterviewEventContext ctx) {

        DateTime startDT = ctx.fullInterview.Interview_Date__c;
        DateTime endDT = startDT.addHours(1);

        EventHolder holder = new EventHolder();

        ConflictCheckContext conflictCtx = new ConflictCheckContext();
        conflictCtx.startDateTime = startDT;
        conflictCtx.endDateTime = endDT;
        conflictCtx.existingEvents =
            ctx.candidateToEvents.get(ctx.fullInterview.Candidate_Name__c);
        conflictCtx.isInsert = ctx.isInsert;
        conflictCtx.jobPositionId = ctx.fullInterview.Job_Position__c;
        conflictCtx.eventHolder = holder;

        if (hasConflict(conflictCtx)) {
            ctx.interview.addError(
                'This candidate already has another interview scheduled in this time slot.'
            );
            return;
        }

        if (ctx.isInsert || holder.event == null) {
            ctx.eventsToInsert.add(buildEvent(ctx, startDT, endDT));
        } else if (holder.event != null) {

            EventUpdateContext updateCtx = new EventUpdateContext();
            updateCtx.event = holder.event;
            updateCtx.interviewCtx = ctx;
            updateCtx.startDateTime = startDT;
            updateCtx.endDateTime = endDT;

            updateEvent(updateCtx);
            ctx.eventsToUpdate.add(holder.event);
        }
    }

	/**
	* @description
	* Checks whether interview timing conflicts with
	* any existing candidate events.
	* @param ctx
	* Wrapper containing conflict evaluation data.
	* @return
	* True if conflict exists, otherwise false.
	*/
	private static Boolean hasConflict(ConflictCheckContext ctx) {

		if (ctx.existingEvents == null) {
			return false;
		}

		for (Event ev : ctx.existingEvents) {

			if (!ctx.isInsert && ev.WhatId == ctx.jobPositionId) {
				ctx.eventHolder.event = ev;
				continue;
			}

			if (ev.StartDateTime != null &&
				ev.EndDateTime != null &&
				ctx.startDateTime < ev.EndDateTime &&
				ctx.endDateTime > ev.StartDateTime) {
				return true;
			}
		}
		return false;
	}

    /**
     * @description
     * Builds and returns a new Event record representing an interview
     * based on the provided interview context and scheduled time window.
     * @param ctx
     * Wrapper containing the Interview__c record and related data
     * required to construct the Event.
     *
     * @param startDT
     * Scheduled start date and time of the interview.
     *
     * @param endDT
     * Scheduled end date and time of the interview.
     *
     * @return
     * Newly constructed Event record ready for insertion.
     */
    private static Event buildEvent(
        InterviewEventContext ctx,
        DateTime startDT,
        DateTime endDT
    ) {
        String candidateName =
            ctx.fullInterview.Candidate_Name__r != null
            ? ctx.fullInterview.Candidate_Name__r.Name
            : 'Unknown Candidate';

        String clientName =
            ctx.fullInterview.Job_Position__r != null &&
            ctx.fullInterview.Job_Position__r.Client_Name__r != null
            ? ctx.fullInterview.Job_Position__r.Client_Name__r.Name
            : 'Unknown Client';

        String jobTitle =
            ctx.fullInterview.Job_Position__r != null
            ? ctx.fullInterview.Job_Position__r.Job_Title__c
            : 'Unknown Job';

        return new Event(
            WhatId = ctx.fullInterview.Job_Position__c,
            StartDateTime = startDT,
            EndDateTime = endDT,
            Subject = 'Interview: ' + candidateName,
            Description = candidateName + ' (' + jobTitle + ') for ' + clientName,
            Location = ctx.fullInterview.Interview_Mode__c,
            Candidate_Name__c = ctx.fullInterview.Candidate_Name__c,
            DurationInMinutes = 60,
            ActivityDate = startDT.date()
        );
    }

    /**
     * @description
     * Updates an existing Event record with the latest interview
     * scheduling and contextual information.
     *
     * @param ctx
     * Wrapper containing the Event to be updated along with
     * interview details and revised scheduling information.
     */
    private static void updateEvent(EventUpdateContext ctx) {

        ctx.event.StartDateTime = ctx.startDateTime;
        ctx.event.EndDateTime = ctx.endDateTime;
        ctx.event.Location = ctx.interviewCtx.fullInterview.Interview_Mode__c;
        ctx.event.Subject = 'Interview: ' +
            (ctx.interviewCtx.fullInterview.Candidate_Name__c != null
                ? ctx.interviewCtx.fullInterview.Candidate_Name__r.Name
                : 'Candidate');
    }
}