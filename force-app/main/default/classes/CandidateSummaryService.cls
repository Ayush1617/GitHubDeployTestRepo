/**
 * @description
 * Service class responsible for generating dynamic HTML summary
 * for Candidate Contact records.
 *
 * @author Kshitiz
 */
public without sharing class CandidateSummaryService {

	/**
     * @description
     * Wrapper class used to transport candidate summary data
     * between internal methods.
     *
     * Encapsulates all required fields needed to build
     * dynamic candidate summary.
     */
    public class CandidateSummaryWrapper {
        public String qualification;
        public String role;
        public String exp;
        public String skills;
        public String softSkills;
        public String canJoin;
    }

/**
     * @description
     * Main entry method used by Lightning components to generate
     * candidate summary.
     *
     * @param recordId
     *        Id of Contact record for which summary needs to be generated.
     *
     * @return String
     *         HTML formatted candidate summary.
     */
    @AuraEnabled
    public static String generateSummary(Id recordId) {

        if (recordId == null) {
            return '';
        }

        List<Contact> records = [
            SELECT Highest_Qualification__c,
                   Designation__c,
                   Total_Experience__c,
                   Skills__c,
                   Soft_Skills__c,
                   Can_join_in__c
            FROM Contact
            WHERE Id = :recordId
            LIMIT 1
        ];

        if(records.isEmpty()){
            return '';
        }

        // Build wrapper
        CandidateSummaryWrapper data = buildWrapper(records[0]);

        // Build summary
        return buildSummary(data);
    }


	/**
     * @description
     * Creates wrapper object from Contact record and applies
     * fallback/default values for missing data.
     * @param c
     *        Contact record.
     * @return CandidateSummaryWrapper
     *         Prepared wrapper object used for summary building.
     */
    private static CandidateSummaryWrapper buildWrapper(Contact c){

        CandidateSummaryWrapper data = new CandidateSummaryWrapper();

        data.qualification = String.isBlank(c.Highest_Qualification__c)
            ? ''
            : c.Highest_Qualification__c;

        data.role = String.isBlank(c.Designation__c)
            ? 'Professional'
            : c.Designation__c;

        data.exp = c.Total_Experience__c != null
            ? String.valueOf(c.Total_Experience__c)
            : '';

        data.skills = String.isBlank(c.Skills__c)
            ? ''
            : c.Skills__c;

        data.softSkills = String.isBlank(c.Soft_Skills__c)
            ? ''
            : c.Soft_Skills__c;

        data.canJoin = c.Can_join_in__c != null
            ? String.valueOf(c.Can_join_in__c)
            : '';

        return data;
    }


 /**
     * @description
     * Builds dynamic HTML candidate summary based on wrapper data.
     *
     * @param data
     *        CandidateSummaryWrapper containing prepared candidate details.
     *
     * @return String
     *         HTML formatted summary string.
     */
    private static String buildSummary(CandidateSummaryWrapper data){

        List<String> parts = new List<String>();

        // Role + Experience
        if (!String.isBlank(data.exp)) {
            parts.add(
                'Working as <b>' + data.role + '</b> with <b>' +
                data.exp + '+ years</b> of experience'
            );
        } else {
            parts.add('<b>' + data.role + '</b>');
        }

        // Qualification
        if (!String.isBlank(data.qualification)) {
            parts[0] += ' and holding <b>' + data.qualification + '</b> Degree';
        }

        // Technical Skills
        if (!String.isBlank(data.skills)) {
            parts.add(' Skilled in <b>' + data.skills + '</b>');
        }

        // Soft Skills
        if (!String.isBlank(data.softSkills)) {
            parts.add(' Soft skills include <b>' + data.softSkills + '</b>');
        }

        // Can Join
        if (!String.isBlank(data.canJoin)) {
            parts.add(' Can join next company in <b>' +
                data.canJoin + ' days</b>');
        }

        return String.join(parts, '.') + '.';
    }
}