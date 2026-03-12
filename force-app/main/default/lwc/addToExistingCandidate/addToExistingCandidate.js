import { LightningElement, api, track } from 'lwc';
import getMyCandidatesBySearch from '@salesforce/apex/SupplierCandidateController.getMyCandidatesBySearch';
import createInterviews from '@salesforce/apex/SupplierCandidateController.createInterviews';
import getNoticePeriodPicklistValues from '@salesforce/apex/CandidatePicklistService.getNoticePeriodPicklistValues';
import updateCandidateFields from '@salesforce/apex/SupplierCandidateController.updateCandidateFields';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class AddToExistingCandidate extends LightningElement {
    @api recordId;

    @track candidates = [];
    @track selectedRowIds = [];
    @track showEditModal = false;


    editingCandidateId;
    editingCandidateName;
    editingNoticeValue;
    editingExpectedRate;

    /* Resume */
    resumeFileName;
    resumeContentType;
    resumeBase64Body;

    noticePeriodOptions = [];

    pageSize = 5;

    pageSizeOptions = [
        { label: '5', value: 5 },
        { label: '10', value: 10 },
        { label: '15', value: 15 },
        { label: '20', value: 20 }
    ];

    pageNumber = 1;
    totalRecords = 0;

    searchKey = '';
    error;

    columns = [
        { label: 'Name', fieldName: 'Name' },
        { label: 'Email', fieldName: 'Email'},
        { label: 'Phone', fieldName: 'Phone'},
        { label: 'Designation', fieldName: 'Designation__c'},
        { label: 'Experience', fieldName: 'Experience_Year__c'},
        { label: 'Notice Period', fieldName: 'Notice_Period__c'},
        {
            label: 'Expected Salary',
            fieldName: 'Supplier_Expected_Rate__c',
            type: 'currency',
            initialWidth: 150,
            typeAttributes: { currencyCode: 'INR' }
        },
        {
            type: 'button-icon',
            initialWidth: 50,
            typeAttributes: {
                iconName: 'utility:edit',
                name: 'edit_candidate'
            }
        }
    ];

    connectedCallback() {
        this.doSearch();
        this.loadPicklist();
    }

    loadPicklist() {
        getNoticePeriodPicklistValues()
            .then(res => this.noticePeriodOptions = res);
    }

    handleSearchInput(event) {
        this.searchKey = event.target.value.trim();
        this.pageNumber = 1;

        if (this.searchKey.length < 2) {
            this.searchKey = '';
        }

        this.doSearch();
    }

    doSearch() {
        getMyCandidatesBySearch({
            searchKey: this.searchKey,
            pageSize: this.pageSize,
            pageNumber: this.pageNumber
        })
        .then(res => {
            this.candidates = res.records;
            this.totalRecords = res.totalRecords;
        })
        .catch(err => {
            this.candidates = [];
            this.error = err.body?.message;
        });
    }

    handlePageSizeChange(event) {
        this.pageSize = Number(event.detail.value);
        this.pageNumber = 1; // reset pagination
        this.doSearch();
    }


    handleNext() {
        if (this.pageNumber < this.totalPages) {
            this.pageNumber++;
            this.doSearch();
        }
    }

    handlePrevious() {
        if (this.pageNumber > 1) {
            this.pageNumber--;
            this.doSearch();
        }
    }

    get totalPages() {
        return Math.ceil(this.totalRecords / this.pageSize);
    }

    get isNextDisabled() {
        return this.pageNumber >= this.totalPages;
    }

    get isPreviousDisabled() {
        return this.pageNumber <= 1;
    }

    handleRowAction(event) {
        const row = event.detail.row;
        this.editingCandidateId = row.Id;
        this.editingCandidateName = row.Name;
        this.editingNoticeValue = row.Notice_Period__c || '';
        this.editingExpectedRate = row.Supplier_Expected_Rate__c || null;
        this.showEditModal = true;
    }

    handleNoticeChange(e) {
        this.editingNoticeValue = e.target.value;
    }

    handleExpectedRateChange(e) {
        this.editingExpectedRate = Number(e.target.value);
    }

    handleResumeChange(event) {
        const file = event.target.files[0];
        if (!file) return;

        this.resumeFileName = file.name;
        this.resumeContentType = file.type;

        const reader = new FileReader();
        reader.onload = () => {
            this.resumeBase64Body = reader.result.split(',')[1];
        };
        reader.readAsDataURL(file);
    }

    closeEditModal() {
        this.showEditModal = false;
        this.resumeFileName = null;
        this.resumeContentType = null;
        this.resumeBase64Body = null;
    }

    saveEditChanges() {
        const payload = {
            candidateId: this.editingCandidateId,
            noticePeriod: this.editingNoticeValue,
            expectedRate: this.editingExpectedRate,
            resume: this.resumeBase64Body
                ? {
                    fileName: this.resumeFileName,
                    contentType: this.resumeContentType,
                    base64Body: this.resumeBase64Body
                }
                : null
        };

        console.log(
            'Payload JSON:',
            JSON.stringify(payload)
        );

        updateCandidateFields({
            payloadJson: JSON.stringify(payload)
        })
            .then(updated => {
                this.candidates = this.candidates.map(c =>
                    c.Id === updated.Id ? updated : c
                );
                this.showToast(
                    'Success',
                    'Candidate updated successfully',
                    'success'
                );
                this.closeEditModal();
            })
            .catch(err => {
                this.showToast(
                    'Error',
                    err.body?.message,
                    'error'
                );
            });
    }

    handleRowSelection(event) {
        this.selectedRowIds = event.detail.selectedRows.map(r => r.Id);
    }

    get isCreateDisabled() {
        return this.selectedRowIds.length === 0;
    }

    handleCreateInterviews() {
        createInterviews({
            candidateIds: this.selectedRowIds,
            jobPositionId: this.recordId
        })
        .then(res => {
            this.showToast('Success', `${res.length} interviews created`, 'success');
            this.selectedRowIds = [];
        })
        .catch(err => {
            this.showToast('Error', err.body?.message, 'error');
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}