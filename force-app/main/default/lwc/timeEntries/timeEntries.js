import { LightningElement, api, track, wire } from 'lwc';
import getTaskTypes from '@salesforce/apex/ProjectTaskTypeController.getTaskTypes';

export default class ProjectTimeEntryGrid extends LightningElement {

    @api recordId;
    @track rows = [];
    @track taskTypeOptions = [];
    @track days = [];

    /* ===============================
       FETCH TASK TYPES
       =============================== */
    @wire(getTaskTypes, { projectId: '$recordId' })
    wiredTaskTypes({ data, error }) {
        if (data) {
            this.taskTypeOptions = data.map(record => ({
                label: record.Name,
                value: record.Id
            }));
        } else if (error) {
            console.error(error);
        }
    }

    /* ===============================
       INIT COMPONENT
       =============================== */
    connectedCallback() {
        this.generateWeekDays();
        this.addInitialRow(); // 👈 first row by default
    }

    generateWeekDays() {

        const today = new Date();
        const dayNumber = today.getDay();
        const sunday = new Date(today);
        sunday.setDate(today.getDate() - dayNumber);

        const dayNames = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];

        this.days = [];

        for (let i = 0; i < 7; i++) {

            const current = new Date(sunday);
            current.setDate(sunday.getDate() + i);

            this.days.push({
                key: dayNames[i],
                label: dayNames[i],
                date: current.getDate() + '/' + (current.getMonth() + 1)
            });
        }
    }

    /* ===============================
       FIRST ROW DEFAULT
       =============================== */
    addInitialRow() {
        this.rows = [this.createNewRow()];
    }

    /* ===============================
       CREATE ROW TEMPLATE
       =============================== */
    createNewRow() {
        return {
            id: Date.now() + Math.random(),
            taskTypeId: '',
            hours: this.days.map(d => ({
                day: d.key,
                value: 0
            }))
        };
    }

    /* ===============================
       ADD ROW (+ icon click)
       =============================== */
    handleAddRow() {
        this.rows = [...this.rows, this.createNewRow()];
    }

    /* ===============================
       TASK TYPE CHANGE
       =============================== */
    handleTaskTypeChange(event) {

        const rowId = event.target.dataset.id;
        const value = event.detail.value;

        this.rows = this.rows.map(row =>
            row.id == rowId
                ? { ...row, taskTypeId: value }
                : row
        );
    }

    /* ===============================
       HOURS CHANGE
       =============================== */
    handleHourChange(event) {

        const rowId = event.target.dataset.id;
        const day = event.target.dataset.day;
        const value = Number(event.target.value);

        this.rows = this.rows.map(row => {

            if (row.id == rowId) {

                const updatedHours = row.hours.map(hour =>
                    hour.day === day
                        ? { ...hour, value: value }
                        : hour
                );

                return { ...row, hours: updatedHours };
            }

            return row;
        });
    }
}