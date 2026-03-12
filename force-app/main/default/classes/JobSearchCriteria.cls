public class JobSearchCriteria {
    @AuraEnabled public Integer pageNumber;
    @AuraEnabled public Integer pageSize;
    @AuraEnabled public String searchKey;
    @AuraEnabled public String cityFilter;
    @AuraEnabled public Integer minExperience;
    @AuraEnabled public Integer maxExperience;
}