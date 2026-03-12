import { LightningElement, track, wire } from 'lwc';
import getJobPositions from '@salesforce/apex/ExternalJobTaskAssignmentController.getJobPositions';
import getUsers from '@salesforce/apex/ExternalJobTaskAssignmentController.getUsers';
import getTaskPriorityValues from '@salesforce/apex/ExternalJobTaskAssignmentController.getTaskPriorityValues';
import saveAssignments from '@salesforce/apex/ExternalJobTaskAssignmentController.saveAssignments';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

export default class ExternalJobTaskAssignmentDashboard extends LightningElement {

    //------------pagination variables-----------

page = 1;
pageSize = 5; // rows per page
totalPages = 1;

filteredRows = [];

get isPrevDisabled() {
    return this.page === 1;
}

get isNextDisabled() {
    return this.page === this.totalPages;
}

//------------------pagination function---------------
updatePagination() {

    this.totalPages = Math.ceil(this.filteredRows.length / this.pageSize) || 1;

    const start = (this.page - 1) * this.pageSize;
    const end = start + this.pageSize;

    this.rows = this.filteredRows.slice(start, end);
}


// handle next logic 
handleNext() {
    if (this.page < this.totalPages) {
        this.page++;
        this.updatePagination();
    }
}

handlePrev() {
    if (this.page > 1) {
        this.page--;
        this.updatePagination();
    }
}
    
    // ================= DATA =================
    @track rows = [];
    allRows = []; // master copy for filtering

    @track userOptions = [];
    @track taskPriorityOptions = [];
    @track jobPriorityFilterOptions = [{ label: 'All', value: 'All' }]; // dynamic from task priority values
    wiredJobResult;

    // ================= FILTER STATE =================
    jobTitleFilter = '';
    clientFilter = '';
    selectedJobPriorityFilter = 'All';
    selectedTaskPriorityFilter = 'All';

    // ================= LOAD JOBS =================
    @wire(getJobPositions)
    wiredJobs(result) {
        this.wiredJobResult = result;
        const { data, error } = result;

        if (data) {
            this.rows = data.map(job => ({
                id: job.id,
                jobId: job.id,
                jobTitle: job.jobTitle,
                requirements: job.totalOpenings,
                priority: job.priority,
                priorityClass: this.getPriorityClass(job.priority),
                client: job.client,
                assignedTo: null,
                targetCount: 0,
                expectedtime: 0,
                taskPriority: 'Normal',
                taskPriorityClass: this.getTaskPriorityClass('Normal'),
                openDate: job.openDate,
                jobUrl: `/lightning/r/Job_Position__c/${job.id}/view`
            }));
            this.allRows = [...this.rows];
            this.filteredRows = [...this.rows];
            this.updatePagination();
        } else if (error) {
            console.error('Job Load Error:', error);
        }
    }

    // ================= LOAD USERS =================
    @wire(getUsers)
    wiredUsers({ data, error }) {
        if (data) {
            this.userOptions = data.map(u => ({ label: u.Name, value: u.Id }));
        } else if (error) {
            console.error('User Load Error:', error);
        }
    }

    // ================= LOAD TASK PRIORITIES =================
    @wire(getTaskPriorityValues)
    wiredTaskPriorities({ data, error }) {
        if (data) {
            // For task combobox
            this.taskPriorityOptions = data.map(v => ({ label: v, value: v }));

            // For job priority filter combobox, prepend 'All'
            this.jobPriorityFilterOptions = [{ label: 'All', value: 'All' }].concat(
                data.map(v => ({ label: v, value: v }))
            );
        } else if (error) {
            console.error('Priority Load Error:', error);
        }
    }

    // ================= JOB PRIORITY TEXT COLOR =================
    getPriorityClass(priority) {
        return priority === 'High' ? 'slds-text-color_error' :
            priority === 'Medium' ? 'slds-text-color_warning' :
                'slds-text-color_default';
    }

    // ================= TASK PRIORITY COLOR CLASS =================
    getTaskPriorityClass(priority) {
        switch (priority) {
            case 'Critical': return 'task-critical';
            case 'High': return 'task-high';
            case 'Medium': return 'task-medium';
            case 'Low': return 'task-low';
            case 'Deferred': return 'task-deferred';
            default: return 'task-normal';
        }
    }

    // ================= UPDATE ROW HELPER =================
    updateRow(id, field, value) {
        this.rows = this.rows.map(r => r.id === id ? { ...r, [field]: value } : r);
        this.allRows = this.allRows.map(r => r.id === id ? { ...r, [field]: value } : r);
    }

    // ================= ASSIGN USER =================
    handleAssignChange(event) {
        const id = event.currentTarget.dataset.id;
        this.updateRow(id, 'assignedTo', event.detail.value);
    }

    // ================= TARGET COUNT =================
    handleTargetChange(event) {
        const id = event.currentTarget.dataset.id;
        this.updateRow(id, 'targetCount', Number(event.target.value));
    }

    // ================= Expected Time =================
    handletimeChange(event) {
        const id = event.currentTarget.dataset.id;
        this.updateRow(id, 'expectedtime', Number(event.target.value));
    }
    // ================= TASK PRIORITY CHANGE =================
    handleTaskPriorityChange(event) {
        const id = event.currentTarget.dataset.id;
        const value = event.detail.value;

        this.rows = this.rows.map(r =>
            r.id === id ? { ...r, taskPriority: value, taskPriorityClass: this.getTaskPriorityClass(value) } : r
        );

        this.allRows = this.allRows.map(r =>
            r.id === id ? { ...r, taskPriority: value, taskPriorityClass: this.getTaskPriorityClass(value) } : r
        );
    }

    // ================= ADD ROW =================
    handleAddRow(event) {
        const id = event.currentTarget.dataset.id;
        const index = this.rows.findIndex(r => r.id === id);
        if (index === -1) return;

        const sourceRow = this.rows[index];

        const newRow = {
            ...sourceRow,
            id: Date.now().toString() + Math.random(),
            assignedTo: null,
            targetCount: 0,
            expectedtime: 0,
            taskPriority: 'Normal',
            taskPriorityClass: this.getTaskPriorityClass('Normal')
        };

        this.rows = [...this.rows.slice(0, index + 1), newRow, ...this.rows.slice(index + 1)];
        this.allRows = [...this.rows];
    }

    // ================= DELETE ROW =================
    handleDeleteRow(event) {
        const id = event.currentTarget.dataset.id;
        this.rows = this.rows.filter(r => r.id !== id);
        this.allRows = this.allRows.filter(r => r.id !== id);
    }

    // ================= FILTER HANDLERS =================
    handleJobTitleFilter(event) {
        this.jobTitleFilter = event.target.value.toLowerCase();
        this.applyFilters();
    }

    handleClientFilter(event) {
        this.clientFilter = event.target.value.toLowerCase();
        this.applyFilters();
    }

    handleJobPriorityFilter(event) {
        this.selectedJobPriorityFilter = event.detail.value;
        this.applyFilters();
    }

    handleTaskPriorityFilter(event) {
        this.selectedTaskPriorityFilter = event.detail.value;
        this.applyFilters();
    }

    // ================= APPLY FILTERS =================
   applyFilters() {

    // Step 1: filtered data store 
    this.filteredRows = this.allRows.filter(row => {

        const matchTitle = !this.jobTitleFilter || row.jobTitle?.toLowerCase().includes(this.jobTitleFilter);
        const matchClient = !this.clientFilter || row.client?.toLowerCase().includes(this.clientFilter);
        const matchJobPriority = this.selectedJobPriorityFilter === 'All' || row.priority === this.selectedJobPriorityFilter;
        const matchTaskPriority = this.selectedTaskPriorityFilter === 'All' || row.taskPriority === this.selectedTaskPriorityFilter;

        return matchTitle && matchClient && matchJobPriority && matchTaskPriority;
    });

    // Step 2: page reset
    this.page = 1;

    // Step 3: pagination apply
    this.updatePagination();
}

    // ================= SAVE =================
    saveAssignments() {

        // 🔴 No data entered at all
        const hasAnyAssignment = this.rows.some(row =>
            row.assignedTo && row.targetCount > 0
        );

        if (!hasAnyAssignment) {
            return this.toast('Error', 'Please assign at least one user and candidate count.', 'error');
        }

        // 🔍 Validate each row
        for (const row of this.rows) {
            const hasUser = row.assignedTo;
            const hasTarget = row.targetCount > 0;

            if ((hasUser && !hasTarget) || (!hasUser && hasTarget)) {
                return this.toast('Error', 'Assign To and Candidates must both be filled.', 'error');
            }

            if (hasUser && hasTarget && !row.taskPriority) {
                return this.toast('Error', 'Task Priority required.', 'error');
            }

            //if (row.targetCount > row.requirements) {
            //    return this.toast('Error', 'Candidates exceed requirements.', 'error');
          //  }
        }

        // Call Apex
        saveAssignments({ rowsJson: JSON.stringify(this.rows) })
            .then(() => {
                this.toast('Success', 'Tasks created successfully', 'success');
                this.resetRows();
                return refreshApex(this.wiredJobResult);
            })
            .catch(err => {
                console.error('Save Error:', JSON.stringify(err));
                this.toast('Error', 'Save failed', 'error');
            });
    }


    resetRows() {
        this.rows = this.rows.map(row => {
            return {
                ...row,
                assignedTo: null,
                targetCount: 0,
                taskPriority: 'Normal',
                taskPriorityClass: this.getTaskPriorityClass('Normal')
            };
        });

        // Force re-render
        this.rows = [...this.rows];
        this.allRows = [...this.rows];
    }



    // ================= TOAST =================
    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}