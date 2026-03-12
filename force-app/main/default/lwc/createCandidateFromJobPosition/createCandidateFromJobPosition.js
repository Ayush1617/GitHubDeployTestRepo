import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createInterviewRecord from '@salesforce/apex/CreateCandidateController.createInterviewRecord';

export default class CreateCandidateFromJobPosition extends NavigationMixin(LightningElement) {
    @api jobPositionId;
    @api recordId; // This will capture the Job Position ID from the quick action context
    hasNavigated = false;

    connectedCallback() {
        console.log('Job Position ID:', this.jobPositionId);
        console.log('Record ID:', this.recordId);
        
        // Use recordId if jobPositionId is not provided (from quick action context)
        const positionId = this.jobPositionId || this.recordId;
        
        if (positionId && !this.hasNavigated) {
            this.hasNavigated = true;
            this.navigateToCandidateCreation(positionId);
        } else {
            this.showError('Job Position ID is missing');
        }
    }

    navigateToCandidateCreation(jobPositionId) {
        // Store the jobPositionId in session storage to use after candidate creation
        if (jobPositionId) {
            sessionStorage.setItem('sourceJobPositionId', jobPositionId);
            sessionStorage.setItem('interviewCreationPending', 'true');
        }

        // Navigate to candidate creation page with pre-populated Job Position
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Candidate__c', // Replace with your candidate object API name
                actionName: 'new'
            },
            state: {
                defaultFieldValues: this.encodeDefaultFieldValues(jobPositionId),
                nooverride: '1'
            }
        }).then(() => {
            // Set up listener for when user returns from candidate creation
            this.setupCandidateCreationListener(jobPositionId);
        }).catch(error => {
            console.error('Navigation error:', error);
            this.showError('Error navigating to candidate creation page');
        });
    }

    encodeDefaultFieldValues(jobPositionId) {
        const defaultValues = {};
        
        // Pre-populate the Job Position lookup on Candidate
        if (jobPositionId) {
            defaultValues.Job_Position__c = jobPositionId;
            // If your field has a different API name, use that instead
            // defaultValues.Custom_Job_Position_Field__c = jobPositionId;
        }
        
        // Set supplier record type if needed
        // defaultValues.RecordTypeId = 'YOUR_SUPPLIER_RECORD_TYPE_ID';
        
        // Add any other default field values for candidate if needed
        // Example: defaultValues.Status__c = 'New';
        
        return encodeURIComponent(JSON.stringify(defaultValues));
    }

    setupCandidateCreationListener(jobPositionId) {
        // Listen for when the user returns to the tab/window after candidate creation
        const handleFocus = () => {
            console.log('User returned from candidate creation - checking for new candidate');
            this.checkForNewCandidate(jobPositionId);
        };

        // Add event listener for focus
        window.addEventListener('focus', handleFocus, { once: true });

        // Also set a timeout as backup to check for new candidate
        setTimeout(() => {
            window.removeEventListener('focus', handleFocus);
            this.checkForNewCandidate(jobPositionId);
        }, 10000); // Check after 10 seconds as backup
    }

    checkForNewCandidate(jobPositionId) {
        // Check if interview creation is still pending
        const interviewPending = sessionStorage.getItem('interviewCreationPending');
        
        if (interviewPending === 'true') {
            // Try to find recently created candidate for this job position
            this.findRecentCandidate(jobPositionId)
                .then(candidateId => {
                    if (candidateId) {
                        console.log('Found new candidate with ID:', candidateId);
                        this.createInterview(candidateId, jobPositionId);
                    } else {
                        console.log('No new candidate found yet');
                        // You might want to show a message to user or retry
                    }
                })
                .catch(error => {
                    console.error('Error finding recent candidate:', error);
                });
        }
    }

    findRecentCandidate(jobPositionId) {
        // This is a placeholder for finding the recently created candidate
        // In a real implementation, you might:
        // 1. Use a specific field on Candidate to mark it as created from this action
        // 2. Query for the most recent Candidate with this Job Position
        // 3. Use a platform event or other mechanism
        
        return new Promise((resolve) => {
            // For now, we'll rely on the trigger approach
            // Clear the session storage flag
            sessionStorage.removeItem('interviewCreationPending');
            sessionStorage.removeItem('sourceJobPositionId');
            resolve(null);
        });
    }

    // Method to create interview record
    createInterview(candidateId, jobPositionId) {
        if (!candidateId || !jobPositionId) {
            this.showError('Candidate ID or Job Position ID is missing');
            return;
        }

        createInterviewRecord({
            candidateId: candidateId,
            jobPositionId: jobPositionId
        })
        .then(interviewId => {
            this.showSuccess('Interview record created successfully!');
            console.log('Interview created with ID:', interviewId);
            
            // Clear session storage
            sessionStorage.removeItem('interviewCreationPending');
            sessionStorage.removeItem('sourceJobPositionId');
            
            // Optionally navigate to the interview record
            this.navigateToInterview(interviewId);
        })
        .catch(error => {
            this.showError('Error creating interview: ' + error.body.message);
            console.error('Error creating interview:', error);
            
            // Clear session storage even on error
            sessionStorage.removeItem('interviewCreationPending');
            sessionStorage.removeItem('sourceJobPositionId');
        });
    }

    navigateToInterview(interviewId) {
        if (!interviewId) return;
        
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: interviewId,
                objectApiName: 'Interview__c', // Replace with your interview object API name
                actionName: 'view'
            }
        });
    }

    // Method to be called from flow if needed
    @api
    createInterviewForCandidate(candidateId) {
        const positionId = this.jobPositionId || this.recordId;
        if (candidateId && positionId) {
            this.createInterview(candidateId, positionId);
        } else {
            this.showError('Required information missing for interview creation');
        }
    }

    // Handle flow invocation
    @api
    invoke() {
        // This method is called when the flow screen loads
        this.connectedCallback();
    }

    showSuccess(message) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: message,
            variant: 'success',
            mode: 'dismissable'
        }));
    }

    showError(message) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: message,
            variant: 'error',
            mode: 'sticky'
        }));
    }

}