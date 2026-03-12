import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord } from 'lightning/uiRecordApi';
import getTaskTypes from '@salesforce/apex/ProjectTaskTypeController.getTaskTypes';
import updateTaskType from '@salesforce/apex/ProjectTaskTypeController.updateTaskType';
import { refreshApex } from '@salesforce/apex';

// 🔹 Project field to watch via LDS
const PROJECT_FIELDS = ['Project__c.Billable_Rate__c'];

export default class ProjectTaskTypes extends NavigationMixin(LightningElement) {
    @api recordId;

    @track taskTypes;
    wiredResult;
    projectBillingRateType;

    /* ===============================
       WATCH PROJECT PICKLIST (LDS)
       =============================== */
    @wire(getRecord, { recordId: '$recordId', fields: PROJECT_FIELDS })
    projectRecord({ data }) {
        if (data) {
            const newValue = data.fields.Billable_Rate__c.value;

            // Update only if value actually changed
            if (this.projectBillingRateType !== newValue) {
                this.projectBillingRateType = newValue;

                // Refresh task list when Project config changes
                if (this.wiredResult) {
                    refreshApex(this.wiredResult);
                }

                // Recalculate UI state
                if (this.taskTypes) {
                    this.taskTypes = this.taskTypes.map(t => ({
                        ...t,
                        rateDisabled: !this.isRateEditable(t)
                    }));
                }
            }
        }
    }

    /* ===============================
       FETCH TASK TYPES
       =============================== */
    @wire(getTaskTypes, { projectId: '$recordId' })
    wiredTasks(result) {
        this.wiredResult = result;

        if (result.data) {
            this.taskTypes = result.data.map(t => ({
                ...t,
                rateDisabled: !this.isRateEditable(t)
            }));
        }
    }

    /* ===============================
       CORE BUSINESS LOGIC
       =============================== */
    isRateEditable(task) {
        return (
            this.projectBillingRateType === 'Task Billable Rate' &&
            task.Billable_Non_Billable__c === true
        );
    }

    /* ===============================
       EVENT HANDLERS
       =============================== */
    handleBillableChange(event) {
        const taskId = event.target.dataset.id;
        const value = event.target.checked;

        this.updateTask(taskId, {
            Billable_Non_Billable__c: value,
            Billing_rate_per_hour__c: value ? null : 0
        });
    }

    handleRateChange(event) {
        const taskId = event.target.dataset.id;
        const value = event.target.value;

        this.updateTask(taskId, {
            Billing_rate_per_hour__c: value
        });
    }

    /* ===============================
       UPDATE TASK (INSTANT SAVE)
       =============================== */
    updateTask(taskId, changes) {
        const task = this.taskTypes.find(t => t.Id === taskId);
        Object.assign(task, changes);

        // Recalculate disabled state
        task.rateDisabled = !this.isRateEditable(task);

        updateTaskType({ taskType: task })
            .then(() => refreshApex(this.wiredResult));
    }

    /* ===============================
       NAVIGATION
       =============================== */
    handleAddTaskType() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Task_Type__c',
                actionName: 'new'
            },
            state: {
                defaultFieldValues: `Task_Type_Project__c=${this.recordId}`
            }
        });
    }

    handleNavigateToTaskType(event) {
        const recordId = event.currentTarget.dataset.id;

        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'Task_Type__c',
                actionName: 'view'
            }
        });
    }
}