import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getProjectsForCandidate from '@salesforce/apex/TimesheetCandidateController.getProjectsForCandidate';
import getCurrentCandidateId from '@salesforce/apex/TimesheetCandidateController.getCurrentCandidateId';
import createTimesheet from '@salesforce/apex/TimesheetCandidateController.createTimesheet';
import getCurrentWeekStartDate from '@salesforce/apex/TimesheetCandidateController.getCurrentWeekStartDate';
import checkExistingTimesheet from '@salesforce/apex/TimesheetCandidateController.checkExistingTimesheet';

export default class TimesheetSelector extends LightningElement {
    @track isLoading = false;
    @track showTimesheetView = false;
    @track projectOptions = [];
    @track selectedProjectId = '';
    @track selectedProjectName = '';
    @track candidateId = '';
    @track currentWeekStart = null;
    @track currentWeekRange = '';
    @track timesheetStatus = 'No timesheet created yet';
    @track timesheetCreated = false;
    @track timesheetId = '';
    @track timesheetData = null;
    
    // Load projects and candidate info on component initialization
    connectedCallback() {
        this.loadCandidateAndProjects();
        this.loadCurrentWeekInfo();
    }
    
    // Load current week information
    loadCurrentWeekInfo() {
        getCurrentWeekStartDate()
            .then(result => {
                console.log('Week start date from Apex:', result);
                this.currentWeekStart = result;
                this.updateWeekRange();
            })
            .catch(error => {
                console.error('Error loading week info:', error);
            });
    }
    
    // Update week range display
    updateWeekRange() {
        if (this.currentWeekStart) {
            // Handle the date properly
            let startDate;
            if (typeof this.currentWeekStart === 'string') {
                const dateParts = this.currentWeekStart.split('-');
                startDate = new Date(dateParts[0], dateParts[1] - 1, dateParts[2]);
            } else {
                startDate = new Date(this.currentWeekStart);
            }
            
            const endDate = new Date(startDate);
            endDate.setDate(startDate.getDate() + 6);
            
            const options = { month: 'short', day: 'numeric', year: 'numeric' };
            this.currentWeekRange = `${startDate.toLocaleDateString('en-US', options)} - ${endDate.toLocaleDateString('en-US', options)}`;
        }
    }
    
    // Load candidate and their projects
    loadCandidateAndProjects() {
        this.isLoading = true;
        
        // First get candidate ID
        getCurrentCandidateId()
            .then(result => {
                console.log('Candidate ID:', result);
                this.candidateId = result;
                // Then load projects
                return getProjectsForCandidate();
            })
            .then(projects => {
                console.log('Projects:', projects);
                if (projects && projects.length > 0) {
                    this.projectOptions = projects.map(project => ({
                        label: project.Name,
                        value: project.Id
                    }));
                } else {
                    this.projectOptions = [];
                    this.showNotification('Info', 'No projects found for this candidate', 'info');
                }
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
                this.handleError(error);
            });
    }
    
    handlePrevioustime() {
        this.navigateWeek(-7);
    }

    handleNexttime() {
        this.navigateWeek(7);
    }
    // Handle project selection change
    handleProjectChange(event) {
        this.selectedProjectId = event.detail.value;
        // Find selected project name
        const selectedOption = this.projectOptions.find(opt => opt.value === this.selectedProjectId);
        this.selectedProjectName = selectedOption ? selectedOption.label : '';
        
        // Reset timesheet status when project changes
        this.resetTimesheetStatus();
    }
    
    // Reset timesheet status
    resetTimesheetStatus() {
        this.timesheetStatus = 'No timesheet created yet';
        this.timesheetCreated = false;
        this.timesheetId = '';
        this.timesheetData = null;
    }
    
    // Check if project is selected
    get isProjectSelected() {
        return this.selectedProjectId !== '';
    }
    
    // Handle Next button click
    handleNext() {
        if (this.selectedProjectId) {
            this.showTimesheetView = true;
            // Check if timesheet already exists for this project and week
            this.checkForExistingTimesheet();
        } else {
            this.showNotification('Error', 'Please select a project', 'error');
        }
    }
    
    // Check for existing timesheet
    checkForExistingTimesheet() {
        if (!this.currentWeekStart || !this.selectedProjectId) {
            return;
        }
        
        this.isLoading = true;
        
        // Format the date properly
        let weekStartDate = this.currentWeekStart;
        if (weekStartDate instanceof Date) {
            const year = weekStartDate.getFullYear();
            const month = String(weekStartDate.getMonth() + 1).padStart(2, '0');
            const day = String(weekStartDate.getDate()).padStart(2, '0');
            weekStartDate = `${year}-${month}-${day}`;
        }
        
        checkExistingTimesheet({
            projectId: this.selectedProjectId,
            weekStartDate: weekStartDate
        })
        .then(result => {
            this.isLoading = false;
            if (result) {
                console.log('Existing timesheet found:', result);
                this.timesheetCreated = true;
                this.timesheetId = result.Id;
                this.timesheetData = result;
                this.timesheetStatus = result.Status__c || 'Draft';
                
                // Show info message
                this.showNotification('Info', 'A timesheet already exists for this week', 'info');
            } else {
                console.log('No existing timesheet found');
                this.resetTimesheetStatus();
            }
        })
        .catch(error => {
            this.isLoading = false;
            console.error('Error checking existing timesheet:', error);
            // Don't show error to user, just reset
            this.resetTimesheetStatus();
        });
    }
    
    // Handle Create Timesheet button click
    handleCreateTimesheet() {
        if (!this.currentWeekStart) {
            this.showNotification('Error', 'Unable to determine current week', 'error');
            return;
        }
        
        this.isLoading = true;
        
        // Format the date properly if it's a Date object
        let weekStartDate = this.currentWeekStart;
        if (weekStartDate instanceof Date) {
            const year = weekStartDate.getFullYear();
            const month = String(weekStartDate.getMonth() + 1).padStart(2, '0');
            const day = String(weekStartDate.getDate()).padStart(2, '0');
            weekStartDate = `${year}-${month}-${day}`;
        }
        
        console.log('Creating timesheet with:', {
            projectId: this.selectedProjectId,
            weekStartDate: weekStartDate
        });
        
        createTimesheet({
            projectId: this.selectedProjectId,
            weekStartDate: weekStartDate
        })
        .then(result => {
            console.log('Timesheet created:', result);
            this.isLoading = false;
            this.timesheetCreated = true;
            this.timesheetId = result.Id;
            this.timesheetData = result;
            this.timesheetStatus = result.Status__c || 'Draft';
            
            this.showNotification('Success', 'Timesheet created successfully', 'success');
        })
        .catch(error => {
            console.error('Error creating timesheet:', error);
            this.isLoading = false;
            this.handleError(error);
            // After error, check again if timesheet exists (in case it was a duplicate error)
            this.checkForExistingTimesheet();
        });
    }
    
    // Handle error messages properly
    handleError(error) {
        console.log('Full error object:', JSON.stringify(error));
        
        let errorMessage = 'An unexpected error occurred';
        
        // Extract error message from different possible formats
        if (error) {
            // Check for Apex error format
            if (error.body && error.body.message) {
                errorMessage = error.body.message;
            } 
            // Check for page errors
            else if (error.body && error.body.pageErrors && error.body.pageErrors.length > 0) {
                errorMessage = error.body.pageErrors[0].message;
            }
            // Check for field errors
            else if (error.body && error.body.fieldErrors) {
                const fieldErrors = error.body.fieldErrors;
                const fields = Object.keys(fieldErrors);
                if (fields.length > 0 && fieldErrors[fields[0]].length > 0) {
                    errorMessage = fieldErrors[fields[0]][0].message;
                }
            }
            // Check for message in error object
            else if (error.message) {
                errorMessage = error.message;
            }
            // Check for statusText
            else if (error.statusText) {
                errorMessage = error.statusText;
            }
        }
        
        // Remove any prefixes
        errorMessage = errorMessage
            .replace('Script-thrown exception:', '')
            .replace('Script-thrown exception', '')
            .replace('AuraHandledException:', '')
            .trim();
        
        console.log('Final error message:', errorMessage);
        
        // Check if this is the duplicate timesheet error
        if (errorMessage.toLowerCase().includes('timesheet already exists')) {
            this.showNotification('Timesheet Exists', errorMessage, 'warning');
        } else {
            this.showNotification('Error', errorMessage, 'error');
        }
    }
    
    // Handle back to project selection
    handleBackToProjects() {
        this.showTimesheetView = false;
        this.selectedProjectId = '';
        this.selectedProjectName = '';
        this.resetTimesheetStatus();
    }
    
    // Get status class for styling
    get statusClass() {
        return this.timesheetCreated ? 'slds-text-color_success' : 'slds-text-color_weak';
    }
    
    // Show notification
    showNotification(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'dismissable'
        });
        this.dispatchEvent(event);
    }

    navigateWeek(dayOffset) {

        if (!this.currentWeekStart || !this.selectedProjectId) {
            return;
        }

        this.isLoading = true;

        let baseDate;

        if (typeof this.currentWeekStart === 'string') {
            const parts = this.currentWeekStart.split('-');
            baseDate = new Date(parts[0], parts[1] - 1, parts[2]);
        } else {
            baseDate = new Date(this.currentWeekStart);
        }

        const targetDate = new Date(baseDate);
        targetDate.setDate(baseDate.getDate() + dayOffset);

        const formattedDate = this.formatDateForApex(targetDate);

        checkExistingTimesheet({
            projectId: this.selectedProjectId,
            weekStartDate: formattedDate
        })
        .then(result => {

            this.isLoading = false;

            // ALWAYS move week
            this.currentWeekStart = targetDate;
            this.updateWeekRange();

            if (result) {

                // Timesheet exists
                this.timesheetCreated = true;
                this.timesheetId = result.Id;
                this.timesheetData = result;
                this.timesheetStatus = result.Status__c || 'Draft';

            } else {

                // No timesheet → allow creation
                this.timesheetCreated = false;
                this.timesheetId = '';
                this.timesheetData = null;
                this.timesheetStatus = 'No timesheet created yet';

            }
        })
        .catch(error => {
            this.isLoading = false;
            this.handleError(error);
        });
    }

    formatDateForApex(dateObj) {
        const year = dateObj.getFullYear();
        const month = String(dateObj.getMonth() + 1).padStart(2, '0');
        const day = String(dateObj.getDate()).padStart(2, '0');
        return `${year}-${month}-${day}`;
    }
}