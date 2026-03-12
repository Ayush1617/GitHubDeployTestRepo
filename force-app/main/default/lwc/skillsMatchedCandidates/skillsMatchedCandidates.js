import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getMatchedCandidates from
    '@salesforce/apex/SkillsMatchedCandidateController.getMatchedCandidates';
import createInterview from
    '@salesforce/apex/SkillsMatchedCandidateController.createInterview';
import createInterviewsBulk from
    '@salesforce/apex/SkillsMatchedCandidateController.createInterviewsBulk';
import { NavigationMixin } from 'lightning/navigation';

export default class SkillsMatchedCandidates extends NavigationMixin(LightningElement) {

    @api recordId;

    data = [];
    selectedRows = [];

    /* PAGINATION */
    pageSize = 10;
    currentPage = 1;

   pageSizeOptions = [
    { label: '5', value: 5 },
    { label: '10', value: 10 },
    { label: '20', value: 20 },
    { label: '50', value: 50 }
];


    /* ================= FETCH ================= */
    @wire(getMatchedCandidates, { jobPositionId: '$recordId' })
    wiredCandidates({ data, error }) {
        if (data) {
            this.data = data.map(row => ({
                ...row,
                matchPercentage: Math.round(row.matchPercentage),
                isSelected: false
            }));
            this.currentPage = 1;
        } else if (error) {
            this.showToast('Error', 'Failed to load candidates', 'error');
        }
    }

    /* ================= PAGED DATA ================= */
    get pagedData() {
        const start = (this.currentPage - 1) * this.pageSize;
        return this.data.slice(start, start + this.pageSize);
    }

    get totalPages() {
        return Math.ceil(this.data.length / this.pageSize);
    }

    get isFirstPage() {
        return this.currentPage === 1;
    }

    get isLastPage() {
        return this.currentPage === this.totalPages;
    }

    handleNext() {
        if (!this.isLastPage) {
            this.currentPage++;
        }
    }

    handlePrev() {
        if (!this.isFirstPage) {
            this.currentPage--;
        }
    }

    
    handleNavigateToRecord(event) {
        const recordId = event.currentTarget.dataset.id;

        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'Contact',
                actionName: 'view'
            }
        });
    }

/* ================= CHECKBOX ================= */
    handleCheckboxChange(event) {
        const id = event.target.dataset.id;
        const checked = event.target.checked;

        this.data = this.data.map(row => {
            if (row.candidateId === id) {
                row.isSelected = checked;
            }
            return row;
        });

        this.selectedRows = this.data
            .filter(r => r.isSelected)
            .map(r => r.candidateId);
    }

    /* ================= SINGLE ADD ================= */
    handleSingleAdd(event) {
        const candidateId = event.target.dataset.id;

        createInterview({
            jobPositionId: this.recordId,
            candidateId
        }).then(() => {
            this.removeRows([candidateId]);
            this.showToast('Success', 'interview created successfully', 'success');
        });
    }

    /* ================= BULK ADD ================= */
    handleBulkAdd() {
        if (!this.selectedRows.length) {
            this.showToast('Warning', 'Select at least one candidate', 'warning');
            return;
        }

        createInterviewsBulk({
            jobPositionId: this.recordId,
            candidateIds: this.selectedRows
        }).then(() => {
            this.removeRows(this.selectedRows);
            this.selectedRows = [];
            this.currentPage = 1;
            this.showToast('Success', 'interviews created successfully', 'success');
        });
    }

    /* ================= REMOVE ================= */
    removeRows(ids) {
        const idSet = new Set(ids);
        this.data = this.data.filter(row => !idSet.has(row.candidateId));
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }


get isAllSelected() {
    if (!this.pagedData.length) {
        return false;
    }
    return this.pagedData.every(row => row.isSelected);
}

handleSelectAll(event) {
    const checked = event.target.checked;

    const pageIds = this.pagedData.map(r => r.candidateId);

    this.data = this.data.map(row => {
        if (pageIds.includes(row.candidateId)) {
            row.isSelected = checked;
        }
        return row;
    });

    this.selectedRows = this.data
        .filter(r => r.isSelected)
        .map(r => r.candidateId);

}
handlePageSizeChange(event) {
    this.pageSize = Number(event.detail.value);
    this.currentPage = 1; // reset to first page
}

get isBulkDisabled() {
    return this.selectedRows.length === 0;
}


get bulkButtonLabel() {
    const count = this.selectedRows.length;

    if (count === 0) {
        return 'Add Candidates';
    }

    if (count === 1) {
        return 'Add 1 Candidate';
    }

    return `Add ${count} Candidates`;
}

get hasData() {
    return this.data && this.data.length > 0;
}



}