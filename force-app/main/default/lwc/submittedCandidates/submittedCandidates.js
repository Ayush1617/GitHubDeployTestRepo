import { LightningElement, track } from 'lwc';
import getCandidatesForDisplay from '@salesforce/apex/CandidateShareController.getCandidatesForDisplay';
import createInterviewsAndGetCandidates from '@salesforce/apex/CandidateShareController.createInterviewsAndGetCandidates';
import updateInterviewStatusToShortlisted from '@salesforce/apex/CandidateShareController.updateInterviewStatusToShortlisted';
import saveCandidateFeedback from '@salesforce/apex/CandidateShareController.saveCandidateFeedback';
import getShortlistedCandidates from '@salesforce/apex/CandidateShareController.getShortlistedCandidates';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getJobDetails from '@salesforce/apex/CandidateShareController.getJobDetails';
import getJobTitle from '@salesforce/apex/CandidateShareController.getJobTitle';

export default class SubmittedCandidates extends LightningElement {

    /* ========================
    Reactive Properties
    ========================= */

    @track candidates = [];
    jobPositionTitle  = '';
    @track isLoading = true;
    @track hasError = false;
    @track errorMessage = '';
    @track showSuccess = false;
    @track showError = false;
    @track message = '';

    shortlistedCandidateIds = [];
    jobId;
    candidateIdsFromUrl = '';

    @track showFeedbackModal = false;
    @track selectedCandidateId;
    @track selectedFeedbackList = [];
    @track currentPage = 1;
    pageSize = 5; 
    @track totalPages = 0;
    @track paginatedCandidates = [];

    previewCandidateId;
    showPreviewModal = false;

    // Flag to track if we've already tried creating interviews
    hasAttemptedCreation = false;

    /* ========================
    Lifecycle
    ========================= */

    connectedCallback() {
        console.log('Component Loaded');
        this.loadCandidatesFromURL();
    }

    /* ========================
    URL Handling
    ========================= */

    loadCandidatesFromURL() {
        console.log('Reading URL Params...');
        const urlParams = new URLSearchParams(window.location.search);

        this.candidateIdsFromUrl = urlParams.get('ids');
        this.jobId = urlParams.get('jobId');
        console.log('Candidate Ids from URL:', this.candidateIdsFromUrl);
        console.log('Job Id from URL:', this.jobId);

        if (!this.candidateIdsFromUrl || !this.jobId) {
            this.hasError = true;
            this.errorMessage = 'Invalid link. Job information missing.';
            this.isLoading = false;
            return;
        }

        console.log('Job Id from URL@@@@:', this.jobId);
        getJobTitle({ jobId: this.jobId })
        .then(result => {
            console.log('Job Details Response:', result);
            if (result) {
                this.jobPositionTitle = result.Job_Title__c;
                console.log('Job Title:', this.jobPositionTitle);
            }
        })
        .catch(error => {
            console.error('Apex Error:', error);
        });

        // STEP 1: First try to get existing interviews
        this.tryGetExistingInterviews();
    }

    /* ========================
    Method 1: Try to get existing interviews (Cacheable)
    ========================= */
    tryGetExistingInterviews() {
        console.log('=== STEP 1: Attempting to fetch existing interviews ===');
        console.log('Calling getCandidatesForDisplay (cacheable method)...');
        
        this.isLoading = true;
        
        getCandidatesForDisplay({ 
            candidateIdsParam: this.candidateIdsFromUrl, 
            jobId: this.jobId 
        })
        .then(result => {
            console.log('getCandidatesForDisplay response:', result);
            
            if (result && result.length > 0) {
                // EXISTING INTERVIEWS FOUND - Use this data
                console.log('✅ EXISTING INTERVIEWS FOUND - Using cacheable method data');
                console.log(`Found ${result.length} existing interview records`);
                this.processCandidates(result);
            } else {
                // NO EXISTING INTERVIEWS - Need to create them
                console.log('❌ NO EXISTING INTERVIEWS FOUND - Will create new ones');
                console.log('Moving to STEP 2: Creating interviews...');
                this.tryCreateNewInterviews();
            }
        })
        .catch(error => {
            console.error('Error in getCandidatesForDisplay:', error);
            console.log('❌ Failed to fetch existing interviews - Attempting to create new ones');
            this.tryCreateNewInterviews();
        });
    }

    /* ========================
    Method 2: Create new interviews (Non-cacheable)
    ========================= */
    tryCreateNewInterviews() {
        console.log('=== STEP 2: Creating new interview records ===');
        console.log('Calling createInterviewsAndGetCandidates (non-cacheable method)...');
        
        // Prevent infinite loops
        if (this.hasAttemptedCreation) {
            console.error('Already attempted creation once - stopping to prevent loop');
            this.hasError = true;
            this.errorMessage = 'Unable to load or create candidate records';
            this.isLoading = false;
            return;
        }
        
        this.hasAttemptedCreation = true;
        
        createInterviewsAndGetCandidates({ 
            candidateIdsParam: this.candidateIdsFromUrl, 
            jobId: this.jobId 
        })
        .then(result => {
            console.log('createInterviewsAndGetCandidates response:', result);
            
            if (result && result.length > 0) {
                // NEW INTERVIEWS CREATED SUCCESSFULLY
                console.log('✅ NEW INTERVIEWS CREATED SUCCESSFULLY');
                console.log(`Created ${result.length} new interview records`);
                
                // Show success toast
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Interview Records Created',
                        message: `Successfully created ${result.length} interview record(s)`,
                        variant: 'success'
                    })
                );
                
                this.processCandidates(result);
            } else {
                // CREATION FAILED OR RETURNED NO DATA
                console.error('❌ Interview creation failed - no records returned');
                this.hasError = true;
                this.errorMessage = 'Failed to create interview records';
                this.isLoading = false;
            }
        })
        .catch(error => {
            console.error('❌ Error in createInterviewsAndGetCandidates:', error);
            this.hasError = true;
            this.errorMessage = error.body?.message || 'Failed to create interview records';
            this.isLoading = false;
        });
    }

    /* ========================
    Common Processing Method
    ========================= */
    processCandidates(candidatesData) {
        console.log('=== STEP 3: Processing candidate data ===');
        console.log('Source:', candidatesData[0]?.interviewId ? 
                   'Existing interviews' : 'Newly created interviews');
        
        this.candidates = candidatesData.map(c => ({
            ...c,
            feedbackList: [],
            isShortlisted: false,
            isDisabled: false
        }));

        // Check for shortlisted candidates
        return getShortlistedCandidates({ jobId: this.jobId })
            .then(shortlistedIds => {
                console.log('Shortlisted IDs:', shortlistedIds);
                
                if (shortlistedIds && shortlistedIds.length > 0) {
                    this.candidates = this.candidates.map(candidate => {
                        const alreadyShortlisted = shortlistedIds.includes(candidate.recordId);
                        return {
                            ...candidate,
                            isShortlisted: alreadyShortlisted,
                            isDisabled: alreadyShortlisted
                        };
                    });
                }
                
                // Update pagination
                this.totalPages = Math.ceil(this.candidates.length / this.pageSize);
                this.currentPage = 1;
                this.updatePagination();
                this.isLoading = false;
                
                console.log('=== PROCESSING COMPLETE ===');
                console.log(`Total candidates displayed: ${this.candidates.length}`);
            })
            .catch(error => {
                console.error('Error checking shortlisted candidates:', error);
                // Still show candidates even if shortlist check fails
                this.totalPages = Math.ceil(this.candidates.length / this.pageSize);
                this.currentPage = 1;
                this.updatePagination();
                this.isLoading = false;
            });
    }

        get hasCandidates() {
            return this.candidates && this.candidates.length > 0;
        }

        get candidateCount() {
            return this.candidates ? this.candidates.length : 0;
        }


        get currentDate() {
            return new Date().toLocaleDateString('en-US', {
                year: 'numeric',
                month: 'long',
                day: 'numeric',
                hour: '2-digit',
                minute: '2-digit'
            });
        }

        //Pagination//
        get isFirstPage() {
        return this.currentPage === 1;
        }

        get isLastPage() {
        return this.currentPage === this.totalPages;
        }

        /* ========================
        Download CSV
        ========================= */

        downloadAsExcel() {

        if (!this.hasCandidates) {
            console.log('No candidates to download');
            return;
        }

        const headers = [
            'ID', 'Name', 'Email', 'Phone', 'Location',
            'Rate', 'Notice Period',
            'Skills', 'Source', 'Date Added'
        ];

        const rows = this.candidates.map(c => [
            c.id ?? '',
            c.name ?? '',
            c.email ?? '',
            c.phone ?? '',
            c.currentLocation ?? '',
            c.Rate ?? '',
            
            c.noticePeriod ?? '',
            c.skills ?? '',
            c.source ?? '',
            c.createdDate ?? ''
        ]);

        const csvContent =
            '\uFEFF' +
            [
                headers.join(','),
                ...rows.map(row =>
                    row.map(cell =>
                        `"${String(cell).replace(/"/g, '""')}"`
                    ).join(',')
                )
            ].join('\n');

        const encodedUri =
            'data:text/csv;charset=utf-8,' +
            encodeURIComponent(csvContent);

        const link = document.createElement('a');
        link.href = encodedUri;
        link.download =
            `Candidates_${new Date().toISOString().split('T')[0]}.csv`;

        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);

        console.log('Download triggered');
    }


        /* ========================
        Shortlist Handling
        ========================= */

        handleShortlistChange(event) {
            const candidateId = event.currentTarget.name;
            const isChecked = event.target.checked;

            if (isChecked) {
                if (!this.shortlistedCandidateIds.includes(candidateId)) {
                    this.shortlistedCandidateIds = [
                        ...this.shortlistedCandidateIds,
                        candidateId
                    ];
                }
            } else {
                this.shortlistedCandidateIds =
                    this.shortlistedCandidateIds.filter(id => id !== candidateId);
            }
        }

        /* ========================
        Resume Download
        ========================= */

        handleDownload(event) {
            const recordId = event.currentTarget.dataset.id;

            const candidate = this.candidates.find(
                c => c.recordId === recordId
            );

            if (!candidate || !candidate.resumeLink) {
                this.hasError = true;
                this.errorMessage = 'Resume is not available for this candidate';

                setTimeout(() => {
                    this.hasError = false;
                    this.errorMessage = '';
                }, 3000);

                return;
            }

            window.open(candidate.resumeLink, '_blank');
        }

        /* ========================
        Feedback Handling
        ========================= */

        handleFeedback(event) {
            const recordId = event.currentTarget.dataset.id;

            const selectedCandidate = this.candidates.find(
                cand => String(cand.recordId) === String(recordId)
            );

            if (!selectedCandidate) return;

            this.selectedCandidateId = recordId;
            this.selectedFeedbackList =
                selectedCandidate.feedbackList
                    ? [...selectedCandidate.feedbackList]
                    : [];

            this.showFeedbackModal = true;
        }

        closeFeedbackModal() {
            this.showFeedbackModal = false;
        }

        handleFeedbackSaved(event) {
            const { candidateId, feedbackList, action } = event.detail;

            this.candidates = this.candidates.map(candidate => {
                if (candidate.recordId === candidateId) {
                    return { ...candidate, feedbackList: feedbackList };
                }
                return candidate;
            });

            this.selectedFeedbackList = [...feedbackList];

            this.dispatchEvent(
                new ShowToastEvent({
                    title: action === 'delete' ? 'Deleted' : 'Success',
                    message:
                        action === 'delete'
                            ? 'Feedback deleted successfully.'
                            : 'Feedback added successfully.',
                    variant: 'success'
                })
            );
        }
        //Update Pagination//
        updatePagination() {
        const start = (this.currentPage - 1) * this.pageSize;
        const end = start + this.pageSize;

        this.paginatedCandidates = this.candidates.slice(start, end);
    }

        /* ========================
        Submit Handling
        ========================= */

        handleSubmit() {

            const hasFeedback = this.candidates.some(
                candidate =>
                    candidate.feedbackList &&
                    candidate.feedbackList.length > 0
            );

            if (
                this.shortlistedCandidateIds.length === 0 &&
                !hasFeedback
            ) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Nothing to Submit',
                        message:
                            'Please shortlist a candidate or provide feedback.',
                        variant: 'warning'
                    })
                );
                return;
            }

            const feedbackMap = {};

            this.candidates.forEach(candidate => {
                if (
                    candidate.feedbackList &&
                    candidate.feedbackList.length > 0
                ) {
                    feedbackMap[candidate.recordId] =
                        candidate.feedbackList.map(fb => fb.comment);
                }
            });

            let promiseChain = Promise.resolve();

            if (Object.keys(feedbackMap).length > 0) {
                promiseChain = promiseChain.then(() =>
                    saveCandidateFeedback({
                        candidateFeedbackMap: feedbackMap,
                        jobId: this.jobId
                    })
                );
            }

            if (this.shortlistedCandidateIds.length > 0) {
                promiseChain = promiseChain.then(() =>
                    updateInterviewStatusToShortlisted({
                        candidateIds: this.shortlistedCandidateIds,
                        jobId: this.jobId
                    })
                );
            }

            promiseChain
                .then(() => {
                    this.message = 'Submission completed successfully';
                    this.showSuccess = true;
                    this.showError = false;

                    this.candidates = this.candidates.map(candidate => {

                        if (this.shortlistedCandidateIds.includes(candidate.recordId)) {
                            return {
                                ...candidate,
                                isShortlisted: true,
                                isDisabled: true
                            };
                        }

                        return candidate;
                    });

                    this.shortlistedCandidateIds = [];

                    setTimeout(() => {
                        this.showSuccess = false;
                        this.message = '';
                    }, 3000);
                })
                .catch(error => {
                    this.message =
                        error.body?.message || 'Something went wrong';
                    this.showError = true;
                    this.showSuccess = false;

                    setTimeout(() => {
                        this.showError = false;
                        this.message = '';
                    }, 3000);
                });
        }

        /* ========================
        Preview Handling
        ========================= */

        handlePreview(event) {
            const recordId = event.currentTarget.dataset.id;
            this.previewCandidateId = recordId;
            this.showPreviewModal = true;
        }
        handleCloseModal() {
        this.isModalOpen = false;
        }
    ///  Pagination Handling//
    handleNext() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.updatePagination();
        }
    }

    handlePrevious() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.updatePagination();
        }
    }

    }