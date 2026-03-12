import { LightningElement, api, wire } from 'lwc';
import getTimeEntries from '@salesforce/apex/TimeEntryNotesController.getTimeEntries';
import saveNotes from '@salesforce/apex/TimeEntryNotesController.saveNotes';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

export default class TimeEntryNotes extends LightningElement {

    @api recordId;

    timeEntries;
    wiredResult;

    isModalOpen = false;  
    selectedRecordId;
    notes = '';

    @wire(getTimeEntries, { timesheetId: '$recordId' })
    wiredEntries(result) {
        console.log('result---'+JSON.stringify(result));
        this.wiredResult = result;
        if (result.data) {
             console.log('result data---'+JSON.stringify(result.data));
            this.timeEntries = result.data;
        }
    }

    openModal(event) {
        console.log('Icon Clicked');
        this.selectedRecordId = event.currentTarget.dataset.id;
        this.notes = event.currentTarget.dataset.notes || '';
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
    }

    handleChange(event) {
        this.notes = event.target.value;
    }

    handleSave() {
        saveNotes({
            recordId: this.selectedRecordId,
            notes: this.notes
        })
        .then(() => {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Notes saved successfully',
                    variant: 'success'
                })
            );
            this.isModalOpen = false;
            return refreshApex(this.wiredResult);
        });
    }
}