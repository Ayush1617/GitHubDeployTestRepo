import { LightningElement, api, track, wire } from 'lwc';
import getTaskTypes from '@salesforce/apex/BillableNonBillableTaskTypeController.getTaskTypes';
import getTimeEntries from '@salesforce/apex/BillableNonBillableTaskTypeController.getTimeEntries';
import saveTimeEntries from '@salesforce/apex/BillableNonBillableTaskTypeController.saveTimeEntries';
import updateTimeEntries from '@salesforce/apex/BillableNonBillableTaskTypeController.updateTimeEntries';
import updateTimesheet from '@salesforce/apex/BillableNonBillableTaskTypeController.updateTimesheet';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class billableNonBillableTaskType extends LightningElement {

    @api recordId;
    @api timesheetId;
    //@api weekStartDate;

    @track days = [];
    @track timesheetStatus;

    @track billableRows = [];
    @track nonBillableRows = [];

    @track updateBillableRows = [];
    @track updateNonBillableRows = [];

    @track billabletimeEntries = [];
    @track nonbillabletimeEntries = [];
    @track dailyTotals = [];
    @track billableSectionTotal = 0;
    @track nonBillableSectionTotal = 0;
    @track grandTotal = 0;
    @track billableDailyTotals = [];
    @track nonBillableDailyTotals = [];
    showNoteModal = false;
    currentNote = '';
    selectedRowId;
    selectedDay;
    selectedSection; // billable / nonBillable / updateBillable / updateNonBillable
    /* ================= FETCH TASK TYPES ================= */


     @wire(getTaskTypes, { projectId: '$recordId' })
        wiredTaskTypes({ data, error }) {

            if (data) {

                console.log('tasktype data ----' , data);

                const billable = data.filter(t => t.Billable_Non_Billable__c);
                const nonBillable = data.filter(t => !t.Billable_Non_Billable__c);

                this.billableTaskTypeOptions = billable.map(t => ({
                    label: t.Name,
                    value: t.Id
                }));

                this.nonBillableTaskTypeOptions = nonBillable.map(t => ({
                    label: t.Name,
                    value: t.Id
                }));

            } else if (error) {
                console.error(error);
            }
    }
    /* ================= INIT ================= */

        connectedCallback() {
        this.generateWeekDays();
        this.addBillableRow();
        this.addNonBillableRow();
        this.calculateDailyTotals();
    }
    renderedCallback() {
        console.log('Rendered Timesheet Id:', this.timesheetId);
    }

    generateWeekDays() {

    // Week start date coming from parent
    const monday = new Date(this.weekStartDate);

    const dayNames = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];

    this.days = [];

    for (let i = 0; i < 7; i++) {

        const current = new Date(monday);
        current.setDate(monday.getDate() + i);

        // Build YYYY-MM-DD safely (no timezone issue)
        const yyyy = current.getFullYear();
        const mm = String(current.getMonth() + 1).padStart(2, '0');
        const dd = String(current.getDate()).padStart(2, '0');

        this.days.push({
            key: dayNames[i],
            label: dayNames[i],
            date: dd + '/' + mm,
            fullDate: `${yyyy}-${mm}-${dd}`   // used to match Work_Date__c
        });
    }

    // Reset daily totals
    this.dailyTotals = this.days.map(d => ({
        day: d.key,
        total: 0
    }));
}

    @api
    set weekStartDate(value) {
        this._weekStartDate = value;

        if(value){
            this.generateWeekDays();
        }
    }

    get weekStartDate() {
        return this._weekStartDate;
    }

    createNewRow() {
        return {
            id: (Date.now() + Math.random()).toString(),
            taskTypeId: '',
            hours: this.days.map(d => ({
                day: d.key,
                value: 0,
                note: ''
            }))
        };
    }

    addBillableRow() {
        this.billableRows = [...this.billableRows, this.createNewRow()];
    }

    addNonBillableRow() {
        this.nonBillableRows = [...this.nonBillableRows, this.createNewRow()];
    }

    handleBillableTaskTypeChange(event) {
        this.updateTaskType(event, true);
    }

    handleNonBillableTaskTypeChange(event) {
        this.updateTaskType(event, false);
    }

    handleBillableHourChange(event) {
        this.updateHours(event, true);
        this.calculateDailyTotals();
    }

    handleNonBillableHourChange(event) {
        this.updateHours(event, false);
        this.calculateDailyTotals();
    }

    handleNoteChange(event) {
        this.currentNote = event.target.value;
    }
    // Total row calculation: //

    calculateDailyTotals() {

        const grandTotals = {};
        const billableTotals = {};
        const nonBillableTotals = {};

        let billableTotal = 0;
        let nonBillableTotal = 0;

        // Initialize all days
        this.days.forEach(d => {
            grandTotals[d.key] = 0;
            billableTotals[d.key] = 0;
            nonBillableTotals[d.key] = 0;
        });

        const sumRows = (rows, isBillable) => {

            if (!rows) return;

            rows.forEach(row => {

                if (!row.hours) return;

                row.hours.forEach(cell => {

                    const value = Number(cell.value) || 0;

                    // GRAND TOTAL PER DAY
                    grandTotals[cell.day] += value;

                    if (isBillable) {
                        billableTotals[cell.day] += value;
                        billableTotal += value;
                    } else {
                        nonBillableTotals[cell.day] += value;
                        nonBillableTotal += value;
                    }
                });
            });
        };

        // Billable
        sumRows(this.billableRows, true);
        sumRows(this.updateBillableRows, true);

        // Non Billable
        sumRows(this.nonBillableRows, false);
        sumRows(this.updateNonBillableRows, false);

        // Assign arrays for UI
        this.dailyTotals = this.days.map(d => ({
            day: d.key,
            total: grandTotals[d.key]
        }));

        this.billableDailyTotals = this.days.map(d => ({
            day: d.key,
            total: billableTotals[d.key]
        }));

        this.nonBillableDailyTotals = this.days.map(d => ({
            day: d.key,
            total: nonBillableTotals[d.key]
        }));

        this.billableSectionTotal = billableTotal;
        this.nonBillableSectionTotal = nonBillableTotal;
        this.grandTotal = billableTotal + nonBillableTotal;
    }

    updateTaskType(event, isBillable) {

        const rowId = event.target.dataset.id;
        const value = event.detail.value;

        const rows = isBillable ? this.billableRows : this.nonBillableRows;

        // 🔹 Check duplicate BEFORE update
        const duplicate = rows.some(r =>
            r.id != rowId && r.taskTypeId === value
        );

        if (duplicate) {
            alert('Duplicate Task Type not allowed');
            return;
        }

        const updated = rows.map(row =>
            row.id == rowId ? { ...row, taskTypeId: value } : row
        );

        if (isBillable) {
            this.billableRows = updated;
        } else {
            this.nonBillableRows = updated;
        }
    }


    updateHours(event, isBillable) {

        const rowId = event.target.dataset.id;
        const day = event.target.dataset.day;
        const value = Number(event.target.value);

        const rows = isBillable ? this.billableRows : this.nonBillableRows;

        const updated = rows.map(row => {

            if (row.id == rowId) {

                const hours = row.hours.map(h =>
                    h.day === day ? { ...h, value: value } : h
                );

                return { ...row, hours: hours };
            }

            return row;
        });

        if (isBillable) {
            this.billableRows = updated;
        } else {
            this.nonBillableRows = updated;
        }
        this.calculateDailyTotals();
    }

    handleDraft() {
        this.saveEntries(false);
        this.saveUpdateRecords('Draft');
        console.log('Draft clicked');
        this.savetimesheet('Draft');
    }

    handleSubmit() {
        this.saveEntries(true);
        this.saveUpdateRecords('Submitted');
        console.log('submit clicked');
        this.savetimesheet('Submitted');
    }

    handleDeleteRow(event) {

        const rowId = event.currentTarget.dataset.id;
        const section = event.currentTarget.dataset.section;

        if (section === 'billable' && this.billableRows.length === 1) {
            alert('At least one row is required.');
            return;
        }

        if (section === 'nonBillable' && this.nonBillableRows.length === 1) {
            alert('At least one row is required.');
            return;
        }

        if (section === 'billable') {
            this.billableRows = this.billableRows.filter(
                row => row.id !== rowId
            );
        }

        if (section === 'nonBillable') {
            this.nonBillableRows = this.nonBillableRows.filter(
                row => row.id !== rowId
            );
        }

        this.calculateDailyTotals();
    }

    saveEntries(isSubmit) {

        console.log('Timesheet Id:', this.timesheetId);

        const payload = [];

        const processRows = (rows) => {

            rows.forEach(row => {

                if (!row.taskTypeId) return;

                row.hours.forEach(hour => {

                    const numericValue = Number(hour.value);

                    if (numericValue > 0) {

                        const dayObj = this.days.find(d => d.key === hour.day);

                        if (!dayObj) {
                            console.error('Day not found:', hour.day);
                            return;
                        }

                        payload.push({
                            taskTypeId: row.taskTypeId,
                            workDate: dayObj.fullDate,   // IMPORTANT
                            hours: numericValue,
                            note: hour.note
                        });
                    }
                });
            });
        };

        processRows(this.billableRows);
        processRows(this.nonBillableRows);

        console.log('FINAL Payload:', JSON.stringify(payload));

        if (payload.length === 0) {
            return;
        }

        saveTimeEntries({
            timesheetId: this.timesheetId,
            entriesJson: JSON.stringify(payload),
            action: isSubmit ? 'Submit' : 'Draft'
        })
        .then(() => {
            console.log('SUCCESS');

            this.showToast(
                'Success',
                isSubmit 
                    ? 'Timesheet submitted successfully.' 
                    : 'Timesheet saved as Draft.',
                'success'
            );
        })
        .catch(error => {
            console.error('ERROR:', error);

            this.showToast(
                'Error',
                'Something went wrong while saving time entries.',
                'error'
            );

        });
    }
/***********Update Case*************/

    // EXISTING TIME ENTRY RECORDS (UPDATE MODE)

    @wire(getTimeEntries, { timesheetId: '$timesheetId', weekStartDate: '$weekStartDate' })
    wiredTimeEntries({ data, error }) {

        if (data) {

            this.timesheetStatus = data.timesheetStatus;

            const records = data.entries;

            console.log('Timesheet Status:', this.timesheetStatus);
            
            console.log('time entries :', data);
        // Ensure days are ready
        if (!this.days || this.days.length === 0) {
            this.generateWeekDays();
        }

        this.updateBillableRows =
            this.buildMatrixRowsFromExistingRecords(
                records.filter(t => t.Task_Type__r.Billable_Non_Billable__c === true)
            );

        this.updateNonBillableRows =
            this.buildMatrixRowsFromExistingRecords(
                records.filter(t => t.Task_Type__r.Billable_Non_Billable__c === false)
            );

        this.calculateDailyTotals();
    } else if (error) {
            console.error(error);
        }
    }

    
     buildMatrixRowsFromExistingRecords(records) {

        const taskMap = new Map();

        records.forEach(t => {

            const taskId = t.Task_Type__c;

            if (!taskMap.has(taskId)) {

                taskMap.set(taskId, {

                    id: taskId,
                    taskTypeId: taskId,
                    taskTypeName: t.Task_Type__r.Name,

                    hours: this.days.map(d => ({
                        day: d.key,
                        fullDate: d.fullDate,
                        value: 0,
                        note: '',
                        recordId: null,

                        // MUST EXIST BY DEFAULT
                        isEditable: true,
                        isDisabled: false
                    }))
                });
            }

            const row = taskMap.get(taskId);

            const cell = row.hours.find(
                h => h.fullDate === t.Work_Date__c
            );

            if (cell) {
                cell.value = t.Hours__c;
                cell.note = t.Notes__c;
                cell.recordId = t.Id;

                // existing record = editable
                const isEditableStatus = (this.timesheetStatus === 'Draft');

                cell.isEditable = isEditableStatus;
                cell.isDisabled = !isEditableStatus;
            }

        });

        return Array.from(taskMap.values());
    }


    handleUpdateBillableHourChange(event) {

        const rowId = event.target.dataset.id;
        const day = event.target.dataset.day;
        const value = event.target.value;

        const row = this.updateBillableRows.find(r => r.id == rowId);

        const cell = row.hours.find(h => h.day == day);

        cell.value = value;
        this.calculateDailyTotals(); 
    }

    handleUpdateNonBillableHourChange(event) {

        const rowId = event.target.dataset.id;
        const day = event.target.dataset.day;
        const value = event.target.value;

        const row = this.updateNonBillableRows.find(r => r.id == rowId);

        const cell = row.hours.find(h => h.day == day);

        cell.value = value;
        this.calculateDailyTotals(); 
    }

    //  Save Timesheet Records
    savetimesheet(value) {

        const payload = {
            Id: this.timesheetId,
            Billable_Hours__c: this.billableSectionTotal,
            Non_Billable_Hours__c: this.nonBillableSectionTotal,
            Total_Hours__c: this.grandTotal,
            Status__c: value
        };

        console.log('Timesheet Payload:', JSON.stringify(payload));

        updateTimesheet({ timesheetRecord: payload })
            .then(() => {
                console.log('Timesheet updated successfully');

                this.showToast(
                    'Success',
                    value === 'Submitted'
                        ? 'Timesheet submitted successfully.'
                        : 'Timesheet saved as Draft.',
                    'success'
                );
            })
            .catch(error => {

                console.error('Error updating timesheet:', error);

                let message = 'Failed to update Timesheet';

                if (error.body && error.body.message) {
                    message = error.body.message;
                }

                this.showToast(
                    'Error',
                    message,
                    'error'
                );
            });
    }

//   Save Updated Records
    saveUpdateRecords(statusValue) {

        const payload = [];

        const processRows = (rows, isBillable) => {

            rows.forEach(row => {

                row.hours.forEach(cell => {

                    if(cell.recordId){

                        // UPDATE existing record
                        payload.push({
                            Id: cell.recordId,
                            Hours__c: cell.value,
                            Notes__c: cell.note
                        });

                    }else if(cell.value > 0 || cell.note){

                        // INSERT new record
                        payload.push({
                            Work_Date__c: cell.fullDate,
                            Hours__c: cell.value,
                            Notes__c: cell.note,
                            Billable__c: isBillable,
                            Timesheet__c: this.timesheetId,
                            Task_Type__c: row.taskTypeId,
                            Status__c: statusValue
                        });
                    }
                });
            });
        };

        processRows(this.updateBillableRows, true);
        processRows(this.updateNonBillableRows, false);

        if(!payload.length){
            return;
        }

        updateTimeEntries({ entries: payload })
            .then(() => {
                console.log('Saved successfully');
            })
            .catch(error => console.error(error));
    }

    get isSaveDisabled() {
        return (
            this.hasExceededLimit ||
            this.hasExceededWeeklyLimit ||
            this.isTimesheetSubmitted ||
            this.hastotalzero
        );
    }

    get hasExceededLimit() {
        return this.dailyTotals.some(d => d.total > 12);
    }

    get hasExceededWeeklyLimit() {
        return this.grandTotal > 60;
    }

    get hastotalzero() {
        return this.grandTotal < 1;
    }

    get isTimesheetSubmitted() {
        return this.timesheetStatus === 'Submitted';
    }

saveNote(){

    let rows;

    switch(this.selectedSection){
        case 'billable':
            rows = this.billableRows;
            break;
        case 'nonBillable':
            rows = this.nonBillableRows;
            break;
        case 'updateBillable':
            rows = this.updateBillableRows;
            break;
        case 'updateNonBillable':
            rows = this.updateNonBillableRows;
            break;
    }

    const updated = rows.map(row => {

        if(row.id == this.selectedRowId){

            return {
                ...row,
                hours: row.hours.map(hour => {

                    if(hour.day == this.selectedDay){
                        return { ...hour, note: this.currentNote };
                    }
                    return hour;
                })
            };
        }

        return row;
    });

    if(this.selectedSection === 'billable') this.billableRows = updated;
    if(this.selectedSection === 'nonBillable') this.nonBillableRows = updated;
    if(this.selectedSection === 'updateBillable') this.updateBillableRows = updated;
    if(this.selectedSection === 'updateNonBillable') this.updateNonBillableRows = updated;

    this.showNoteModal = false;
}

closeNoteModal() {
    this.showNoteModal = false;
}

openNoteModal(event) {

    // Get dataset values from button
    this.selectedRowId = event.currentTarget.dataset.id;
    this.selectedDay = event.currentTarget.dataset.day;
    this.selectedSection = event.currentTarget.dataset.section;

    let rows;

    switch(this.selectedSection){
        case 'billable':
            rows = this.billableRows;
            break;

        case 'nonBillable':
            rows = this.nonBillableRows;
            break;

        case 'updateBillable':
            rows = this.updateBillableRows;
            break;

        case 'updateNonBillable':
            rows = this.updateNonBillableRows;
            break;
    }

    // Find existing note
    const row = rows.find(r => r.id == this.selectedRowId);

    if(row){
        const hour = row.hours.find(h => h.day == this.selectedDay);
        this.currentNote = hour?.note || '';
    }

    // Open modal
    this.showNoteModal = true;
}
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }
}