/**
 * @description Apex Controller to support Extend Work Order LWC.
 *              - Fetches field values for defaulting.
 *              - Creates new Work Order for extension.
 * @author Admin
 * @date 22 Jul, 2025
 */
public with sharing class ExtendWorkOrderController {

    /**
     * @description Fetches required Work Order field values for UI defaulting.
     * @param recordId Id of the Work Order record
     * @return Work_Order__c record with required fields
     */
    @AuraEnabled
    public static Work_Order__c getAllFieldsValue(Id recordId) {
        try {
            return [
                SELECT Id,
                       Status__c,
                       Candidate_Name__c,
                       Project__c,
                       Role_on_Project__c,
                       Recruiter_Name__c,
                       Renewed__c,
                       Salary_Offered__c,
                       Name,
                       Project__r.Name,
                       Candidate_Name__r.Name,
                       Recruiter_Name__r.Name
                FROM Work_Order__c
                WHERE Id = :recordId
                WITH USER_MODE
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException(
                'Failed to fetch Work Order fields: ' + e.getMessage()
            );
        }
    }

    /**
     * @description Creates a new Work Order record for extension.
     * @param workOrderData JSON string containing Work Order field values
     * @return Id of newly created Work Order
     */
    @AuraEnabled
    public static Id createWorkOrder(String workOrderData) {
        try {
            Map<String, Object> workOrderMap =
                (Map<String, Object>) JSON.deserializeUntyped(workOrderData);

            if (!Schema.sObjectType.Work_Order__c.isCreateable()) {
                throw new AuraHandledException(
                    'You do not have permission to create Work Orders.'
                );
            }

            Work_Order__c newWorkOrder =
                mapFieldsToWorkOrder(workOrderMap);

            insert as user newWorkOrder;

            return newWorkOrder.Id;

        } catch (Exception e) {
            throw new AuraHandledException(
                'Failed to create Work Order: ' + e.getMessage()
            );
        }
    }

    /**
     * @description Maps input values to Work_Order__c record.
     * @param workOrderMap Map containing field values
     * @return Populated Work_Order__c record
     */
    private static Work_Order__c mapFieldsToWorkOrder(
        Map<String, Object> workOrderMap
    ) {
        Work_Order__c wo = new Work_Order__c();

        wo.Parent_Work_OrderId__c =
            getIdValue(workOrderMap, 'Parent_Work_OrderId__c');
        wo.Project__c =
            getIdValue(workOrderMap, 'Project__c');
        wo.Role_on_Project__c =
            getStringValue(workOrderMap, 'Role_on_Project__c');
        wo.Candidate_Name__c =
            getIdValue(workOrderMap, 'Candidate_Name__c');
        wo.Recruiter_Name__c =
            getIdValue(workOrderMap, 'Recruiter_Name__c');
        wo.Start_Date__c =
            getDateValue(workOrderMap, 'Start_Date__c');
        wo.End_Date__c =
            getDateValue(workOrderMap, 'End_Date__c');
        wo.Renewed__c =
            getBooleanValue(workOrderMap, 'Renewed__c');
        wo.Status__c =
            getStringValue(workOrderMap, 'Status__c');
        wo.Salary_Offered__c =
            getDecimalValue(workOrderMap, 'Salary_Offered__c');

        return wo;
    }

    private static Id getIdValue(Map<String, Object> mapData, String key) {
        return mapData.containsKey(key) && mapData.get(key) != null
            ? (Id) mapData.get(key) : null;
    }

    private static String getStringValue(
        Map<String, Object> mapData,
        String key
    ) {
        return mapData.containsKey(key)
            ? (String) mapData.get(key): null;
    }

    private static Date getDateValue(
        Map<String, Object> mapData,
        String key
    ) {
        return mapData.containsKey(key) && mapData.get(key) != null
            ? Date.valueOf((String) mapData.get(key)): null;
    }

    private static Boolean getBooleanValue(
        Map<String, Object> mapData,
        String key
    ) {
        return mapData.containsKey(key)
            ? (Boolean) mapData.get(key): null;
    }

    private static Decimal getDecimalValue(
        Map<String, Object> mapData,
        String key
    ) {
        if (!mapData.containsKey(key)) {
            return null;
        }

        String value = (String) mapData.get(key);

        if (String.isBlank(value) || value == '[ ]') {
            return null;
        }

        return Decimal.valueOf(value);
    }
}