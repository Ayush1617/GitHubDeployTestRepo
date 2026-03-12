/**
 * @File Name          : InterviewCleanupAndReminderBatch.cls
 * @Description        : Batch and schedulable Apex class that deletes old Interview__c records
 *                       and sends reminder emails/notifications to owners before cleanup.
 *                       Uses values from RecruitmentAutomationVariable__mdt for configuration.
 * @Author             : Dixit
 * @Created On         : 09-september-2025
 * @Last Modified On   : 15-october-2025
 */

public class InterviewCleanupAndReminderBatch
    implements Database.Batchable<sObject>, Database.Stateful, Schedulable {

    @TestVisible private static Set<Id> ownerIds = new Set<Id>();
    @TestVisible private Integer reminderDays;
    @TestVisible private Integer cleanupDays;

    /**
     * @description Initializes batch by fetching configuration
     *              and preparing Interview__c records for processing.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {

        RecruitmentAutomationVariable__mdt config =
            RecruitmentAutomationVariable__mdt.getInstance('Sender_Email');

        reminderDays = (config == null) ? 80 : (Integer) config.Reminder_Days_Before_Cleanup__c;
        cleanupDays  = (config == null) ? 90 : (Integer) config.Cleanup_Age_in_Days__c;

        Date reminderDate = System.today().addDays(-reminderDays);
        Date cleanupDate  = System.today().addDays(-cleanupDays);

        return Database.getQueryLocator([
            SELECT Id, OwnerId, CreatedDate
            FROM Interview__c
            WHERE CreatedDate <= :cleanupDate
               OR CreatedDate <= :reminderDate
        ]);
    }

    /**
     * @description Processes Interview__c records:
     *              - Tracks owners
     *              - Sends reminders
     *              - Deletes old records
     */
    public void execute(Database.BatchableContext bc, List<Interview__c> interviews) {

        Date reminderDate = System.today().addDays(-reminderDays);
        Date cleanupDate  = System.today().addDays(-cleanupDays);

        List<Interview__c> toDelete = new List<Interview__c>();
        Set<Id> reminderOwnerIds = new Set<Id>();

        for (Interview__c i : interviews) {

            Date createdDateOnly = i.CreatedDate.date();

            if (i.OwnerId != null) {
                ownerIds.add(i.OwnerId);
            }

            if (createdDateOnly <= cleanupDate) {
                toDelete.add(i);
            }

            if (i.OwnerId != null && createdDateOnly <= reminderDate) {
                reminderOwnerIds.add(i.OwnerId);
            }
        }

        if (!reminderOwnerIds.isEmpty()) {
            sendReminderEmailsAndNotifications(reminderOwnerIds);
        }
        
        if (!Schema.sObjectType.Interview__c.isDeletable()) {
           throw new AuraHandledException('You do not have permission to delete Interview records.');
           }

        if (!toDelete.isEmpty()) {
            delete toDelete;
        }
    }

    /**
     * @description Sends final cleanup completion email
     *              to all involved owners and queue members.
     */
    public void finish(Database.BatchableContext bc) {

        if (ownerIds.isEmpty()) {
            return;
        }

        List<User> users = [
            SELECT Id, Email
            FROM User
            WHERE Id IN :ownerIds
            AND IsActive = true
        ];

        List<Group> queues = [
            SELECT Id
            FROM Group
            WHERE Type = 'Queue'
            AND Id IN :ownerIds
        ];

        Set<String> emailAddresses = new Set<String>();

        for (User u : users) {
            if (u.Email != null) {
                emailAddresses.add(u.Email);
            }
        }

        emailAddresses.addAll(resolveQueueMemberEmails(queues));

        if (emailAddresses.isEmpty()) {
            return;
        }

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>(emailAddresses));
        mail.setSubject('Interview Cleanup Completed');
        mail.setPlainTextBody(
            'Interview records older than ' + cleanupDays +
            ' days have been deleted successfully.'
        );

        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
    }

    /**
     * @description Schedules the batch job.
     */
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new InterviewCleanupAndReminderBatch(), 200);
    }

    /**
     * @description Sends reminder emails and custom notifications
     *              before interview record cleanup.
     */
    @TestVisible
    private void sendReminderEmailsAndNotifications(Set<Id> ownerIds) {

        if (ownerIds.isEmpty()) {
            return;
        }

        List<User> users = [
            SELECT Id, Email
            FROM User
            WHERE Id IN :ownerIds
            AND IsActive = true
        ];

        List<Group> queues = [
            SELECT Id
            FROM Group
            WHERE Type = 'Queue'
            AND Id IN :ownerIds
        ];

        Set<String> emailAddresses = new Set<String>();

        for (User u : users) {
            if (u.Email != null) {
                emailAddresses.add(u.Email);
            }
        }

        emailAddresses.addAll(resolveQueueMemberEmails(queues));

        if (!emailAddresses.isEmpty()) {

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>(emailAddresses));
            mail.setSubject('Reminder: Upcoming Interview Cleanup');
            mail.setPlainTextBody(
                'Interview records older than 3 months will be deleted on ' +
                System.today().addDays(reminderDays)
            );

            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        }

        sendCustomNotifications(users);
    }

    /**
     * @description Sends custom Salesforce notifications to users.
     */
    private void sendCustomNotifications(List<User> users) {

        if (users.isEmpty()) {
            return;
        }

        CustomNotificationType notifType = [
            SELECT Id
            FROM CustomNotificationType
            WHERE DeveloperName = 'Interview_Cleanup_Reminder'
            LIMIT 1
        ];

        if (notifType == null) {
            return;
        }

        for (User u : users) {
            Messaging.CustomNotification cn = new Messaging.CustomNotification();
            cn.setTitle('Upcoming Data Cleanup');
            cn.setBody(
                'Interview records older than 3 months will be deleted on ' +
                System.today().addDays(reminderDays)
            );
            cn.setNotificationTypeId(notifType.Id);
            cn.setSenderId(UserInfo.getUserId());
            cn.setTargetId(u.Id);
            cn.send(new Set<String>{ u.Id });
        }
    }

    /**
     * @description Resolves queue members into active user email addresses.
     */
    private static Set<String> resolveQueueMemberEmails(List<Group> queues) {

        Set<String> emails = new Set<String>();

        if (queues == null || queues.isEmpty()) {
            return emails;
        }

        List<GroupMember> members = [
            SELECT UserOrGroupId
            FROM GroupMember
            WHERE GroupId IN :queues
        ];

        Set<Id> userIds = new Set<Id>();
        for (GroupMember gm : members) {
            if (gm.UserOrGroupId.getSObjectType() == User.sObjectType) {
                userIds.add(gm.UserOrGroupId);
            }
        }

        if (userIds.isEmpty()) {
            return emails;
        }

        for (User u : [
            SELECT Email
            FROM User
            WHERE Id IN :userIds
            AND IsActive = true
        ]) {
            if (u.Email != null) {
                emails.add(u.Email);
            }
        }

        return emails;
    }
}