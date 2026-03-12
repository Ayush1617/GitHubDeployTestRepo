import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { encodeDefaultFieldValues } from 'lightning/pageReferenceUtils';
import getTasks from '@salesforce/apex/JobPositionTaskController.getTasks';

const ROW_ACTIONS = [
    { label: 'Edit', name: 'edit' }
];

const COLUMNS = [
    { label: 'Subject', fieldName: 'Subject' },
    { label: 'Status', fieldName: 'Status' },
    { label: 'Priority', fieldName: 'Priority' },
    { label: 'Due Date', fieldName: 'ActivityDate', type: 'date' },
    { label: 'Owner', fieldName: 'OwnerName' },
    {
        type: 'action',
        typeAttributes: { rowActions: ROW_ACTIONS }
    }
];

export default class JobPositionTaskList extends NavigationMixin(LightningElement) {

    @api recordId;            // Job_Position__c Id
    columns = COLUMNS;
    tasks = [];
    error;

    // 🔹 Load Tasks related to this Job Position
    @wire(getTasks, { jobPositionId: '$recordId' })
    wiredTasks({ data, error }) {
        if (data) {
            this.tasks = data.map(task => ({
                ...task,
                OwnerName: task.Owner ? task.Owner.Name : ''
            }));
            this.error = undefined;
        } else if (error) {
            this.tasks = [];
            this.error = error;
            console.error('Error loading tasks', error);
        }
    }

    // 🔹 Create NEW Task (Related To = Job Position)
    handleNewTask() {
        const defaultValues = encodeDefaultFieldValues({
            WhatId: this.recordId,        // Related To → Job Position
            Status: 'Not Started',
            Priority: 'Normal'
        });

        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Task',
                actionName: 'new'
            },
            state: {
                defaultFieldValues: defaultValues
            }
        });
    }

    // 🔹 Row action handler
    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'edit') {
            this.editTask(row.Id);
        }
    }

    // 🔹 Edit existing Task
    editTask(taskId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: taskId,
                objectApiName: 'Task',
                actionName: 'edit'
            }
        });
    }
}