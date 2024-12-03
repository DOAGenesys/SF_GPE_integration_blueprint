import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getConfigDetailsByName from '@salesforce/apex/GenesysGPEController.getConfigDetailsByName';
import getConfigId from '@salesforce/apex/GenesysGPEController.getConfigId';
import LightningIcon from 'lightning/icon';

export default class GenesysGPE extends LightningElement {
    @api gpeConfigName;
    @track isGPELoaded = false;
    @track statusMessage = '';
		@track gpeConfigId;
		@track email;
		@track phone;
		@track showForm = true;
		
    gpeConfig;
    isEmbeddedMessagingReady = false;

    connectedCallback() {
        this.addEmbeddedMessagingEventListeners();
    }

		loadGPEConfig() {
				this.log('Attempting to load GPE configuration');
				if (!this.gpeConfigName) {
						this.log('No GPE Configuration Name provided', null, 'error');
						return;
				}

				this.statusMessage = 'Loading GPE configuration...';
				getConfigDetailsByName({ configName: this.gpeConfigName })
						.then(result => {
								this.log('GPE configuration loaded successfully', result);
								this.gpeConfig = JSON.parse(result);
								// Query for the config ID
								this.getConfigId();
								this.initializeGPE();
						})
						.catch(error => {
								this.handleError('Failed to load GPE configuration', error);
						});
		}
		
		getConfigId() {
				getConfigId({ configName: this.gpeConfigName })
						.then(result => {
								this.gpeConfigId = result;
								this.log('Config ID received:', result);
								if (this.isEmbeddedMessagingReady) {
										this.setupPrechatFields();
								}
						})
						.catch(error => {
								this.handleError('Failed to get config ID', error);
						});
		}

		initializeGPE() {
				this.log('Initializing GPE Script generation');
				const gpeScript = this.generateGPEScript();

				try {
						eval(gpeScript);
						this.isGPELoaded = true;
				} catch (error) {
						this.handleError('Failed to execute GPE script', error);
				}
		}

    generateGPEScript() {
        return `
        (function (g, e, n, es, ys) {
            console.log('GenesysGPE - Execution started.');
            g['_genesysJs'] = e;
            g[e] = g[e] || function () {
                (g[e].q = g[e].q || []).push(arguments);
            };
            g[e].t = 1 * new Date();
            g[e].c = es;
            ys = document.createElement('script');
            ys.async = 1;
            ys.src = n;
            ys.charset = 'utf-8';
            ys.onload = function() {
                console.log('GenesysGPE - Script loaded successfully.');
                g[e]("subscribe", "Journey.ready", function() {
                    console.log("GenesysGPE - Journey plugin is ready.");
                    setupJourneyTracking();
                    setupJourneySubscriptions();
                });
            };
            ys.onerror = function() {
                console.error('GenesysGPE - Error loading script.');
            };
            document.head.appendChild(ys);
        })(window, 'Genesys', '${this.gpeConfig.gcDomain}/genesys-bootstrap/genesys.min.js', {
            environment: '${this.gpeConfig.gcEnvironment}',
            deploymentId: '${this.gpeConfig.gcMessagingDeplId}'
        });

        function setupJourneyTracking() {
        ${this.generateJourneyTrackingCode()}
        }

        function setupJourneySubscriptions() {
            Genesys("subscribe", "Journey.qualifiedOpenAction", function(event) {
                console.log("GenesysGPE - Received Genesys qualified open action event:", event);

                if (event.data.openActionProperties.openActionName === "${this.gpeConfig.gcOpenActionName}") {
                    console.log("GenesysGPE - Showing Salesforce Web Messaging chat button and launching chat...");                    
                    if (typeof embeddedservice_bootstrap !== 'undefined' && embeddedservice_bootstrap.utilAPI) {
                        embeddedservice_bootstrap.utilAPI.showChatButton();

                        // Launch chat immediately after showing the button
                        embeddedservice_bootstrap.utilAPI.launchChat()
                            .then(() => {
                                console.log("GenesysGPE - Salesforce chat launched successfully.");
                            })
                            .catch((error) => {
                                console.error("GenesysGPE - Failed to launch Salesforce chat:", error);
                            })
                            .finally(() => {
                                console.log("GenesysGPE - Chat launch attempt completed.");
                            });
                    } else {
                        console.error("GenesysGPE - Salesforce Embedded Service is not fully initialized.");
                    }
                }
            });
        }

        setupJourneySubscriptions();
        `.trim();
    }

    generateJourneyTrackingCode() {
        let code = [];

				const generateCustomAttributesAndTraits = (customAttributes) => {
						const traitsMapper = [
								{ fieldName: "CustomerEmail", traitName: "email" },
								{ fieldName: "CustomerPhone", traitName: "workPhone" },
								{ fieldName: "CustomerPhone", traitName: "cellPhone" },
								{ fieldName: "CustomerPhone", traitName: "otherPhone" },
								{ fieldName: "CustomerPhone", traitName: "homePhone" }
						];

						let result = '';
						if (this.email || this.phone) {
								const attributes = {};
								if (this.email) attributes.CustomerEmail = this.email;
								if (this.phone) attributes.CustomerPhone = this.phone;
								result = `customAttributes: ${this.stringifyConfig(attributes)}`;
						}

						result += `${result ? ',\n        ' : ''}traitsMapper: ${this.stringifyConfig(traitsMapper)}`;
						return result;
				};

        if (this.gpeConfig.pageviewConfig.enabled) {
            const customAttrsAndTraits = generateCustomAttributesAndTraits(this.gpeConfig.pageviewConfig.customAttributes);
            const pageviewConfig = this.gpeConfig.pageviewConfig.captureAll ? {} : {
                pageTitle: this.gpeConfig.pageviewConfig.pageTitle,
                pageLocation: this.gpeConfig.pageviewConfig.pageLocation,
            };

            code.push(`    Genesys("command", "Journey.pageview", {
                ${this.stringifyConfig(pageviewConfig).slice(1, -1)}${customAttrsAndTraits ? (pageviewConfig.pageTitle || pageviewConfig.pageLocation ? ',\n        ' : '') + customAttrsAndTraits : ''}
            });`);
        }

        if (this.gpeConfig.formsTrackConfig.enabled) {
            const formsTrackConfig = {
                captureFormDataOnAbandon: this.gpeConfig.formsTrackConfig.captureFormDataOnAbandon,
                captureFormDataOnSubmit: this.gpeConfig.formsTrackConfig.captureFormDataOnSubmit
            };

            if (!this.gpeConfig.formsTrackConfig.captureAll) {
                if (this.gpeConfig.formsTrackConfig.selector) {
                    formsTrackConfig.selector = this.gpeConfig.formsTrackConfig.selector;
                }
                if (this.gpeConfig.formsTrackConfig.formName) {
                    formsTrackConfig.formName = this.gpeConfig.formsTrackConfig.formName;
                }
            }

            const customAttrsAndTraits = generateCustomAttributesAndTraits(this.gpeConfig.formsTrackConfig.customAttributes);
            code.push(`    Genesys("command", "Journey.formsTrack", {
                ${this.stringifyConfig(formsTrackConfig).slice(1, -1)}${customAttrsAndTraits ? ',\n        ' + customAttrsAndTraits : ''}
            });`);
        }

        if (this.gpeConfig.clickEventsConfig.enabled) {
            const clickEvents = this.gpeConfig.clickEventsConfig.clickEvents.map(event => {
                const cleanEvent = {
                    selector: event.selector,
                    eventName: event.eventName,
                };
                const customAttrsAndTraits = generateCustomAttributesAndTraits(event.customAttributes);
                return `        {
                    ${this.stringifyConfig(cleanEvent).slice(1, -1)}${customAttrsAndTraits ? ',\n            ' + customAttrsAndTraits : ''}
                }`;
            });
            code.push(`    Genesys("command", "Journey.trackClickEvents", {
                clickEvents: [
                    ${clickEvents.join(',\n')}
                ]
            });`);
        }

        if (this.gpeConfig.idleEventsConfig.enabled) {
            const idleEvents = this.gpeConfig.idleEventsConfig.idleEvents.map(event => {
                const cleanEvent = {
                    idleAfterSeconds: event.idleAfterSeconds,
                    eventName: event.eventName,
                };
                const customAttrsAndTraits = generateCustomAttributesAndTraits(event.customAttributes);
                return `        {
                    ${this.stringifyConfig(cleanEvent).slice(1, -1)}${customAttrsAndTraits ? ',\n            ' + customAttrsAndTraits : ''}
                }`;
            });
            code.push(`    Genesys("command", "Journey.trackIdleEvents", {
                idleEvents: [
                    ${idleEvents.join(',\n')}
                ]
            });`);
        }

        if (this.gpeConfig.inViewportConfig.enabled) {
            const inViewportEvents = this.gpeConfig.inViewportConfig.inViewportEvents.map(event => {
                const cleanEvent = {
                    selector: event.selector,
                    eventName: event.eventName,
                };
                const customAttrsAndTraits = generateCustomAttributesAndTraits(event.customAttributes);
                return `        {
                    ${this.stringifyConfig(cleanEvent).slice(1, -1)}${customAttrsAndTraits ? ',\n            ' + customAttrsAndTraits : ''}
                }`;
            });
            code.push(`    Genesys("command", "Journey.trackInViewport", {
                inViewportEvents: [
                    ${inViewportEvents.join(',\n')}
                ]
            });`);
        }

        if (this.gpeConfig.scrollDepthConfig.enabled) {
            const scrollDepthEvents = this.gpeConfig.scrollDepthConfig.scrollDepthEvents.map(event => {
                const cleanEvent = {
                    percentage: event.percentage,
                    eventName: event.eventName,
                };
                const customAttrsAndTraits = generateCustomAttributesAndTraits(event.customAttributes);
                return `        {
                    ${this.stringifyConfig(cleanEvent).slice(1, -1)}${customAttrsAndTraits ? ',\n            ' + customAttrsAndTraits : ''}
                }`;
            });
            code.push(`    Genesys("command", "Journey.trackScrollDepth", {
                scrollDepthEvents: [
                    ${scrollDepthEvents.join(',\n')}
                ]
            });`);
        }

        return code.join('\n');
    }
		
		handleSubmit() {
				if (!this.email || !this.phone) {
						this.showToast('Error', 'Email and phone are required', 'error');
						return;
				}
				if (this.validateEmail(this.email) && this.validatePhone(this.phone)) {
						this.showForm = false;
						if (this.gpeConfigName) {
								this.loadGPEConfig();
						}
						this.showToast('Success', 'Information submitted successfully', 'success');
				} else {
						this.showToast('Error', 'Please enter valid email and phone number', 'error');
				}
		}
		
		get emailValidationIcon() {
				if (!this.email) return '';
				return this.validateEmail(this.email) ? 'utility:success' : 'utility:error';
		}

		get phoneValidationIcon() {
				if (!this.phone) return '';
				return this.validatePhone(this.phone) ? 'utility:success' : 'utility:error';
		}

		get emailIconClass() {
				return this.validateEmail(this.email) ? 'slds-icon-utility-success' : 'slds-icon-utility-error';
		}

		get phoneIconClass() {
				return this.validatePhone(this.phone) ? 'slds-icon-utility-success' : 'slds-icon-utility-error';
		}

		get emailValidationText() {
				return this.validateEmail(this.email) ? 'Valid email' : 'Invalid email format';
		}

		get phoneValidationText() {
				return this.validatePhone(this.phone) ? 'Valid phone number' : 'Invalid phone format (E.164)';
		}

		get isSubmitDisabled() {
				return !this.email || !this.phone || 
							 !this.validateEmail(this.email) || 
							 !this.validatePhone(this.phone);
		}
		
		handleEmailChange(event) {
				this.email = event.target.value;
				if (!this.validateEmail(this.email)) {
						this.showToast('Warning', 'Please enter a valid email address', 'warning');
				}
		}

		handlePhoneChange(event) {
			 this.phone = event.target.value;
			 if (!this.validatePhone(this.phone)) {
					 this.showToast('Warning', 'Please enter a valid phone number in E.164 format (e.g. +34666111222)', 'warning');
			 }
		}

    stringifyConfig(obj) {
        return JSON.stringify(obj, null, 4)
            .replace(/"([^"]+)":/g, '$1:')
            .replace(/"/g, "'")
            .replace(/\n/g, '\n    ');
    }

		addEmbeddedMessagingEventListeners() {
				window.addEventListener("onEmbeddedMessagingReady", () => {
						this.log("Received the onEmbeddedMessagingReady event.");
						this.isEmbeddedMessagingReady = true;
				});
		}
		
		setupPrechatFields() {
				if (this.isEmbeddedMessagingReady && this.gpeConfig) {
						if (typeof embeddedservice_bootstrap !== 'undefined' && embeddedservice_bootstrap.prechatAPI) {
								const hiddenPrechatFields = {
										"CustomerEmail": this.email,
										"CustomerPhone": this.phone,
										"GPEConfigId": this.gpeConfigId
								};
								embeddedservice_bootstrap.prechatAPI.setHiddenPrechatFields(hiddenPrechatFields);
								this.log("Hidden prechat fields set:", hiddenPrechatFields);
						} else {
								this.log("Embedded Service prechat API not available.", null, 'error');
						}
				}
		}

		validateEmail(email) {
				return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
		}

		validatePhone(phone) {
			 return /^\+[1-9]\d{1,14}$/.test(phone); // E.164 format validation
		}

    showChatButton() {
        if (typeof embeddedservice_bootstrap !== 'undefined' && embeddedservice_bootstrap.utilAPI) {
            embeddedservice_bootstrap.utilAPI.showChatButton();
        } else {
            this.log("Embedded Service API not available", null, 'warn');
        }
    }

    hideChatButton() {
        if (typeof embeddedservice_bootstrap !== 'undefined' && embeddedservice_bootstrap.utilAPI) {
            embeddedservice_bootstrap.utilAPI.hideChatButton();
        } else {
            this.log("Embedded Service API not available", null, 'warn');
        }
    }

    launchChat() {
        if (typeof embeddedservice_bootstrap !== 'undefined' && embeddedservice_bootstrap.utilAPI) {
            embeddedservice_bootstrap.utilAPI.launchChat()
                .then(() => {
                    this.log("Chat launched successfully");
                })
                .catch((error) => {
                    this.handleError("Failed to launch chat", error);
                });
        } else {
            this.log("Embedded Service API not available", null, 'warn');
        }
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(event);
        this.log(`Toast shown: ${title} - ${message}`, null, variant);
    }

    log(message, data = null, level = 'info') {
        const logMessage = `GenesysGPE - ${message}`;
        switch (level) {
            case 'error':
                console.error(logMessage, data);
                break;
            case 'warn':
                console.warn(logMessage, data);
                break;
            default:
                console.log(logMessage, data);
        }
    }

    handleError(message, error) {
        const errorMessage = error.body?.message || error.message || 'Unknown error';
        this.showToast('Error', `${message}: ${errorMessage}`, 'error');
        this.log(`${message}: ${errorMessage}`, error, 'error');
    }

    get statusMessageClass() {
        return this.isGPELoaded ? 'slds-text-color_success' : 'slds-text-color_error';
    }
}
