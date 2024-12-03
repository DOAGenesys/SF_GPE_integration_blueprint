trigger GenesysGPEConfigTrigger on Genesys_GPE_Config__c (after update, before delete) {
    if (Trigger.isUpdate && Trigger.isAfter) {
        GenesysGPEConfigTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    } else if (Trigger.isDelete && Trigger.isBefore) {
        GenesysGPEConfigTriggerHandler.handleBeforeDelete(Trigger.old);
    }
}
