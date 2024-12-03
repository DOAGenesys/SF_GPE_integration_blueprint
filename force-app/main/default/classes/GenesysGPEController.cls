public with sharing class GenesysGPEController {
    private static final String DEBUG_HEADER = 'GenesysGPEController: ';
    
    @AuraEnabled
    public static String saveGPEConfig(String config, String configId) {
        System.debug(DEBUG_HEADER + 'Entering saveGPEConfig with configId: ' + configId);
        Savepoint sp = Database.setSavepoint();
        try {
            Map<String, Object> configMap = (Map<String, Object>)JSON.deserializeUntyped(config);
            System.debug(DEBUG_HEADER + 'Deserialized config: ' + JSON.serializePretty(configMap));
            
            Genesys_GPE_Config__c gpeConfig;
            if (String.isNotBlank(configId)) {
                gpeConfig = [SELECT Id FROM Genesys_GPE_Config__c WHERE Id = :configId LIMIT 1];
                System.debug(DEBUG_HEADER + 'Updating existing config with Id: ' + gpeConfig.Id);
            } else {
                gpeConfig = new Genesys_GPE_Config__c();
                System.debug(DEBUG_HEADER + 'Creating new config');
            }
            
            // Assign fields
            gpeConfig.Name = (String)configMap.get('configName');
            gpeConfig.GC_Domain__c = (String)configMap.get('gcDomain');
            gpeConfig.GC_Environment__c = (String)configMap.get('gcEnvironment');
            gpeConfig.GC_Messaging_Deployment_ID__c = (String)configMap.get('gcMessagingDeplId');
            gpeConfig.SF_WM_URL__c = (String)configMap.get('sfWmUrl');
            gpeConfig.SF_Org_Id__c = (String)configMap.get('sfOrgId');
            gpeConfig.SF_WM_Name__c = (String)configMap.get('sfWmName');
            gpeConfig.Pageview_Config__c = JSON.serialize(configMap.get('pageviewConfig'));
            gpeConfig.Forms_Track_Config__c = JSON.serialize(configMap.get('formsTrackConfig'));
            gpeConfig.Click_Events_Config__c = JSON.serialize(configMap.get('clickEventsConfig'));
            gpeConfig.Idle_Events_Config__c = JSON.serialize(configMap.get('idleEventsConfig'));
            gpeConfig.In_Viewport_Config__c = JSON.serialize(configMap.get('inViewportConfig'));
            gpeConfig.Scroll_Depth_Config__c = JSON.serialize(configMap.get('scrollDepthConfig'));
            
            if (configMap.containsKey('openActionName')) {
                gpeConfig.GC_Open_action_Name__c = (String)configMap.get('openActionName');
            }
            
            System.debug(DEBUG_HEADER + 'Upserting GPE Config: ' + JSON.serializePretty(gpeConfig));
            upsert gpeConfig;
            
            if (String.isBlank(configId) && configMap.containsKey('openActionName')) {
                String openActionName = (String)configMap.get('openActionName');
                createOpenActionFuture(gpeConfig.Id, openActionName);
            }
            
            System.debug(DEBUG_HEADER + 'Successfully saved GPE Config with Id: ' + gpeConfig.Id);
            return gpeConfig.Id;
        } catch (DmlException e) {
            Database.rollback(sp);
            System.debug(LoggingLevel.ERROR, DEBUG_HEADER + 'DML Exception in saveGPEConfig: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new AuraHandledException('Error saving GPE Configuration: ' + e.getDmlMessage(0));
        } catch (Exception e) {
            Database.rollback(sp);
            System.debug(LoggingLevel.ERROR, DEBUG_HEADER + 'Exception in saveGPEConfig: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new AuraHandledException('Error saving GPE Configuration: ' + e.getMessage());
        }
    }

    @future(callout=true)
    public static void createOpenActionFuture(Id gpeConfigId, String openActionName) {
        System.debug(DEBUG_HEADER + 'Entering createOpenActionFuture with gpeConfigId: ' + gpeConfigId + ' and openActionName: ' + openActionName);
        try {
            String openActionId = createOpenAction(openActionName);
            
            Genesys_GPE_Config__c gpeConfig = [SELECT Id FROM Genesys_GPE_Config__c WHERE Id = :gpeConfigId];
            gpeConfig.GC_Open_action_Id__c = openActionId;
            update gpeConfig;
            
            System.debug(DEBUG_HEADER + 'Successfully updated GPE Config with Open Action ID: ' + openActionId);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, DEBUG_HEADER + 'Exception in createOpenActionFuture: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }
    }

    private static String createOpenAction(String openActionName) {
        System.debug(DEBUG_HEADER + 'Entering createOpenAction with openActionName: ' + openActionName);
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:GC_Base_API/api/v2/journey/openactions');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        
        Map<String, Object> bodyMap = new Map<String, Object>{
            'name' => openActionName,
            'displayName' => openActionName,
            'description' => 'Used for GPE and SF Web messaging integration',
            'type' => 'web',
            'documentation' => new Map<String, String>{
                'displayText' => 'example.com',
                'url' => 'https://www.example.com'
            },
            'icons' => new Map<String, Object>{
                'actionMapIconConfig' => new Map<String, Object>{
                    'primaryIcon' => new Map<String, String>{
                        'defaultIconUrl' => 'https://www.example.com',
                        'hoverIconUrl' => 'https://www.example.com',
                        'activeIconUrl' => 'https://www.example.com'
                    }
                }
            },
            'createdDate' => Datetime.now().formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'')
        };
        
        req.setBody(JSON.serialize(bodyMap));
        System.debug(DEBUG_HEADER + 'Request body: ' + req.getBody());
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        System.debug(DEBUG_HEADER + 'Response status: ' + res.getStatusCode());
        System.debug(DEBUG_HEADER + 'Response body: ' + res.getBody());
        
        if (res.getStatusCode() == 200) {
            Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
            String openActionId = (String)responseMap.get('id');
            System.debug(DEBUG_HEADER + 'Successfully created Open Action with ID: ' + openActionId);
            return openActionId;
        } else {
            String errorMsg = 'Error creating Open Action. Status: ' + res.getStatus() + ', Body: ' + res.getBody();
            System.debug(LoggingLevel.ERROR, DEBUG_HEADER + errorMsg);
            throw new OpenActionException(errorMsg);
        }
    }
    
    @AuraEnabled
    public static void deleteGPEConfig(String configId) {
        System.debug(DEBUG_HEADER + 'Entering deleteGPEConfig with configId: ' + configId);
        Savepoint sp = Database.setSavepoint();
        try {
            Genesys_GPE_Config__c configToDelete = [SELECT Id FROM Genesys_GPE_Config__c WHERE Id = :configId LIMIT 1];
            delete configToDelete;
            System.debug(DEBUG_HEADER + 'Successfully deleted GPE Config with Id: ' + configId);
        } catch (DmlException e) {
            Database.rollback(sp);
            System.debug(LoggingLevel.ERROR, DEBUG_HEADER + 'DML Exception in deleteGPEConfig: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new AuraHandledException('Error deleting GPE Configuration: ' + e.getDmlMessage(0));
        } catch (Exception e) {
            Database.rollback(sp);
            System.debug(LoggingLevel.ERROR, DEBUG_HEADER + 'Exception in deleteGPEConfig: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new AuraHandledException('Error deleting GPE Configuration: ' + e.getMessage());
        }
    }    
    
    @AuraEnabled(cacheable=true)
    public static String getConfigDetails(String configId) {
        System.debug(DEBUG_HEADER + 'Entering getConfigDetails with configId: ' + configId);
        try {
            Genesys_GPE_Config__c config = [SELECT 
                Name, 
                GC_Domain__c, 
                GC_Environment__c, 
                GC_Messaging_Deployment_ID__c,
                SF_WM_URL__c,
                SF_Org_Id__c,
                SF_WM_Name__c, 
                GC_Open_action_Name__c,
                Pageview_Config__c, 
                Forms_Track_Config__c, 
                Click_Events_Config__c, 
                Idle_Events_Config__c, 
                In_Viewport_Config__c, 
                Scroll_Depth_Config__c 
                FROM Genesys_GPE_Config__c 
                WHERE Id = :configId 
                LIMIT 1];
            
            System.debug(DEBUG_HEADER + 'Retrieved config: ' + JSON.serializePretty(config));
            String serializedConfig = JSON.serialize(createConfigMap(config));
            System.debug(DEBUG_HEADER + 'Serialized config: ' + serializedConfig);
            return serializedConfig;
        } catch (QueryException e) {
            System.debug(LoggingLevel.ERROR, DEBUG_HEADER + 'Query Exception in getConfigDetails: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new AuraHandledException('Error retrieving GPE Configuration: Configuration not found');
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, DEBUG_HEADER + 'Exception in getConfigDetails: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new AuraHandledException('Error retrieving GPE Configuration: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static String getConfigDetailsByName(String configName) {
        System.debug(DEBUG_HEADER + 'Entering getConfigDetailsByName with configName: ' + configName);
        try {
            Genesys_GPE_Config__c config = [SELECT 
                Name, 
                GC_Domain__c, 
                GC_Environment__c, 
                GC_Messaging_Deployment_ID__c,
                SF_WM_URL__c,
                SF_Org_Id__c,
                SF_WM_Name__c,
                GC_Open_action_Name__c,
                Pageview_Config__c, 
                Forms_Track_Config__c, 
                Click_Events_Config__c, 
                Idle_Events_Config__c, 
                In_Viewport_Config__c, 
                Scroll_Depth_Config__c 
                FROM Genesys_GPE_Config__c 
                WHERE Name = :configName 
                LIMIT 1];
            
            System.debug(DEBUG_HEADER + 'Retrieved config: ' + JSON.serializePretty(config));
            String serializedConfig = JSON.serialize(createConfigMap(config));
            System.debug(DEBUG_HEADER + 'Serialized config: ' + serializedConfig);
            return serializedConfig;
        } catch (QueryException e) {
            System.debug(LoggingLevel.ERROR, DEBUG_HEADER + 'Query Exception in getConfigDetailsByName: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new AuraHandledException('Error retrieving GPE Configuration: Configuration not found');
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, DEBUG_HEADER + 'Exception in getConfigDetailsByName: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new AuraHandledException('Error retrieving GPE Configuration: ' + e.getMessage());
        }
    }
    
    private static Map<String, Object> createConfigMap(Genesys_GPE_Config__c config) {
        System.debug(DEBUG_HEADER + 'Entering createConfigMap');
        Map<String, Object> configMap = new Map<String, Object>{
            'configName' => config.Name,
            'gcDomain' => config.GC_Domain__c,
            'gcEnvironment' => config.GC_Environment__c,
            'gcMessagingDeplId' => config.GC_Messaging_Deployment_ID__c,
            'sfWmUrl' => config.SF_WM_URL__c,
            'sfOrgId' => config.SF_Org_Id__c,
            'sfWmName' => config.SF_WM_Name__c,
            'gcOpenActionName' => config.GC_Open_action_Name__c,
            'pageviewConfig' => JSON.deserializeUntyped(config.Pageview_Config__c),
            'formsTrackConfig' => JSON.deserializeUntyped(config.Forms_Track_Config__c),
            'clickEventsConfig' => JSON.deserializeUntyped(config.Click_Events_Config__c),
            'idleEventsConfig' => JSON.deserializeUntyped(config.Idle_Events_Config__c),
            'inViewportConfig' => JSON.deserializeUntyped(config.In_Viewport_Config__c),
            'scrollDepthConfig' => JSON.deserializeUntyped(config.Scroll_Depth_Config__c)
        };
        System.debug(DEBUG_HEADER + 'Created configMap: ' + JSON.serializePretty(configMap));
        return configMap;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<ConfigurationOption> getExistingConfigs() {
        System.debug(DEBUG_HEADER + 'Entering getExistingConfigs');
        try {
            List<Genesys_GPE_Config__c> configs = [SELECT Id, Name FROM Genesys_GPE_Config__c ORDER BY Name];
            System.debug(DEBUG_HEADER + 'Retrieved configs: ' + configs);
            
            List<ConfigurationOption> options = new List<ConfigurationOption>();
            
            for (Genesys_GPE_Config__c config : configs) {
                options.add(new ConfigurationOption(config.Id, config.Name));
            }
            
            System.debug(DEBUG_HEADER + 'Returning options: ' + options);
            return options;
		} catch (Exception e) {
				System.debug(LoggingLevel.ERROR, DEBUG_HEADER + 'Exception in getExistingConfigs: ' + e.getMessage() + '\n' + e.getStackTraceString());
				throw new AuraHandledException('Error retrieving GPE Configurations: ' + e.getMessage());
			}
		}

		@AuraEnabled(cacheable=true)
		public static List<Map<String, String>> getGCDomainOptions() {
			System.debug(DEBUG_HEADER + 'Entering getGCDomainOptions');
			return getPicklistOptions('Genesys_GPE_Config__c', 'GC_Domain__c');
		}

		@AuraEnabled(cacheable=true)
		public static List<Map<String, String>> getGCEnvironmentOptions() {
			System.debug(DEBUG_HEADER + 'Entering getGCEnvironmentOptions');
			return getPicklistOptions('Genesys_GPE_Config__c', 'GC_Environment__c');
		}

		private static List<Map<String, String>> getPicklistOptions(String objectName, String fieldName) {
			System.debug(DEBUG_HEADER + 'Entering getPicklistOptions for object: ' + objectName + ', field: ' + fieldName);
			List<Map<String, String>> options = new List<Map<String, String>>();
			
			try {
				Schema.DescribeFieldResult fieldResult = Schema.getGlobalDescribe().get(objectName).getDescribe().fields.getMap().get(fieldName).getDescribe();
				List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
				
				for(Schema.PicklistEntry f : ple) {
					options.add(new Map<String, String>{
						'label' => f.getLabel(),
						'value' => f.getValue()
					});
				}
				System.debug(DEBUG_HEADER + 'Retrieved picklist options: ' + options);
				return options;
			} catch (Exception e) {
				System.debug(LoggingLevel.ERROR, DEBUG_HEADER + 'Exception in getPicklistOptions: ' + e.getMessage() + '\n' + e.getStackTraceString());
				throw new AuraHandledException('Error retrieving picklist options: ' + e.getMessage());
			}
		}

		public class ConfigurationOption {
			@AuraEnabled public String value;
			@AuraEnabled public String label;
			
			public ConfigurationOption(String value, String label) {
				this.value = value;
				this.label = label;
			}
		}

    public class OpenActionException extends Exception {}

    @AuraEnabled(cacheable=true)
    public static List<Genesys_Session_Event__c> getSessionEvents(Id messagingSessionId) {
        System.debug(DEBUG_HEADER + 'Entering getSessionEvents with messagingSessionId: ' + messagingSessionId);
        try {
            List<Genesys_Session_Event__c> events = [
                SELECT 
                    Id, Event_Type__c, Event_Name__c, Created_Date__c,
                    Page_URL__c, Page_Title__c, Browser_Family__c, Browser_Version__c,
                    Device_Category__c, OS_Family__c, OS_Version__c,
                    Geolocation_Country_Name__c, Geolocation_Region_Name__c, Geolocation_Locality__c,
                    Total_Event_Count__c, Total_Pageview_Count__c,
                    IP_Organization__c, Is_Authenticated__c,
                    Custom_Attributes__c, Traits__c,
                    Action_Id__c, Action_State__c, Action_Map_Id__c, Action_Map_Version__c, Action_Map_Display_Name__c,
                    Segment_Id__c
                FROM Genesys_Session_Event__c
                WHERE Messaging_Session__c = :messagingSessionId
                ORDER BY Created_Date__c ASC
            ];
            
            System.debug(DEBUG_HEADER + 'Retrieved ' + events.size() + ' events for messaging session: ' + messagingSessionId);
            return events;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, DEBUG_HEADER + 'Exception in getSessionEvents: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new AuraHandledException('Error retrieving session events: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String getConfigId(String configName) {
        Genesys_GPE_Config__c config = [SELECT Id FROM Genesys_GPE_Config__c WHERE Name = :configName LIMIT 1];
        return config?.Id;
    }    
}
