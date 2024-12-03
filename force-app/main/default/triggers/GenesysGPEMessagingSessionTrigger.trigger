trigger GenesysGPEMessagingSessionTrigger on MessagingSession (after update) {
    GenesysGPEMessagingSessionHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
}
