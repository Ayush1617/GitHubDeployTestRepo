/**
* @File Name : CreateCandidateController.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : November 26, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | November 26, 2025 |   | Initial Version
**/

public with sharing class CreateCandidateController {
    
    @AuraEnabled
    public static String createInterviewRecord(String candidateId, String jobPositionId) {
        try {
            // Validate inputs
            if (String.isBlank(candidateId) || String.isBlank(jobPositionId)) {
                throw new AuraHandledException('Candidate ID and Job Position ID are required');
            }
            
            // Verify candidate exists
            List<Contact> candidates = [SELECT Id, Name FROM Contact WHERE Id = :candidateId LIMIT 1];
            if (candidates.isEmpty()) {
                throw new AuraHandledException('Candidate not found with ID: ' + candidateId);
            }
            
            // Verify job position exists
            List<Job_Position__c> jobPositions = [SELECT Id, Name FROM Job_Position__c WHERE Id = :jobPositionId LIMIT 1];
            if (jobPositions.isEmpty()) {
                throw new AuraHandledException('Job Position not found with ID: ' + jobPositionId);
            }
            
            // Create interview record
            Interview__c interview = new Interview__c(
                Candidate_Name__c = candidateId,
                Job_Position__c = jobPositionId,
                // Add other required fields for interview
                Interview_Status__c = 'New', // Example field
                Interview_Date__c = System.today().addDays(7) // Example field
            );
            
            insert interview;
            return interview.Id;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error creating interview record: ' + e.getMessage());
        }
    }
    
    // Method to get candidate object API name dynamically
    @AuraEnabled
    public static String getCandidateObjectName() {
        return Contact.SObjectType.getDescribe().getName();
    }
    
    // Method to get interview object API name dynamically
    @AuraEnabled
    public static String getInterviewObjectName() {
        return Interview__c.SObjectType.getDescribe().getName();
    }
    
    // Method to automatically create interview when candidate is created from job position
    @AuraEnabled
    public static void createInterviewForNewCandidate(String candidateName, String email, String jobPositionId) {
        try {
            // Resolve Candidate Record Type Id
       	 Id candidateRecordTypeId = Schema.SObjectType.Contact
            .getRecordTypeInfosByDeveloperName()
            .get('Candidate')
            .getRecordTypeId();

            // Create candidate record first
            Contact newCandidate = new Contact(
                LastName    = candidateName,
                Email    = email,
                RecordTypeId = candidateRecordTypeId            
                // Add other required fields
            );
            
            insert as user newCandidate;
            
            // Then create interview record
            createInterviewRecord(newCandidate.Id, jobPositionId);
            
        } catch (Exception e) {
            throw new AuraHandledException('Error creating candidate and interview: ' + e.getMessage());
        }
    }
}