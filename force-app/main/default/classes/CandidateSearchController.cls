/**
 * @description Controller providing candidate search, job position retrieval,
 *              and assignment of candidates to job positions.
 */
public with sharing class CandidateSearchController {
	
	// Record Type Developer Names - Use these for getRecordTypeInfosByDeveloperName()
    private static final String CANDIDATE_RECORD_TYPE_DEV_NAME = 'Candidate'; // Use actual Developer Name

    /**
     * @description Wrapper class containing all search parameters used for candidate filtering.
     */
    public class CandidateSearchParams {

    /**
     * @description Comma-separated list of skills to filter candidates by.
     */
    @AuraEnabled public String skillQuery { get; set; }

    /**
     * @description Minimum total experience required.
     */
    @AuraEnabled public Decimal minExperience { get; set; }

    /**
     * @description Maximum total experience allowed.
     */
    @AuraEnabled public Decimal maxExperience { get; set; }

    /**
     * @description Minimum current CTC of the candidate.
     */
    @AuraEnabled public Decimal minSalary { get; set; }

    /**
     * @description Maximum current CTC of the candidate.
     */
    @AuraEnabled public Decimal maxSalary { get; set; }

    /**
     * @description Phone number filter (partial match allowed).
     */
    @AuraEnabled public String phone { get; set; }

    /**
     * @description Current location of the candidate.
     */
    @AuraEnabled public String currentLocation { get; set; }

    /**
     * @description Gender filter for the candidate.
     */
    @AuraEnabled public String gender { get; set; }

    /**
     * @description Notice period filter for the candidate.
     */
    @AuraEnabled public String noticePeriod { get; set; }

    /**
     * @description Highest educational qualification.
     */
    @AuraEnabled public String highestQualification { get; set; }

    /**
     * @description Institute name used as a filter.
     */
    @AuraEnabled public String instituteName { get; set; }

    /**
     * @description Language proficiency filter.
     */
    @AuraEnabled public String languageKnown { get; set; }

    /**
     * @description Preferred job location of the candidate.
     */
    @AuraEnabled public String preferredLocation { get; set; }

    /**
     * @description Expected CTC filter for candidate selection.
     */
    @AuraEnabled public Decimal expectedCTC { get; set; }

    /**
     * @description Number of days within which the candidate can join.
     */
    @AuraEnabled public Integer canJoinIn { get; set; }
}

        /**
        * @description Performs dynamic candidate search based on multiple filter criteria such as
        *              experience, salary, location, gender, notice period, qualification, etc.
        *              Executes SOQL using a secure query builder and performs additional
        *              in-memory skill matching.
        *
        * @param params CandidateSearchParams – wrapper object containing all search filters.
        *
        * @return List<Contact> – Final list of candidates matching both SOQL and skill criteria.
        */
        @AuraEnabled
        public static List<Contact> searchCandidates(CandidateSearchParams params) {
			
            // Build safe SOQL
            String query = buildSOQL(params);

            // Execute using bind variables (PMD safe)
            List<Contact> candidates = Database.query(query);

            // Apply in-memory skill filtering
            return filterBySkills(candidates, params.skillQuery);
        }

		 /**
     * @description
     * Helper method to get record type ID by name for any object.
     * Tries Developer Name first, then falls back to Label.
     *
     * @param objectName
     *        API name of the object.
     *
     * @param recordTypeName
     *        Developer Name or Label of the record type.
     *
     * @return Id
     *         Record type ID.
     *
     * @throws AuraHandledException
     *         If record type is not found.
     
    private static Id getRecordTypeId(String objectName, String recordTypeName) {
        try {
            SObjectType objType = Schema.getGlobalDescribe().get(objectName);
            if (objType == null) {
                throw new AuraHandledException('Object ' + objectName + ' not found.');
            }
            
            // First try to get by Developer Name
            Map<String, Schema.RecordTypeInfo> recordTypesByDevName = objType.getDescribe().getRecordTypeInfosByDeveloperName();
            if (recordTypesByDevName.containsKey(recordTypeName)) {
                return recordTypesByDevName.get(recordTypeName).getRecordTypeId();
            }
            
            // If not found by Developer Name, try by Label
            Map<String, Schema.RecordTypeInfo> recordTypesByLabel = objType.getDescribe().getRecordTypeInfosByName();
            if (recordTypesByLabel.containsKey(recordTypeName)) {
                return recordTypesByLabel.get(recordTypeName).getRecordTypeId();
            }
            
            throw new AuraHandledException('Record type "' + recordTypeName + '" not found for ' + objectName);
        } catch (Exception e) {
            throw new AuraHandledException('Error getting record type: ' + e.getMessage());
        }
    } */

       /**
        * @description Builds a fully secure, PMD-compliant SOQL query string based on provided filter parameters.
        *
        * @param params CandidateSearchParams – The filtering criteria for the SOQL query.
        * @return String – A complete SOQL query ready for execution.
        */
        private static String buildSOQL(CandidateSearchParams params) {
        
            List<String> whereConditions = new List<String>();
        
            // Filter by Candidate record type directly
            whereConditions.add(
                'RecordType.DeveloperName = \'' +
                String.escapeSingleQuotes(CANDIDATE_RECORD_TYPE_DEV_NAME) +
                '\''
            );        
            addExperienceFilters(params, whereConditions);
            addSalaryFilters(params, whereConditions);
            addTextLikeFilters(params, whereConditions);
            addExactMatchFilters(params, whereConditions);
        
            String whereClause = ' WHERE ' + String.join(whereConditions, ' AND ');
        
            return
                'SELECT Id, Name, Skills__c, Total_Experience__c, Current_CTC__c, RecordTypeId, ' +
                'Phone, Current_Location__c, Gender__c, Notice_Period__c, LinkedIn_Profile__c, ' +
                'Highest_Qualification__c, Institute_Name__c, Preferred_Location__c, Expected_CTC__c, ' +
                'Can_join_in__c, Language_Known__c, CreatedDate, Rating__c, ' +
                'LastModifiedDate, Total_Experience_txt__c ' +
                'FROM Contact' +
                whereClause;
        }

            private static void addExperienceFilters(CandidateSearchParams params, List<String> conditions) {

                if (params.minExperience != null) {
                    conditions.add('Total_Experience__c >= ' + params.minExperience);
                }

                if (params.maxExperience != null) {
                    conditions.add('Total_Experience__c <= ' + params.maxExperience);
                }
            }


            private static void addSalaryFilters(CandidateSearchParams params, List<String> conditions) {
                if (params.minSalary != null) {
                    conditions.add('Current_CTC__c >= ' + params.minSalary);
                }
                if (params.maxSalary != null) {
                    conditions.add('Current_CTC__c <= ' + params.maxSalary);
                }
            }


        private static void addTextLikeFilters(CandidateSearchParams params, List<String> conditions) {
            conditions.addAll(createLikeFilter('Phone', params.phone));
            conditions.addAll(createLikeFilter('Current_Location__c', params.currentLocation));
            conditions.addAll(createLikeFilter('Highest_Qualification__c', params.highestQualification));
            conditions.addAll(createLikeFilter('Language_Known__c', params.languageKnown));
            conditions.addAll(createLikeFilter('Institute_Name__c', params.instituteName));
            conditions.addAll(createLikeFilter('Preferred_Location__c', params.preferredLocation));
        }

       private static void addExactMatchFilters(CandidateSearchParams params, List<String> conditions) {

            // Gender (string) — must be escaped
            if (!String.isBlank(params.gender) && params.gender != 'Any') {
                String safeGender = String.escapeSingleQuotes(params.gender);
                conditions.add('Gender__c = \'' + safeGender + '\'');
            }

            // Notice Period (string) — must be escaped
            if (!String.isBlank(params.noticePeriod) && params.noticePeriod != 'Any') {
                String safeNotice = String.escapeSingleQuotes(params.noticePeriod);
                conditions.add('Notice_Period__c = \'' + safeNotice + '\'');
            }

            // Expected CTC (number) — safe to concatenate
            if (params.expectedCTC != null) {
                conditions.add('Expected_CTC__c <= ' + params.expectedCTC);
            }

            // Can Join In (number) — safe to concatenate
            if (params.canJoinIn != null) {
                conditions.add('Can_join_in__c <= ' + params.canJoinIn);
            }
        }


        /**
        * @description Generates a dynamic LIKE filter using bind variables. Ensures the pattern
        *              is sanitized and prevents SOQL injection.
        *
        * @param fieldName String – The field used in the LIKE clause.
        * @param value String – The user-provided input to match.
        *
        * @return List<String> – A list containing the filter clause if applicable, else empty.
        */
        private static List<String> createLikeFilter(String fieldName, String value) {
            List<String> conditions = new List<String>();

            if (!String.isBlank(value)) {
                String safeValue = String.escapeSingleQuotes(value);
                conditions.add(fieldName + ' LIKE \'%' + safeValue + '%\'');
            }

            return conditions;
        }

        /**
        * @description Performs in-memory skill matching after SOQL filtering.
        *
        * @param candidates List<Contact> – The initial SOQL result list.
        * @param skillQuery String – Comma-separated skill search terms.
        *
        * @return List<Contact> – Filtered list where at least one skill matches.
        */
        private static List<Contact> filterBySkills(List<Contact> candidates, String skillQuery) {

            if (String.isBlank(skillQuery)) {
                return candidates;
            }

            // Convert comma-separated skills into a normalized list
            List<String> skills = new List<String>();
            for (String s : skillQuery.split(',')) {
                if (!String.isBlank(s)) {
                    skills.add(s.trim().toLowerCase());
                }
            }

            List<Contact> filtered = new List<Contact>();

            for (Contact c : candidates) {
                if (c.Skills__c == null) {continue;}

                String skillString = c.Skills__c.toLowerCase();
                Boolean matched = false;
                for (String s : skills) {
                    if (skillString.contains(s)) {
                        matched = true;
                        break;
                    }
                }

                if (matched) {
                    filtered.add(c);
                }
            }

            return filtered;
        }

    /**
     * @description Retrieves all open job positions based on an optional search key.
     *
     * @param searchKey String - Partial text used to match job name or title.
     *
     * @return List<Job_Position__c> - List of open job positions.
     */
    @AuraEnabled(cacheable=true)
    public static List<Job_Position__c> getOpenJobPositions(String searchKey) {
        String key = '%' + searchKey + '%';

        return [
            SELECT Id, Name, Job_Title__c, Client_Name__r.Name, Status__c, Total_Openings__c, Required_Experience_Range__c, CreatedDate
            FROM Job_Position__c
            WHERE Status__c = 'Open'
            AND (Name LIKE :key OR Job_Title__c LIKE :key) WITH USER_MODE
            ORDER BY CreatedDate DESC
        ];
    }

    /**
     * @description Creates interview records associating selected candidates
     *              with selected job positions.
     *
     * @param candidateIds List<Id> - Contact record IDs.
     * @param jobPositionIds List<Id> - Job_Position__c record IDs.
     */
    @AuraEnabled
    public static void assignCandidatesToJobs(List<Id> candidateIds, List<Id> jobPositionIds) {

        List<Interview__c> interviews = new List<Interview__c>();

        for (Id jobId : jobPositionIds) {
            for (Id candidateId : candidateIds) {
                interviews.add(new Interview__c(
                    Candidate_Name__c = candidateId,
                    Job_Position__c = jobId,
                    Interview_Status__c = 'New'
                ));
            }
        }

        if (!interviews.isEmpty()) {
            Database.insert(interviews, false, AccessLevel.USER_MODE);
        }
    }
}