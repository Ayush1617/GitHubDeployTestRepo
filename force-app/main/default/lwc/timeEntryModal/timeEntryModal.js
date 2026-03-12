import { LightningElement, track } from 'lwc';
export default class TimeEntryModal extends LightningElement {
    @track project = '';
    @track taskType = 'Design';
    @track notes = '';
    @track timeValue = '0:00';

    handleProjectChange(e) {
        this.project = e.target.value;
    }

    handleTaskChange(e) {
        this.taskType = e.target.value;
    }

    handleNotesChange(e) {
        this.notes = e.target.value;
    }

    handleTimeChange(e) {
        this.timeValue = e.target.value;
    }

    close() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    saveEntry() {
        this.dispatchEvent(new CustomEvent('save', {
            detail: {
                project: this.project,
                taskType: this.taskType,
                notes: this.notes,
                time: this.timeValue
            }
        }));
    }
}