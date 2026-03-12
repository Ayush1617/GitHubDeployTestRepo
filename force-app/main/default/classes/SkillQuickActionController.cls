/**
 * @description Controller used by Quick Actions to fetch and update
 *              skills and soft skills for Candidate and Job Position records.
 */
public with sharing class SkillQuickActionController { 

    /**
     * @description Fetches skills and soft skills for Candidate or Job Position.
     * @param candidateId Record Id of Candidate or Job Position
     * @param objName Object name (Candidate | Job Position)
     * @return Map containing skills and softSkills
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getCandidateSkills(
        Id candidateId,
        String objName
    ) {
        validateId(candidateId);

        if (objName == 'Contact') {
            return getCandidateSkillMap(candidateId);
        }

        if (objName == 'Job Position') {
            return getJobPositionSkillMap(candidateId);
        }

        return new Map<String, List<String>>();
    }

    /**
     * @description Updates skills and soft skills for Candidate or Job Position.
     * @param req Wrapper containing update details
     */
    @AuraEnabled
    public static void updateCandidateSkills(SkillUpdateWrapper req) {
        validateRequest(req);

        if (req.objName == 'Contact') {
            updateCandidate(req);
            return;
        }

        if (req.objName == 'Job Position') {
            updateJobPosition(req);
            return;
        }

        throw new AuraHandledException('Invalid object name provided.');
    }

    /**
     * @description Builds skill map from stored comma-separated values.
     * @param skills Hard skills string
     * @param softSkills Soft skills string
     * @return Map with parsed skill lists
     */
    private static Map<String, List<String>> buildSkillMap(
        String skills,
        String softSkills,
        String industrialSkills
    ) {
        Map<String, List<String>> result = new Map<String, List<String>>();
        result.put('skills', parseSkills(skills));
        result.put('softSkills', parseSkills(softSkills));
        result.put('industrialSkills', parseSkills(industrialSkills));
        return result;
    }

    /**
     * @description Parses comma-separated skill values.
     * @param value Comma-separated string
     * @return List of parsed skills
     */
    private static List<String> parseSkills(String value) {
        List<String> values = new List<String>();

        if (String.isBlank(value)) {
            return values;
        }

        for (String s : value.split(',')) {
            if (String.isNotBlank(s)) {
                values.add(s.trim());
            }
        }
        return values;
    }

    /**
     * @description Fetches Candidate skills.
     * @param candidateId Candidate record Id
     * @return Map of skills
     */
    private static Map<String, List<String>> getCandidateSkillMap(Id candidateId) {
        Contact cand = [
            SELECT Skills__c, Soft_Skills__c, Industrial_Knowledge__c
            FROM Contact
            WHERE Id = :candidateId
            WITH USER_MODE
            LIMIT 1
        ];
        return buildSkillMap(cand.Skills__c, cand.Soft_Skills__c, cand.Industrial_Knowledge__c);
    }

    /**
     * @description Fetches Job Position skills.
     * @param recordId Job Position record Id
     * @return Map of skills
     */
    private static Map<String, List<String>> getJobPositionSkillMap(Id recordId) {
        Job_Position__c jp = [
            SELECT Skills_Required__c, Soft_Skills__c, Industrial_Knowledge_Required__c
            FROM Job_Position__c
            WHERE Id = :recordId
            WITH USER_MODE
            LIMIT 1
        ];
        return buildSkillMap(jp.Skills_Required__c, jp.Soft_Skills__c, jp.Industrial_Knowledge_Required__c);
    }

    /**
     * @description Updates Candidate skills.
     * @param req Skill update request
     */
    private static void updateCandidate(SkillUpdateWrapper req) {
        Contact cand = new Contact(
            Id = req.recordId,
            Skills__c = joinValues(req.skills),
            Soft_Skills__c = joinValues(req.softSkills),
            Industrial_Knowledge__c = joinValues(req.industrialSkills)
        );
        Database.update(cand, AccessLevel.USER_MODE);
    }

    /**
     * @description Updates Job Position skills.
     * @param req Skill update request
     */
    private static void updateJobPosition(SkillUpdateWrapper req) {
        Job_Position__c jp = new Job_Position__c(
            Id = req.recordId,
            Skills_Required__c = joinValues(req.skills),
            Soft_Skills__c = joinValues(req.softSkills),
            Industrial_Knowledge_Required__c = joinValues(req.industrialSkills)
        );
        Database.update(jp, AccessLevel.USER_MODE);
    }

    /**
     * @description Joins list values into a comma-separated string.
     * @param values List of strings
     * @return Joined string or null
     */
    private static String joinValues(List<String> values) {  
        return (values != null && !values.isEmpty())
            ? String.join(values, ', ')
            : null;
    }

    /**
     * @description Validates record Id.
     * @param recordId Record Id to validate
     */
    private static void validateId(Id recordId) {
        if (recordId == null) {
            throw new AuraHandledException('Candidate Id is required.');
        }
    }

    /**
     * @description Validates update request wrapper.
     * @param req Skill update wrapper
     */
    private static void validateRequest(SkillUpdateWrapper req) {
        if (req == null || req.recordId == null) {
            throw new AuraHandledException('Request object or Id is missing.');
        }
    }

    /**
     * @description Wrapper used to update skills and soft skills.
     */
    public class SkillUpdateWrapper {

        /**
         * @description Record Id of Candidate or Job Position.
         */
        @AuraEnabled
        public Id recordId { get; set; }

        /**
         * @description Object name (Candidate or Job Position).
         */
        @AuraEnabled
        public String objName { get; set; }

        /**
         * @description List of hard skills.
         */
        @AuraEnabled
        public List<String> skills { get; set; }

        /**
         * @description List of soft skills.
         */
        @AuraEnabled
        public List<String> softSkills { get; set; }

         /**
         * @description List of Industrial skills.
         */
        @AuraEnabled
        public List<String> industrialSkills { get; set; }
    }
}