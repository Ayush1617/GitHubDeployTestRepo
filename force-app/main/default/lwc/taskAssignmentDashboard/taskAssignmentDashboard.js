import { LightningElement, track } from 'lwc';
import getTasks from '@salesforce/apex/TaskAssignmentController.getTasks';
import getRecruiters from '@salesforce/apex/TaskAssignmentController.getRecruiters';
import getTaskPicklistValues from '@salesforce/apex/InternalTaskAssignmentController.getTaskPicklistValues';
import getTaskRecordTypes from '@salesforce/apex/TaskAssignmentController.getTaskRecordTypes';

export default class TaskAssignmentDashboard extends LightningElement {

    @track tasks = [];
    @track recruiterOptions = [];
    @track selectedPriority = 'All';
    @track selectedRecruiter = null;
    @track priorityOptions = [];
    @track isLoading = false;
    @track startDate = null;
    @track endDate = null;
    @track selectedRecordType = 'All';
    @track recordTypeOptions = [];


    pageSize = 5;
    pageNumber = 1;
    totalRecords = 0;

    connectedCallback() {
        this.loadRecruiters();
        this.loadPicklists();
        this.loadTasks();
        this.loadRecordTypes();

        console.log('START DATE TYPE:', typeof this.startDate);
    }

    handleRefresh() {
        console.log('🔄 Refresh clicked');

        this.isLoading = true;
        this.pageNumber = 1;

        this.loadTasks(true);
    }

     loadPicklists() {
        getTaskPicklistValues()
            .then(result => {
                this.priorityOptions = [
            { label: 'All', value: 'All' },
            ...result.Priority.map(v => ({ label: v, value: v }))
        ];
            
            })
            .catch(error => {
                console.error('Error fetching picklists', error);
                this.showToast('Error', 'Failed to fetch Task picklist values', 'error');
            });
    }

    loadRecruiters() {
        getRecruiters()
            .then(result => {
                this.recruiterOptions = [
                    { label: 'All Recruiters', value: null },
                    ...result.map(r => ({ label: r.Name, value: r.Id }))
                ];
            })
            .catch(err => console.error('Recruiter error', err));
    }

    loadTasks(forceRefresh = false) {
        this.isLoading = true;

        const requestPayload = {
            priorityFilter: this.selectedPriority,
            recruiterId: this.selectedRecruiter,
            pageSize: this.pageSize,
            pageNumber: this.pageNumber,
            refreshTime: forceRefresh ? Date.now() : null,
            startDate: this.startDate,
            endDate: this.endDate,
            recordTypeName: this.selectedRecordType
        };

        console.log('SENDING JSON:', JSON.stringify(requestPayload));

        getTasks({
            requestJson: JSON.stringify(requestPayload)
        })
        .then(result => {
            console.log('result !@@@@: ',JSON.stringify(result));
            this.totalRecords = result.totalRecords;


            this.tasks = result.tasks.map(task => ({
                ...task,
                OwnerName: task.Owner ? task.Owner.Name : '',
                priorityClass: this.getPriorityClass(task.Priority),
                taskUrl: `/lightning/r/Task/${task.Id}/view`,
                createdDateFormatted: new Date(task.CreatedDate).toLocaleDateString(),
                dueDateFormatted: task.ActivityDate
                    ? new Date(task.ActivityDate).toLocaleDateString()
                    : '',
                    
        expectedTimeDisplay: task.Expected_Completion_time__c ?? 'Not Applicable',

        actualHoursDisplay: task.Actual_Working_Hours__c ?? 'Not Applicable',
        candidatesToSubmit: task.Candidates_to_submit__c ?? '0',

        actualCandidateSubmitted: task.Actual_Candidate_submitted__c ?? '0'
                    
                    
            }));
            console.log('Expected:', task.Expected_Completion_time__c, typeof task.Expected_Completion_time__c);
            
        })
        
        .catch(error => {
            console.error('Task load error', error);
        })
        .finally(() => {
            this.isLoading = false;
        });
    }
    loadRecordTypes() {
    getTaskRecordTypes()
        .then(result => {
            this.recordTypeOptions = [
                { label: 'All', value: 'All' },
                ...result.map(rt => ({
                    label: rt.Name,
                    value: rt.DeveloperName
                }))
            ];
        })
        .catch(error => {
            console.error('Record Type error', error);
        });
}

    getPriorityClass(priority) {
        switch (priority) {
            case 'Critical': return 'priority critical';
            case 'High': return 'priority high';
            case 'Medium': return 'priority medium';
            case 'Low': return 'priority low';
            case 'Deferred': return 'priority deferred';
            default: return 'priority';
        }
    }

    handlePriorityChange(event) {
        this.selectedPriority = event.detail.value;
        this.pageNumber = 1;
        this.loadTasks(true);
    }

    handleRecruiterChange(event) {
        this.selectedRecruiter = event.detail.value;
        this.pageNumber = 1;
        this.loadTasks(true);
    }

    handleNext() {
        this.pageNumber++;
        this.loadTasks();
    }

    handlePrevious() {
        this.pageNumber--;
        this.loadTasks();
    }


    //Handle Manual Date Change
    handleStartDateChange(event) {
        this.startDate = event.target.value;
    }

    handleEndDateChange(event) {
        this.endDate = event.target.value;
    }

    applyDateFilter() {
        this.pageNumber = 1;
        this.loadTasks(true);
    }

    handleResetDate() {

        // Reset filters
        this.selectedPriority = 'All';
        this.selectedRecruiter = null;
        this.startDate = null;
        this.endDate = null;
        this.selectedRecordType = 'All';

        // Reset pagination
        this.pageNumber = 1;

        // Reload data
        this.loadTasks(true);
}

    // Quick Buttons Logic
    handleQuickDate(event) {
        const type = event.target.dataset.type;
        const today = new Date();

        if (type === 'today') {
            this.startDate = this.formatDate(today);
            this.endDate = this.formatDate(today);
        }

        if (type === 'yesterday') {
            const yesterday = new Date();
            yesterday.setDate(today.getDate() - 1);
            this.startDate = this.formatDate(yesterday);
            this.endDate = this.formatDate(yesterday);
        }

        if (type === 'last7') {
            const last7 = new Date();
            last7.setDate(today.getDate() - 6);
            this.startDate = this.formatDate(last7);
            this.endDate = this.formatDate(today);
        }

        this.pageNumber = 1;
        this.loadTasks(true);
    }

    formatDate(date) {
        return date.toISOString().split('T')[0];
    }

    get disablePrevious() {
        return this.pageNumber === 1;
    }

    get disableNext() {
        return this.pageNumber * this.pageSize >= this.totalRecords;
    }

    get startRecord() {
        return (this.pageNumber - 1) * this.pageSize + 1;
    }

    get endRecord() {
        return Math.min(this.pageNumber * this.pageSize, this.totalRecords);
    }

    get isNoData() {
        return !this.isLoading && (!this.tasks || this.tasks.length === 0);
    }
    handleRecordTypeChange(event) {
    this.selectedRecordType = event.detail.value;
    this.pageNumber = 1;
    this.loadTasks(true);
    }
}