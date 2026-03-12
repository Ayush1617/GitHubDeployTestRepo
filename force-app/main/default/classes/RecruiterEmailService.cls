public without sharing class RecruiterEmailService {

    public static void sendRecruiterSubmissionEmail(
        List<Id> candidateIds,
        Id jobId
    ) {
        if (candidateIds == null || candidateIds.isEmpty() || jobId == null) {
            return;
        }

        List<Interview__c> interviews = [
            SELECT
                Candidate_Name__r.Name,
                Job_Position__r.Name,
                Job_Position__r.Recruiter__c,
                Job_Position__r.Recruiter__r.Name,
                Job_Position__r.Recruiter__r.Email,
                Feedback__c
            FROM Interview__c
            WHERE Candidate_Name__c IN :candidateIds
            AND Job_Position__c = :jobId
            AND Job_Position__r.Recruiter__c != NULL
        ];

        if (interviews.isEmpty()) {
            return;
        }

        Map<Id, List<String>> recruiterCandidates = new Map<Id, List<String>>();
        Map<Id, User> recruiterMap = new Map<Id, User>();
        String jobName = interviews[0].Job_Position__r.Name;

        for (Interview__c interview : interviews) {

            Id recruiterId = interview.Job_Position__r.Recruiter__c;
            User recruiter = interview.Job_Position__r.Recruiter__r;

            if (recruiter.Email == null) {
                continue;
            }

            if (!recruiterCandidates.containsKey(recruiterId)) {
                recruiterCandidates.put(recruiterId, new List<String>());
                recruiterMap.put(recruiterId, recruiter);
            }

            recruiterCandidates.get(recruiterId)
                .add(buildCandidateLine(
                    interview.Candidate_Name__r.Name,
                    interview.Feedback__c
                ));
        }

        List<Messaging.SingleEmailMessage> emails =
            buildEmails(recruiterCandidates, recruiterMap, jobName);

        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }
    }

    private static String buildCandidateLine(
        String candidateName,
        String feedback
    ) {
        String safeFeedback = String.isBlank(feedback)
            ? 'No feedback provided'
            : feedback;

        return candidateName + ' - Feedback: ' + safeFeedback;
    }

    private static List<Messaging.SingleEmailMessage> buildEmails(
        Map<Id, List<String>> recruiterCandidates,
        Map<Id, User> recruiterMap,
        String jobName
    ) {
        List<Messaging.SingleEmailMessage> emails =
            new List<Messaging.SingleEmailMessage>();

        Id orgWideEmailId = getOrgWideEmailId();

        for (Id recruiterId : recruiterCandidates.keySet()) {

            User recruiter = recruiterMap.get(recruiterId);

            Messaging.SingleEmailMessage mail =
                new Messaging.SingleEmailMessage();

            mail.setToAddresses(
                new String[] { recruiter.Email }
            );

            mail.setSubject('Candidate Shortlisted Update');

            mail.setHtmlBody(
                buildHtmlBody(
                    recruiter.Name,
                    recruiterCandidates.get(recruiterId),
                    jobName
                )
            );

            mail.setPlainTextBody(
                buildPlainTextBody(
                    recruiter.Name,
                    recruiterCandidates.get(recruiterId),
                    jobName
                )
            );

            if (orgWideEmailId != null) {
                mail.setOrgWideEmailAddressId(orgWideEmailId);
            }

            emails.add(mail);
        }

        return emails;
    }

    private static String buildHtmlBody(
        String recruiterName,
        List<String> candidates,
        String jobName
    ) {
        String candidateHtml = '';

        for (String candidate : candidates) {
            candidateHtml += '<p>' + candidate + '</p>';
        }

        return '<html><body style="font-family:Arial;">' +
               '<p>Dear ' + recruiterName + ',</p>' +
               '<br/>' +
               '<p>We have received an update from the client regarding the <b>' +
               jobName + '</b> role.</p>' +
               '<br/>' +
               '<p>The following candidate(s) have been shortlisted for the next round:</p>' +
               '<br/>' +
               candidateHtml +
               '<br/>' +
               '<p>Kindly coordinate with the candidates and share their availability ' +
               'for the next steps at the earliest. Please ensure they are informed ' +
               'about the interview process and prepared accordingly.</p>' +
               '<br/><br/>' +
               '<p>Regards,<br/>Recruitment Management System</p>' +
               '</body></html>';
    }

    private static String buildPlainTextBody(
        String recruiterName,
        List<String> candidates,
        String jobName
    ) {
        return 'Dear ' + recruiterName + ',\n\n' +
               'We have received an update from the client regarding the ' +
               jobName + ' role.\n\n' +
               'The following candidate(s) have been shortlisted for the next round:\n\n' +
               String.join(candidates, '\n') +
               '\n\nKindly coordinate with the candidates and share their availability ' +
               'for the next steps at the earliest. Please ensure they are informed ' +
               'about the interview process and prepared accordingly.\n\n' +
               'Regards,\nRecruitment Management System';
    }

    private static Id getOrgWideEmailId() {
        List<OrgWideEmailAddress> owea = [
            SELECT Id
            FROM OrgWideEmailAddress
            LIMIT 1
        ];

        return owea.isEmpty() ? null : owea[0].Id;
    }
}