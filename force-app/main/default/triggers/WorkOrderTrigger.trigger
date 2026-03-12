/*
*#################################################################
* Created By (Date) : Ayush Agrawal (05 Aug, 2025)
* Description       : WorkOrder Trigger Class for WorkOrder__c Object.
* Modifications Log :
* Ver   Date          Author           Modification
* 1.0   05 Aug, 2025  Ayush Agrawal    Initial Version
################################################################# 
*/
trigger WorkOrderTrigger on Work_Order__c (before delete, before insert, before update, after delete, after insert, after update) {
  if (Trigger.isBefore) {
        if (Trigger.isDelete) {
		WorkOrderHandler.BeforeDelete(Trigger.oldMap);
        }
        if (Trigger.isInsert) {
		WorkOrderHandler.BeforeInsert(Trigger.new);
        }
        if (Trigger.isUpdate) {
		WorkOrderHandler.BeforeUpdate(Trigger.new, Trigger.oldMap);
        }    	        
    } 
    if (Trigger.isAfter) {
        if (Trigger.isDelete) {
            WorkOrderHandler.AfterDelete(Trigger.oldMap);
        }
        if (Trigger.isInsert) {
            WorkOrderHandler.AfterInsert(Trigger.new);
        }
        if (Trigger.isUpdate) {
            WorkOrderHandler.AfterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}