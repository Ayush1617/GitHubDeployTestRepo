public without sharing class CandidateShareController {
    
   /* @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getCandidatesForDisplay(
        String candidateIdsParam,
        Id jobId
    ) {
        try {
            if (String.isBlank(candidateIdsParam) || jobId == null) {
                throw new AuraHandledException('Missing candidate IDs or job ID');
            }

            String decodedIds = EncodingUtil.urlDecode(candidateIdsParam, 'UTF-8');
            List<String> candidateIds = decodedIds.split(',');

            // 🔹 Query Interview (Junction Object)
            List<Interview__c> interviews = [
                SELECT Id,
                    Candidate_Name__c,
                    Candidate_Name__r.Name,
                    Candidate_Name__r.Email,
                    Candidate_Name__r.Phone,
                    Candidate_Name__r.Current_Location__c,
                    Candidate_Name__r.Source__c,
                    Candidate_Name__r.Skills__c,
                    Candidate_Name__r.Resume_Link__c,
                    Candidate_Name__r.CreatedDate,
                    Candidate_Name__r.Notice_Period__c,
                    Rate__c
                FROM Interview__c
                WHERE Candidate_Name__c IN :candidateIds
                AND Job_Position__c = :jobId
            ];
            system.debug('candidateIds----->>>'+candidateIds);
            system.debug('jobId----->>>'+jobId);
            
            
            // If no interviews found, create them and get the new IDs
        if (interviews.isEmpty()) {
            System.debug('No interviews found. Creating new interview records...');
            
            // Call helper method to create interviews and return IDs
            List<Id> newInterviewIds = createInterviewsAndGetIds(candidateIds, jobId);
            
            if (!newInterviewIds.isEmpty()) {
                // Query the newly created interviews using the IDs
                interviews = [
                    SELECT Id,
                        Candidate_Name__c,
                        Candidate_Name__r.Name,
                        Candidate_Name__r.Email,
                        Candidate_Name__r.Phone,
                        Candidate_Name__r.Current_Location__c,
                        Candidate_Name__r.Source__c,
                        Candidate_Name__r.Skills__c,
                        Candidate_Name__r.Resume_Link__c,
                        Candidate_Name__r.CreatedDate,
                        Candidate_Name__r.Notice_Period__c,
                        Rate__c
                    FROM Interview__c
                    WHERE Id IN :newInterviewIds
                ];
                
                System.debug('Retrieved ' + interviews.size() + ' newly created interviews');
            }
        }


            List<Map<String, Object>> result = new List<Map<String, Object>>();
            Integer index = 1;

            for (Interview__c interview : interviews) {

                Contact candidate = interview.Candidate_Name__r;

                Map<String, Object> candidateMap = new Map<String, Object>{
                    'id' => index,
                    'recordId' => candidate.Id,
                    'name' => candidate.Name,
                    'email' => candidate.Email,
                    'phone' => candidate.Phone,
                    'currentLocation' => candidate.Current_Location__c,
                    'source' => candidate.Source__c,
                    'skills' => candidate.Skills__c,
                    'Rate' => interview.Rate__c != null 
                                ? '₹' + String.valueOf(interview.Rate__c) 
                                : 'Not provided',
                    'noticePeriod' => Candidate.Notice_Period__c != null 
                                ? String.valueOf(Candidate.Notice_Period__c) + ' days'
                                : 'Not provided',
                    'resumeLink' => candidate.Resume_Link__c,
                    'createdDate' => candidate.CreatedDate?.format('dd-MM-yyyy')
                };

                result.add(candidateMap);
                index++;
            }

            return result;

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error loading candidates - Line: ' + e.getLineNumber() + 
                         ', Message: ' + e.getMessage() + 
                         ', Cause: ' + e.getCause() + 
                         ', Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException(
                'Error loading candidates: ' + e.getMessage()
            );
        }
    }*/
    
     // Cacheable method for reading - returns empty list if no interviews
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getCandidatesForDisplay(
        String candidateIdsParam,
        Id jobId
    ) {
        try {
            if (String.isBlank(candidateIdsParam) || jobId == null) {
                throw new AuraHandledException('Missing candidate IDs or job ID');
            }

            String decodedIds = EncodingUtil.urlDecode(candidateIdsParam, 'UTF-8');
            List<String> candidateIds = decodedIds.split(',');

            // Query Interview records
            List<Interview__c> interviews = [
                SELECT Id,
                    Candidate_Name__c,
                    Candidate_Name__r.Name,
                    Candidate_Name__r.Email,
                    Candidate_Name__r.Phone,
                    Candidate_Name__r.Current_Location__c,
                    Candidate_Name__r.Source__c,
                    Candidate_Name__r.Skills__c,
                    Candidate_Name__r.Resume_Link__c,
                    Candidate_Name__r.CreatedDate,
                    Candidate_Name__r.Notice_Period__c,
                    Rate__c
                FROM Interview__c
                WHERE Candidate_Name__c IN :candidateIds
                AND Job_Position__c = :jobId
            ];

            // If no interviews found, return empty list
            if (interviews.isEmpty()) {
                return new List<Map<String, Object>>();
            }

            List<Map<String, Object>> result = new List<Map<String, Object>>();
            Integer index = 1;

            for (Interview__c interview : interviews) {
                Contact candidate = interview.Candidate_Name__r;

                Map<String, Object> candidateMap = new Map<String, Object>{
                    'id' => index,
                    'recordId' => candidate.Id,
                    'interviewId' => interview.Id,
                    'name' => candidate.Name,
                    'email' => candidate.Email,
                    'phone' => candidate.Phone,
                    'currentLocation' => candidate.Current_Location__c,
                    'source' => candidate.Source__c,
                    'skills' => candidate.Skills__c,
                    'Rate' => interview.Rate__c != null 
                                ? '₹' + String.valueOf(interview.Rate__c) 
                                : 'Not provided',
                    'noticePeriod' => candidate.Notice_Period__c != null 
                                ? String.valueOf(candidate.Notice_Period__c) + ' days'
                                : 'Not provided',
                    'resumeLink' => candidate.Resume_Link__c,
                    'createdDate' => candidate.CreatedDate?.format('dd-MM-yyyy')
                };

                result.add(candidateMap);
                index++;
            }

            return result;

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error loading candidates - Line: ' + e.getLineNumber() + 
                         ', Message: ' + e.getMessage());
            throw new AuraHandledException(
                'Error loading candidates: ' + e.getMessage()
            );
        }
    }

    // NEW METHOD: Create interviews and return candidates
    @AuraEnabled
    public static List<Map<String, Object>> createInterviewsAndGetCandidates(
        String candidateIdsParam,
        Id jobId
    ) {
        try {
            if (String.isBlank(candidateIdsParam) || jobId == null) {
                throw new AuraHandledException('Missing candidate IDs or job ID');
            }

            String decodedIds = EncodingUtil.urlDecode(candidateIdsParam, 'UTF-8');
            List<String> candidateIds = decodedIds.split(',');

            // Create interview records
            List<Interview__c> interviewsToCreate = new List<Interview__c>();
            for (String candidateId : candidateIds) {
                Interview__c newInterview = new Interview__c(
                    Candidate_Name__c = candidateId,
                    Job_Position__c = jobId
                );
                interviewsToCreate.add(newInterview);
            }
            
            if (!interviewsToCreate.isEmpty()) {
                insert interviewsToCreate;
            }

            // Query the newly created interviews
            List<Interview__c> interviews = [
                SELECT Id,
                    Candidate_Name__c,
                    Candidate_Name__r.Name,
                    Candidate_Name__r.Email,
                    Candidate_Name__r.Phone,
                    Candidate_Name__r.Current_Location__c,
                    Candidate_Name__r.Source__c,
                    Candidate_Name__r.Skills__c,
                    Candidate_Name__r.Resume_Link__c,
                    Candidate_Name__r.CreatedDate,
                    Candidate_Name__r.Notice_Period__c,
                    Rate__c
                FROM Interview__c
                WHERE Id IN :interviewsToCreate
            ];

            List<Map<String, Object>> result = new List<Map<String, Object>>();
            Integer index = 1;

            for (Interview__c interview : interviews) {
                Contact candidate = interview.Candidate_Name__r;

                Map<String, Object> candidateMap = new Map<String, Object>{
                    'id' => index,
                    'recordId' => candidate.Id,
                    'interviewId' => interview.Id,
                    'name' => candidate.Name,
                    'email' => candidate.Email,
                    'phone' => candidate.Phone,
                    'currentLocation' => candidate.Current_Location__c,
                    'source' => candidate.Source__c,
                    'skills' => candidate.Skills__c,
                    'Rate' => interview.Rate__c != null 
                                ? '₹' + String.valueOf(interview.Rate__c) 
                                : 'Not provided',
                    'noticePeriod' => candidate.Notice_Period__c != null 
                                ? String.valueOf(candidate.Notice_Period__c) + ' days'
                                : 'Not provided',
                    'resumeLink' => candidate.Resume_Link__c,
                    'createdDate' => candidate.CreatedDate?.format('dd-MM-yyyy')
                };

                result.add(candidateMap);
                index++;
            }

            return result;

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error creating interviews - Line: ' + e.getLineNumber() + 
                         ', Message: ' + e.getMessage());
            throw new AuraHandledException('Error creating interviews: ' + e.getMessage());
        }
    }
        
    @AuraEnabled
    public static Map<String, Object> generateAndSendShareLink(List<Id> candidateIds, Id clientId, Id jobId) {
        system.debug('candidateIds'+candidateIds);
        system.debug('clientId'+clientId);
        system.debug('jobId'+jobId);
        try {
            // Validate inputs
            if (candidateIds == null || candidateIds.isEmpty()) {
                throw new AuraHandledException('No candidates selected');
            }
            
            if (clientId == null) {
                throw new AuraHandledException('Client not selected');
            }
            
            // Get client and job details
            Account client = getClientDetails(clientId);
            Job_Position__c job = getJobDetails(jobId);
            
            // Generate share link with candidate IDs
             system.debug('candidateIds111'+candidateIds);
            String shareLink = generateShareLink(candidateIds, jobId);
            
            // Send email
            system.debug('candidateIds222'+candidateIds.size());
            sendShareLinkEmail(client, job, shareLink, candidateIds.size());
            
            return new Map<String, Object>{
                'shareLink' => shareLink,
                'success' => true,
                'message' => 'Share link sent successfully'
            };
            
        } catch (Exception e) {
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }
    
    private static Account getClientDetails(Id clientId) {
        List<Account> clients = [
            SELECT Id, Name, Email__c
            FROM Account
            WHERE Id = :clientId
            LIMIT 1
        ];
        
        if (clients.isEmpty()) {
            throw new AuraHandledException('Client not found');
        }
        
        return clients[0];
    }
    @AuraEnabled(cacheable=true)
    public static Job_Position__c getJobDetails(Id jobId) {
        system.debug('jobId'+jobId);
        List<Job_Position__c> jobs = [
            SELECT Id, Name, Job_Title__c, Job_Location__City__s, 
                   Employment_Type__c, Job_Description__c
            FROM Job_Position__c
            WHERE Id = :jobId
            
            LIMIT 1
        ];
        
        if (jobs.isEmpty()) {
            
            throw new AuraHandledException('Job position not found');
        }
        
        return jobs[0];
    }
    
    @AuraEnabled(cacheable=true)
public static Job_Position__c getJobTitle(Id jobId) {

    System.debug('jobId: ' + jobId);

    Job_Position__c job = [
        SELECT Id, Name, Job_Title__c, Job_Location__City__s,
               Employment_Type__c, Job_Description__c
        FROM Job_Position__c
        WHERE Id = :jobId
        LIMIT 1
    ];

    return job;
}
    private static String generateShareLink(List<Id> candidateIds , Id jobId) {
        system.debug('candidateIds333'+candidateIds);
        String communityUrl = System.Label.ClientFormOrgUrl;
        
        String encodedIds = EncodingUtil.urlEncode(String.join(candidateIds, ','), 'UTF-8');
        //return communityUrl + '/SubmitedCandidate?ids=' + encodedIds;
        return communityUrl + '/SubmitedCandidate?ids=' + encodedIds + '&jobId=' + jobId;
    }
    
    private static void sendShareLinkEmail(Account client, Job_Position__c job, 
                                           String shareLink, Integer candidateCount) {
                                               system.debug('client'+client);
                                               system.debug('job'+job);
                                               system.debug('shareLink'+shareLink);
                                               system.debug('candidateCount'+candidateCount);
          try {
        String emailBody = buildEmailBody(client, job, shareLink, candidateCount);
        String emailSubject = 'Candidate Details - ' + job.Job_Title__c;
 
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[]{ client.Email__c });
            mail.setSubject(emailSubject);
            mail.setHtmlBody(emailBody);
            mail.setPlainTextBody(convertHtmlToPlain(emailBody));
            
            // Set org-wide email address if available
            Id oweaId = getOrgWideEmailId();
            if (oweaId != null) {
                mail.setOrgWideEmailAddressId(oweaId);
            }
            
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
            
        } catch (Exception e) {
            throw new AuraHandledException('Failed to send email: ' + e.getMessage());
        }
    }
    
    private static String buildEmailBody(Account client, Job_Position__c job, 
                                         String shareLink, Integer candidateCount) {
        return '<!DOCTYPE html>' +
               '<html>' +
               '<head>' +
               '    <style>' +
               '        body { font-family: Arial, sans-serif; line-height: 1.6; }' +
               '        .container { max-width: 600px; margin: 0 auto; padding: 20px; }' +
               '        .button {' +
               '            display: inline-block;' +
               '            padding: 12px 24px;' +
               '            background-color: #0070d2;' +
               '            color: white;' +
               '            text-decoration: none;' +
               '            border-radius: 4px;' +
               '            font-weight: bold;' +
               '            margin: 20px 0;' +
               '        }' +
               '        .info-box {' +
               '            background-color: #f3f2f2;' +
               '            padding: 15px;' +
               '            border-radius: 4px;' +
               '            margin: 20px 0;' +
               '        }' +
               '    </style>' +
               '</head>' +
               '<body>' +
               '    <div class="container">' +
               '        <h2>Candidate Details for ' + job.Job_Title__c + '</h2>' +
               '        <p>Dear ' + client.Name + ',</p>' +
               '        <p>You can access the candidate details for the <strong>' + job.Job_Title__c + '</strong> ' +
               '        position using the link below:</p>' +
               '        <div style="text-align: center;">' +
               '            <a href="' + shareLink + '" class="button">View Candidate Details (' + candidateCount + ' candidates)</a>' +
               '        </div>' +
               '        <div class="info-box">' +
               '            <h4>Job Details:</h4>' +
               '            <ul>' +
               '                <li><strong>Position:</strong> ' + job.Job_Title__c + '</li>' +
               '                <li><strong>Location:</strong> ' + job.Job_Location__City__s + '</li>' +
               '                <li><strong>Employment Type:</strong> ' + job.Employment_Type__c + '</li>' +
               '            </ul>' +
               '        </div>' +
               '        <p>If the button doesn\'t work, you can copy and paste this link in your browser:</p>' +
               '        <p><code>' + shareLink + '</code></p>' +
               '        <p>Best regards,<br>Recruitment Team</p>' +
               '    </div>' +
               '</body>' +
               '</html>';
    }
    @TestVisible
    private static String convertHtmlToPlain(String html) {
        return html.replaceAll('<[^>]+>', '')
                   .replaceAll('&nbsp;', ' ')
                   .replaceAll('&amp;', '&')
                   .replaceAll('&lt;', '<')
                   .replaceAll('&gt;', '>')
                   .replaceAll('&quot;', '"')
                   .replaceAll('\\s+', ' ')
                   .trim();
    }
    
    private static Id getOrgWideEmailId() {
        try {
            List<OrgWideEmailAddress> owea = [
                SELECT Id 
                FROM OrgWideEmailAddress 
                WHERE Address = :UserInfo.getUserEmail()
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            return owea.isEmpty() ? null : owea[0].Id;
        } catch (Exception e) {
            return null;
        }
    }
    @AuraEnabled
public static void updateInterviewStatusToShortlisted(List<Id> candidateIds, Id jobId) {

    if (candidateIds == null || candidateIds.isEmpty()) {
        throw new AuraHandledException('No candidates provided for shortlisting');
    }

    try {

        List<Interview__c> interviewsToUpdate = [
            SELECT Id, Interview_Status__c,Interview_Date__c
            FROM Interview__c
            WHERE Candidate_Name__c IN :candidateIds
            AND Job_Position__c = :jobId
        ];

        if (interviewsToUpdate.isEmpty()) {
            throw new AuraHandledException('No interviews found for selected job');
        }

        for (Interview__c interview : interviewsToUpdate) {
            interview.Interview_Status__c = 'Shortlisted';
            interview.Interview_Date__c  = null;
            
        }

        update interviewsToUpdate;

        RecruiterEmailService.sendRecruiterSubmissionEmail(candidateIds, jobId);

    } catch (Exception e) {
        throw new AuraHandledException(
            'Failed to update interview status: ' + e.getMessage()
        );
    }
}


    @AuraEnabled
    public static void saveCandidateFeedback(Map<Id, List<String>> candidateFeedbackMap, Id jobId) {

        if (candidateFeedbackMap == null || candidateFeedbackMap.isEmpty()) {
            throw new AuraHandledException('No feedback data received');
        }

        try {

            List<Interview__c> interviews = [
                SELECT Id, Candidate_Name__c, Feedback__c
                FROM Interview__c
                WHERE Candidate_Name__c IN :candidateFeedbackMap.keySet()
                AND Job_Position__c = :jobId
            ];

            for (Interview__c interview : interviews) {

                List<String> feedbackEntries = candidateFeedbackMap.get(interview.Candidate_Name__c);

                if (feedbackEntries != null && !feedbackEntries.isEmpty()) {

                    String newFeedback = String.join(feedbackEntries, ',\n');

                    // Replace completely instead of append
                    interview.Feedback__c = newFeedback;
                } else {
                    // If no feedback exists in UI, clear field
                    interview.Feedback__c = null;
                }
            }


            update interviews;

        } catch (Exception e) {
            throw new AuraHandledException(
                'Error saving feedback: ' + e.getMessage()
            );
        }
    }
       /* @AuraEnabled
        public static void sendSubmissionEmailToRecruiter(List<Id> candidateIds) {

        if (candidateIds == null || candidateIds.isEmpty()) {
            throw new AuraHandledException('No candidates selected');
        }

        try {
            RecruiterEmailService.sendRecruiterSubmissionEmail(
                new Set<Id>(candidateIds)
            );
        } catch (Exception e) {
            throw new AuraHandledException(
                'Failed to send recruiter email: ' + e.getMessage()
            );
        }
    }*/
@AuraEnabled(cacheable=true)
public static List<Id> getShortlistedCandidates(Id jobId) {

    if (jobId == null) {
        return new List<Id>();
    }

    List<Interview__c> interviews = [
        SELECT Candidate_Name__c
        FROM Interview__c
        WHERE Job_Position__c = :jobId
        AND Interview_Status__c = 'Shortlisted'
    ];

    List<Id> shortlistedIds = new List<Id>();

    for (Interview__c i : interviews) {
        shortlistedIds.add(i.Candidate_Name__c);
    }

    return shortlistedIds;
}
    
    




}