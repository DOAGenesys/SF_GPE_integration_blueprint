# Salesforce GPE Integration

## Overview

This project implements a strategic integration between Salesforce and Genesys Predictive Engagement (GPE), bringing together two powerful platforms:
- **Salesforce** serves as the system of record and messaging platform
- **Genesys Cloud** adds proactive and AI-powered predictive engagement capabilities 

The integration enables:
- Monitoring and tracking of web events on Salesforce digital experience sites
- Intelligent triggering of Salesforce messaging based on configurable conditions
- Real-time visibility of customer web journey events for messaging agents
- Advanced customer journey tracking and predictive engagement
- Comprehensive configuration management and event tracking

Key goals of this integration:
- Enhance Salesforce messaging with Genesys Cloud's unique predictive engagement capabilities
- Make GPE data readily available in Salesforce for improved user experience and reporting purposes

## Features

- **Genesys Configuration Management**: 
  - Create and manage Genesys Predictive Engagement configurations
  - Admin-friendly Lightning Web Component for condition configuration
  - Customizable triggers for Salesforce messaging initiation

- **Event Tracking**: Comprehensive monitoring of customer interactions including:
  - Pageview tracking
  - Form submission tracking
  - Click event tracking
  - Idle event tracking
  - Viewport tracking
  - Scroll depth tracking

- **Customer Journey Visualization**: 
  - Real-time visualization of customer interactions and journey
  - Custom Lightning Web Component for agents to view complete web customer journey
  - Timeline view of all events during customer sessions

- **Web Messaging Integration**: 
  - Seamless integration with Salesforce Web Messaging
  - Intelligent trigger conditions based on customer behavior
  - Real-time agent access to customer journey data

- **Automated Event Processing**: 
  - Background processing of customer events and session data
  - Real-time event capture and processing
  - Automatic data synchronization between platforms

## Prerequisites

- Salesforce CLI installed
- Salesforce organization with Service Cloud and MIAW licenses
- Genesys Cloud organization with API access

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
- Configure Salesforce CLI: https://developer.salesforce.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/sfdx_setup_intro.htm

### 2. Clone the Repository

Option 1: Using HTTPS
```bash
git clone https://github.com/DOAGenesys/SF_GPE_integration_blueprint.git
cd SF_GPE_integration_blueprint
```

Option 2: Using SSH (if configured)
```bash
git clone git@github.com:DOAGenesys/SF_GPE_integration_blueprint.git
cd SF_GPE_integration_blueprint
```

Option 3: Download ZIP
- Navigate to https://github.com/DOAGenesys/SF_GPE_integration_blueprint
- Click the "Code" button
- Select "Download ZIP"
- Extract the ZIP file to your local machine

### 3. Authentication

Log in to your Salesforce org:

```bash
sfdx org login web
```

### 4. Deployment

Once you are logged in and have the code locally, deploy the components to your org (change your username properly at the end of the command below):

```bash
sfdx force:source:deploy -p force-app/main/default/objects/Genesys_GPE_Config__c,force-app/main/default/objects/Genesys_Session_Event__c,force-app/main/default/objects/MessagingSession,force-app/main/default/classes/GenesysGPEController.cls,force-app/main/default/classes/GenesysGPEConfigTriggerHandler.cls,force-app/main/default/classes/GenesysGPEMessagingSessionHandler.cls,force-app/main/default/lwc/genesysGPE,force-app/main/default/lwc/genesysGPEConfig,force-app/main/default/lwc/genesysCustomerJourney,force-app/main/default/triggers/GenesysGPEConfigTrigger.trigger,force-app/main/default/triggers/GenesysGPEMessagingSessionTrigger.trigger,force-app/main/default/flows/GPE_Route_Web_Messaging.flow-meta.xml -u <username>
```

## Configuration

See configuration guide

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
