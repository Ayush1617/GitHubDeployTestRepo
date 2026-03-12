public with sharing class InterviewEmailService {

    public static void sendInterviewCreationEmail(
        List<Id> candidateIds,
        Id jobPositionId
    ) {
        try {
            Job_Position__c jp = [
                SELECT Id, Name, OwnerId
                FROM Job_Position__c
                WHERE Id = :jobPositionId
                LIMIT 1
            ];

            User owner = [
                SELECT Id, Name, Email
                FROM User
                WHERE Id = :jp.OwnerId
                LIMIT 1
            ];

            if (String.isBlank(owner.Email)) {
                return;
            }

            Messaging.SingleEmailMessage mail =
                new Messaging.SingleEmailMessage();

            mail.setToAddresses(new String[]{ owner.Email });
            mail.setSubject('Interview(s) Created for ' + jp.Name);
            mail.setPlainTextBody(
                'Interview(s) have been created for Job Position: ' + jp.Name
            );

            Messaging.sendEmail(
                new Messaging.SingleEmailMessage[]{ mail }
            );
        } catch (Exception e) {
            System.debug('Interview email failed: ' + e.getMessage());
        }
    }
}