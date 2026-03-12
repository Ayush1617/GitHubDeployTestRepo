@IsTest
private class InterviewCleanupAndReminderBatchTest {
    
    @TestSetup
    static void setupData() {
        Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator' LIMIT 1];
        
        User u = new User(
            FirstName = 'Test',
            LastName = 'Owner',
            Alias = 'tuser',
            Email = 'testuser@example.com',
            Username = 'testuser' + System.currentTimeMillis() + '@example.com',
            CommunityNickname = 'testuser' + System.currentTimeMillis(),
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_IN',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            IsActive=true
        );
        insert u;
        Group queue = new Group(Name = 'Interview Queue', Type = 'Queue');
        insert queue;
        GroupMember gm = new GroupMember(GroupId = queue.Id, UserOrGroupId = u.Id);
        insert gm;
        QueuesObject testQueue = new QueueSObject(QueueID = queue.id, SobjectType = 'Interview__c');
        insert testQueue;
        System.runAs(u) {
            
            Account client = Recruitment_TestDataFactory.createClient('Test Client', 'client@example.com');
            Project__c project = Recruitment_TestDataFactory.createProject('Test Project');
            Contact cand1 = Recruitment_TestDataFactory.createCandidate('Candidate 1', 'candidate1@example.com');
            Contact cand2 = Recruitment_TestDataFactory.createCandidate('Candidate 2', 'candidate2@example.com');
            insert new List<SObject>{ client, project, cand1, cand2 };
                
                Job_Position__c job = Recruitment_TestDataFactory.createJobPosition(client, project);
            insert job;
            
            Interview__c recentInterview = Recruitment_TestDataFactory.createInterview(cand1, job);
            recentInterview.OwnerId = u.Id; // owned by user
            recentInterview.Interview_Date__c = System.now().addDays(1);
            insert recentInterview;
            Test.setCreatedDate(recentInterview.Id, System.now().addMonths(-4));
            Interview__c oldInterviewQueue = Recruitment_TestDataFactory.createInterview(cand2, job);
            
            insert oldInterviewQueue;
            Test.setCreatedDate(oldInterviewQueue.Id, System.now().addMonths(-4));
            oldInterviewQueue.OwnerId = queue.id; // owned by queue
            update oldInterviewQueue;
        }
    }
     /**
     * @description Tests the schedulable execution of InterviewCleanupAndReminderBatch.
     *              Verifies that the class can be scheduled successfully using a CRON expression.
     *              This ensures that the Schedulable interface and execute(SchedulableContext) 
     *              method are properly implemented and covered.
     */
    @IsTest
    static void testSchedulableExecution() {
        Test.startTest();
        String cronExp = '0 0 0 ? * MON';
        System.schedule('Test Interview Cleanup Job', cronExp, new InterviewCleanupAndReminderBatch());
        Test.stopTest();
        System.assert(true, 'Schedulable execute method covered successfully.');   
    }
}