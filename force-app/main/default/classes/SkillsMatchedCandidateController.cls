/**
* @File Name : SkillsMatchedCandidateController.cls
* @Author    : Ajay Kaurav
* @Last Modified On : December 26, 2025
* @Description :
* Dynamically matches candidates to Job Position based on
* Skills, Experience, Location and Availability.
*/

public without sharing class SkillsMatchedCandidateController { 
    
    /**
     * @description
     * Retrieves a ranked list of eligible candidates matched against a Job Position.
     * Performs dynamic skill matching and calculates weighted match scores based on
     * skills, experience, location, and availability.
     *
     * @param jobPositionId
     *        Id of the Job_Position__c record for which candidates are evaluated.
     *
     * @return List<CandidateWrapper>
     *         Sorted list of matched candidates with match percentage breakdown.
     */
    @AuraEnabled(cacheable=true)
    public static List<CandidateWrapper> getMatchedCandidates(Id jobPositionId) {
        
        Job_Position__c job = fetchJobPosition(jobPositionId);
        
        JobSkillContext jobSkillContext = prepareJobSkills(job);
        
        Set<Id> assignedCandidateIds = fetchAssignedCandidateIds(jobPositionId);
        
        List<Contact> candidates = fetchCandidates();
        
        List<CandidateWrapper> result = new List<CandidateWrapper>();
        
        for (Contact c : candidates) {
            
            if (!isCandidateEligible(c, assignedCandidateIds)) {
                continue;
            }
            
            SkillMatchResult skillMatch = calculateCandidateSkillMatch(
                c.Skills__c,
                jobSkillContext.jobSkills
            );
            
            if (!skillMatch.isMatched) {
                continue;
            }
            
            MatchScore score = calculateDynamicMatchScore(
                c,
                job,
                skillMatch.matchedCount,
                jobSkillContext.totalJobSkills
            );
            
            result.add(buildCandidateWrapper(c, skillMatch, score));
        }
        
        result.sort();
        return result;
    }

    /**
     * @description
     * Fetches the Job Position record used for candidate matching.
     * Applies user-mode security to enforce record-level access.
     *
     * @param jobPositionId
     *        Id of the Job_Position__c record.
     *
     * @return Job_Position__c
     *         Job Position record with skill, experience, and location attributes.
     */
    private static Job_Position__c fetchJobPosition(Id jobPositionId) {
        return [
            SELECT Id, Name,
            Aditional_Skills__c,
            Soft_skills__c,
            Skills_Required__c,
            Minimum_Experience_Required__c,
            Maximum_Experience_Required__c,
            Work_Location__c,
            Industrial_Knowledge_Required__c
            FROM Job_Position__c
            WHERE Id = :jobPositionId WITH USER_MODE
            LIMIT 1
        ];
    }

    /**
     * @description
     * Helper container for normalized job skill data.
     * Stores the unique skill set and total skill count used in matching calculations.
     */
    private class JobSkillContext {
        Set<String> jobSkills;
        Integer totalJobSkills;
        
        JobSkillContext(Set<String> skills, Integer total) {
            jobSkills = skills;
            totalJobSkills = total;
        }
    }

    /**
     * @description
     * Extracts and normalizes required job skills from multiple Job Position fields.
     * Converts skills to lowercase and trims whitespace for consistent matching.
     *
     * @param job
     *        Job Position record containing skill definitions.
     *
     * @return JobSkillContext
     *         Normalized job skill set and total skill count.
     */
    private static JobSkillContext prepareJobSkills(Job_Position__c job) {
        
        Set<String> jobSkills = new Set<String>();
        Integer totalJobSkills = 0;
        
        List<String> skillFields = new List<String>{
            job.Aditional_Skills__c,
                job.Soft_skills__c,
                job.Skills_Required__c
                };
                    
                    for (String field : skillFields) {
                        if (String.isBlank(field)) {continue;}
                        
                        for (String s : field.toLowerCase().split(',')) {
                            String trimmed = s.trim();
                            if (String.isNotBlank(trimmed)) {
                                jobSkills.add(trimmed);
                                totalJobSkills++;
                            }
                        }
                    }
        
        return new JobSkillContext(jobSkills, totalJobSkills);
    }

    /**
     * @description
     * Retrieves candidate Ids already assigned to a Job Position.
     * Used to prevent duplicate interview creation.
     *
     * @param jobPositionId
     *        Id of the Job_Position__c record.
     *
     * @return Set<Id>
     *         Set of Contact Ids already associated with the job.
     */
    private static Set<Id> fetchAssignedCandidateIds(Id jobPositionId) {
        
        Set<Id> result = new Set<Id>();
        
        for (Interview__c iv : [
            SELECT Candidate_Name__c
            FROM Interview__c
            WHERE Job_Position__c = :jobPositionId WITH USER_MODE
        ]) {
            result.add(iv.Candidate_Name__c);
        }
        
        return result;
    }

    /**
     * @description
     * Retrieves all Contact records with Candidate record type.
     * Applies user-mode security to enforce access permissions.
     *
     * @return List<Contact>
     *         List of candidate Contact records.
     */
    private static List<Contact> fetchCandidates() {
        return [
            SELECT Id, Name,
            Skills__c,
            Soft_Skills__c,
            Rating__c,
            Total_Experience__c,
            Relevant_Experience__c,
            Current_Location__c,
            Preferred_Location__c,
            Notice_Period__c,
            RecordType.Name, 
            LastModifiedDate,
            Industrial_Knowledge__c
            FROM Contact
            WHERE RecordType.Name  = 'Candidate' WITH USER_MODE
        ];
    }

    /**
     * @description
     * Determines whether a candidate is eligible for matching.
     * Excludes candidates already assigned to the job or without skill data.
     *
     * @param c
     *        Candidate Contact record.
     * @param assignedCandidateIds
     *        Set of candidate Ids already assigned to the job.
     *
     * @return Boolean
     *         True if the candidate is eligible for matching.
     */
    private static Boolean isCandidateEligible(
        Contact c,
        Set<Id> assignedCandidateIds
    ) {
        return !assignedCandidateIds.contains(c.Id)
            && String.isNotBlank(c.Skills__c);
    }

    /**
     * @description
     * Result container for candidate skill matching.
     * Stores matched skill set and match count.
     */
    private class SkillMatchResult {
        Boolean isMatched;
        Set<String> matchedSkills;
        Integer matchedCount;
        
        SkillMatchResult(Boolean matched, Set<String> skills) {
            isMatched = matched;
            matchedSkills = skills;
            matchedCount = skills.size();
        }
    }

    /**
     * @description
     * Compares candidate skills with job-required skills.
     * Determines whether at least one skill matches and returns matched skills.
     *
     * @param candidateSkills
     *        Comma-separated candidate skill string.
     * @param jobSkills
     *        Normalized set of job-required skills.
     *
     * @return SkillMatchResult
     *         Skill match outcome and matched skill set.
     */
    private static SkillMatchResult calculateCandidateSkillMatch(
        String candidateSkills,
        Set<String> jobSkills
    ) {
        Set<String> candidateSkillSet = new Set<String>();
        
        for (String s : candidateSkills.toLowerCase().split(',')) {
            String trimmed = s.trim();
            if (String.isNotBlank(trimmed)) {
                candidateSkillSet.add(trimmed);
            }
        }
        
        Set<String> matched = new Set<String>();
        matched.addAll(candidateSkillSet);
        matched.retainAll(jobSkills);
        
        return new SkillMatchResult(!matched.isEmpty(), matched);
    }

    /**
     * @description
     * Builds a CandidateWrapper object containing candidate details,
     * matched skills, and calculated match percentages.
     *
     * @param c
     *        Candidate Contact record.
     * @param skillMatch
     *        Skill match result.
     * @param score
     *        Calculated dynamic match score.
     *
     * @return CandidateWrapper
     *         Wrapper object for UI consumption.
     */
    private static CandidateWrapper buildCandidateWrapper(
        Contact c,
        SkillMatchResult skillMatch,
        MatchScore score
    ) {
        return new CandidateWrapper(
            c,
            skillMatch.matchedSkills,
            score.totalScore,
            score.skillMatchPercentage,
            score.industrialKnowledgeMatchPercentage,
            score.additionalSkillMatchPercentage,
            score.experienceMatchPercentage,
            score.locationMatchPercentage,
            score.availabilityMatchPercentage
        );
    }

    /**
     * @description
     * Container class holding calculated match percentages and final score.
     */
    private class MatchScore {
        /**
         * @description : totalscore
         */
        public Decimal totalScore { get; set; }
        /**
         * @description : skillMatchPercentage
         */
        public Decimal skillMatchPercentage { get; set; }
        /**
         * @description : experienceMatchPercentage
         */
        public Decimal experienceMatchPercentage { get; set; }
        /**
         * @description : locationMatchPercentage
         */
        public Decimal locationMatchPercentage { get; set; }
        /**
         * @description : availabilityMatchPercentage
         */
        public Decimal availabilityMatchPercentage { get; set; }
        /**
         * @description : industrialKnowledgeMatchPercentage
         */
        public Decimal industrialKnowledgeMatchPercentage { get; set; }
        /**
         * @description : additionalSkillMatchPercentage
         */
        public Decimal additionalSkillMatchPercentage { get; set; }

    }

    /**
     * @description
     * Calculates the dynamic weighted match score for a candidate based on
     * available skill, experience, location, and availability data.
     *
     * @param candidate
     *        Candidate Contact record.
     * @param job
     *        Job Position record.
     * @param matchedSkillsCount
     *        Number of skills matched.
     * @param totalJobSkills
     *        Total number of job-required skills.
     *
     * @return MatchScore
     *         Calculated score with percentage breakdown.
     */
    private static MatchScore calculateDynamicMatchScore(
        Contact candidate,
        Job_Position__c job,
        Integer matchedSkillsCount,
        Integer totalJobSkills
    ) {
        MatchScore score = new MatchScore();
        
        score.skillMatchPercentage =
            calculateSkillMatchPercentage(matchedSkillsCount, totalJobSkills);
        
        score.experienceMatchPercentage =
            calculateExperienceMatch(candidate, job);
        
        score.locationMatchPercentage =
            calculateLocationMatch(candidate, job);
        
        score.availabilityMatchPercentage =
            calculateAvailabilityMatch(candidate, job);

        score.industrialKnowledgeMatchPercentage =
            calculateSkillCategoryMatch(
                candidate.Industrial_Knowledge__c,
                job.Industrial_Knowledge_Required__c
            );

        score.additionalSkillMatchPercentage =
            calculateSkillCategoryMatch(
                candidate.Soft_Skills__c,
                job.Soft_skills__c
            );

        score.totalScore = calculateFinalWeightedScore(score);

        return score;
    }

   private static Decimal calculateSkillCategoryMatch(
        String candidateValues,
        String jobValues
    ) {
        if (String.isBlank(candidateValues) || String.isBlank(jobValues)) {
            return 0;
        }

        Set<String> candidateSet = new Set<String>();
        for(String s : candidateValues.toLowerCase().split(',')) {
            candidateSet.add(s.trim());
        }

        Set<String> jobSet = new Set<String>();
        for(String s : jobValues.toLowerCase().split(',')) {
            jobSet.add(s.trim());
        }

        Integer matched = 0;

        for(String skill : jobSet) {
            if(candidateSet.contains(skill)) {
                matched++;
            }
        }

        Decimal percentage =
            (Decimal.valueOf(matched) / jobSet.size()) * 100;

        return Math.min(100, percentage.setScale(2));
    }

    /**
     * @description
     * Calculates the skill match percentage based on matched and total job skills.
     * @param matchedSkillsCount
     *        Number of skills matched.
     * @param totalJobSkills
     *        Total number of job-required skills.
     *
     * @return Decimal
     *         Calculated value in decimal.
     */
    private static Decimal calculateSkillMatchPercentage(
        Integer matchedSkillsCount,
        Integer totalJobSkills
    ) {
        if (totalJobSkills == null || totalJobSkills == 0 || matchedSkillsCount == 0) {
            return 0;
        }
        
        Decimal percentage =
            (Decimal.valueOf(matchedSkillsCount) / totalJobSkills) * 100;
        
        if (percentage > 100) {
            percentage = 100;
        }
        
        return percentage.setScale(2);
    }

    /**
     * @description
     * Calculates experience match percentage based on job requirements
     * and candidate experience range.
     * @param candidate
     *        candidate record for which calculation to do.
     * @param job
     *        Job positions record with whome skills should be checked.
     *
     * @return Decimal
     *         Calculated value in decimal.
     */
    private static Decimal calculateExperienceMatch(
        Contact candidate,
        Job_Position__c job
    ) {
        if (candidate.Relevant_Experience__c == null ||
            job.Minimum_Experience_Required__c == null) {
                return 0;
            }
        
        return calculateExperiencePercentage(candidate, job);
    }

    /**
     * @description
     * Calculates location match percentage using preferred and current location.
     * @param candidate
     *        candidate record for which calculation to do.
     * @param job
     *        Job positions record with whome skills should be checked.
     *
     * @return Decimal
     *         Calculated value in decimal.
     */
    private static Decimal calculateLocationMatch(
        Contact candidate,
        Job_Position__c job
    ) {
        if (String.isBlank(job.Work_Location__c)) {
            return 0;
        }
        
        if (String.isBlank(candidate.Current_Location__c) &&
            String.isBlank(candidate.Preferred_Location__c)) {
                return 0;
            }
        
        return calculateLocationPercentage(candidate, job);
    }

    /**
     * @description
     * Calculates availability match percentage based on notice period.
     * @param candidate
     *        candidate record for which calculation to do.
     * @param job
     *        Job positions record with whome skills should be checked.
     *
     * @return Decimal
     *         Calculated value in decimal.
     */
    private static Decimal calculateAvailabilityMatch(
        Contact candidate,
        Job_Position__c job
    ) {
        if (String.isBlank(candidate.Notice_Period__c)) {
            return 0;
        }
        
        return calculateAvailabilityPercentage(candidate, job);
    }

    /**
     * @description
     * Calculates the final weighted score using predefined weight distribution.
     * @param score
     *         MatchScore value.
     *
     * @return Decimal
     *         Calculated value in decimal.
     */
    private static Decimal calculateFinalWeightedScore(MatchScore score) {
        Decimal total =
            (score.skillMatchPercentage * 0.50)
            + (score.industrialKnowledgeMatchPercentage * 0.05)
            + (score.additionalSkillMatchPercentage * 0.05)
            + (score.experienceMatchPercentage * 0.20)
            + (score.locationMatchPercentage * 0.10)
            + (score.availabilityMatchPercentage * 0.10);
        
        return total.setScale(2);
    }

    /**
     * @description
     * Calculates experience match percentage using minimum and maximum
     * experience thresholds.
     */
    private static Decimal calculateExperiencePercentage(Contact c, Job_Position__c job) {
        Decimal candidateExp = c.Relevant_Experience__c;
        Decimal minExp = job.Minimum_Experience_Required__c;
        Decimal maxExp = job.Maximum_Experience_Required__c;
        
        if (candidateExp == null || minExp == null) {
            return 0;
        }
        
        // Candidate meets minimum requirement
        if (candidateExp >= minExp) {
            // If no maximum specified or candidate is within range
            if (maxExp == null || candidateExp <= maxExp) {
                return 100; // Perfect match
            } else {
                // Overqualified - calculate penalty
                Decimal overage = candidateExp - maxExp;
                // More than 5 years over maximum is significant
                if (overage > 5) {
                    return 70; // 70% match for significantly overqualified
                } else if (overage > 2) {
                    return 80; // 80% match for moderately overqualified
                } else {
                    return 90; // 90% match for slightly overqualified
                }
            }
        } else {
            // Below minimum - calculate based on how close they are
            Decimal ratio = (candidateExp / minExp) * 100;
            // Minimum 10% match if they have some experience
            return Math.max(10, ratio.setScale(2));
        }
    }

    /**
     * @description
     * Calculates location match percentage using string comparison and
     * partial matching rules.
     */
    private static Decimal calculateLocationPercentage(Contact c, Job_Position__c job) {
        if (String.isBlank(job.Work_Location__c)) {
            return 0;
        }
        
        String jobLocation = job.Work_Location__c.toLowerCase();
        
        // Check preferred location first
        if (String.isNotBlank(c.Preferred_Location__c)) {
            String preferred = c.Preferred_Location__c.toLowerCase();
            if (preferred.equals(jobLocation)) {
                return 100; // Exact match
            }
            
            // Check if locations contain each other
            if (preferred.contains(jobLocation) || jobLocation.contains(preferred)) {
                return 90; // 90% match for containing match
            }
            
            // Check for partial matches (same city name)
            List<String> preferredParts = preferred.split('[ ,-]+');
            List<String> jobParts = jobLocation.split('[ ,-]+');
            
            for (String prefPart : preferredParts) {
                for (String jobPart : jobParts) {
                    if (prefPart.length() > 3 && jobPart.length() > 3 && 
                        prefPart.equals(jobPart)) {
                            return 70; // 70% for same city/area
                        }
                }
            }
        }
        
        // Check current location
        if (String.isNotBlank(c.Current_Location__c)) {
            String current = c.Current_Location__c.toLowerCase();
            if (current.equals(jobLocation)) {
                return 85; // 85% match for exact match in current location
            }
            
            if (current.contains(jobLocation) || jobLocation.contains(current)) {
                return 75; // 75% match for containing match in current location
            }
            
            // Check for partial matches
            List<String> currentParts = current.split('[ ,-]+');
            List<String> jobParts = jobLocation.split('[ ,-]+');
            
            for (String currPart : currentParts) {
                for (String jobPart : jobParts) {
                    if (currPart.length() > 3 && jobPart.length() > 3 && 
                        currPart.equals(jobPart)) {
                            return 60; // 60% for same city/area in current location
                        }
                }
            }
        }
        
        return 0; // No match
    }

    /**
     * @description
     * Calculates availability match percentage based on parsed notice period.
     */
    private static Decimal calculateAvailabilityPercentage(Contact c, Job_Position__c job) {
        if (String.isBlank(c.Notice_Period__c)) {
            return 0;
        }
        
        Integer candidateDays = parseNoticePeriodToDays(c.Notice_Period__c);
        
        // Job preferred notice period (if specified)
        Integer jobPreferredDays = 0;
      /*  if (c.Can_join_in__c != null) {
jobPreferredDays = parseNoticePeriodToDays(c.Can_join_in__c);

}
   */     
        // If job doesn't specify, assume immediate availability is best
        if (jobPreferredDays == 0) {
            // Job wants immediate availability
            if (candidateDays == 0) {
                return 100; // Available immediately
            } else if (candidateDays <= 7) {
                return 80; // Available within a week
            } else if (candidateDays <= 15) {
                return 60; // Available within 15 days
            } else if (candidateDays <= 30) {
                return 40; // Available within a month
            } else {
                return 20; // More than a month
            }
        } else {
            // Job has specific notice period preference
            if (candidateDays <= jobPreferredDays) {
                // Candidate can join within or earlier than preferred period
                if (candidateDays == 0 && jobPreferredDays > 0) {
                    return 95; // Available immediately when job can wait
                }
                return 100; // Perfect match or earlier
            } else {
                // Candidate needs more time
                Decimal ratio = (Decimal)jobPreferredDays / candidateDays;
                return (ratio * 100).setScale(2);
            }
        }
    }

    /**
     * @description
     * Parses a notice period string into a numeric day value.
     *
     * @param noticePeriod
     *        Notice period string (e.g., "Immediate", "30 days", "2 months").
     *
     * @return Integer
     *         Number of days represented by the notice period.
     */
    private static Integer parseNoticePeriodToDays(String noticePeriod) {
        if (String.isBlank(noticePeriod)) {return 0;}
        
        String notice = noticePeriod.toLowerCase().trim();
        
        if (notice.contains('immediate') || notice.contains('now') || 
            notice.contains('available') || notice.contains('serving') ||
            notice.contains('0 day') || notice.contains('0 days')) {
                return 0;
            }
        
        // Try to extract number
        Pattern digitPattern = Pattern.compile('(\\d+)');
        Matcher digitMatcher = digitPattern.matcher(notice);
        
        if (digitMatcher.find()) {
            Integer daynumber = Integer.valueOf(digitMatcher.group(1));
            
            if (notice.contains('day') || notice.contains('days')) {
                return daynumber;
            } else if (notice.contains('week') || notice.contains('weeks')) {
                return daynumber * 7;
            } else if (notice.contains('month') || notice.contains('months')) {
                return daynumber * 30;
            }
        }
        
        return 30; // Default assumption
    }

    /**
     * @description
     * Wrapper class representing a candidate with detailed match scoring.
     * Implements Comparable to allow deterministic sorting in the UI.
     */
    public class CandidateWrapper implements Comparable {
        @AuraEnabled public Id candidateId;
        @AuraEnabled public String candidateName;
        @AuraEnabled public Decimal matchPercentage;
        @AuraEnabled public String candidateRating;
        @AuraEnabled public String primarySkills;
        @AuraEnabled public Decimal totalExperience;
        @AuraEnabled public Decimal relevantExperience;
        @AuraEnabled public String currentLocation;
        @AuraEnabled public String preferredLocation;
        @AuraEnabled public String noticePeriod;
        @AuraEnabled public Date lastProfileUpdate;
        @AuraEnabled public Datetime lastUpdateDatetime;
        
        // Match percentage breakdown (nullable for missing data)
        @AuraEnabled public Decimal skillMatchPercentage;
        @AuraEnabled public Decimal experienceMatchPercentage;
        @AuraEnabled public Decimal locationMatchPercentage;
        @AuraEnabled public Decimal availabilityMatchPercentage;
        @AuraEnabled public Decimal industrialKnowledgeMatchPercentage;
        @AuraEnabled public Decimal additionalSkillMatchPercentage;

        
        // For sorting
        private Integer ratingWeight;
        
        public CandidateWrapper(
            Contact c,
            Set<String> matchedSkillSet,
            Decimal totalMatchPercentage,
            Decimal skillMatchPercentage,
            Decimal industrialKnowledgeMatchPercentage,
            Decimal additionalSkillMatchPercentage,
            Decimal experienceMatchPercentage,
            Decimal locationMatchPercentage,
            Decimal availabilityMatchPercentage
        ) {
            this.candidateId = c.Id;
            this.candidateName = c.Name;
            this.matchPercentage = totalMatchPercentage;
            this.candidateRating = String.isBlank(c.Rating__c) ? 'Not Rated' : c.Rating__c;
            this.primarySkills = c.Skills__c;
            this.totalExperience = c.Total_Experience__c;
            this.relevantExperience = c.Relevant_Experience__c;
            this.currentLocation = c.Current_Location__c;
            this.preferredLocation = c.Preferred_Location__c;
            this.noticePeriod = c.Notice_Period__c;
            
            // Date only
            this.lastProfileUpdate = c.LastModifiedDate != null 
                ? c.LastModifiedDate.date() 
                : Date.today();
            
            // Datetime version
            this.lastUpdateDatetime = c.LastModifiedDate != null 
                ? c.LastModifiedDate 
                : Datetime.now();
            
            // Store match percentage breakdown
            this.skillMatchPercentage = skillMatchPercentage;
            this.experienceMatchPercentage = experienceMatchPercentage;
            this.locationMatchPercentage = locationMatchPercentage;
            this.availabilityMatchPercentage = availabilityMatchPercentage;
            this.industrialKnowledgeMatchPercentage = industrialKnowledgeMatchPercentage;
            this.additionalSkillMatchPercentage = additionalSkillMatchPercentage;

            // Calculate rating weight for sorting
            if (String.isBlank(c.Rating__c)) {
                this.ratingWeight = 0;
            } else {
                switch on c.Rating__c {
                    when 'Excellent' { this.ratingWeight = 5; }
                    when 'Good'      { this.ratingWeight = 4; }
                    when 'Average'   { this.ratingWeight = 3; }
                    when 'Poor'      { this.ratingWeight = 2; }
                    when 'Bad'       { this.ratingWeight = 1; }
                    when else        { this.ratingWeight = 0; }
                }
            }
        }
        
        public Integer compareTo(Object o) {
            CandidateWrapper other = (CandidateWrapper)o;
            
            // 1. Highest Match Percentage (descending)
            if (this.matchPercentage != other.matchPercentage) {
                return (other.matchPercentage > this.matchPercentage) ? 1 : -1;
            }
            
            // 2. Highest Candidate Rating (descending)
            if (this.ratingWeight != other.ratingWeight) {
                return other.ratingWeight - this.ratingWeight;
            }
            
            // 3. Most Recent Profile Update (descending)
            if (this.lastUpdateDatetime != other.lastUpdateDatetime) {
                return (other.lastUpdateDatetime > this.lastUpdateDatetime) ? 1 : -1;
            }
            
            return 0;
        }
    }

    /**
     * @description
     * Creates Interview records in bulk for the specified Job Position.
     * Performs CRUD validation before insertion.
     *
     * @param jobPositionId
     *        Id of the Job_Position__c record.
     * @param candidateIds
     *        List of candidate Contact Ids.
     *
     * @return List<Id>
     *         List of created Interview record Ids.
     *
     * @throws AuraHandledException
     *         Thrown when permission or DML errors occur.
     */
    @AuraEnabled
    public static List<Id> createInterviewsBulk(Id jobPositionId, List<Id> candidateIds) {
        List<Interview__c> interviews = new List<Interview__c>();
        
        for (Id candidateId : candidateIds) {
            interviews.add(new Interview__c(
                Job_Position__c = jobPositionId,
                Candidate_Name__c = candidateId
            ));
        }
        
        try {
            
            // ✅ CRUD CHECK
            if (!Schema.sObjectType.Interview__c.isCreateable()) {
                throw new AuraHandledException('You do not have permission to create Interview records.');
            }
            
            insert interviews;
            
            List<Id> interviewIds = new List<Id>();
            for (Interview__c iv : interviews) {
                interviewIds.add(iv.Id);
            }
            return interviewIds;
            
        } catch (DmlException dmlex) {
            throw new AuraHandledException(dmlex.getDmlMessage(0));
        } catch (Exception ex) {
            throw new AuraHandledException('Unexpected error: ' + ex.getMessage());
        }
        
    }

    /**
     * @description
     * Creates a single Interview record for a candidate and job position.
     * Performs CRUD validation before insertion.
     *
     * @param jobPositionId
     *        Id of the Job_Position__c record.
     * @param candidateId
     *        Id of the candidate Contact record.
     *
     * @return Id
     *         Id of the newly created Interview record.
     *
     * @throws AuraHandledException
     *         Thrown when permission or DML errors occur.
     */
    @AuraEnabled
    public static Id createInterview(Id jobPositionId, Id candidateId) {
        try {
            
            // ✅ CRUD CHECK (PMD satisfied)
            if (!Schema.sObjectType.Interview__c.isCreateable()) {
                throw new AuraHandledException(
                    'You do not have permission to create Interview records.'
                );
            }
            
            Interview__c interview = new Interview__c(
                Job_Position__c = jobPositionId,
                Candidate_Name__c    = candidateId
            );
            
            insert interview;
            return interview.Id;
            
        } catch (DmlException dmlex) {
            throw new AuraHandledException(dmlex.getDmlMessage(0));
        } catch (Exception ex) {
            throw new AuraHandledException('Unexpected error: ' + ex.getMessage());
        }
    }    
}