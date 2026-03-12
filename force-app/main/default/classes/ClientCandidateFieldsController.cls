/**
 * @description
 * Controller class for managing client-specific email preferences.
 * Allows configuration of which Candidate (Contact) fields should appear
 * in client emails and in what order. Used by SubmitToClient LWC component.
 *
 * @author Shivam Shivhare
 * @since 6 Oct, 2025
 */
public with sharing class ClientCandidateFieldsController {

    /**
     * @description
     * Dynamically fetches all accessible Candidate (Contact) fields
     * that can be selected by clients for email configuration.
     *
     * @return
     * List of maps containing:
     *  - label : Field label
     *  - value : Field API name
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String,String>> getCandidateFieldOptions() {
        Map<String, Schema.SObjectField> fieldsMap = Schema.SObjectType.Contact.fields.getMap();
        List<Map<String,String>> options = new List<Map<String,String>>();
        
        for(String fieldName : fieldsMap.keySet()){
            Schema.DescribeFieldResult f = fieldsMap.get(fieldName).getDescribe();
            if(f.isAccessible() && !f.isCalculated() && f.getType() != Schema.DisplayType.ID) {
                options.add(new Map<String,String>{
                    'label' => f.getLabel(),
                    'value' => fieldName
                });
            }
        }

        
        for(Integer i = 0; i < options.size() - 1; i++){
            for(Integer j = i + 1; j < options.size(); j++){
                String labelA = options[i].get('label').toLowerCase();
                String labelB = options[j].get('label').toLowerCase();
                if(labelA > labelB){
                    Map<String,String> temp = options[i];
                    options[i] = options[j];
                    options[j] = temp;
                }
            }
        }

        return options;
    }

    /**
     * @description
     * Retrieves saved Candidate field preferences for a given Client account.
     *
     * @param clientId
     * Id of the Client Account record
     *
     * @return
     * Comma-separated list of Candidate field API names
     */
    @AuraEnabled(cacheable=true)
    public static String getClientCandidateFields(Id clientId) {
        Account acc = [
                       SELECT Candidate_Fields__c, RecordType.DeveloperName FROM Account
                       WHERE Id = :clientId 
                       WITH SECURITY_ENFORCED
                       LIMIT 1
                      ];

                     if(acc.RecordType.DeveloperName != 'Client'){
                        throw new AuraHandledException('Record is not a Client account.');
                        }

                        return acc.Candidate_Fields__c;
                        }
	
    /**
     * @description
     * Saves or updates the Candidate field configuration for a Client account.
     *
     * @param clientId
     * Id of the Client Account record
     *
     * @param selectedFields
     * Comma-separated Candidate field API names in preferred order
     */
    @AuraEnabled
    public static void saveClientCandidateFields(Id clientId, String selectedFields) {

          if (!Schema.sObjectType.Account.isUpdateable()) {
            throw new AuraHandledException('Insufficient permission to update Account.');
        }

        if (!Schema.sObjectType.Account.fields.Candidate_Fields__c.isUpdateable()) {
            throw new AuraHandledException('Insufficient field update access.');
        }

        Account acc = new Account(
        Id = clientId,
        Candidate_Fields__c = selectedFields
        );
        update acc;
    }
}