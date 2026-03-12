/**
 * @description
 * Service class responsible for validating inputs, preparing updates,
 * and persisting Interview__c records.
 * This class separates business logic from controllers and triggers
 * to ensure reusability, readability, and testability.
 *
 * All operations respect user-level access by executing queries and DML
 * in USER_MODE where applicable.
 */
public with sharing class InterviewService {

    /**
     * @description
     * Validates input parameters before processing Interview updates.
     * Ensures that Interview Ids are provided and at least one
     * updatable field (Stage or Feedback) is present.
     *
     * @param recordIds
     *        List of Interview__c record Ids to be processed.
     *
     * @param newStage
     *        New Interview stage value to be applied (optional).
     *
     * @param feedback
     *        Feedback text to be applied to the Interview records (optional).
     */
    public static void validateInterviewInputs(
        List<Id> recordIds,
        String newStage,
        String feedback
    ) {
        if (recordIds == null
            || recordIds.isEmpty()
            || (String.isBlank(newStage) && String.isBlank(feedback))) {
            throw new AuraHandledException(
                'Invalid input: At least one field (Stage or Feedback) and Interview IDs are required.'
            );
        }
    }

    /**
     * @description
     * Retrieves Interview__c records and applies the provided
     * stage and/or feedback updates in memory.
     *
     * @param recordIds
     *        List of Interview__c record Ids to update.
     *
     * @param newStage
     *        Interview stage value to be set on the records (optional).
     *
     * @param feedback
     *        Feedback text to be set on the records (optional).
     *
     * @return List<Interview__c>
     *         List of Interview__c records populated with updated values
     *         and ready for persistence.
     */
    public static List<Interview__c> prepareInterviewUpdates(
        List<Id> recordIds,
        String newStage,
        String feedback
    ) {
        if (recordIds == null || recordIds.isEmpty()) {
            return new List<Interview__c>();
        }

        List<Interview__c> records = [
            SELECT Id, Interview_Status__c, Feedback__c
            FROM Interview__c
            WHERE Id IN :recordIds
            WITH USER_MODE
        ];

        for (Interview__c i : records) {
            if (!String.isBlank(newStage)) {
                i.Interview_Status__c = newStage;
            }
            if (!String.isBlank(feedback)) {
                i.Feedback__c = feedback;
            }
        }
        return records;
    }

    /**
     * @description
     * Persists updated Interview__c records using user-level access.
     * Handles and surfaces any DML errors in a user-friendly manner.
     *
     * @param interviewsToUpdate
     *        List of Interview__c records to be updated.
     *
     * @throws AuraHandledException
     *         If an error occurs while updating Interview records.
     */
    public static void saveInterviewRecords(
        List<Interview__c> interviewsToUpdate
    ) {
        if (!interviewsToUpdate.isEmpty()) {
            try {
                Database.update(interviewsToUpdate, AccessLevel.USER_MODE);
            } catch (Exception e) {
                throw new AuraHandledException(
                    'Error updating interviews: ' + e.getMessage()
                );
            }
        }
    }
}