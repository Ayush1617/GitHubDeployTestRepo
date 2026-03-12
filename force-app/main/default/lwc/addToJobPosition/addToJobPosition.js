import { LightningElement, track, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getJobPositions from '@salesforce/apex/AddToJobPositionController.getJobPositions';
import addCandidateToJobs from '@salesforce/apex/AddToJobPositionController.addCandidateToJobs';

export default class AddToJobPosition extends LightningElement {

    @api recordId;
    @track jobPositions = [];
    @track filteredJobPositions = [];
    @track selectedRows = [];
    searchKey = '';

    columns = [
        { label: 'Job Name', fieldName: 'Name', type: 'text' },
        { label: 'Job Title', fieldName: 'Job_Title__c', type: 'text' },
        { label: 'Client Name', fieldName: 'ClientName', type: 'text' },
        {
            label: 'Created Date',
            fieldName: 'CreatedDate',
            type: 'date',
            typeAttributes: { day: '2-digit', month: 'short', year: 'numeric' }
        }
    ];

    // 🔥 Reactive Apex call (no async timers)
    @wire(getJobPositions, { candidateId: '$recordId', searchKey: '$searchKey' })
    wiredJobs({ data, error }) {
        if (data) {
            this.jobPositions = data.map(job => ({
                Id: job.Id,
                Name: job.Name,
                Job_Title__c: job.Job_Title__c,
                CreatedDate: job.CreatedDate,
                ClientName: job.Client_Name__r?.Name || ''
            }));
            this.filteredJobPositions = this.jobPositions;
        } else if (error) {
            this.showToast('Error', 'Failed to load job positions', 'error');
        }
    }

    handleSearch(event) {
        this.searchKey = event.target.value.trim();
    }

    handleRowSelection(event) {
        this.selectedRows = event.detail.selectedRows.map(row => row.Id);
    }

    get isButtonDisabled() {
        return this.selectedRows.length === 0;
    }

    handleAddCandidate() {
        if (!this.selectedRows.length) return;

        addCandidateToJobs({
            candidateId: this.recordId,
            jobIds: this.selectedRows
        })
            .then(() => {
                this.showToast('Success', 'Candidate added successfully!', 'success');
                this.selectedRows = [];
            })
            .catch(error => {
                this.showToast(
                    'Error',
                    error?.body?.message || 'Error adding candidate',
                    'error'
                );
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }
}