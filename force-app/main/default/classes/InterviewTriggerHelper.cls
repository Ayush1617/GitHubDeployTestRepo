/**
 * @Created By (Date) : Admin (26 Aug, 2025)
 * @description      : Trigger Helper Class for Interview__c Object.
 *                     Contains business logic for interview status changes,
 *                     work order creation, chatter posting, email notification,
 *                     task creation, and interview event handling.
 * @author           : Admin
 * @since            : 26-Aug-2025
 * Modifications Log :
 * Ver   Date         Author     Modification
 * 1.0   26 Aug, 2025 Admin      Initial Version
 */
public without sharing class InterviewTriggerHelper {

   /**
    * @description Wrapper Class to hold values.
    */
        public class WorkOrderEmailContext {
            public String recipientName;
            public String candidateName;
            public String clientName;
            public String jobPosition;
            public String workOrderName;
            public String workOrderLink;
            public String orgName;
        }

    /**
     * @description Compares Trigger.new and Trigger.oldMap.
     *              If Interview status or round changes and feedback exists,
     *              creates a Chatter post on the related Candidate record.
     *
     * @param newList List of Interview__c records from Trigger.new
     * @param oldMap  Map of Interview__c records from Trigger.oldMap
     */
    public static void handleStatusChange(
        List<Interview__c> newList,
        Map<Id, Interview__c> oldMap
    ) {
        Set<Id> interviewsToQuery = new Set<Id>();

        for (Interview__c newRec : newList) {
            Interview__c oldRec = oldMap.get(newRec.Id);

            if (
                String.isNotBlank(newRec.Interview_Status__c) &&
                newRec.Candidate_Name__c != null &&
                String.isNotBlank(newRec.Feedback__c) &&
                (
                    newRec.Interview_Status__c != oldRec.Interview_Status__c ||
                    newRec.Round__c != oldRec.Round__c
                )
            ) {
                interviewsToQuery.add(newRec.Id);
            }
        }

        if (interviewsToQuery.isEmpty()) {
            return;
        }

       createInterviewFeedbackPosts(interviewsToQuery);
    }
    
    /**
     * @description
     * Creates Chatter text posts on related Candidate records
     * containing interview feedback details.
     *
     * @param interviewIds
     * Set of Interview__c record Ids for which feedback
     * posts need to be created.
     */
    public static void createInterviewFeedbackPosts(Set<Id> interviewIds) {

        List<Interview__c> interviewList = [
            SELECT Id, Feedback__c, Interview_Status__c, Round__c,
                   Candidate_Name__c,
                   Job_Position__r.Client_Name__r.Name,
                   Job_Position__r.Job_Title__c
            FROM Interview__c
            WHERE Id IN :interviewIds
            WITH SYSTEM_MODE
        ];

        List<FeedItem> chatterPosts = new List<FeedItem>();
        for (Interview__c rec : interviewList) {
            FeedItem post = new FeedItem();
            post.ParentId = rec.Candidate_Name__c;
            post.Type = 'TextPost';
            post.IsRichText = true;
			post.NetworkScope = 'AllNetworks';
            post.Visibility   = 'AllUsers';
            String body =
                'Interview feedback by <b>' + rec.Job_Position__r.Client_Name__r.Name +
                '</b> for <b>' + rec.Job_Position__r.Job_Title__c +
                '</b> job at the <b>' + rec.Interview_Status__c + '</b> stage';

            if (rec.Round__c != null) {
                body += ' in the <b>' + rec.Round__c + '</b> round.';
            } else {
                body += '.';
            }

            body += '<p>-</p><p><b>Feedback:</b> ' + rec.Feedback__c + '</p>';
            post.Body = body;

            chatterPosts.add(post);
        }

        if (!chatterPosts.isEmpty()) {
            System.enqueueJob(new InterviewChatterQueue(chatterPosts));
        }
    }

   /**
    * @description Identifies Interview__c records whose status
    *              changed to "Hired" and delegates Work Order creation.
    *
    * @param newList List of Interview__c records from Trigger.new
    * @param oldMap  Map of Interview__c records from Trigger.oldMap
    */
    public static void createWorkOrder(
        List<Interview__c> newList,
        Map<Id, Interview__c> oldMap
    ) {
        Set<Id> interviewsToProcess = new Set<Id>();

        for (Interview__c newRec : newList) {
            Interview__c oldRec = oldMap.get(newRec.Id);

            if (
                String.isNotBlank(newRec.Interview_Status__c) &&
                newRec.Interview_Status__c == RecruitmentApp_Constants.INTERVIEW_STATUS_HIRED &&
                oldRec.Interview_Status__c != newRec.Interview_Status__c
            ) {
                interviewsToProcess.add(newRec.Id);
            }
        }

        if (interviewsToProcess.isEmpty()) {
            return;
        }

        InterviewTriggerHelperAssist.processWorkOrderCreation(interviewsToProcess);
    }

    /**
     * @description Inserts records using Database.insert and returns save results.
     *
     * @param recordsForInsert List of SObjects to insert
     * @return Database.SaveResult list
     */
    public static Database.SaveResult[] insertrecord(
        List<SObject> recordsForInsert) {
        Database.SaveResult[] srList = Database.insert(recordsForInsert, true);

        for (Database.SaveResult sr : srList) {
            if (sr.isSuccess()) {
                continue;
            } else {
                throw new AuraHandledException(
                    'Insert failed: ' + sr.getErrors()[0].getMessage());
            }
        }
        return srList;
    }

    /**
    * @description Sends email notifications and creates Tasks
    *              for Work Order owners.
    *
    * @param workOrderIds List of Work_Order__c Ids
    * @param interviewIds List of Interview__c Ids
    */
    public static void emailToOwner(
        List<Id> workOrderIds,
        List<Id> interviewIds
    ) {
        Map<Id, Work_Order__c> woMap = new Map<Id, Work_Order__c>([
            SELECT Id, Name, Status__c, Owner.Email, Owner.Name, OwnerId, Candidate_Name__c
            FROM Work_Order__c WHERE Id IN :workOrderIds WITH SYSTEM_MODE ]);

        Map<Id, Interview__c> intMap = new Map<Id, Interview__c>([
            SELECT Id, Candidate_Name__c, Candidate_Name__r.Name, Job_Position__r.Job_Title__c, Job_Position__r.Client_Name__r.Name
            FROM Interview__c WHERE Id IN :interviewIds WITH USER_MODE ]);

        String orgName = getOrgInfo();
        String baseUrl = getBaseOrgUrl();

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        List<Task> tasks = new List<Task>();

        for (Id woId : workOrderIds) {
            Work_Order__c wo = woMap.get(woId);
            Interview__c interview = intMap.get(
                interviewIds[workOrderIds.indexOf(woId)]
            );

            String emailSubject =
                'Collect signed agreement from candidate: ' +
                interview.Candidate_Name__r.Name;
            WorkOrderEmailContext ctx = new WorkOrderEmailContext();
            ctx.recipientName = wo.Owner.Name;
            ctx.candidateName = interview.Candidate_Name__r.Name;
            ctx.clientName = interview.Job_Position__r.Client_Name__r.Name;
            ctx.jobPosition = interview.Job_Position__r.Job_Title__c;
            ctx.workOrderName = wo.Name;
            ctx.workOrderLink = baseUrl + '/' + wo.Id;
            ctx.orgName = orgName;

            String emailBody = workOrderEmailBody(ctx);

            if (String.isNotBlank(wo.Owner.Email)) {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new String[] { wo.Owner.Email });
                mail.setSubject(emailSubject);
                mail.setHtmlBody(emailBody);
                mail.setOrgWideEmailAddressId(getOrgWideEmailIdForCurrentUser());
                emails.add(mail);
            }
            tasks.add(buildFollowUpTask(wo, emailSubject));
        }

        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }
        if (!tasks.isEmpty()) {
            Database.insert(tasks, AccessLevel.USER_MODE);
        }
    }

    /**
    * @description
    * Builds and returns a follow-up Task assigned to the Work Order owner.
    * The Task reminds the owner to collect the signed agreement from
    * the candidate and upload it to the related Work Order.
    *
    * @param wo
    *        Work_Order__c record for which the follow-up Task is created.
    *
    * @param subject
    *        Subject line to be set on the Task.
    *
    * @return Task
    *         Configured Task record ready for insertion.
    */
    private static Task buildFollowUpTask(
        Work_Order__c wo,
        String subject
    ) {
        Id taskRecordTypeId = Schema.SObjectType.Task
            .getRecordTypeInfosByDeveloperName()
            .get('Recruitment_Operations')
            .getRecordTypeId();

        Task t = new Task();
        t.Subject = subject;
        t.Description = 'Collect signed agreement and upload it.';
        t.ActivityDate = Date.today().addDays(2);
        t.OwnerId = wo.OwnerId;
        t.WhatId = wo.Id;
        t.Candidate_Name__c = wo.Candidate_Name__c;
        t.RecordTypeId = taskRecordTypeId;
        return t;
    }

    /**
     * @description
     * Retrieves the base domain URL of the current Salesforce organization.
     * @return
     * String representing the base organization domain URL.
     */
    private static String getBaseOrgUrl() {
        return String.valueOf(URL.getOrgDomainUrl());
    }

    /**
     * @description
     * Retrieves basic Organization information for the current Salesforce org.
     *
     * @return
     * Organization record representing the current Salesforce org.
     */
    public static String getOrgInfo() {
         Organization orgInfo = [  SELECT Name
            FROM Organization
            WITH USER_MODE
            LIMIT 1  ];
            String orgName = orgInfo.Name;
        return orgName;
    }

    /**
     * @description Returns Org-Wide Email Address Id
     *              matching the current user's email.
     *
     * @return OrgWideEmailAddress Id
     */
    public static Id getOrgWideEmailIdForCurrentUser() {
        List<OrgWideEmailAddress> oweaList = [
            SELECT Id
            FROM OrgWideEmailAddress
            WHERE IsAllowAllProfiles = true WITH USER_MODE
            LIMIT 1
        ];
    
        if (oweaList.isEmpty()) {
            return null; // ✔ safe fallback
        }
    
        return oweaList[0].Id;
    }

    /**
    * @description Builds the HTML email body used for
    *              Work Order notification emails.
    *
    * @param context Wrapper containing all email-related values
    *
    * @return HTML formatted email body
    */
    public static String workOrderEmailBody(WorkOrderEmailContext context) {

        return
            '<p>Hello ' + context.recipientName + ',</p>' +
            '<p>A new work order has been created:</p>' +
            '<p><b>Candidate:</b> ' + context.candidateName + '<br/>' +
            '<b>Client:</b> ' + context.clientName + '<br/>' +
            '<b>Job:</b> ' + context.jobPosition + '<br/>' +
            '<b>Work Order:</b> <a href="' + context.workOrderLink + '">' +
                context.workOrderName + '</a></p>' +
            '<p>Regards,<br/>' + context.orgName + '</p>';
    }

   /**
    * @description Entry point for Interview Event handling.
    *              Determines insert/update context and delegates processing.
    *
    * @param newList List of Interview__c records
    * @param oldMap  Old Interview__c map (null for insert)
    */
    public static void handleInterviewEvents(
        List<Interview__c> newList,
        Map<Id, Interview__c> oldMap
    ) {
        Set<Id> interviewIds;

        if (oldMap == null) {
            // Insert context
            interviewIds =
                InterviewTriggerHelperAssist.getInterviewIdsForInsert(newList);

            if (interviewIds.isEmpty()) {
                return;
            }

            InterviewTriggerHelperHelp.processInterviewInsertEvents(
                newList,
                interviewIds
            );
        } else {
            // Update context
            interviewIds =
                InterviewTriggerHelperAssist.getInterviewIdsForUpdate(
                    newList,
                    oldMap
                );

            if (interviewIds.isEmpty()) {
                return;
            }

            InterviewTriggerHelperHelp.processInterviewUpdateEvents(
                newList,
                interviewIds
            );
        }
    }
}