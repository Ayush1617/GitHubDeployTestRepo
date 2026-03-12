/**
 * @File Name      : JobpositionCard.js
 * @Description    : LWC component to display and manage open job positions. 
 *                   Provides search, selection, and assignment of candidates 
 *                   to job positions. Integrates with Apex methods 
 *                   (getOpenJobPositions, assignCandidatesToJobs) 
 *                   and shows success/error messages via toast.
 * @Author         : Yuvraj Singh
 * @Last Modified By : Yuvraj Singh
 * @Last Modified On : August 25, 2025
 * @Modification Log : Changed the search controller class
 * -------------------------------------------------------------------------------
 * Ver   | Date           | Author             | Modification
 * -------------------------------------------------------------------------------
 * 1.01  | August 25, 2025| Yuvraj Singh       | Changed the controller class
 * 1.00  | August 19, 2025| Yuvraj Singh       | Initial Version
 */

import { LightningElement, track, api } from 'lwc';
import getOpenJobPositions from '@salesforce/apex/CandidateSearchController.getOpenJobPositions';
import assignCandidatesToJobs from '@salesforce/apex/CandidateSearchController.assignCandidatesToJobs';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class JobpositionCard extends LightningElement {
    @track jobPositions = [];
    @track selectedJobIds = [];
    @track searchKey = '';
    @track isOpen = false;
    searchTimeout;

    @api selectedCandidateIds = [];
    @api hideCheckboxColumn = false;

    columns = [
        {
            label: 'Job ID',
            fieldName: 'Name',
            type: 'text',
            cellAttributes: { iconName: 'standard:case', iconPosition: 'left' }
        },
        {
            label: 'Job Title',
            fieldName: 'Job_Title__c',
            type: 'text',
            cellAttributes: { iconName: 'standard:lead', iconPosition: 'left' }
        },
        {
            label: 'Client Name',
            fieldName: 'ClientName',
            type: 'text',
            cellAttributes: { iconName: 'standard:account', iconPosition: 'left' }
        },
        {
            label: 'Status',
            fieldName: 'Status__c',
            type: 'text',
            cellAttributes: { iconName: 'utility:check', iconPosition: 'left' }
        },
        {
            label: 'Total Opening',
            fieldName: 'Total_Openings__c',
            type: 'number',
            cellAttributes: { iconName: 'standard:people', iconPosition: 'left', alignment: 'left' }
        },
        {
            label: 'Experience',
            fieldName: 'Required_Experience_Range__c',
            type: 'text',
            cellAttributes: { iconName: 'utility:skill', iconPosition: 'left', alignment: 'left' }
        },
        {
            label: 'Created Date',
            fieldName: 'CreatedDate',
            type: 'date',
            cellAttributes: { iconName: 'utility:calendar', iconPosition: 'left' }
        }
    ];

    @api openModal() {
        this.isOpen = true;
        this.loadJobPositions('');
    }

    closeModal() {
        this.isOpen = false;
    }

    loadJobPositions(searchKey) {
        getOpenJobPositions({ searchKey })
            .then(result => {
                const processedJobs = result.map(job => {
                    return {
                        ...job,
                        // Extract Client Name from Client__r relationship
                        ClientName: job.Client__r ? job.Client__r.Name : ''
                    };
                });

                const preservedSelection = new Set(this.selectedJobIds);
                this.jobPositions = processedJobs;
                this.selectedJobIds = processedJobs
                    .filter(job => preservedSelection.has(job.Id))
                    .map(job => job.Id);
            })
            .catch(error => {
                console.error(error);
                //show the actual error as well
                let message = 'An unexpected error occurred while assigning candidates';
                if (error && error.body && error.body.message) {
                    message = error.body.message;
                } else if (error && error.message) {
                    message = error.message;
                }

                this.showToast('Error', message, 'error');
            });
    }

    handleSearch(event) {
        this.searchKey = event.target.value;
        this.loadJobPositions(this.searchKey);
    }

    handleRowSelection(event) {
        const newlySelected = event.detail.selectedRows.map(row => row.Id);
        this.selectedJobIds = Array.from(new Set(newlySelected));
    }

    assignCandidates() {
        if (this.selectedJobIds.length === 0) {
            this.showToast('Warning', 'Please select at least one job position', 'warning');
            return;
        }
        //Can be removed - test after removing
        if (this.selectedCandidateIds.length === 0) {
            this.showToast('Warning', 'No candidates selected', 'warning');
            return;
        }
        assignCandidatesToJobs({
            jobPositionIds: this.selectedJobIds,
            candidateIds: this.selectedCandidateIds
        })
            .then(() => {
                this.showToast('Success', 'Candidates assigned successfully!', 'success');
                this.closeModal();
            })
            .catch(error => {
                console.error(error);
                //show what error
                let message = 'An unexpected error occurred while assigning candidates';
                if (error && error.body && error.body.message) {
                    message = error.body.message;
                } else if (error && error.message) {
                    message = error.message;
                }

                this.showToast('Error', message, 'error');
            });
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

    get hasJobPositions() {
        return this.jobPositions && this.jobPositions.length > 0;
    }
}