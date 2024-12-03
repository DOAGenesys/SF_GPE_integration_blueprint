import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import saveGPEConfig from '@salesforce/apex/GenesysGPEController.saveGPEConfig';
import deleteGPEConfig from '@salesforce/apex/GenesysGPEController.deleteGPEConfig';
import getGCDomainOptions from '@salesforce/apex/GenesysGPEController.getGCDomainOptions';
import getGCEnvironmentOptions from '@salesforce/apex/GenesysGPEController.getGCEnvironmentOptions';
import getExistingConfigs from '@salesforce/apex/GenesysGPEController.getExistingConfigs';
import getConfigDetails from '@salesforce/apex/GenesysGPEController.getConfigDetails';

export default class GenesysGPEConfig extends LightningElement {
    @api recordId;
    @track configName = '';
    @track gcDomain = '';
    @track gcEnvironment = '';
    @track gcMessagingDeplId = '';
		@track openActionName = '';
    @track pageviewConfig = {
        enabled: false,
        captureAll: false,
        pageTitle: '',
        pageLocation: '',
        customAttributes: []
    };
    @track formsTrackConfig = {
        enabled: false,
        captureAll: false,
        selector: 'form',
        formName: '',
        captureFormDataOnAbandon: false,
        captureFormDataOnSubmit: true
    };
    @track clickEventsConfig = {
        enabled: false,
        clickEvents: []
    };
    @track idleEventsConfig = {
        enabled: false,
        idleEvents: []
    };
    @track inViewportConfig = {
        enabled: false,
        inViewportEvents: []
    };
    @track scrollDepthConfig = {
        enabled: false,
        scrollDepthEvents: []
    };
    
    @track gcDomainOptions = [];
    @track gcEnvironmentOptions = [];
    @track existingConfigOptions = [];
    @track showInitialChoice = true;
    @track showExistingConfigDropdown = false;
    @track showConfigForm = false;
    @track selectedConfigAction = '';
    @track selectedExistingConfig = '';
    @track isEditMode = false;
		
    @track sfWmUrl = '';
    @track sfOrgId = '';
    @track sfWmName = '';		

    configActionOptions = [
        { label: 'Create New Configuration', value: 'create' },
        { label: 'Edit Existing Configuration', value: 'edit' }
    ];

    selectorHelpText = `Steps to find "Selector" value on Chrome:
1. Locate the UI element you want to track. Right-click it, select "Inspect".
2. Right-click the highlighted area in the developer tools section, and select "Copy" > "Copy selector".`;

    get saveButtonLabel() {
        return this.isEditMode ? 'Update Configuration' : 'Save Configuration';
    }

    @wire(getGCDomainOptions)
    wiredGCDomainOptions({ error, data }) {
        if (data) {
            this.gcDomainOptions = data.map(option => ({
                label: option.label,
                value: option.value
            }));
            console.log('genesysGPEConfig - GC Domain options loaded successfully');
        } else if (error) {
            console.error('Error fetching GC Domain options:', error);
        }
    }

    @wire(getGCEnvironmentOptions)
    wiredGCEnvironmentOptions({ error, data }) {
        if (data) {
            this.gcEnvironmentOptions = data.map(option => ({
                label: option.label,
                value: option.value
            }));
            console.log('genesysGPEConfig - GC Environment options loaded successfully');
        } else if (error) {
            console.error('Error fetching GC Environment options:', error);
        }
    }

		@wire(getExistingConfigs)
		wiredExistingConfigs({ error, data }) {
				if (data) {
						console.log('genesysGPEConfig - Existing configs:', JSON.stringify(data));
						this.existingConfigOptions = data.map(config => ({
								label: config.label,
								value: config.value
						}));
						console.log('genesysGPEConfig - Existing config options:', JSON.stringify(this.existingConfigOptions));
				} else if (error) {
						console.error('Error fetching existing configurations:', error);
				}
		}

		get noConfigurationsFound() {
				return this.existingConfigOptions && this.existingConfigOptions.length === 0;
		}		

    handleConfigActionChange(event) {
        this.selectedConfigAction = event.detail.value;
        if (this.selectedConfigAction === 'create') {
            this.showExistingConfigDropdown = false;
            this.showConfigForm = true;
            this.isEditMode = false;
            this.resetForm();
        } else if (this.selectedConfigAction === 'edit') {
            this.showExistingConfigDropdown = true;
            this.showConfigForm = false;
            this.isEditMode = true;
        }
        this.showInitialChoice = false;
        console.log(`Config action changed to: ${this.selectedConfigAction}`);
    }

    handleExistingConfigChange(event) {
        this.selectedExistingConfig = event.detail.value;
        this.loadExistingConfig(this.selectedExistingConfig);
        console.log(`Selected existing config: ${this.selectedExistingConfig}`);
    }

		loadExistingConfig(configId) {
				getConfigDetails({ configId: configId })
						.then(result => {
								const config = JSON.parse(result);
								this.configName = config.configName;
								this.gcDomain = config.gcDomain;
								this.gcEnvironment = config.gcEnvironment;
								this.gcMessagingDeplId = config.gcMessagingDeplId;
								this.sfWmUrl = config.sfWmUrl;
								this.sfOrgId = config.sfOrgId;
								this.sfWmName = config.sfWmName;
								this.pageviewConfig = config.pageviewConfig;
								this.formsTrackConfig = config.formsTrackConfig;
								this.clickEventsConfig = config.clickEventsConfig;
								this.idleEventsConfig = config.idleEventsConfig;
								this.inViewportConfig = config.inViewportConfig;
								this.scrollDepthConfig = config.scrollDepthConfig;
								this.showConfigForm = true;
								console.log('genesysGPEConfig - Existing configuration loaded successfully');
						})
						.catch(error => {
								console.error('Error loading existing configuration:', error);
								this.showToast('Error', 'Failed to load existing configuration', 'error');
						});
		}

    returnToStart() {
        this.showInitialChoice = true;
        this.showExistingConfigDropdown = false;
        this.showConfigForm = false;
        this.selectedConfigAction = '';
        this.selectedExistingConfig = '';
        this.isEditMode = false;
        this.resetForm();
        console.log('genesysGPEConfig - Returned to start');
    }

		resetForm() {
				this.configName = '';
				this.gcDomain = '';
				this.gcEnvironment = '';
				this.gcMessagingDeplId = '';
				this.sfWmUrl = '';
				this.sfOrgId = '';
				this.sfWmName = '';
				this.pageviewConfig = {
						enabled: false,
						captureAll: false,
						pageTitle: '',
						pageLocation: '',
						customAttributes: []
				};
				this.formsTrackConfig = {
						enabled: false,
						captureAll: false,
						selector: '',
						formName: '',
						captureFormDataOnAbandon: false,
						captureFormDataOnSubmit: true
				};
				this.clickEventsConfig = {
						enabled: false,
						clickEvents: []
				};
				this.idleEventsConfig = {
						enabled: false,
						idleEvents: []
				};
				this.inViewportConfig = {
						enabled: false,
						inViewportEvents: []
				};
				this.scrollDepthConfig = {
						enabled: false,
						scrollDepthEvents: []
				};
				this.openActionName = '';
				console.log('genesysGPEConfig - Form reset');
		}

    handleConfigNameChange(event) {
        this.configName = event.target.value;
        console.log('genesysGPEConfig - Configuration name changed:', this.configName);
    }

		handleInputChange(event) {
				this[event.target.dataset.field] = event.target.value;
				console.log(`${event.target.dataset.field} changed:`, this[event.target.dataset.field]);
		}

		getGCEnvironmentFromDomain(domain) {
				const domainMapping = {
						'https://apps.mypurecloud.ie': 'prod-euw1',
						'https://apps.mypurecloud.de': 'prod-euc1',
						'https://apps.euw2.pure.cloud': 'prod-euw2',
						'https://apps.euc2.pure.cloud': 'prod-euc2',
						'https://apps.mypurecloud.com': 'prod-use1',
						'https://apps.use2.us-gov-pure.cloud': 'prod-use2',
						'https://apps.usw2.pure.cloud': 'prod-usw2',
						'https://apps.cac1.pure.cloud': 'prod-cac1',
						'https://apps.sae1.pure.cloud': 'prod-sae1',
						'https://apps.aps1.pure.cloud': 'prod-aps1',
						'https://apps.apne2.pure.cloud': 'prod-apne2',
						'https://apps.mypurecloud.com.au': 'prod-apse2',
						'https://apps.apne3.pure.cloud': 'prod-apne3',
						'https://apps.mypurecloud.jp': 'prod-apne1',
						'https://apps.mec1.pure.cloud': 'prod-mec1'
				};
				return domainMapping[domain] || '';
		}

		handleGCDomainChange(event) {
				this.gcDomain = event.detail.value;
				this.gcEnvironment = this.getGCEnvironmentFromDomain(this.gcDomain);
				this.gcEnvironmentDisabled = !!this.gcEnvironment;
				console.log('genesysGPEConfig - GC Domain changed:', this.gcDomain);
				console.log('genesysGPEConfig - GC Environment set to:', this.gcEnvironment);
		}

    handleGCEnvironmentChange(event) {
        this.gcEnvironment = event.detail.value;
        console.log('genesysGPEConfig - GC Environment changed:', this.gcEnvironment);
    }

    handlePageviewChange(event) {
        const field = event.target.dataset.field;
        if (field === 'enabled' || field === 'captureAll') {
            this.pageviewConfig[field] = event.target.checked;
            if (field === 'captureAll' && event.target.checked) {
                this.pageviewConfig.pageTitle = '';
                this.pageviewConfig.pageLocation = '';
                this.pageviewConfig.customAttributes = [];
            }
        } else {
            this.pageviewConfig[field] = event.target.value;
        }
        console.log(`Pageview config ${field} changed:`, this.pageviewConfig[field]);
    }

		addPageviewCustomAttribute() {
				this.pageviewConfig.customAttributes.push({ id: Date.now(), name: '', value: '', traitName: '' });
				console.log('genesysGPEConfig - Pageview custom attribute added');
		}

		handlePageviewCustomAttributeChange(event) {
				const index = event.target.dataset.index;
				const field = event.target.dataset.field;
				this.pageviewConfig.customAttributes[index][field] = event.target.value;
				console.log(`Pageview custom attribute ${field} changed at index ${index}`);
		}

    removePageviewCustomAttribute(event) {
        const index = event.target.dataset.index;
        this.pageviewConfig.customAttributes.splice(index, 1);
        console.log(`Pageview custom attribute removed at index ${index}`);
    }

		handleFormsTrackChange(event) {
				const field = event.target.dataset.field;
				if (field === 'enabled' || field === 'captureAll' || field === 'captureFormDataOnAbandon' || field === 'captureFormDataOnSubmit') {
						this.formsTrackConfig[field] = event.target.checked;
				} else {
						this.formsTrackConfig[field] = event.target.value;
				}
				console.log(`Forms track config ${field} changed:`, this.formsTrackConfig[field]);
		}

		addFormsCustomAttribute() {
				this.formsTrackConfig.customAttributes.push({ id: Date.now(), name: '', value: '', traitName: '' });
				console.log('genesysGPEConfig - Forms custom attribute added');
		}

		handleFormsCustomAttributeChange(event) {
				const index = event.target.dataset.index;
				const field = event.target.dataset.field;
				this.formsTrackConfig.customAttributes[index][field] = event.target.value;
				console.log(`Forms custom attribute ${field} changed at index ${index}`);
		}

		removeFormsCustomAttribute(event) {
				const index = event.target.dataset.index;
				this.formsTrackConfig.customAttributes.splice(index, 1);
				console.log(`Forms custom attribute removed at index ${index}`);
		}

		handleClickEventsChange(event) {
				const field = event.target.dataset.field;
				if (field === 'enabled') {
						this.clickEventsConfig.enabled = event.target.checked;
				}
				console.log('genesysGPEConfig - Click events config enabled changed:', this.clickEventsConfig.enabled);
		}

		addClickEvent() {
				this.clickEventsConfig.clickEvents.push({ id: Date.now(), selector: '', eventName: '', customAttributes: [] });
				console.log('genesysGPEConfig - Click event added');
		}

    handleClickEventChange(event) {
        const index = event.target.dataset.index;
        const field = event.target.dataset.field;
        if (field === 'eventNameSuffix') {
            this.clickEventsConfig.clickEvents[index].eventNameSuffix = event.target.value;
            this.clickEventsConfig.clickEvents[index].eventName = 'click_' + event.target.value;
        } else {
            this.clickEventsConfig.clickEvents[index][field] = event.target.value;
        }
        console.log(`Click event ${field} changed at index ${index}`);
    }

		addClickEventCustomAttribute(event) {
				const index = event.target.dataset.index;
				this.clickEventsConfig.clickEvents[index].customAttributes.push({ id: Date.now(), name: '', value: '', traitName: '' });
				console.log(`Click event custom attribute added at index ${index}`);
		}

		handleClickEventCustomAttributeChange(event) {
				const eventIndex = event.target.dataset.eventIndex;
				const attrIndex = event.target.dataset.attrIndex;
				const field = event.target.dataset.field;
				this.clickEventsConfig.clickEvents[eventIndex].customAttributes[attrIndex][field] = event.target.value;
				console.log(`Click event custom attribute ${field} changed at event index ${eventIndex}, attribute index ${attrIndex}`);
		}

		removeClickEventCustomAttribute(event) {
				const eventIndex = event.target.dataset.eventIndex;
				const attrIndex = event.target.dataset.attrIndex;
				this.clickEventsConfig.clickEvents[eventIndex].customAttributes.splice(attrIndex, 1);
				console.log(`Click event custom attribute removed at event index ${eventIndex}, attribute index ${attrIndex}`);
		}

		handleIdleEventsChange(event) {
				const field = event.target.dataset.field;
				if (field === 'enabled') {
						this.idleEventsConfig.enabled = event.target.checked;
				}
				console.log('genesysGPEConfig - Idle events config enabled changed:', this.idleEventsConfig.enabled);
		}

		addIdleEvent() {
				this.idleEventsConfig.idleEvents.push({ id: Date.now(), idleAfterSeconds: 30, eventName: '', customAttributes: [] });
				console.log('genesysGPEConfig - Idle event added');
		}

    handleIdleEventChange(event) {
        const index = event.target.dataset.index;
        const field = event.target.dataset.field;
        if (field === 'eventNameSuffix') {
            this.idleEventsConfig.idleEvents[index].eventNameSuffix = event.target.value;
            this.idleEventsConfig.idleEvents[index].eventName = 'idle_' + event.target.value;
        } else {
            this.idleEventsConfig.idleEvents[index][field] = field === 'idleAfterSeconds' ? parseInt(event.target.value) : event.target.value;
        }
        console.log(`Idle event ${field} changed at index ${index}`);
    }

		removeIdleEvent(event) {
				const index = event.target.dataset.index;
				this.idleEventsConfig.idleEvents.splice(index, 1);
				console.log(`Idle event removed at index ${index}`);
		}

		addIdleEventCustomAttribute(event) {
				const index = event.target.dataset.index;
				this.idleEventsConfig.idleEvents[index].customAttributes.push({ id: Date.now(), name: '', value: '', traitName: '' });
				console.log(`Idle event custom attribute added at index ${index}`);
		}

		handleIdleEventCustomAttributeChange(event) {
				const eventIndex = event.target.dataset.eventIndex;
				const attrIndex = event.target.dataset.attrIndex;
				const field = event.target.dataset.field;
				this.idleEventsConfig.idleEvents[eventIndex].customAttributes[attrIndex][field] = event.target.value;
				console.log(`Idle event custom attribute ${field} changed at event index ${eventIndex}, attribute index ${attrIndex}`);
		}

		removeIdleEventCustomAttribute(event) {
				const eventIndex = event.target.dataset.eventIndex;
				const attrIndex = event.target.dataset.attrIndex;
				this.idleEventsConfig.idleEvents[eventIndex].customAttributes.splice(attrIndex, 1);
				console.log(`Idle event custom attribute removed at event index ${eventIndex}, attribute index ${attrIndex}`);
		}

		handleInViewportChange(event) {
				const field = event.target.dataset.field;
				if (field === 'enabled') {
						this.inViewportConfig.enabled = event.target.checked;
				}
				console.log('genesysGPEConfig - In Viewport config enabled changed:', this.inViewportConfig.enabled);
		}

		addInViewportEvent() {
				this.inViewportConfig.inViewportEvents.push({ id: Date.now(), selector: '', eventName: '', customAttributes: [] });
				console.log('genesysGPEConfig - In Viewport event added');
		}

    handleInViewportEventChange(event) {
        const index = event.target.dataset.index;
        const field = event.target.dataset.field;
        if (field === 'eventNameSuffix') {
            this.inViewportConfig.inViewportEvents[index].eventNameSuffix = event.target.value;
            this.inViewportConfig.inViewportEvents[index].eventName = 'viewport_' + event.target.value;
        } else {
            this.inViewportConfig.inViewportEvents[index][field] = event.target.value;
        }
        console.log(`In Viewport event ${field} changed at index ${index}`);
    }

		removeInViewportEvent(event) {
				const index = event.target.dataset.index;
				this.inViewportConfig.inViewportEvents.splice(index, 1);
				console.log(`In Viewport event removed at index ${index}`);
		}

		addInViewportEventCustomAttribute(event) {
				const index = event.target.dataset.index;
				this.inViewportConfig.inViewportEvents[index].customAttributes.push({ id: Date.now(), name: '', value: '', traitName: '' });
				console.log(`In Viewport event custom attribute added at index ${index}`);
		}

		handleInViewportEventCustomAttributeChange(event) {
				const eventIndex = event.target.dataset.eventIndex;
				const attrIndex = event.target.dataset.attrIndex;
				const field = event.target.dataset.field;
				this.inViewportConfig.inViewportEvents[eventIndex].customAttributes[attrIndex][field] = event.target.value;
				console.log(`In Viewport event custom attribute ${field} changed at event index ${eventIndex}, attribute index ${attrIndex}`);
		}

		removeInViewportEventCustomAttribute(event) {
				const eventIndex = event.target.dataset.eventIndex;
				const attrIndex = event.target.dataset.attrIndex;
				this.inViewportConfig.inViewportEvents[eventIndex].customAttributes.splice(attrIndex, 1);
				console.log(`In Viewport event custom attribute removed at event index ${eventIndex}, attribute index ${attrIndex}`);
		}

		handleScrollDepthChange(event) {
				const field = event.target.dataset.field;
				if (field === 'enabled') {
						this.scrollDepthConfig.enabled = event.target.checked;
				}
				console.log('genesysGPEConfig - Scroll Depth config enabled changed:', this.scrollDepthConfig.enabled);
		}

		addScrollDepthEvent() {
				this.scrollDepthConfig.scrollDepthEvents.push({ id: Date.now(), percentage: 25, eventName: '', customAttributes: [] });
				console.log('genesysGPEConfig - Scroll Depth event added');
		}

    handleScrollDepthEventChange(event) {
        const index = event.target.dataset.index;
        const field = event.target.dataset.field;
        if (field === 'eventNameSuffix') {
            this.scrollDepthConfig.scrollDepthEvents[index].eventNameSuffix = event.target.value;
            this.scrollDepthConfig.scrollDepthEvents[index].eventName = 'scroll_' + event.target.value;
        } else {
            this.scrollDepthConfig.scrollDepthEvents[index][field] = field === 'percentage' ? parseInt(event.target.value) : event.target.value;
        }
        console.log(`Scroll Depth event ${field} changed at index ${index}`);
    }

		removeScrollDepthEvent(event) {
				const index = event.target.dataset.index;
				this.scrollDepthConfig.scrollDepthEvents.splice(index, 1);
				console.log(`Scroll Depth event removed at index ${index}`);
		}

		addScrollDepthEventCustomAttribute(event) {
				const index = event.target.dataset.index;
				this.scrollDepthConfig.scrollDepthEvents[index].customAttributes.push({ id: Date.now(), name: '', value: '', traitName: '' });
				console.log(`Scroll Depth event custom attribute added at index ${index}`);
		}

		handleScrollDepthEventCustomAttributeChange(event) {
				const eventIndex = event.target.dataset.eventIndex;
				const attrIndex = event.target.dataset.attrIndex;
				const field = event.target.dataset.field;
				this.scrollDepthConfig.scrollDepthEvents[eventIndex].customAttributes[attrIndex][field] = event.target.value;
				console.log(`Scroll Depth event custom attribute ${field} changed at event index ${eventIndex}, attribute index ${attrIndex}`);
		}

		removeScrollDepthEventCustomAttribute(event) {
				const eventIndex = event.target.dataset.eventIndex;
				const attrIndex = event.target.dataset.attrIndex;
				this.scrollDepthConfig.scrollDepthEvents[eventIndex].customAttributes.splice(attrIndex, 1);
				console.log(`Scroll Depth event custom attribute removed at event index ${eventIndex}, attribute index ${attrIndex}`);
		}

		validateMandatoryFields() {
				const missingFields = [];
				if (!this.configName) missingFields.push('Configuration Name');
				if (!this.gcDomain) missingFields.push('GC Domain');
				if (!this.gcEnvironment) missingFields.push('GC Environment');
				if (!this.gcMessagingDeplId) missingFields.push('GC Messaging Deployment ID');
				if (!this.sfWmUrl) missingFields.push('SF WM URL');
				if (!this.sfOrgId) missingFields.push('SF Org ID');
				if (!this.sfWmName) missingFields.push('SF WM Name');
				if (!this.isEditMode && !this.openActionName) missingFields.push('Open Action Name'); // Add this line

				if (missingFields.length > 0) {
						const errorMessage = `Please fill out the following mandatory fields: ${missingFields.join(', ')}`;
						this.showToast('Error', errorMessage, 'error');
						console.error('Validation failed:', errorMessage);
						return false;
				}
				return true;
		}
		
    deleteConfiguration() {
        if (confirm('Are you sure you want to delete this configuration?')) {
            deleteGPEConfig({ configId: this.selectedExistingConfig })
                .then(() => {
                    this.showToast('Success', 'Configuration deleted successfully', 'success');
                    this.returnToStart();
                })
                .catch(error => {
                    this.showToast('Error', 'Failed to delete configuration: ' + error.message, 'error');
                    console.error('Error deleting configuration:', error);
                });
        }
    }		

		saveConfiguration() {
				console.log('genesysGPEConfig - Entering saveConfiguration method');

				if (!this.validateMandatoryFields()) {
						console.log('genesysGPEConfig - Mandatory field validation failed');
						return;
				}

				this.cleanUpConfigurations();

				this.clickEventsConfig.clickEvents.forEach(event => {
						event.eventName = 'click_' + (event.eventNameSuffix || '');
				});
				this.inViewportConfig.inViewportEvents.forEach(event => {
						event.eventName = 'viewport_' + (event.eventNameSuffix || '');
				});
				this.idleEventsConfig.idleEvents.forEach(event => {
						event.eventName = 'idle_' + (event.eventNameSuffix || '');
				});
				this.scrollDepthConfig.scrollDepthEvents.forEach(event => {
						event.eventName = 'scroll_' + (event.eventNameSuffix || '');
				});

				const config = {
						configName: this.configName,
						gcDomain: this.gcDomain,
						gcEnvironment: this.gcEnvironment,
						gcMessagingDeplId: this.gcMessagingDeplId,
						sfWmUrl: this.sfWmUrl,
						sfOrgId: this.sfOrgId,
						sfWmName: this.sfWmName,
						pageviewConfig: this.pageviewConfig,
						formsTrackConfig: this.formsTrackConfig,
						clickEventsConfig: this.clickEventsConfig,
						idleEventsConfig: this.idleEventsConfig,
						inViewportConfig: this.inViewportConfig,
						scrollDepthConfig: this.scrollDepthConfig
				};

				if (!this.isEditMode && this.openActionName) {
						config.openActionName = this.openActionName;
				}

				console.log('genesysGPEConfig - Config to be saved:', JSON.stringify(config, null, 2));
				console.log('genesysGPEConfig - Is Edit Mode:', this.isEditMode);
				console.log('genesysGPEConfig - Selected Existing Config ID:', this.selectedExistingConfig);

				const startTime = performance.now();

				saveGPEConfig({ config: JSON.stringify(config), configId: this.isEditMode ? this.selectedExistingConfig : null })
						.then(result => {
								const endTime = performance.now();
								console.log(`Save operation completed in ${endTime - startTime} ms`);
								console.log('genesysGPEConfig - Save result:', result);

								this.showToast('Success', 'GPE Configuration saved successfully', 'success');
								this.dispatchEvent(new CustomEvent('configsaved', { detail: result }));

								console.log('genesysGPEConfig - Returning to start');
								this.returnToStart();
						})
						.catch(error => {
								const endTime = performance.now();
								console.error(`Save operation failed after ${endTime - startTime} ms`);
								console.error('Error saving configuration:', error);
								console.error('Error details:', JSON.stringify(error, Object.getOwnPropertyNames(error)));

								this.showToast('Error', 'Failed to save GPE Configuration: ' + error.message, 'error');
						})
						.finally(() => {
								console.log('genesysGPEConfig - Save operation finished');
						});
		}
		
		cleanUpConfigurations() {
				if (this.pageviewConfig.captureAll) {
						this.pageviewConfig.pageTitle = '';
						this.pageviewConfig.pageLocation = '';
				}

				if (this.formsTrackConfig.captureAll) {
						this.formsTrackConfig.selector = '';
						this.formsTrackConfig.formName = '';
				}
		}

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(event);
        console.log(`Toast shown: ${title} - ${message}`);
    }

		handleOpenActionNameChange(event) {
				this.openActionName = event.target.value;
				console.log('Open Action Name changed:', this.openActionName);
		}
}
