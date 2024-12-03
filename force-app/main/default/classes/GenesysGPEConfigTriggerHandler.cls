public class GenesysGPEConfigTriggerHandler {
    private static final String DEBUG_HEADER = 'GenesysGPEConfigTriggerHandler: ';

    public static void handleAfterUpdate(List<Genesys_GPE_Config__c> newConfigs, Map<Id, Genesys_GPE_Config__c> oldConfigMap) {
        System.debug(LoggingLevel.INFO, DEBUG_HEADER + 'Entering handleAfterUpdate with ' + newConfigs.size() + ' configs');
        List<Genesys_GPE_Config__c> configsToProcess = new List<Genesys_GPE_Config__c>();
        
        for (Genesys_GPE_Config__c newConfig : newConfigs) {
            Genesys_GPE_Config__c oldConfig = oldConfigMap.get(newConfig.Id);
            
            boolean nameChanged = String.isBlank(oldConfig.GC_Open_action_Name__c) && String.isNotBlank(newConfig.GC_Open_action_Name__c);
            boolean idChanged = String.isBlank(oldConfig.GC_Open_action_Id__c) && String.isNotBlank(newConfig.GC_Open_action_Id__c);
            
            if ((nameChanged && String.isNotBlank(newConfig.GC_Open_action_Id__c)) || 
                (idChanged && String.isNotBlank(newConfig.GC_Open_action_Name__c)) ||
                (nameChanged && idChanged)) {
                configsToProcess.add(newConfig);
                System.debug(LoggingLevel.INFO, DEBUG_HEADER + 'Config ' + newConfig.Id + ' added to processing list');
            }
        }
        
        if (!configsToProcess.isEmpty()) {
            System.debug(LoggingLevel.INFO, DEBUG_HEADER + 'Enqueueing ActionMapCreator for ' + configsToProcess.size() + ' configs');
            try {
                System.enqueueJob(new ActionMapCreator(configsToProcess));
            } catch (System.AsyncException e) {
                System.debug(LoggingLevel.ERROR, DEBUG_HEADER + 'Failed to enqueue ActionMapCreator: ' + e.getMessage() + '\n' + e.getStackTraceString());
            }
        } else {
            System.debug(LoggingLevel.INFO, DEBUG_HEADER + 'No configs to process in handleAfterUpdate');
        }
    }

    public static void handleBeforeDelete(List<Genesys_GPE_Config__c> oldConfigs) {
        System.debug(LoggingLevel.INFO, DEBUG_HEADER + 'Entering handleBeforeDelete with ' + oldConfigs.size() + ' configs');
        for (Genesys_GPE_Config__c config : oldConfigs) {
            if (String.isNotBlank(config.GC_Open_action_Id__c)) {
                System.debug(LoggingLevel.INFO, DEBUG_HEADER + 'Calling deleteOpenAction for config ' + config.Id);
                deleteOpenAction(config.GC_Open_action_Id__c);
            }
            if (String.isNotBlank(config.GC_Action_map_Id__c)) {
                System.debug(LoggingLevel.INFO, DEBUG_HEADER + 'Calling deleteActionMap for config ' + config.Id);
                deleteActionMap(config.GC_Action_map_Id__c);
            }
        }
    }

    @future(callout=true)
    public static void deleteOpenAction(String openActionId) {
        System.debug(LoggingLevel.INFO, DEBUG_HEADER + 'Deleting Open Action: ' + openActionId);
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:GC_Base_API/api/v2/journey/openactions/' + openActionId);
        req.setMethod('DELETE');
        
        Http http = new Http();
        HttpResponse res;
        try {
            res = http.send(req);
        } catch (System.CalloutException e) {
            System.debug(LoggingLevel.ERROR, DEBUG_HEADER + 'Callout failed when deleting Open Action: ' + e.getMessage() + '\n' + e.getStackTraceString());
            return;
        }
        
        if (res.getStatusCode() != 204) {
            String errorMsg = 'Error deleting Open Action. Status: ' + res.getStatus() + ', Body: ' + res.getBody();
            System.debug(LoggingLevel.ERROR, DEBUG_HEADER + errorMsg);
        } else {
            System.debug(LoggingLevel.INFO, DEBUG_HEADER + 'Successfully deleted Open Action: ' + openActionId);
        }
    }

    @future(callout=true)
    public static void deleteActionMap(String actionMapId) {
        System.debug(LoggingLevel.INFO, DEBUG_HEADER + 'Deleting Action Map: ' + actionMapId);
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:GC_Base_API/api/v2/journey/actionmaps/' + actionMapId);
        req.setMethod('DELETE');
        
        Http http = new Http();
        HttpResponse res;
        try {
            res = http.send(req);
        } catch (System.CalloutException e) {
            System.debug(LoggingLevel.ERROR, DEBUG_HEADER + 'Callout failed when deleting Action Map: ' + e.getMessage() + '\n' + e.getStackTraceString());
            return;
        }
        
        if (res.getStatusCode() != 204) {
            String errorMsg = 'Error deleting Action Map. Status: ' + res.getStatus() + ', Body: ' + res.getBody();
            System.debug(LoggingLevel.ERROR, DEBUG_HEADER + errorMsg);
        } else {
            System.debug(LoggingLevel.INFO, DEBUG_HEADER + 'Successfully deleted Action Map: ' + actionMapId);
        }
    }

    public class ActionMapCreator implements Queueable, Database.AllowsCallouts {
        private List<Genesys_GPE_Config__c> configs;
        
        public ActionMapCreator(List<Genesys_GPE_Config__c> configs) {
            this.configs = configs;
        }
        
        public void execute(QueueableContext context) {
            System.debug(LoggingLevel.INFO, DEBUG_HEADER + 'Executing ActionMapCreator for ' + configs.size() + ' configs');
            Map<Id, String> configToActionMapId = new Map<Id, String>();
            
            for (Genesys_GPE_Config__c config : configs) {
                try {
                    String actionMapId = createActionMap(config);
                    if (String.isNotBlank(actionMapId)) {
                        configToActionMapId.put(config.Id, actionMapId);
                        System.debug(LoggingLevel.INFO, DEBUG_HEADER + 'Action Map created for config ' + config.Id + ': ' + actionMapId);
                    }
                } catch (Exception e) {
                    System.debug(LoggingLevel.ERROR, DEBUG_HEADER + 'Error creating Action Map for config ' + config.Id + ': ' + e.getMessage() + '\n' + e.getStackTraceString());
                }
            }
            
            if (!configToActionMapId.isEmpty()) {
                System.debug(LoggingLevel.INFO, DEBUG_HEADER + 'Enqueueing ConfigUpdater for ' + configToActionMapId.size() + ' configs');
                System.enqueueJob(new ConfigUpdater(configToActionMapId));
            } else {
                System.debug(LoggingLevel.WARN, DEBUG_HEADER + 'No Action Maps created, skipping update');
            }
        }
    }

    public class ConfigUpdater implements Queueable {
        private Map<Id, String> configToActionMapId;
        
        public ConfigUpdater(Map<Id, String> configToActionMapId) {
            this.configToActionMapId = configToActionMapId;
        }
        
        public void execute(QueueableContext context) {
            System.debug(LoggingLevel.INFO, DEBUG_HEADER + 'Executing ConfigUpdater for ' + configToActionMapId.size() + ' configs');
            List<Genesys_GPE_Config__c> configsToUpdate = new List<Genesys_GPE_Config__c>();
            
            for (Id configId : configToActionMapId.keySet()) {
                configsToUpdate.add(new Genesys_GPE_Config__c(
                    Id = configId,
                    GC_Action_map_Id__c = configToActionMapId.get(configId)
                ));
            }
            
            try {
                update configsToUpdate;
                System.debug(LoggingLevel.INFO, DEBUG_HEADER + 'Successfully updated ' + configsToUpdate.size() + ' configs with Action Map IDs');
            } catch (DmlException e) {
                System.debug(LoggingLevel.ERROR, DEBUG_HEADER + 'Error updating configs with Action Map IDs: ' + e.getMessage() + '\n' + e.getStackTraceString());
            }
        }
    }
    
    private static String createActionMap(Genesys_GPE_Config__c config) {
        System.debug(LoggingLevel.INFO, DEBUG_HEADER + 'Creating Action Map for config: ' + config.Id);
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:GC_Base_API/api/v2/journey/actionmaps');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        
        Map<String, Object> bodyMap = new Map<String, Object>{
            'isActive' => true,
            'displayName' => config.Name,
            'triggerWithSegments' => new List<Object>(),
            'activation' => new Map<String, Object>{
                'type' => 'immediate'
            },
            'action' => new Map<String, Object>{
                'mediaType' => 'openAction',
                'openActionFields' => new Map<String, Object>{
                    'openAction' => new Map<String, Object>{
                        'name' => config.GC_Open_action_Name__c,
                        'id' => config.GC_Open_action_Id__c
                    }
                }
            }
        };
        
        req.setBody(JSON.serialize(bodyMap));
        System.debug(LoggingLevel.DEBUG, DEBUG_HEADER + 'Action Map request body: ' + req.getBody());
        
        Http http = new Http();
        HttpResponse res;
        try {
            res = http.send(req);
        } catch (System.CalloutException e) {
            System.debug(LoggingLevel.ERROR, DEBUG_HEADER + 'Callout failed when creating Action Map: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new ActionMapException('Callout failed: ' + e.getMessage());
        }
        
        System.debug(LoggingLevel.DEBUG, DEBUG_HEADER + 'Action Map response status: ' + res.getStatusCode());
        System.debug(LoggingLevel.DEBUG, DEBUG_HEADER + 'Action Map response body: ' + res.getBody());
        
        if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
            Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
            String actionMapId = (String)responseMap.get('id');
            System.debug(LoggingLevel.INFO, DEBUG_HEADER + 'Successfully created Action Map with ID: ' + actionMapId + ' for config: ' + config.Id);
            return actionMapId;
        } else {
            String errorMsg = 'Error creating Action Map. Status: ' + res.getStatus() + ', Body: ' + res.getBody();
            System.debug(LoggingLevel.ERROR, DEBUG_HEADER + errorMsg);
            throw new ActionMapException(errorMsg);
        }
    }
    
    public class ActionMapException extends Exception {}
}
