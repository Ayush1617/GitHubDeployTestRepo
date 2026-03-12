/* 
	###########################################################
    # Trigger Name : InterviewTrigger
    # Object       : Interview__c
    # Events       : before insert, before update, after insert, after update
    # Description  : Handles automation related to Interview__c object.
    #                Delegates execution logic to InterviewTriggerHandler 
    #                to keep trigger lean and maintainable.
    # Modifications Log :
    # Ver   Date         Author   Modification
    # 1.0   20-Aug-2025  Admin    Initial Version
	########################################################### 
 */
trigger InterviewTrigger on Interview__c (before delete, before insert, before update, after delete, after insert, after update) {
   
    if (Trigger.isAfter){

        if (Trigger.isInsert) {
		   InterviewTriggerHandler.handleAfterInsert(Trigger.new);
        }
        if (Trigger.isUpdate) {
        InterviewTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    	}        
    }    
}