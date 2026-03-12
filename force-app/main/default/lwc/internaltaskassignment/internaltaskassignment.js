import { LightningElement, track } from 'lwc';
import getUsers from '@salesforce/apex/InternalTaskAssignmentController.getUsers';
import getTaskPicklistValues from '@salesforce/apex/InternalTaskAssignmentController.getTaskPicklistValues';
import saveTasks from '@salesforce/apex/InternalTaskAssignmentController.saveTasks';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class InternalTaskAssignment extends LightningElement {

    @track rows = [];
    @track userOptions = [];
    @track priorityOptions = [];
    @track statusOptions = [];
    @track subjectOptions = [];

    connectedCallback() {
        getUsers().then(data => {
            this.userOptions = data.map(u => ({ label: u.Name, value: u.Id }));
        });

        getTaskPicklistValues().then(result => {
            this.priorityOptions = result.Priority.map(v => ({ label: v, value: v }));
            this.statusOptions = result.Status.map(v => ({ label: v, value: v }));
            this.subjectOptions = result.Subject.map(v => ({ label: v, value: v }));

            this.rows = [this.createBlankRow()];
        });
    }

    createBlankRow() {
        return {
            id: String(Date.now() + Math.random()),
            subject: '',
            filteredSubjects: [],
            showSubjectList: false,
            priority: '',
            priorityClass: 'task-normal',
            dueDate: '',
            status: 'Not Started',
            assignedTo: ''
        };
    }

    addRow() {
        this.rows = [...this.rows, this.createBlankRow()];
    }

    deleteRow(e) {
        const id = e.currentTarget.dataset.id;
        this.rows = this.rows.filter(r => r.id !== id);
    }


    updateRow(id, field, value) {
        this.rows = this.rows.map(r => r.id === id ? { ...r, [field]: value } : r);
    }

    // SUBJECT AUTOCOMPLETE
    handleSubjectSearch(e) {
        const id = e.target.dataset.id;
        const value = e.target.value;

        const filtered = this.subjectOptions.filter(opt =>
            opt.label.toLowerCase().includes(value.toLowerCase())
        );

        const exactMatch = this.subjectOptions.some(opt => opt.label === value);

        this.rows = this.rows.map(r =>
            r.id === id ? {
                ...r,
                subject: value,
                filteredSubjects: filtered,
                showSubjectList: !exactMatch
            } : r
        );
    }

    showSubjectDropdown(e) {
        const id = e.target.dataset.id;
        this.rows = this.rows.map(r =>
            r.id === id ? { ...r, showSubjectList: true } : r
        );
    }

    hideSubjectDropdown(e) {
        const id = e.target.dataset.id;

        this.rows = this.rows.map(r =>
            r.id === id ? { ...r, showSubjectList: false } : r
        );
    }

    selectSubject(e) {
        const id = e.target.dataset.id;
        const value = e.target.dataset.value;

        this.rows = this.rows.map(r =>
            r.id === id ? { ...r, subject: value, showSubjectList: false } : r
        );
    }

    // OTHER FIELDS
    handlePriorityChange(e) {
        const id = e.target.dataset.id;
        const value = e.detail.value;

        this.rows = this.rows.map(r =>
            r.id === id ? { ...r, priority: value, priorityClass: this.getPriorityClass(value) } : r
        );
    }

    handleStatusChange(e) { this.updateRow(e.target.dataset.id, 'status', e.detail.value); }
    handleDueDateChange(e) { this.updateRow(e.target.dataset.id, 'dueDate', e.target.value); }
    handleAssignChange(e) { this.updateRow(e.target.dataset.id, 'assignedTo', e.detail.value); }

    getPriorityClass(priority) {
        switch (priority) {
            case 'Critical': return 'task-critical';
            case 'High': return 'task-high';
            case 'Medium': return 'task-medium';
            case 'Low': return 'task-low';
            case 'Deferred': return 'task-deferred';
            default: return 'task-normal';
        }
    }

    saveTasks() {
        saveTasks({ rowsJson: JSON.stringify(this.rows) })
            .then(count => {
                this.toast('Success', count + ' Tasks created', 'success');

                this.resetRows(); // ✅ CLEAR DATA
            })
            .catch(err => this.toast('Error', err.body?.message || 'Save failed', 'error'));
    }

    resetRows() {
        this.rows = [this.createBlankRow()];
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}