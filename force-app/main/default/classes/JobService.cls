public without sharing class JobService {

    public static CandidatePublicController.JobSearchResponse searchJobs(
        JobSearchCriteria criteria
    ) {
        Integer pageNumber = (criteria.pageNumber == null || criteria.pageNumber < 1)
            ? 1 : criteria.pageNumber;

        Integer pageSize = (criteria.pageSize == null || criteria.pageSize < 1)
            ? 10 : criteria.pageSize;

        Integer offsetVal = (pageNumber - 1) * pageSize;

        List<String> conditions = new List<String>();
        conditions.add('Status__c = \'Open\'');

        if (!String.isBlank(criteria.searchKey)) {
            conditions.add(
                'Job_Title__c LIKE \'%' +
                String.escapeSingleQuotes(criteria.searchKey.trim()) +
                '%\''
            );
        }

        if (!String.isBlank(criteria.cityFilter)) {
            conditions.add(
                'Job_Location__City__s LIKE \'%' +
                String.escapeSingleQuotes(criteria.cityFilter.trim()) +
                '%\''
            );
        }

        if (criteria.minExperience != null) {
    		conditions.add('Maximum_Experience_Required__c >= ' + criteria.minExperience);
        }
        
        if (criteria.maxExperience != null) {
            conditions.add('Minimum_Experience_Required__c <= ' + criteria.maxExperience);
        }

        String whereClause =
            ' FROM Job_Position__c WHERE ' + String.join(conditions, ' AND ');

        Integer total =
            Database.countQuery('SELECT COUNT() ' + whereClause);

        List<Job_Position__c> jobs =
            Database.query(
                'SELECT Id, Name, Job_Title__c, Job_Location__City__s,' +
                ' Skills_Required__c, Pay_Rate_Salary_range__c,' +
                ' Status__c, Job_Description__c, Minimum_Experience_Required__c, Maximum_Experience_Required__c,' +
                ' CreatedDate ' +
                whereClause +
                ' ORDER BY CreatedDate DESC ' +
                ' LIMIT ' + pageSize +
                ' OFFSET ' + offsetVal
            );

        CandidatePublicController.JobSearchResponse resp =
            new CandidatePublicController.JobSearchResponse();
        resp.totalRecords = total;
        resp.pageNumber = pageNumber;
        resp.pageSize = pageSize;
        resp.jobs = jobs;

        return resp;
    }

    @AuraEnabled(cacheable=true)
    public static Job_Position__c getJobDetails(Id jobId) {
        if (jobId == null) return null;

        return [
            SELECT Id, Name, Job_Title__c, Job_Location__City__s,
                   Skills_Required__c, Pay_Rate_Salary_range__c,
                   Status__c, Job_Description__c,
                   Minimum_Experience_Required__c, Maximum_Experience_Required__c, OwnerId
            FROM Job_Position__c
            WHERE Id = :jobId
            LIMIT 1
        ];
    }
}