/**
 * @description
 * Service class to expose Candidate picklist values
 * for Lightning Web Components. 
 * used in - addToExistngCandidate lwc component
 */
public with sharing class CandidatePicklistService {
     
    /**
     * @description
     * Returns Notice Period picklist values
     * for Contact.Notice_Period__c field.
     *
     * @return List of label-value maps for combobox
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getNoticePeriodPicklistValues() {
        List<Map<String, String>> res = new List<Map<String, String>>();

        for (Schema.PicklistEntry p :
            Contact.Notice_Period__c.getDescribe().getPicklistValues()
        ) {
            res.add(new Map<String, String>{
                'label' => p.getLabel(),
                'value' => p.getValue()
            });
        }

        return res;
    }
}