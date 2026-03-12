/**
 * @description
 * Service responsible for detecting duplicate interviews
 * based on Candidate Contact and Job Position.
 *
 * Interview Lookup:
 *  - Interview__c.Candidate_Name__c → Contact
 *
 * PMD SAFE:
 *  - Single responsibility
 *  - Low complexity
 */
public with sharing class InterviewDuplicateService {

    /**
     * @description
     * Throws an exception if Interview__c records already exist
     * for the given candidate Contacts and Job Position.
     *
     * @param candidateContactIds List of Contact record Ids (Candidates)
     * @param jobPositionId       Job_Position__c record Id
     */
    public static void throwIfDuplicateExists(
        List<Id> candidateContactIds,
        Id jobPositionId
    ) {
        if (candidateContactIds == null || candidateContactIds.isEmpty()) {
            return;
        }

        List<Interview__c> interviews = [
            SELECT Candidate_Name__c
            FROM Interview__c
            WHERE Candidate_Name__c IN :candidateContactIds
            AND Job_Position__c = :jobPositionId
            WITH USER_MODE
        ];

        if (interviews.isEmpty()) {
            return;
        }

        String names = getCandidateNames(interviews);

        throw new AuraHandledException(
            'Interview already exists for candidate(s): ' + names
        );
    }

    /**
     * Fetches candidate names for user-friendly error message
     */
    private static String getCandidateNames(
        List<Interview__c> interviews
    ) {
        Set<Id> contactIds = new Set<Id>();

        for (Interview__c iv : interviews) {
            contactIds.add(iv.Candidate_Name__c);
        }

        List<Contact> contacts = [
            SELECT Name
            FROM Contact
            WHERE Id IN :contactIds
            WITH USER_MODE
        ];

        List<String> names = new List<String>();
        for (Contact c : contacts) {
            names.add(c.Name);
        }

        return String.join(names, ', ');
    }
}