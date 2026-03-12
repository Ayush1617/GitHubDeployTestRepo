import { LightningElement, wire, track,api } from 'lwc';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import INTERVIEW_OBJECT from '@salesforce/schema/Interview__c';
import INTERVIEW_Stages from '@salesforce/schema/Interview__c.Interview_Status__c';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import updateInterviews from '@salesforce/apex/ATSController.updateInterviews';
import removeCandidateFromJob from '@salesforce/apex/ATSController.removeCandidateFromJob';
import requestFeedbackFromClient from '@salesforce/apex/ATSController.collectFeedback';
import getATSData from '@salesforce/apex/ATSController.getATSData';
import getCandidateIdsFromInterviews from '@salesforce/apex/ATSController.getCandidateIdsFromInterviews';
import { NavigationMixin } from 'lightning/navigation';

export default class ApplicantTrackingSystem extends NavigationMixin(LightningElement) {
    @track showStagePicklist = false;
    @track stagePicklistLabel = '';
    @track error;
    @track isLoading = false;
    @api recordId;
    @track interviewData = [];
    @track pagedRecords = [];
    @track picklistSteps = [];
    @track roundOptions = [];   
    @track selectedRecordIds = [];
    @track modalRecordIds = [];
    @track pageSize = 5;
    @track currentPage = 1;
    @track totalRecords = 0;
    @track selectedRound = null;
    @track selectedinterviewstages = null;
    @track selectedStage = null;  
    @track feedback = '';          
    @track selectAll = false;  
    @track selectedFeedbackType; 
    @track isFeedbackDisabled = true;
    @track isSaveDisabled = true;
    @track isModalOpen = false;
    @track isDeleteModalOpen = false;
    @track recordIdPendingDelete = null;
    @track pillData = [];
    @track isEditModalOpen = false;  
    @track editRecordId = null;
    wiredInterviewDataResult;
    prevVariant = 'neutral';
    nextVariant = 'neutral'; 
    FINAL_LABEL = 'Final';
    //my add
    showSubmitToClient = false;
    selectedCandidateIds=[];
    @track isFilterModalOpen = false;

    // FILTER VALUES
    @track selectedStageFilter = 'All';
    @track selectedSourceFilter = 'All';
    @track startDateFilter = null;
    @track endDateFilter = null;  
    @track showFinalSendBtn = false; 

    handleShowSendButton() {
    console.log('Next clicked → show parent send button');
    this.showFinalSendBtn = true;
}

    // Source dropdown
    sourceOptions = [
        { label: 'All Sources', value: 'All' },
        { label: 'Job Portal', value: 'Job Portal (e.g., Naukri, Monster)' },
        { label: 'Employee Referral', value: 'Employee Referral' },
        { label: 'Recruitment Agency', value: 'Recruitment Agency' },
        { label: 'LinkedIn', value: 'LinkedIn' },
        { label: 'Company Website', value: 'Company Website' },
        { label: 'Social Media', value: 'SSocial Media' },
        { label: 'Walk-in', value: 'Walk-in' },
        { label: 'Campus Hiring', value: 'Campus Hiring' },
        { label: 'Internal Database', value: 'Internal Database' },
        {label: 'Supplier', value: 'Supplier' }
    ];

    feedbackTypeOptions = [
    { label: 'Excellent communication', value: 'Excellent communication' },
    { label: 'Good technical knowledge', value: 'Good technical knowledge' },
    { label: 'Average performance', value: 'Average performance' },
    { label: 'Needs improvement', value: 'Needs improvement' },
    { label: 'Not a good fit', value: 'Not a good fit' },
    { label: 'Other', value: 'Other' }
    ];


handleCloseSubmitModal() {
    this.showSubmitToClient = false;
}
    
    // ---------------- WIRE: Object Metadata ----------------
    @wire(getObjectInfo, { objectApiName: INTERVIEW_OBJECT })
    objectInfo;
    // ---------------- WIRE: Picklist Values ----------------

    @wire(getPicklistValues, {
        recordTypeId: '$objectInfo.data.defaultRecordTypeId',
        fieldApiName: INTERVIEW_Stages
    })
    wiredPicklistValues({ data, error }) {
        if (data) {
            console.log('picklist : ',data);
            this.picklistSteps = data.values.map(item => ({
                label: item.label,
                value: item.value
            }));
            this.tryUpdatePagedRecords();
        } else if (error) {
            console.error('Error loading picklist :', error);
        }
    }

  // ---------------- WIRE: Interview Data ----------------
@wire(getATSData, { jobPositionId: '$recordId' })
wiredData(result) {
    this.wiredInterviewDataResult = result;
    const { data, error } = result;

    if (data) {

        // Sort alphabetically by candidate name
        let sortedData = [...data].sort((a, b) => {
            const nameA = a.Candidate_Name__r?.Name?.toLowerCase() || '';
            const nameB = b.Candidate_Name__r?.Name?.toLowerCase() || '';
            return nameA.localeCompare(nameB);
        });

        // Add resume flag
        sortedData = sortedData.map(item => {
            return {
                ...item,
                isResumeLinkEmpty: !item.Candidate_Name__r?.Resume_Link__c
            };
        });

        // 🔥 STORE BOTH DATASETS HERE
        this.allInterviewData = sortedData;   // master copy (never modified)
        this.interviewData = [...sortedData]; // working copy (filtered)

        this.totalRecords = sortedData.length;
        this.error = undefined;

        this.tryUpdatePagedRecords();

        // --- Compute pill counts ---
        const statuses = [
            'New', 'Recruiter Screening', 'Internal Assessment', 'Shortlisted', 'Interviewing',
            'Offered', 'Hired', 'Rejected'
        ];

        const counts = {};
        sortedData.forEach(interview => {
            const status = interview.Interview_Status__c || 'Unknown';
            counts[status] = (counts[status] || 0) + 1;
        });

        this.pillData = statuses.map(status => ({
            status,
            count: counts[status] || 0
        }));

    } else if (error) {
        this.error = error;
        this.interviewData = [];
        this.totalRecords = 0;
        this.pillData = [];
    }
}

    // ---------------- Refresh Data from Server ----------------
    refreshData() {
        if (this.wiredInterviewDataResult) {
            refreshApex(this.wiredInterviewDataResult);
        }
    }
    // ---------------- GETTERS ----------------
    get hasData() {
        const result = this.interviewData && this.interviewData.length > 0;
        return result;
    }
    get isActionDisabled() {
        return !(this.selectedRecordIds && this.selectedRecordIds.length > 0);
    }
    get totalPages() {
        return this.interviewData ? Math.ceil(this.interviewData.length / this.pageSize) : 1;
    }

    // ---------------- DATA + PICKLIST SYNC ----------------
    tryUpdatePagedRecords() {
        console.log('tryUpdatePagedRecords triggered');
        console.log('interviewDatalength : ', this.interviewData.length);
        console.log('picklistStepslength : ', this.picklistSteps.length);

        if (this.interviewData.length && this.picklistSteps.length) {
            this.updatePagedRecords(true);
        } else if (this.interviewData.length) {
            this.updatePagedRecords(false);
        }
    }
    // ---------------- PAGINATION ----------------

    updatePagedRecords(includeSteps = true) {
        const startIndex = (this.currentPage - 1) * this.pageSize;
        const endIndex = startIndex + this.pageSize;
        const slice = (this.interviewData || []).slice(startIndex, endIndex);
        // Add display steps for path component

        this.pagedRecords = slice.map(r => ({
            ...r,
            pathCurrentStep: r?.Interview_Status__c,
            displaySteps: includeSteps && this.picklistSteps.length ? this.buildDisplaySteps(r) : []
        }));
    }

    handlePageSizeChange(event) {
        const newSize = parseInt(event.target.value, 10);
        if (newSize > 0) {
            this.pageSize = newSize;
            this.currentPage = 1;
            this.updatePagedRecords();
        }
    }

    handlePrev() {

        if (this.currentPage > 1) {
             this.prevVariant = 'brand';
             this.nextVariant = 'neutral'; 
            this.currentPage--;
            this.updatePagedRecords();
        }
    }

    handleNext() {
        if (this.currentPage < this.totalPages) {
            this.nextVariant = 'brand';
            this.prevVariant = 'neutral';
            this.currentPage++;
            this.updatePagedRecords();
        }
    }

   // ---------------- FILTERS ----------------

    // Open filter modal
    handleFilterClick() {
        this.isFilterModalOpen = true;
    }

    // Close filter modal
    closeFilterModal() {
        this.isFilterModalOpen = false;
    }

    // Apply all filters
    applyFilters() {
        let filtered = [...this.allInterviewData];  
        // IMPORTANT:
        // Use original unfiltered dataset (store your full data in allInterviewData)
        // to avoid applying filters on already filtered records.

        // --- Stage Filter ---
        if (this.selectedStageFilter && this.selectedStageFilter !== 'All') {
            filtered = filtered.filter(rec =>
                rec.Interview_Status__c === this.selectedStageFilter
            );
        }

        // --- Source Filter ---
        if (this.selectedSourceFilter && this.selectedSourceFilter !== 'All') {
            filtered = filtered.filter(rec =>
                rec.Candidate_Name__r?.Source__c === this.selectedSourceFilter
            );
        }

        // --- Date Filter (Using CreatedDate — change if needed) ---
        if (this.startDateFilter || this.endDateFilter) {
            filtered = filtered.filter(rec => {
                const recordDate = new Date(rec.CreatedDate);

                const afterStart =
                    !this.startDateFilter ||
                    recordDate >= new Date(this.startDateFilter);

                const beforeEnd =
                    !this.endDateFilter ||
                    recordDate <= new Date(this.endDateFilter);

                return afterStart && beforeEnd;
            });
        }

        // Update UI with filtered list
        this.interviewData = filtered;
        this.currentPage = 1;
        this.updatePagedRecords();

        this.isFilterModalOpen = false;
    }

    // ---------------- FILTER FIELD HANDLERS ----------------
        openFilterPanel() {
        this.isFilterModalOpen = true;
    }

    // Stage picklist change
    handleStageFilterChange(event) {
        this.selectedStageFilter = event.detail.value;
    }

    // Source picklist change
    handleSourceFilterChange(event) {
        this.selectedSourceFilter = event.detail.value;
    }

    // Start date change
    handleStartDateChange(event) {
        this.startDateFilter = event.target.value;
    }

    // End date change
    handleEndDateChange(event) {
        this.endDateFilter = event.target.value;
    }

    // Quick-select date buttons
    handleQuickDateSelect(event) {
        const value = event.target.value;

        const today = new Date();
        let start, end;

        if (value === 'today') {
            start = end = today.toISOString().split('T')[0];
        }

        if (value === 'yesterday') {
            const y = new Date(today);
            y.setDate(y.getDate() - 1);
            start = end = y.toISOString().split('T')[0];
        }

        if (value === 'last7') {
            const d = new Date(today);
            d.setDate(d.getDate() - 7);
            start = d.toISOString().split('T')[0];
            end = today.toISOString().split('T')[0];
        }

        this.startDateFilter = start;
        this.endDateFilter = end;
    }
    // Clear all filters
        clearFilters() {
            // Reset all filter values
            this.selectedStageFilter = 'All';
            this.selectedSourceFilter = 'All';
            this.startDateFilter = null;
            this.endDateFilter = null;

            // Clear quick filters (UI updated automatically)

            // Reset filtered data back to original full list
            this.interviewData = [...this.allInterviewData];

            // Reset pagination
            this.currentPage = 1;
            this.updatePagedRecords();

            // Close modal
           // this.isFilterModalOpen = false;
        }



    // ---------------- Selection ----------------
    get dataWithSelection() {
        const result = this.pagedRecords.map(record => {
            return {
                ...record,
                selected: this.selectedRecordIds.includes(record.Id)
                //candidateLink: `${window.location.origin}/lightning/r/Contact/${record.Candidate_Name__c}/view`
            };
        });
        return result;
    }
    get allSelected() {
                // Check if all records on current page are selected

        const result = this.pagedRecords.length > 0 && this.pagedRecords.every(rec => this.selectedRecordIds.includes(rec.Id)); //This checks if every record in pagedRecords has its Id included in selectedRecordIds.
        return result;
    }

    handleCandidateClick(event) {
        event.preventDefault();

        const recordId = event.currentTarget.dataset.id;

        console.log('Navigating to record:', recordId);

        if (!recordId) {
            console.error('Record Id is undefined');
            return;
        }

        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                actionName: 'view'
            }
        });
    }

    handleSelectAll(event) {
        const isChecked = event.target.checked;
        this.selectAll = isChecked;

        if (isChecked) {
                        // Add all records on current page to selected list

            const idsToAdd = this.pagedRecords
                .map(rec => rec.Id)
                .filter(id => !this.selectedRecordIds.includes(id));
            this.selectedRecordIds = [...this.selectedRecordIds, ...idsToAdd];
        } else {
                        // Remove all records on current page from selection

            const idsToRemove = this.pagedRecords.map(rec => rec.Id);
            this.selectedRecordIds = this.selectedRecordIds.filter(id => !idsToRemove.includes(id));
        }
    }

    handleCheckboxChange(event) {
        const recordId = event.target.dataset.id;
        const isChecked = event.target.checked;

        if (isChecked) {
            if (!this.selectedRecordIds.includes(recordId)) {
                this.selectedRecordIds = [...this.selectedRecordIds, recordId];
            }
        } else {
            this.selectedRecordIds = this.selectedRecordIds.filter(id => id !== recordId);
        }

        this.selectAll = this.pagedRecords.every(rec =>
            this.selectedRecordIds.includes(rec.Id)
        );

    }

    // ---------------- HANDLERS for Modal ----------------
        handleStageChange(event) {
            this.selectedStage = event.detail.value;
            this.updateSaveButtonState();
        }        

        handleFeedbackChange(event) {
            this.feedback = event.detail.value;
            this.updateSaveButtonState();
        }

        handleFeedbackTypeChange(event) {
            this.selectedFeedbackType = event.detail.value;

            if (this.selectedFeedbackType === 'Other') {
                this.isFeedbackDisabled = false;
                this.feedback = '';
                this.updateSaveButtonState();
            } else {
                this.isFeedbackDisabled = false;
                this.feedback = this.selectedFeedbackType;
                this.updateSaveButtonState();
            }
        }        

        async handleSave() {
            if (this.selectedStage && !this.feedback) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'Please provide feedback when changing Stage.',
                        variant: 'error'
                    })
                );
                return;
            }

            if (!this.selectedStage && !this.feedback) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'Please update at least Stage or Feedback before saving.',
                        variant: 'error'
                    })
                );
                return;
            }

            this.isLoading = true;

           try {
                console.log('🟢 modal Ids: ', this.modalRecordIds);
                console.log('🟢 modal Stage: ', this.selectedStage);
                console.log('🟢 modal feedback: ', this.feedback);

                // Call Apex Imperatively with direct parameters
                await updateInterviews({
                    recordIds: this.modalRecordIds,
                    newStage: this.selectedStage,
                    feedback: this.feedback
                });

                // Success Toast
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Interview updated successfully.',
                        variant: 'success'
                    })
                );

                // Refresh Data + Close Modal
                await this.refreshData();
                this.closeModal();

            } catch (error) {
                console.error('❌ Apex error:', error);
                const msg = error?.body?.message || 'Error updating interview';
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error updating interview',
                        message: msg,
                        variant: 'error'
                    })
                );
            } finally {
                this.isLoading = false;
            }
        }

        openModal() {
            this.isModalOpen = true;
            this.modalRecordIds = this.selectedRecordIds;
        }
        closeModal() {
            this.isModalOpen = false;
            this.selectedStage = null;
            this.feedback = '';
            this.selectedFeedbackType = null;
            this.isFeedbackDisabled = true;
            this.isSaveDisabled = true;
        }

//         handleSendEmailClick() {
//     this.dispatchEvent(
//         new CustomEvent('sendemail', {
//             bubbles: true,
//             composed: true
//         })
//     );
// }
    //@track sendEmailFlag = false;

    handleSendEmailClick() {
    console.log('Parent send email clicked');

    const child = this.template.querySelector('c-submit-candidate-to-client')

    if(child){
        child.sendEmailFromParent();
    } else {
        console.log('child not found');
    }
    
    
}

handleEmailSuccess() {
    console.log('Email sent success → closing modal');

    // now close modal AFTER toast
    this.showSubmitToClient = false;
    this.showFinalSendBtn = false;
}

 
//    handleSendEmailClick() {
//     const child = this.template.querySelector('c-custom-email-composer');

//     if (child) {
//         child.sendEmailFromFooter();
//     }
// }

        updateSaveButtonState() {
            const hasFeedback = this.feedback && this.feedback.trim() !== '';
            const hasPicklistSelection = (this.selectedStage && this.selectedStage.trim() !== '');
            
            this.isSaveDisabled = !(hasFeedback && hasPicklistSelection);
        }

        //------------- open delete confirmation modal and store record id
            handleOpenDeleteConfirm(event) {
                const recId = event.currentTarget.dataset.id;
                this.recordIdPendingDelete = recId;
                this.isDeleteModalOpen = true;
            }

            // close modal without deleting
            handleCloseDeleteConfirm() {
                this.isDeleteModalOpen = false;
                this.recordIdPendingDelete = null;
            }

            // confirm delete and call apex
            handleConfirmDelete() {
                if (!this.recordIdPendingDelete) return;

                this.isLoading = true;

                // Reusing the same Apex from bulk delete but sending a single record
                removeCandidateFromJob({
                    interviewIds: [this.recordIdPendingDelete]
                })
                    .then(() => {
                        this.showToast('Success', 'Interview record deleted successfully.', 'success');
                        this.updatePagedRecords();
                        return refreshApex(this.wiredInterviewDataResult);
                    })
                    .catch(error => {
                        const msg = error?.body?.message || 'Failed to delete interview record.';
                        this.showToast('Error', msg, 'error');
                    })
                    .finally(() => {
                        this.isLoading = false;
                        this.isDeleteModalOpen = false;
                        this.recordIdPendingDelete = null;
                    });
            }

            
    //----------------- Edit Modal ---------------------------

        handleOpenEditModal(event) {
            this.editRecordId = event.currentTarget.dataset.id;
            this.isEditModalOpen = true;
        }

        // close modal (cancel or after save)
        handleCloseEditModal() {
            this.isEditModalOpen = false;
            this.editRecordId = null;
        }
        // refresh data after successful edit
        handleSuccessEdit() {
            this.showToast('Success', 'Interview updated successfully.', 'success');
            this.isEditModalOpen = false;
            this.editRecordId = null;
            this.refreshData();
        }

// ---------------- Bulk Remove Candidate ----------------
        handleRemoveCandidate() {
            if (!this.selectedRecordIds?.length) {
                this.showToast('Warning', 'Please select at least one candidate to remove.', 'warning');
                return;
            }

            this.isLoading = true;

            removeCandidateFromJob({
                interviewIds: this.selectedRecordIds
            })
                .then(() => {
                    this.showToast('Success', 'Candidate(s) removed successfully.', 'success');
                    this.updatePagedRecords();
                    return refreshApex(this.wiredInterviewDataResult);
                })
                .catch(error => {
                    const msg = error?.body?.message || 'Failed to remove candidate.';
                    this.showToast('Error', msg, 'error');
                })
                .finally(() => {
                    this.isLoading = false;
                   /* setTimeout(() => {
                        this.isLoading = false; // Hide the spinner after the operation
                    }, 1000);*/
                });
        }

        // ---------------- Bulk send email to client ----------------
        handleRequestFeedback() {
            if (!this.selectedRecordIds?.length) {
                this.showToast('Warning', 'Please select at least one interview to request feedback.', 'warning');
                return;
            }

            this.isLoading = true;

            requestFeedbackFromClient({
                interviewIds: this.selectedRecordIds
            })
                .then(() => {
                    this.showToast('Success', 'Feedback request sent successfully.', 'success');
                    return refreshApex(this.wiredInterviewDataResult);
                })
                .catch(error => {
                    const msg = error?.body?.message || 'Failed to request feedback.';
                    this.showToast('Error', msg, 'error');
                })
                .finally(() => {
                    this.isLoading = false;
                   /* setTimeout(() => {
                        this.isLoading = false; // Hide the spinner after the operation
                    }, 1000);*/
                });
        }

    // ---------------- Bulk Round Update ----------------
   /* handleRoundChange(event) {
        const chosen = event.detail.value;
        this.selectedRound = chosen;

        if (!this.selectedRecordIds || this.selectedRecordIds.length === 0) {
            this.showToast('Warning', 'Please select at least one record to update.', 'warning');
            return;
        }

    updateInterviewStages({
        interviewIds: this.selectedRecordIds,
        newStageValue: chosen
    })
    .then(() => {
        // Update UI immediately
        this.interviewData = this.interviewData.map(record => {
            if (this.selectedRecordIds.includes(record.Id)) {
                return { ...record, Interview_Status__c: chosen };
            }
            return record;
        });
        this.updatePagedRecords();

        this.showToast('Success', 'Interview stages updated successfully', 'success');

        // Reset selections
        this.selectedRound = null;
        this.selectedRecordIds = [];

        // Now refresh from server in background
        return refreshApex(this.wiredInterviewDataResult);
    })
    .catch(error => {
        console.log('OUTPUT : ',JSON.stringify(this.selectedRecordIds));
        console.log('[handleRoundChange] Error:', error);
        // let message = error?.body?.message || 'Failed to update interview rounds.';
        // console.log('OUTPUT : ', error?.body?.message);
        // this.showToast('Error', message, 'error');
         let message = 'Failed to update interview rounds.';

        // Check if validation errors exist
        if (error?.body?.output?.errors?.length) {
            message = error.body.output.errors.map(err => err.message).join('\n');
        } else if (error?.body?.pageErrors?.length) {
            message = error.body.pageErrors.map(err => err.message).join('\n');
        } else if (error?.body?.message) {
            message = error.body.message;
        }

        console.log('Final Error Message for Toast:', message);
        this.showToast('Error', message, 'error');
        });
    } */

    // ---------------- Helpers ----------------
    equalsIgnoreCase(a, b) {
        return (a || '').toString().toLowerCase() === (b || '').toString().toLowerCase();
    }
    findOptionByValue(value) {
        return (this.picklistSteps || []).find(o =>
            this.equalsIgnoreCase(o.value, value)
        );
    }
    buildDisplaySteps(record) {
        if (!this.picklistSteps || this.picklistSteps.length === 0) {
            return [];
        }
        const hiredOpt = this.findOptionByValue('Hired');
        const rejectedOpt = this.findOptionByValue('Rejected');
        // Exclude hired/rejected from base steps
        const baseSteps = this.picklistSteps
            .filter(s =>
                !this.equalsIgnoreCase(s.value, hiredOpt?.value || 'Hired') &&
                !this.equalsIgnoreCase(s.value, rejectedOpt?.value || 'Rejected')
            )
            .slice(0, 6);
        // decide last step dynamically
        const status = record?.Interview_Status__c || '';
        let last;
        if (this.equalsIgnoreCase(status, hiredOpt?.value || 'Hired')) {
            last = hiredOpt || { label: 'Hired', value: 'Hired' };
        } else if (this.equalsIgnoreCase(status, rejectedOpt?.value || 'Rejected')) {
            last = rejectedOpt || { label: 'Rejected', value: 'Rejected' };
        } else {
            last = { label: this.FINAL_LABEL, value: this.FINAL_LABEL };
        }

        const steps = [...baseSteps, last];
        return steps;
    }
    
    handleEmailClick() {
        const evt = new ShowToastEvent({
            title: 'Success',
            message: 'Emails sent successfully to selected candidates.',
            variant: 'success',
            mode: 'dismissable'
        });
        this.dispatchEvent(evt);
    }

    get computedData() {
    return this.dataWithSelection.map((rec, i) => {
        return {
            ...rec,
            rowClass: `record-container slds-p-vertical_small ${i % 2 === 0 ? 'striped-bg' : 'plain-bg'}`
        };
    });
    }

     /*SHivam addition */
    handleSubmitToClient() {
        console.log('Selected Interview Ids:', JSON.stringify(this.selectedRecordIds));
        this.showFinalSendBtn = false;
        getCandidateIdsFromInterviews({ interviewIds: this.selectedRecordIds })
            .then(result => {
                console.log('Candidate Ids:', JSON.stringify(result));
                this.selectedCandidateIds = result;
                this.showSubmitToClient = true; 
            })
            .catch(error => {
                let message = 'An unexpected error occurred.';
                if (error && error.body && error.body.message) {
                    message = error.body.message;
                } else if (error && error.message) {
                    message = error.message;
                }

                console.error('Apex Error:', error);
                this.showToast('Error', message, 'error');
            });
    }

    closeSubmitToClient() {
         this.showSubmitToClient = false;

    // 🔥 IMPORTANT RESET
    this.showFinalSendBtn = false;
    }   

    handleExportButtonClick() {
        console.log('Export button clicked');

        getCandidateIdsFromInterviews({ interviewIds: this.selectedRecordIds })
            .then(result => {
                console.log('Candidate Ids:', JSON.stringify(result));
                this.selectedCandidateIds = result;

                // ✅ Call child component’s export method with these IDs
                const exportComp = this.template.querySelector('c-export-to-excel');
                if (exportComp) {
                    exportComp.triggerExport(this.selectedCandidateIds);
                }
            })
            .catch(error => {
                let message = 'An unexpected error occurred.';
                if (error?.body?.message) {
                    message = error.body.message;
                } else if (error?.message) {
                    message = error.message;
                }
                console.error('Apex Error:', error);
                this.showToast('Error', message, 'error');
            });
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({ title, message, variant });
        this.dispatchEvent(event);
    }
}