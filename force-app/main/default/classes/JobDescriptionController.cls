/**
 * @description
 * Controller for LWC/Flow integration with OpenAI (ChatGPT)
 * to generate and save job descriptions dynamically.
 *
 * @author AJay Kaurav
 * @since 2025-09-25
 */
public with sharing class JobDescriptionController {
    /**
     * @description
     * Fetches job position details required for job description generation.
     *
     * @param jobId Id of the Job_Position__c record
     * @return Job_Position__c record
     */
@AuraEnabled(cacheable=true)
public static Job_Position__c getJobDetails(Id jobId) {
    Job_Position__c jobp =  [SELECT Id, Skills_Required__c, Job_description__c, Aditional_Skills__c, Qualification__c, Required_Experience_Range__c, Soft_skills__c FROM Job_Position__c WHERE Id = :jobId WITH SECURITY_ENFORCED LIMIT 1];
    System.debug('Generated job record= '+ jobp);
    return jobp;
}

/**
 * @description
 * Generates a professional job description using OpenAI
 * based on provided or existing job data.
 *
 * @param requestJson JSON string containing JobDescriptionRequest data
 * @return Generated job description text
 */
@AuraEnabled
    public static String generateJobDescription(String requestJson) {
        // Deserialize JSON to wrapper class
        JobDescriptionRequest req = (JobDescriptionRequest) JSON.deserialize(
            requestJson, 
            JobDescriptionRequest.class
        );
    Job_Position__c job = [
     SELECT Skills_Required__c, Job_description__c,
        Aditional_Skills__c, Qualification__c,
        Required_Experience_Range__c, Soft_skills__c
     FROM Job_Position__c
     WHERE Id = :req.jobId WITH SECURITY_ENFORCED
     LIMIT 1
     ];

String skills          = req.skillsData    != null ? req.skillsData    : job.Skills_Required__c;
String additionalskill = req.additional    != null ? req.additional    : job.Aditional_Skills__c;
String qualifications  = req.qualification != null ? req.qualification : job.Qualification__c;
String experiences    = req.experience    != null ? req.experience    : job.Required_Experience_Range__c;
String softskill       = req.soft          != null ? req.soft          : job.Soft_skills__c;


    String prompt = 'You are a recruiter assistant. Generate a professional job description for the following skills: ' + skills +
    '. additionalskill: ' + additionalskill +
    '. qualification: ' + qualifications +
    '. Experience: ' + experiences +
    '. softskill: ' + softskill +
    '. Tone: ' + req.tone +
    '. Length: ' + req.length +
    '. Lengthsize: ' + req.lengthsize +
    '. Only include these sections, each on a new line: ' +
    'Job Description:, Key Responsibilities:, Qualifications:, ' +
    'and at the end include: "At Cloudespacio Software Private Limited, we value diversity and are dedicated to fostering an inclusive workplace where every employee can thrive". ' +
    'Do NOT include company overview, "How to apply" section, or any other content.'+ 'Do NOT include any Markdown, bold, asterisks, or other formatting.';
    return OpenAIService.generateJobDescription(prompt);
}

    /**
     * @description
     * Saves the generated job description back to the Job_Position__c record
     * after performing CRUD and FLS validations.
     *
     * @param jobId Id of the Job_Position__c record
     * @param description Generated job description text
     */
@AuraEnabled
public static void saveJobDescription(Id jobId, String description) {
    try {
        if (jobId == null) {
            throw new AuraHandledException('Job Id is required.');
        }

        // CRUD check
        if (!Schema.sObjectType.Job_Position__c.isUpdateable()) {
            throw new AuraHandledException('You do not have permission to update Job records.');
        }

        // FLS check
        if (!Schema.sObjectType.Job_Position__c.fields.Job_Description__c.isUpdateable()) {
            throw new AuraHandledException('You do not have permission to update Job Description.');
        }

        Job_Position__c job = new Job_Position__c(
            Id = jobId,
            Job_Description__c = description
        );

        update job;

    } catch (Exception ex) {
        throw new AuraHandledException('Failed to save job description: ' + ex.getMessage());
    }
}

    /**
     * @description
     * Request object used to pass job description parameters
     * from LWC or Flow to Apex.
     */
public class JobDescriptionRequest {
@AuraEnabled public Id jobId;
@AuraEnabled public String skillsData;
@AuraEnabled public String additional;
@AuraEnabled public String qualification;
@AuraEnabled public String experience;
@AuraEnabled public String soft;
@AuraEnabled public String tone;
@AuraEnabled public String length;
@AuraEnabled public String lengthsize;
}
}