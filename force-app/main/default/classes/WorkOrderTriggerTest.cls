@IsTest
public class WorkOrderTriggerTest {

    @testSetup
    static void setupTestData() {
        // ---------------------------
        // Create Test User
        // ---------------------------
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
         user testUser = new User(
            Alias = 'tuser',
            Email = 'testuser@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            Username = 'testuser' + System.currentTimeMillis() + '@test.com'
        );
        insert testUser;

        // ---------------------------
        // Create Candidates
        // ---------------------------
        Contact cand1 = Recruitment_TestDataFactory.createCandidate('Candidate 1', 'cand1@test.com');
        Contact cand2 = Recruitment_TestDataFactory.createCandidate('Candidate 2', 'cand2@test.com');
        Contact cand3 = Recruitment_TestDataFactory.createCandidate('Candidate 3', 'cand3@test.com');
        Contact cand4 = Recruitment_TestDataFactory.createCandidate('Candidate 4', 'cand4@test.com');
        insert new List<Contact>{cand1, cand2, cand3, cand4};

        // ---------------------------
        // Create Projects
        // ---------------------------
        Project__c proj1 = Recruitment_TestDataFactory.createProject('Project X');
        Project__c proj2 = Recruitment_TestDataFactory.createProject('Project Y');
        insert new List<Project__c>{proj1, proj2};

        // ---------------------------
        // Create Recruiter
        // ---------------------------
        Contact rec = Recruitment_TestDataFactory.createRecruiter('Recruiter X', 'rec@test.com');
        insert rec;

        // ---------------------------
        // Parent-Child Work Orders
        // ---------------------------
        Work_Order__c parentWO = Recruitment_TestDataFactory.createWorkOrder(cand1.Id, proj1.Id, rec.Id);
        insert parentWO;

        Work_Order__c childWO = Recruitment_TestDataFactory.createWorkOrder(cand1.Id, proj1.Id, rec.Id);
        childWO.Parent_Work_OrderID__c = parentWO.Id;
        insert childWO;

        // ---------------------------
        // Additional Work Orders
        // ---------------------------
        insert new List<Work_Order__c>{
            Recruitment_TestDataFactory.createWorkOrder(cand1.Id, proj1.Id, rec.Id),
            Recruitment_TestDataFactory.createWorkOrder(cand1.Id, proj1.Id, rec.Id),
            Recruitment_TestDataFactory.createWorkOrder(cand2.Id, proj1.Id, rec.Id),
            Recruitment_TestDataFactory.createWorkOrder(cand2.Id, proj1.Id, rec.Id),
            new Work_Order__c(Candidate_Name__c = cand3.Id, Recruiter_Name__c = rec.Id, Status__c = 'Working'),
            Recruitment_TestDataFactory.createWorkOrder(cand4.Id, proj1.Id, rec.Id),
            Recruitment_TestDataFactory.createWorkOrder(cand1.Id, proj1.Id, rec.Id),
            Recruitment_TestDataFactory.createWorkOrder(cand2.Id, proj2.Id, rec.Id),
            new Work_Order__c(Project__c = proj1.Id, Recruiter_Name__c = rec.Id, Status__c = 'Working')
        };
    }

    // -------------------------------------------------------------------------
    // Project Count Tests
    // -------------------------------------------------------------------------

    @IsTest
    static void testCandidateProjectCounts() {
        User testUser = [Select Id from User LIMIT 1];
        System.runAs(testUser) {
            List<Work_Order__c> workOrders = [
                SELECT Id, Status__c FROM Work_Order__c WHERE Candidate_Name__r.Name = 'Candidate 4'
            ];

            for (Work_Order__c wo : workOrders) {
                wo.Status__c = 'Completed';
            }

            Test.startTest();
            update workOrders;
            Test.stopTest();

            Contact cand =
                [SELECT No_of_Projects__c FROM Contact WHERE Name = 'Candidate 4' LIMIT 1];

            System.assertEquals(1, cand.No_of_Projects__c);
        }
    }

    @IsTest
    static void testDuplicateProjectsPerCandidate() {
        User testUser = [Select Id from User LIMIT 1];
        System.runAs(testUser) {
            List<Work_Order__c> workOrders = [
                SELECT Id, Status__c FROM Work_Order__c
                WHERE Candidate_Name__r.Name = 'Candidate 4' AND Project__c != NULL
            ];

            for (Work_Order__c wo : workOrders) {
                wo.Status__c = 'Completed';
            }

            Test.startTest();
            update workOrders;
            Test.stopTest();

            Contact cand =
                [SELECT No_of_Projects__c FROM Contact WHERE Name = 'Candidate 4' LIMIT 1];

            System.assertEquals(1, cand.No_of_Projects__c);
        }
    }

    @IsTest
    static void testWorkOrderWithNullProject() {
        User testUser = [Select Id from User LIMIT 1];
        System.runAs(testUser) {
            Work_Order__c wo = [
                SELECT Id, Candidate_Name__c, Project__c
                FROM Work_Order__c WHERE Project__c != NULL LIMIT 1
            ];

            Decimal countBefore =
                [SELECT No_of_Projects__c FROM Contact WHERE Id = :wo.Candidate_Name__c]
                    .No_of_Projects__c;

            wo.Project__c = null;

            Test.startTest();
            update wo;
            Test.stopTest();

            Decimal countAfter =
                [SELECT No_of_Projects__c FROM Contact WHERE Id = :wo.Candidate_Name__c]
                    .No_of_Projects__c;

            System.assert(countAfter <= countBefore);
        }
    }

    @IsTest
    static void testCandidateProjectCountAfterWorkOrderDelete() {
        User testUser = [Select Id from User LIMIT 1];
        System.runAs(testUser) {
            Work_Order__c wo = [
                SELECT Id, Candidate_Name__c FROM Work_Order__c
                WHERE Candidate_Name__r.Name = 'Candidate 4' LIMIT 1
            ];

            wo.Status__c = 'Completed';
            update wo;

            Contact cand =
                [SELECT No_of_Projects__c FROM Contact WHERE Id = :wo.Candidate_Name__c];

            System.assertEquals(1, cand.No_of_Projects__c);

            Test.startTest();
            delete wo;
            Test.stopTest();

            cand =
                [SELECT No_of_Projects__c FROM Contact WHERE Id = :wo.Candidate_Name__c];

            System.assertEquals(0, cand.No_of_Projects__c);
        }
    }

    // -------------------------------------------------------------------------
    // Billable & Parent–Child Tests
    // -------------------------------------------------------------------------

    @IsTest
    static void testCandidateBillableNotAllCompleted() {
        User testUser = [Select Id from User LIMIT 1];
        System.runAs(testUser) {
            List<Work_Order__c> wos = [
                SELECT Id, Status__c FROM Work_Order__c
                WHERE Candidate_Name__r.Name = 'Candidate 1'
            ];

            wos[0].Status__c = 'Completed';
            wos[1].Status__c = 'Working';

            update wos;

            Contact cand =
                [SELECT IsBillable__c FROM Contact WHERE Name = 'Candidate 1'];

            System.assertEquals(true, cand.IsBillable__c);
        }
    }

    @IsTest
    static void testChildWOCompletionCascadesParent() {
        User testUser = [Select Id from User LIMIT 1];
        System.runAs(testUser) {
            Work_Order__c childWO = [
                SELECT Id, Parent_Work_OrderID__c, Candidate_Name__c
                FROM Work_Order__c WHERE Parent_Work_OrderID__c != NULL LIMIT 1
            ];

            Test.startTest();
            childWO.Status__c = 'Completed';
            update childWO;
            Test.stopTest();

            Work_Order__c parentWO =
                [SELECT Status__c FROM Work_Order__c WHERE Id = :childWO.Parent_Work_OrderID__c];

            Contact cand =
                [SELECT IsBillable__c FROM Contact WHERE Id = :childWO.Candidate_Name__c];

            System.assertEquals('Completed', parentWO.Status__c);
        }
    }

    @IsTest
    static void testBulkParentChildCompletionAndCandidateBillable() {
        User testUser = [Select Id from User LIMIT 1];
        System.runAs(testUser) {
            List<Work_Order__c> childWOs = [
                SELECT Id, Parent_Work_OrderID__c, Candidate_Name__c
                FROM Work_Order__c WHERE Parent_Work_OrderID__c != NULL
            ];

            for (Work_Order__c wo : childWOs) {
                wo.Status__c = 'Working';
            }
            update childWOs;

            Set<Id> candidateIds = new Set<Id>();
            for (Work_Order__c wo : childWOs) {
                candidateIds.add(wo.Candidate_Name__c);
            }

            List<Work_Order__c> allWOs = [
                SELECT Id, Status__c FROM Work_Order__c
                WHERE Candidate_Name__c IN :candidateIds
            ];

            for (Work_Order__c wo : allWOs) {
                wo.Status__c = 'Completed';
            }

            Test.startTest();
            update allWOs;
            Test.stopTest();

            List<Contact> cands =
                [SELECT IsBillable__c FROM Contact WHERE Id IN :candidateIds];

            for (Contact c : cands) {
                System.assertEquals(true, c.IsBillable__c);
            }
        }
    }

    @IsTest
    static void testCandidateBillablePartialCompletion() {
        User testUser = [Select Id from User LIMIT 1];
        System.runAs(testUser) {
            Contact cand =
                [SELECT Id FROM Contact WHERE Name = 'Candidate 2' LIMIT 1];

            List<Work_Order__c> wos =
                [SELECT Id, Status__c FROM Work_Order__c WHERE Candidate_Name__c = :cand.Id];

            wos[0].Status__c = 'Completed';

            Test.startTest();
            update wos;
            Test.stopTest();

            Contact updated =
                [SELECT IsBillable__c FROM Contact WHERE Id = :cand.Id];

            System.assertEquals(true, updated.IsBillable__c);
        }
    }
}