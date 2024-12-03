public class GenesysGPEMessagingSessionHandler {
    private static final String DEBUG_HEADER = 'GenesysGPEMessagingSessionHandler: ';
    private static final String NAMED_CREDENTIAL = 'GC_Base_API';
    private static final String PERMISSION_SET_NAME = 'GC_API_callouts_access';
    private static final String AUTO_PROCESS_ALIAS = 'autoproc';
    
    public static void handleAfterUpdate(List<MessagingSession> newSessions, Map<Id, MessagingSession> oldSessionsMap) {
        System.debug(DEBUG_HEADER + 'Entering handleAfterUpdate with ' + newSessions.size() + ' updated sessions');
        
        checkAndAssignPermissionSet();
        
        List<Id> sessionsToUpdateExternalContact = new List<Id>();
        List<Id> sessionsToUpdateSessionId = new List<Id>();
        List<Id> sessionsToFetchEvents = new List<Id>();
        List<Id> sessionsToSendIdentifiedEvent = new List<Id>();
        
        for (MessagingSession session : newSessions) {
            MessagingSession oldSession = oldSessionsMap.get(session.Id);
            
            System.debug(DEBUG_HEADER + 'Processing session: ' + session.Id);
            System.debug(DEBUG_HEADER + 'New Pre_chat_email__c: ' + session.Pre_chat_email__c);
            System.debug(DEBUG_HEADER + 'Old Pre_chat_email__c: ' + oldSession.Pre_chat_email__c);
            System.debug(DEBUG_HEADER + 'New GC_External_Contact_Id__c: ' + session.GC_External_Contact_Id__c);
            System.debug(DEBUG_HEADER + 'Old GC_External_Contact_Id__c: ' + oldSession.GC_External_Contact_Id__c);
            System.debug(DEBUG_HEADER + 'New GC_Session_Id__c: ' + session.GC_Session_Id__c);
            System.debug(DEBUG_HEADER + 'Old GC_Session_Id__c: ' + oldSession.GC_Session_Id__c);
            
            if (String.isNotBlank(session.Pre_chat_email__c) && 
                String.isNotBlank(session.Pre_chat_phone__c) && 
                (String.isBlank(oldSession.Pre_chat_email__c) || 
                 String.isBlank(oldSession.Pre_chat_phone__c))) {
                sessionsToUpdateExternalContact.add(session.Id);
    			System.debug(DEBUG_HEADER + 'Added session ' + session.Id + ' to update external contact');
            }
            
            if (String.isNotBlank(session.GC_External_Contact_Id__c) && String.isBlank(oldSession.GC_External_Contact_Id__c)) {
                sessionsToUpdateSessionId.add(session.Id);
                System.debug(DEBUG_HEADER + 'Added session ' + session.Id + ' to update session ID');
            }
            
            if (String.isNotBlank(session.GC_Session_Id__c) && String.isBlank(oldSession.GC_Session_Id__c)) {
                sessionsToFetchEvents.add(session.Id);
                System.debug(DEBUG_HEADER + 'Added session ' + session.Id + ' to fetch events');
            }
        }
        
        System.debug(DEBUG_HEADER + 'Sessions to update external contact: ' + sessionsToUpdateExternalContact.size());
        System.debug(DEBUG_HEADER + 'Sessions to update session ID: ' + sessionsToUpdateSessionId.size());
        System.debug(DEBUG_HEADER + 'Sessions to fetch events: ' + sessionsToFetchEvents.size());
        
        if (!sessionsToUpdateExternalContact.isEmpty()) {
            System.debug(DEBUG_HEADER + 'Enqueuing UpdateExternalContactIdsQueueable');
            System.enqueueJob(new UpdateExternalContactIdsQueueable(sessionsToUpdateExternalContact));
        }
        
        if (!sessionsToUpdateSessionId.isEmpty()) {
            System.debug(DEBUG_HEADER + 'Enqueuing UpdateSessionIdsQueueable');
            System.enqueueJob(new UpdateSessionIdsQueueable(sessionsToUpdateSessionId));
        }
        
        if (!sessionsToFetchEvents.isEmpty()) {
            System.debug(DEBUG_HEADER + 'Enqueuing FetchSessionEventsQueueable');
            System.enqueueJob(new FetchSessionEventsQueueable(sessionsToFetchEvents));
        }
        
        System.debug(DEBUG_HEADER + 'Exiting handleAfterUpdate');
    }
    
    private static void checkAndAssignPermissionSet() {
        System.debug(DEBUG_HEADER + 'Checking and assigning permission set if necessary');
        
        User autoProcessUser = [SELECT Id FROM User WHERE Alias = :AUTO_PROCESS_ALIAS LIMIT 1];
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = :PERMISSION_SET_NAME LIMIT 1];
        
        List<PermissionSetAssignment> existingAssignments = [
            SELECT Id 
            FROM PermissionSetAssignment 
            WHERE AssigneeId = :autoProcessUser.Id 
            AND PermissionSetId = :ps.Id 
            LIMIT 1
        ];
        
        if (existingAssignments.isEmpty()) {
            System.debug(DEBUG_HEADER + 'Permission set not assigned. Calling future method to assign.');
            assignPermissionSetFuture(autoProcessUser.Id, ps.Id);
        } else {
            System.debug(DEBUG_HEADER + 'Permission set already assigned');
        }
    }
    
    @future
    private static void assignPermissionSetFuture(Id userId, Id permissionSetId) {
        System.debug(DEBUG_HEADER + 'Entering assignPermissionSetFuture');
        try {
            insert new PermissionSetAssignment(
                AssigneeId = userId,
                PermissionSetId = permissionSetId
            );
            System.debug(DEBUG_HEADER + 'Permission set assigned successfully');
        } catch (Exception e) {
            System.debug(DEBUG_HEADER + 'Error assigning permission set: ' + e.getMessage());
        }
    }
    
    public class UpdateExternalContactIdsQueueable implements Queueable, Database.AllowsCallouts {
        private List<Id> sessionIds;
        
        public UpdateExternalContactIdsQueueable(List<Id> sessionIds) {
            this.sessionIds = sessionIds;
        }
        
        public void execute(QueueableContext context) {
            System.debug(DEBUG_HEADER + 'Entering UpdateExternalContactIdsQueueable.execute with ' + sessionIds.size() + ' sessions');
            List<MessagingSession> sessionsToUpdate = [SELECT Id, Pre_chat_email__c FROM MessagingSession WHERE Id IN :sessionIds];
            System.debug(DEBUG_HEADER + 'Retrieved ' + sessionsToUpdate.size() + ' sessions for updating external contact IDs');
            
            for (MessagingSession session : sessionsToUpdate) {
                System.debug(DEBUG_HEADER + 'Processing session: ' + session.Id + ' with email: ' + session.Pre_chat_email__c);
                String externalContactId = getExternalContactId(session.Pre_chat_email__c);
                if (String.isNotBlank(externalContactId)) {
                    session.GC_External_Contact_Id__c = externalContactId;
                    System.debug(DEBUG_HEADER + 'Updated external contact ID for session ' + session.Id + ': ' + externalContactId);
                } else {
                    System.debug(DEBUG_HEADER + 'No external contact ID found for session ' + session.Id);
                }
            }
            
            if (!sessionsToUpdate.isEmpty()) {
                System.debug(DEBUG_HEADER + 'Updating ' + sessionsToUpdate.size() + ' sessions with external contact IDs');
                update sessionsToUpdate;
                System.debug(DEBUG_HEADER + 'Update completed');
            } else {
                System.debug(DEBUG_HEADER + 'No sessions to update with external contact IDs');
            }
            
            System.debug(DEBUG_HEADER + 'Exiting UpdateExternalContactIdsQueueable.execute');
        }
    }
    
    public class UpdateSessionIdsQueueable implements Queueable, Database.AllowsCallouts {
        private List<Id> sessionIds;
        
        public UpdateSessionIdsQueueable(List<Id> sessionIds) {
            this.sessionIds = sessionIds;
        }
        
        public void execute(QueueableContext context) {
            System.debug(DEBUG_HEADER + 'Entering UpdateSessionIdsQueueable.execute with ' + sessionIds.size() + ' sessions');
            List<MessagingSession> sessionsToUpdate = [SELECT Id, GC_External_Contact_Id__c FROM MessagingSession WHERE Id IN :sessionIds];
            System.debug(DEBUG_HEADER + 'Retrieved ' + sessionsToUpdate.size() + ' sessions for updating GC session IDs');
            
            for (MessagingSession session : sessionsToUpdate) {
                System.debug(DEBUG_HEADER + 'Processing session: ' + session.Id + ' with external contact ID: ' + session.GC_External_Contact_Id__c);
                String gcSessionId = getGCSessionId(session.GC_External_Contact_Id__c);
                if (String.isNotBlank(gcSessionId)) {
                    session.GC_Session_Id__c = gcSessionId;
                    System.debug(DEBUG_HEADER + 'Updated GC session ID for session ' + session.Id + ': ' + gcSessionId);
                } else {
                    System.debug(DEBUG_HEADER + 'No GC session ID found for session ' + session.Id);
                }
            }
            
            if (!sessionsToUpdate.isEmpty()) {
                System.debug(DEBUG_HEADER + 'Updating ' + sessionsToUpdate.size() + ' sessions with GC session IDs');
                update sessionsToUpdate;
                System.debug(DEBUG_HEADER + 'Update completed');
            } else {
                System.debug(DEBUG_HEADER + 'No sessions to update with GC session IDs');
            }
            
            System.debug(DEBUG_HEADER + 'Exiting UpdateSessionIdsQueueable.execute');
        }
    }
    
	public class FetchSessionEventsQueueable implements Queueable, Database.AllowsCallouts {
	   private List<Id> sessionIds;
	   
	   public FetchSessionEventsQueueable(List<Id> sessionIds) {
		   this.sessionIds = sessionIds;
	   }
	   
	   public void execute(QueueableContext context) {
		   System.debug(DEBUG_HEADER + 'Entering FetchSessionEventsQueueable.execute with ' + sessionIds.size() + ' sessions');
		   List<MessagingSession> sessionsToFetchEvents = [SELECT Id, GC_Session_Id__c FROM MessagingSession WHERE Id IN :sessionIds];
		   System.debug(DEBUG_HEADER + 'Retrieved ' + sessionsToFetchEvents.size() + ' sessions for fetching events');
		   
		   List<Genesys_Session_Event__c> eventsToInsert = new List<Genesys_Session_Event__c>();
		   
		   for (MessagingSession session : sessionsToFetchEvents) {
			   System.debug(DEBUG_HEADER + 'Processing session: ' + session.Id + ' with GC session ID: ' + session.GC_Session_Id__c);
			   Map<String, Object> sessionResults = getSessionEvents(session.Id, session.GC_Session_Id__c);
			   List<Genesys_Session_Event__c> sessionEvents = (List<Genesys_Session_Event__c>)sessionResults.get('events');
			   String customerCookieId = (String)sessionResults.get('customerCookieId');
			   			   
			   if (!sessionEvents.isEmpty()) {
				   eventsToInsert.addAll(sessionEvents);
				   System.debug(DEBUG_HEADER + 'Retrieved ' + sessionEvents.size() + ' events for session ' + session.Id);
			   } else {
				   System.debug(DEBUG_HEADER + 'No events found for session ' + session.Id);
			   }
		   }
		   
		   if (!sessionsToFetchEvents.isEmpty()) {
			   System.debug(DEBUG_HEADER + 'Updating ' + sessionsToFetchEvents.size() + ' sessions with customer cookie IDs');
			   update sessionsToFetchEvents;
		   }
		   
		   if (!eventsToInsert.isEmpty()) {
			   System.debug(DEBUG_HEADER + 'Inserting ' + eventsToInsert.size() + ' session events');
			   insert eventsToInsert;
			   System.debug(DEBUG_HEADER + 'Insertion completed');
		   } else {
			   System.debug(DEBUG_HEADER + 'No session events to insert');
		   }
		   
		   System.debug(DEBUG_HEADER + 'Exiting FetchSessionEventsQueueable.execute');
	   }
	}
    
    private static String getExternalContactId(String email) {
        System.debug(DEBUG_HEADER + 'Entering getExternalContactId for email: ' + email);
        HttpRequest req = new HttpRequest();
        String encodedEmail = EncodingUtil.urlEncode(email, 'UTF-8');
        String endpoint = 'callout:' + NAMED_CREDENTIAL + '/api/v2/externalcontacts/contacts?q=' + encodedEmail;
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        
        System.debug(DEBUG_HEADER + 'Making HTTP request to endpoint: ' + endpoint);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        System.debug(DEBUG_HEADER + 'Response status: ' + res.getStatusCode());
        System.debug(DEBUG_HEADER + 'Response body: ' + res.getBody());
        
        if (res.getStatusCode() == 200) {
            Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
            List<Object> entities = (List<Object>)responseMap.get('entities');
            
            System.debug(DEBUG_HEADER + 'Number of entities found: ' + entities.size());
            
            if (!entities.isEmpty()) {
                Map<String, Object> firstContact = (Map<String, Object>)entities[0];
                String externalContactId = (String)firstContact.get('id');
                System.debug(DEBUG_HEADER + 'Found external contact ID: ' + externalContactId);
                return externalContactId;
            }
        }
        
        System.debug(DEBUG_HEADER + 'No external contact found for email: ' + email);
        return null;
    }
    
    private static String getGCSessionId(String externalContactId) {
        System.debug(DEBUG_HEADER + 'Entering getGCSessionId for externalContactId: ' + externalContactId);
        HttpRequest req = new HttpRequest();
        String endpoint = 'callout:' + NAMED_CREDENTIAL + '/api/v2/externalcontacts/contacts/' + externalContactId + '/journey/sessions?pageSize=1';
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        
        System.debug(DEBUG_HEADER + 'Making HTTP request to endpoint: ' + endpoint);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        System.debug(DEBUG_HEADER + 'Response status: ' + res.getStatusCode());
        System.debug(DEBUG_HEADER + 'Response body: ' + res.getBody());
        
        if (res.getStatusCode() == 200) {
            Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
            List<Object> entities = (List<Object>)responseMap.get('entities');
            
            System.debug(DEBUG_HEADER + 'Number of entities found: ' + entities.size());
            
            if (!entities.isEmpty()) {
                Map<String, Object> firstSession = (Map<String, Object>)entities[0];
				String gcSessionId = (String)firstSession.get('id');
                System.debug(DEBUG_HEADER + 'Found GC session ID: ' + gcSessionId);
                return gcSessionId;
            }
        }

        System.debug(DEBUG_HEADER + 'No GC session found for external contact ID: ' + externalContactId);
        return null;
    }
    
	private static Map<String, Object> getSessionEvents(Id messagingSessionId, String gcSessionId) {
       System.debug(DEBUG_HEADER + 'Entering getSessionEvents for GC session ID: ' + gcSessionId);
       HttpRequest req = new HttpRequest();
       String endpoint = 'callout:' + NAMED_CREDENTIAL + '/api/v2/journey/sessions/' + gcSessionId + '/events?pageSize=200';
       req.setEndpoint(endpoint);
       req.setMethod('GET');
       
       System.debug(DEBUG_HEADER + 'Making HTTP request to endpoint: ' + endpoint);
       
       Http http = new Http();
       HttpResponse res = http.send(req);
       
       System.debug(DEBUG_HEADER + 'Response status: ' + res.getStatusCode());
       System.debug(DEBUG_HEADER + 'Response body: ' + res.getBody());
       
       List<Genesys_Session_Event__c> sessionEvents = new List<Genesys_Session_Event__c>();
       String customerCookieId;
       
       if (res.getStatusCode() == 200) {
           Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
           List<Object> entities = (List<Object>)responseMap.get('entities');
           
           // Create set of event types to ignore
           Set<String> ignoredEventTypes = new Set<String>{
               'com.genesys.journey.WebActionEvent',
               'com.genesys.journey.SegmentAssignmentEvent',
               'com.genesys.journey.OutcomeAssignmentEvent'
           };
           
           System.debug(DEBUG_HEADER + 'Number of events found before filtering: ' + entities.size());
           
           // Find first event with cookie customerIdType
           for (Object entity : entities) {
               Map<String, Object> eventMap = (Map<String, Object>)entity;
               String customerIdType = (String)eventMap.get('customerIdType');
               if (customerIdType == 'cookie') {
                   customerCookieId = (String)eventMap.get('customerId');
                   System.debug(DEBUG_HEADER + 'Found customer cookie ID: ' + customerCookieId);
                   break;
               }
           }
           
           for (Object entity : entities) {
               Map<String, Object> eventMap = (Map<String, Object>)entity;
               String eventType = (String)eventMap.get('eventType');
               
               // Skip if event type is in ignored list
               if (String.isNotBlank(eventType) && ignoredEventTypes.contains(eventType)) {
                   System.debug(DEBUG_HEADER + 'Skipping ignored event type: ' + eventType);
                   continue;
               }
               
               Genesys_Session_Event__c sessionEvent = new Genesys_Session_Event__c();
               sessionEvent.Messaging_Session__c = messagingSessionId;
               sessionEvent.Event_Id__c = (String)eventMap.get('id');
               sessionEvent.Correlation_Id__c = (String)eventMap.get('correlationId');
               sessionEvent.Customer_Id__c = (String)eventMap.get('customerId');
               sessionEvent.Customer_Id_Type__c = (String)eventMap.get('customerIdType');
               sessionEvent.Event_Type__c = eventType;
               
               String createdDateString = (String)eventMap.get('createdDate');
               if (String.isNotBlank(createdDateString)) {
                   createdDateString = createdDateString.removeEnd('Z').replace('T', ' ');
                   sessionEvent.Created_Date__c = Datetime.valueOfGmt(createdDateString);
               }
               
               Map<String, Object> sessionMap = (Map<String, Object>)eventMap.get('session');
               if (sessionMap != null) {
                   sessionEvent.Session_Id__c = (String)sessionMap.get('id');
                   sessionEvent.Session_Type__c = (String)sessionMap.get('type');
               }
               
               if (eventType == 'com.genesys.journey.WebEvent') {
                   Map<String, Object> webEventMap = (Map<String, Object>)eventMap.get('webEvent');
                   if (webEventMap != null) {
                       sessionEvent.Event_Name__c = (String)webEventMap.get('eventName');
                       sessionEvent.Total_Event_Count__c = (Integer)webEventMap.get('totalEventCount');
                       sessionEvent.Total_Pageview_Count__c = (Integer)webEventMap.get('totalPageviewCount');
                       
                       if (sessionEvent.Event_Name__c != null && sessionEvent.Event_Name__c.contains('idle')) {
                           sessionEvent.Idle_Duration_Seconds__c = 120; // Default value, adjust if needed
                       }
                       
                       Map<String, Object> pageMap = (Map<String, Object>)webEventMap.get('page');
                       if (pageMap != null) {
                           sessionEvent.Page_URL__c = (String)pageMap.get('url');
                           sessionEvent.Page_Title__c = (String)pageMap.get('title');
                           sessionEvent.Page_Domain__c = (String)pageMap.get('domain');
                           sessionEvent.Page_Hostname__c = (String)pageMap.get('hostname');
                           sessionEvent.Page_Language__c = (String)pageMap.get('lang');
                           sessionEvent.Page_Pathname__c = (String)pageMap.get('pathname');
                       }
                       
                       Map<String, Object> browserMap = (Map<String, Object>)webEventMap.get('browser');
                       if (browserMap != null) {
                           sessionEvent.Browser_Family__c = (String)browserMap.get('family');
                           sessionEvent.Browser_Version__c = (String)browserMap.get('version');
                           sessionEvent.Browser_Language__c = (String)browserMap.get('lang');
                       }
                       
                       Map<String, Object> deviceMap = (Map<String, Object>)webEventMap.get('device');
                       if (deviceMap != null) {
                           sessionEvent.Device_Category__c = (String)deviceMap.get('category');
                           sessionEvent.Device_Type__c = (String)deviceMap.get('type');
                           sessionEvent.Device_Is_Mobile__c = (Boolean)deviceMap.get('isMobile');
                           sessionEvent.OS_Family__c = (String)deviceMap.get('osFamily');
                           sessionEvent.OS_Version__c = (String)deviceMap.get('osVersion');
                       }
                       
                       Map<String, Object> geolocationMap = (Map<String, Object>)webEventMap.get('geolocation');
                       if (geolocationMap != null) {
                           sessionEvent.Geolocation_Country__c = (String)geolocationMap.get('country');
                           sessionEvent.Geolocation_Country_Name__c = (String)geolocationMap.get('countryName');
                           sessionEvent.Geolocation_Locality__c = (String)geolocationMap.get('locality');
                           sessionEvent.Geolocation_Postal_Code__c = (String)geolocationMap.get('postalCode');
                           sessionEvent.Geolocation_Region__c = (String)geolocationMap.get('region');
                           sessionEvent.Geolocation_Region_Name__c = (String)geolocationMap.get('regionName');
                           sessionEvent.Geolocation_Timezone__c = (String)geolocationMap.get('timezone');
                       }
                       
                       sessionEvent.IP_Organization__c = (String)webEventMap.get('ipOrganization');
                       
                       Map<String, Object> referrerMap = (Map<String, Object>)webEventMap.get('referrer');
                       if (referrerMap != null) {
                           sessionEvent.Referrer_URL__c = (String)referrerMap.get('url');
                           sessionEvent.Referrer_Domain__c = (String)referrerMap.get('domain');
                           sessionEvent.Referrer_Hostname__c = (String)referrerMap.get('hostname');
                           sessionEvent.Referrer_Pathname__c = (String)referrerMap.get('pathname');
                           sessionEvent.Referrer_Medium__c = (String)referrerMap.get('medium');
                       }
                       
                       sessionEvent.Is_Authenticated__c = (Boolean)webEventMap.get('authenticated');
                       
                       Map<String, Object> attributesMap = (Map<String, Object>)webEventMap.get('attributes');
                       if (attributesMap != null) {
                           sessionEvent.Custom_Attributes__c = JSON.serialize(attributesMap);
                           
                           if (sessionEvent.Event_Name__c != null && sessionEvent.Event_Name__c.contains('form')) {
                               Object formNameObj = attributesMap.get('formName');
                               if (formNameObj != null) {
                                   sessionEvent.Form_Name__c = String.valueOf(formNameObj);
                               }
                               Object formDataObj = attributesMap.get('formData');
                               if (formDataObj != null) {
                                   sessionEvent.Form_Data__c = JSON.serialize(formDataObj);
                               }
                           } else if (sessionEvent.Event_Name__c != null && sessionEvent.Event_Name__c.contains('scroll')) {
                               Object percentageObj = attributesMap.get('percentage');
                               if (percentageObj instanceof Map<String, Object>) {
                                   Map<String, Object> percentageMap = (Map<String, Object>)percentageObj;
                                   Object valueObj = percentageMap.get('value');
                                   if (valueObj != null) {
                                       sessionEvent.Scroll_Depth_Percentage__c = Integer.valueOf(String.valueOf(valueObj));
                                   }
                               }
                           }
                           
                           Object selectorObj = attributesMap.get('selector');
                           if (selectorObj != null) {
                               sessionEvent.Viewport_Element_Selector__c = String.valueOf(selectorObj);
                           }
                       }
                       
                       Map<String, Object> traitsMap = (Map<String, Object>)webEventMap.get('traits');
                       if (traitsMap != null) {
                           sessionEvent.Traits__c = JSON.serialize(traitsMap);
                       }
                   }
               }
               
               sessionEvents.add(sessionEvent);
           }
       }
       
       System.debug(DEBUG_HEADER + 'Returning ' + sessionEvents.size() + ' session events');
       
       return new Map<String, Object>{
           'events' => sessionEvents,
           'customerCookieId' => customerCookieId
       };
   }
    
	private static void sendCustomerIdentifiedEvent(String deploymentId, String email, String phone, String cookieId) {
        System.debug(DEBUG_HEADER + 'Sending customer identified event for deployment: ' + deploymentId);
        
        HttpRequest req = new HttpRequest();
        String endpoint = 'callout:' + NAMED_CREDENTIAL + '/api/v2/journey/deployments/' + deploymentId + '/webevents';
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        
		Map<String, Object> payload = new Map<String, Object>{
			'eventName' => 'customer_identified',
			'createdDate' => Datetime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
			'customerCookieId' => cookieId,
            'page' => new Map<String, Object>{
                'url' => 'customer_autentication',
                'title' => 'customer_autentication'
            },
            'attributes' => new Map<String, Object>{
                'emailAddress' => new Map<String, Object>{
                    'dataType' => 'string',
                    'value' => email
                },
                'mobilePhone' => new Map<String, Object>{
                    'dataType' => 'string',
                    'value' => phone
                }
            },
            'traits' => new Map<String, Object>{
                'email' => new Map<String, Object>{
                    'dataType' => 'string',
                    'value' => email
                },
                'cellPhone' => new Map<String, Object>{
                    'dataType' => 'string',
                    'value' => phone
                }
            }
        };
        
        req.setBody(JSON.serialize(payload));
        
        System.debug(DEBUG_HEADER + 'Making HTTP request to endpoint: ' + endpoint);
        System.debug(DEBUG_HEADER + 'Request body: ' + req.getBody());
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        System.debug(DEBUG_HEADER + 'Response status: ' + res.getStatusCode());
        System.debug(DEBUG_HEADER + 'Response body: ' + res.getBody());
        
        if (res.getStatusCode() != 200 && res.getStatusCode() != 201) {
            System.debug(DEBUG_HEADER + 'Error sending customer identified event: ' + res.getBody());
        }
    }
}
