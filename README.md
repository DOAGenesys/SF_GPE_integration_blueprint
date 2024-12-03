# Salesforce Genesys Integration Project

## Overview

This project implements a comprehensive integration between Salesforce and Genesys Cloud, enabling advanced customer journey tracking, predictive engagement, and web messaging capabilities. The integration includes configuration management, event tracking, and real-time customer journey visualization.

## Features

- **Genesys Configuration Management**: Create and manage Genesys Predictive Engagement configurations
- **Event Tracking**: Track various customer interactions including:
  - Pageview tracking
  - Form submission tracking
  - Click event tracking
  - Idle event tracking
  - Viewport tracking
  - Scroll depth tracking
- **Customer Journey Visualization**: Real-time visualization of customer interactions and journey
- **Web Messaging Integration**: Seamless integration with Salesforce Web Messaging
- **Automated Event Processing**: Background processing of customer events and session data

## Prerequisites

- Salesforce CLI installed
- Salesforce Dev Hub enabled organization
- Genesys Cloud organization with API access
- Appropriate permissions and licenses for both Salesforce and Genesys Cloud

## Project Structure

```
force-app/
├── main/
    └── default/
        ├── classes/
        │   ├── GenesysGPEController.cls
        │   ├── GenesysGPEConfigTriggerHandler.cls
        │   └── GenesysGPEMessagingSessionHandler.cls
        ├── lwc/
        │   ├── genesysGPE/
        │   ├── genesysGPEConfig/
        │   └── genesysCustomerJourney/
        ├── triggers/
        │   ├── GenesysGPEConfigTrigger.trigger
        │   └── GenesysGPEMessagingSessionTrigger.trigger
        └── objects/
            ├── Genesys_GPE_Config__c/
            ├── Genesys_Session_Event__c/
            └── MessagingSession/
```

## Installation

### 1. Prerequisites

- Install Salesforce CLI from: https://developer.salesforce.com/tools/salesforcecli
- Ensure you have appropriate permissions in both Salesforce and Genesys Cloud organizations

### 2. Authentication

Log in to your Salesforce org:

```bash
sfdx org login web
```

### 2. Deployment

Once you are logged in, deploy the components to your org (change your username properly at the end of the command below):

```bash
sfdx force:source:deploy -p force-app/main/default/objects/Genesys_GPE_Config__c,force-app/main/default/objects/Genesys_Session_Event__c,force-app/main/default/objects/MessagingSession,force-app/main/default/classes/GenesysGPEController.cls,force-app/main/default/classes/GenesysGPEConfigTriggerHandler.cls,force-app/main/default/classes/GenesysGPEMessagingSessionHandler.cls,force-app/main/default/lwc/genesysGPE,force-app/main/default/lwc/genesysGPEConfig,force-app/main/default/lwc/genesysCustomerJourney,force-app/main/default/triggers/GenesysGPEConfigTrigger.trigger,force-app/main/default/triggers/GenesysGPEMessagingSessionTrigger.trigger,force-app/main/default/flows/GPE_Route_Web_Messaging.flow-meta.xml -u <username>
```

## Configuration

1. Configure Named Credentials:
   - Set up 'GC_Base_API' named credential for Genesys Cloud API access
   - Configure authentication and endpoint URL

2. Assign Permissions:
   - Create and assign permission sets for user access
   - Configure field-level security for custom objects

3. Configure Genesys Cloud:
   - Set up API credentials
   - Configure Web Messaging deployment
   - Set up Predictive Engagement rules

## Component Overview

### Custom Objects

1. **Genesys_GPE_Config__c**
   - Stores Genesys Predictive Engagement configurations
   - Manages tracking settings and integration parameters

2. **Genesys_Session_Event__c**
   - Records customer journey events
   - Stores detailed interaction data

### Lightning Web Components

1. **genesysGPE**
   - Main component for GPE integration
   - Handles customer identification and session management

2. **genesysGPEConfig**
   - Configuration management interface
   - Supports creation and editing of GPE configurations

3. **genesysCustomerJourney**
   - Visualizes customer journey data
   - Displays interaction timeline and analytics

### Apex Classes

1. **GenesysGPEController**
   - Main controller for GPE functionality
   - Handles configuration management and data retrieval

2. **GenesysGPEConfigTriggerHandler**
   - Manages GPE configuration changes
   - Handles GPE action map creation and updates

3. **GenesysGPEMessagingSessionHandler**
   - Processes messaging session events
   - Manages customer identification and session tracking

### Triggers

1. **GenesysGPEConfigTrigger**
   - Handles configuration record changes
   - Manages related record updates

2. **GenesysGPEMessagingSessionTrigger**
   - Processes messaging session updates
   - Triggers event processing and customer identification

## Usage

### Creating a GPE Configuration

1. Navigate to the GPE Configuration tab
2. Click "Create New Configuration"
3. Fill in required fields:
   - Configuration Name
   - GC Domain
   - GC Environment
   - Messaging Deployment ID
   - SF Web Messaging settings
4. Configure tracking options as needed
5. Save the configuration

### Monitoring Customer Journey

1. Open a Messaging Session record
2. View the Customer Journey component
3. Access detailed event timeline and analytics
4. Monitor customer interactions in real-time

## Troubleshooting

Open browser logs in the browser you are using to navigate the Digital Experience Site, go to the "Console" tab, and filter by "GPE".
