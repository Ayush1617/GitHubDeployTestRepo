import { LightningElement, track } from 'lwc';
import handleAuthCallback from '@salesforce/apex/LinkedInAuthCallback.handleAuthCallback';
import { NavigationMixin } from 'lightning/navigation';

export default class LinkedInAuthCallback extends NavigationMixin(LightningElement) {
    
    connectedCallback() {
        this.processCallback();
    }
    
    async processCallback() {
        try {
            const result = await handleAuthCallback();
            
            // Close this tab/window
            if (window.opener) {
                // If this is a popup, close it
                window.close();
            } else {
                // If it's a full page, navigate back
                this[NavigationMixin.Navigate]({
                    type: 'standard__webPage',
                    attributes: {
                        url: '/lightning/n/Job_Posting'
                    }
                });
            }
        } catch (error) {
            console.error('Error in callback:', error);
            this.showError(error);
        }
    }
    
    showError(error) {
        const evt = new ShowToastEvent({
            title: 'Error',
            message: error.body?.message || 'Failed to complete LinkedIn login',
            variant: 'error'
        });
        this.dispatchEvent(evt);
        
        // Still close after error
        setTimeout(() => {
            if (window.opener) {
                window.close();
            }
        }, 3000);
    }
}