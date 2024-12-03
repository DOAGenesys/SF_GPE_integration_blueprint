import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getSessionEvents from '@salesforce/apex/GenesysGPEController.getSessionEvents';

export default class GenesysCustomerJourney extends NavigationMixin(LightningElement) {
    @api recordId;
    @track events = [];
    @track error;
    @track chartData = [];
    @track pageViewData = [];
    @track showTimelineDetails = false;

    @wire(getSessionEvents, { messagingSessionId: '$recordId' })
    wiredEvents({ error, data }) {
        if (data) {
            this.events = data.map(event => ({
                ...event,
                iconName: this.getIconName(event.Event_Type__c),
                formattedDate: this.formatDate(event.Created_Date__c),
                shortEventType: this.getShortEventType(event.Event_Type__c)
            }));
            this.error = undefined;
            this.processChartData();
            this.processPageViewData();
        } else if (error) {
            this.error = error;
            this.events = [];
        }
    }

    getIconName(eventType) {
        switch (eventType) {
            case 'com.genesys.journey.WebEvent':
                return 'standard:visit';
            case 'com.genesys.journey.WebActionEvent':
                return 'standard:action';
            case 'com.genesys.journey.SegmentAssignmentEvent':
                return 'standard:segment';
            default:
                return 'standard:event';
        }
    }

    handleTimelineToggle(event) {
        this.showTimelineDetails = event.target.checked;
    }

    handleEventClick(event) {
        event.preventDefault();
        const recordId = event.currentTarget.dataset.recordId;
        
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'Genesys_Session_Event__c',
                actionName: 'view'
            }
        });
    }

    formatDate(dateString) {
        const options = { 
            year: 'numeric', 
            month: 'short', 
            day: 'numeric', 
            hour: '2-digit', 
            minute: '2-digit', 
            second: '2-digit',
            hour12: false 
        };
        return new Date(dateString).toLocaleString('en-US', options);
    }

    getShortEventType(eventType) {
        return eventType.replace('com.genesys.journey.', '');
    }

    processChartData() {
        const counts = {};
        this.events.forEach(event => {
            counts[event.Event_Name__c] = (counts[event.Event_Name__c] || 0) + 1;
        });
        const total = this.events.length;
        let startAngle = 0;

        this.chartData = Object.entries(counts).map(([type, count], index) => {
            const percentage = (count / total) * 100;
            const endAngle = startAngle + (percentage / 100) * Math.PI * 2;
            const largeArcFlag = percentage > 50 ? 1 : 0;
            const color = this.getColor(index);

            const data = {
                type,
                count,
                percentage: percentage.toFixed(1),
                color,
                path: this.describeArc(100, 100, 80, startAngle, endAngle, largeArcFlag),
                style: `background-color: ${color};`
            };

            startAngle = endAngle;
            return data;
        });
    }

    processPageViewData() {
        const pageCounts = {};
        this.events.forEach(event => {
            if (event.Event_Name__c === 'page_viewed') {
                const page = event.Page_Title__c || 'Unknown Page';
                pageCounts[page] = (pageCounts[page] || 0) + 1;
            }
        });

        const sortedPages = Object.entries(pageCounts)
            .sort((a, b) => b[1] - a[1])
            .slice(0, 5);

        const maxCount = Math.max(...sortedPages.map(([, count]) => count));

        this.pageViewData = sortedPages.map(([page, count], index) => ({
            page,
            count,
            percentage: (count / maxCount) * 100,
            color: this.getColor(index)
        }));
    }

    getColor(index) {
        const colors = ['#1589EE', '#FF9A3C', '#4BCE97', '#F2B2A8', '#7F8DE1'];
        return colors[index % colors.length];
    }

    describeArc(x, y, radius, startAngle, endAngle, largeArcFlag) {
        const start = this.polarToCartesian(x, y, radius, endAngle);
        const end = this.polarToCartesian(x, y, radius, startAngle);
        return [
            "M", start.x, start.y,
            "A", radius, radius, 0, largeArcFlag, 0, end.x, end.y,
            "L", x, y,
            "Z"
        ].join(" ");
    }

    polarToCartesian(centerX, centerY, radius, angleInRadians) {
        return {
            x: centerX + (radius * Math.cos(angleInRadians)),
            y: centerY + (radius * Math.sin(angleInRadians))
        };
    }

    get formattedEvents() {
        return this.events
            .map(event => {
                const details = this.getEventDetails(event);
                return details ? { ...event, details } : null;
            })
            .filter(Boolean);
    }

    getEventDetails(event) {
        if (!event || typeof event !== 'object') {
            return null;
        }

        const details = [];
        const eventName = (event.Event_Name__c || '').toLowerCase();
        const eventType = event.Event_Type__c || '';

        // Add event name with recordId for the click handler
        details.push({ 
            label: 'Event Name', 
            value: event.Event_Name__c, 
            recordId: event.Id,
            icon: 'utility:link' 
        });

        // Conditional display of event details based on Event_Name__c and Event_Type__c
        if (eventName.includes('idle')) {
            details.push({ label: 'Idle Duration', value: `${event.Idle_Duration_Seconds__c || 0} seconds`, icon: 'utility:clock' });
        } else if (eventName.includes('click')) {
            details.push({ label: 'Clicked Element', value: event.Clicked_Element_Selector__c || 'N/A', icon: 'utility:touch_action' });
        } else if (eventName.includes('viewport')) {
            details.push({ label: 'Viewport Element', value: event.Viewport_Element_Selector__c || 'N/A', icon: 'utility:preview' });
        } else if (eventName.includes('form')) {
            details.push({ label: 'Form Name', value: event.Form_Name__c || 'N/A', icon: 'utility:form' });
            details.push({ label: 'Form Data', value: event.Form_Data__c || 'N/A', icon: 'utility:database' });
        } else if (eventName.includes('page')) {
            details.push({ label: 'Page Title', value: event.Page_Title__c || 'N/A', icon: 'utility:page' });
            details.push({ label: 'Page URL', value: event.Page_URL__c || 'N/A', url: event.Page_URL__c, icon: 'utility:link' });
        } else if (eventName.includes('scroll')) {
            details.push({ label: 'Scroll Depth', value: `${event.Scroll_Depth_Percentage__c || 0}%`, icon: 'utility:vertical_alignment_bottom' });
        } else if (eventType === 'com.genesys.journey.SegmentAssignmentEvent') {
            details.push({ label: 'Event Type', value: 'Segment assignment', icon: 'utility:strategy' });
        } else {
            // If no condition is met, don't display this event
            return null;
        }

        // Add common details
        if (event.Browser_Family__c) {
            details.push({ label: 'Browser', value: `${event.Browser_Family__c} ${event.Browser_Version__c || ''}`, icon: 'utility:desktop' });
        }
        if (event.Device_Category__c) {
            details.push({ label: 'Device', value: `${event.Device_Category__c} (${event.OS_Family__c || ''} ${event.OS_Version__c || ''})`, icon: 'utility:tablet_portrait' });
        }
        if (event.Geolocation_Country_Name__c) {
            details.push({ label: 'Location', value: `${event.Geolocation_Country_Name__c || ''}, ${event.Geolocation_Region_Name__c || ''}, ${event.Geolocation_Locality__c || ''}`, icon: 'utility:location' });
        }

        return details;
    }

    get totalEvents() {
        return this.events.length;
    }

    get uniquePages() {
        const uniquePages = new Set(this.events.filter(event => event.Event_Name__c === 'page_viewed').map(event => event.Page_Title__c));
        return uniquePages.size;
    }

    get sessionDuration() {
        if (this.events.length < 2) return 'N/A';
        const start = new Date(this.events[0].Created_Date__c);
        const end = new Date(this.events[this.events.length - 1].Created_Date__c);
        const durationMs = end - start;
        const minutes = Math.floor(durationMs / 60000);
        const seconds = Math.floor((durationMs % 60000) / 1000);
        return `${minutes}m ${seconds}s`;
    }
}
