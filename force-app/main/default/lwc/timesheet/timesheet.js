import { LightningElement, api, track } from 'lwc';
//import getCandidateTimesheet
    //from '@salesforce/apex/TimesheetController.getCandidateTimesheet';
//import saveTimesheetTasks
    //from '@salesforce/apex/TimesheetController.saveTimesheetTasks';

export default class Timesheet extends LightningElement {

    @api recordId; // Contact Id (Candidate)

    @track rows = [];
    weekDates = [];

    /* ===============================
       INIT
    =============================== */
    connectedCallback() {
        this.generateCurrentWeek();
        this.loadData();
    }

    /* ===============================
       GENERATE MON–SUN WEEK
    =============================== */
    generateCurrentWeek() {
        this.weekDates = [];

        const today = new Date();
        const day = today.getDay();
        const diff = today.getDate() - day + (day === 0 ? -6 : 1);
        const monday = new Date(today.setDate(diff));

        for (let i = 0; i < 7; i++) {
            const d = new Date(monday);
            d.setDate(monday.getDate() + i);
            this.weekDates.push(d.toISOString().split('T')[0]);
        }
    }

    /* ===============================
       DATE LABELS
    =============================== */
    get weekDateLabels() {
        return this.weekDates.map(d => {
            const dt = new Date(d);
            return {
                key: d,
                day: dt.toLocaleDateString('en-US', { weekday: 'short' }),
                date: `${dt.getDate()} ${dt.toLocaleDateString('en-US', { month: 'short' })}`
            };
        });
    }

    /* ===============================
       LOAD DATA
    =============================== */
    loadData() {
        if (!this.recordId) return;

        getCandidateTimesheet({
            contactId: this.recordId,
            startDate: this.weekDates[0],
            endDate: this.weekDates[this.weekDates.length - 1]
        })
        .then(data => this.prepareRows(data))
        .catch(err => console.error(err));
    }

    /* ===============================
       GROUP DATA
       ONE ROW = WorkOrder + TaskType
    =============================== */
    prepareRows(data) {
        const map = {};

        data.forEach(t => {
            const key = `${t.workOrderId}-${t.taskTypeId}`;

            if (!map[key]) {
                map[key] = {
                    key,
                    workOrderId: t.workOrderId,
                    taskTypeId: t.taskTypeId,
                    workOrderName: t.workOrderName,
                    taskTypeName: t.taskTypeName,
                    dailyHours: [],
                    taskIdByDate: {},
                    total: 0,
                    isDirty: false
                };
            }

            let day = map[key].dailyHours.find(d => d.date === t.workDate);
            if (!day) {
                day = { date: t.workDate, hours: 0 };
                map[key].dailyHours.push(day);
            }

            day.hours += t.hours;
            map[key].taskIdByDate[t.workDate] = t.taskId;
            map[key].total += t.hours;
        });

        // Ensure all 7 days exist
        Object.values(map).forEach(row => {
            this.weekDates.forEach(d => {
                if (!row.dailyHours.find(x => x.date === d)) {
                    row.dailyHours.push({ date: d, hours: 0 });
                }
            });
            row.dailyHours.sort((a,b) => new Date(a.date) - new Date(b.date));
        });

        this.rows = Object.values(map);
    }

    /* ===============================
       EDIT HOURS
    =============================== */
    handleHourChange(event) {
        const rowKey = event.target.dataset.rowkey;
        const date = event.target.dataset.date;
        const value = Number(event.target.value) || 0;

        if (value > 24) {
            event.target.setCustomValidity('Max 24 hours allowed');
            event.target.reportValidity();
            return;
        }
        event.target.setCustomValidity('');

        const row = this.rows.find(r => r.key === rowKey);
        const day = row.dailyHours.find(d => d.date === date);

        day.hours = value;
        row.isDirty = true;

        row.total = row.dailyHours.reduce(
            (sum, d) => sum + (d.hours || 0), 0
        );

        this.rows = [...this.rows];
    }

    /* ===============================
       SAVE
    =============================== */
    handleSave() {
        const records = [];

        this.rows.forEach(row => {
            if (!row.isDirty) return;

            row.dailyHours.forEach(day => {
                records.push({
                    Id: row.taskIdByDate[day.date],
                    Candidate__c: this.recordId,
                    Work_Order__c: row.workOrderId,
                    Task_Type__c: row.taskTypeId,
                    Date__c: day.date,
                    Hours__c: day.hours
                });
            });
        });

        if (!records.length) return;

        saveTimesheetTasks({ tasks: records })
            .then(() => {
                this.rows.forEach(r => r.isDirty = false);
                this.rows = [...this.rows];
            })
            .catch(err => console.error(err));
    }

    /* ===============================
       TOTALS
    =============================== */
    get dayTotalsArray() {
        return this.weekDates.map(d => {
            let total = 0;
            this.rows.forEach(r => {
                const day = r.dailyHours.find(x => x.date === d);
                if (day) total += day.hours;
            });
            return { date: d, total };
        });
    }

    get weekTotal() {
        return this.dayTotalsArray.reduce((s,d) => s + d.total, 0);
    }
   handleSave() {
    const records = [];

    this.rows.forEach(row => {
        if (!row.isDirty) return;

        row.dailyHours.forEach(day => {
            records.push({
                Id: row.taskIdByDate[day.date],
                Candidate__c: this.recordId,
                Work_Order__c: row.workOrderId,
                Task_Type__c: row.taskTypeId,
                Date__c: day.date,
                Hours__c: day.hours
            });
        });
    });

    saveTimesheetTasks({
        tasks: records,
        candidateId: this.recordId,
        weekStart: this.weekDates[0],
        weekEnd: this.weekDates[this.weekDates.length - 1],
        totalHours: this.weekTotal   
    })
    .then(() => {
        this.rows.forEach(r => r.isDirty = false);
        this.rows = [...this.rows];
    });
}


}