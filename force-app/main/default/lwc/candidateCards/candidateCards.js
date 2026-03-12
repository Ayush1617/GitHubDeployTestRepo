import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import LINKEDIN_LOGO from '@salesforce/resourceUrl/LinkedIn_Logo';
import getCandidateProfilePhotoBase64 from '@salesforce/apex/CandidatePhotoService.getCandidateProfilePhotoBase64';

const photoCache = new Map();

export default class CandidateCards extends NavigationMixin(LightningElement) {
    _candidates;
    selectedCandidateIds = [];
    @track showShortlistButton = false;
    @track shortlistButtonVariant = 'neutral';
    @api searchFlag = false;
    @track isLoading = false;
    linkedInLogo = LINKEDIN_LOGO;
    showSubmitToClient = false;
    @api searchSkills = [];
    @track sortOption = 'matched';

    get sortOptions() {
        return [
            { label: 'Most Matched Profile', value: 'matched' },
            { label: 'Recently Updated', value: 'recent' },
            { label: 'Notice Period (Immediate Joiner first)', value: 'notice' },
            { label: 'Candidate Rating (Highest to Lowest)', value: 'rating' }
        ];
    }

    // -----------------------------
    // Setter / Getter for candidates
    // -----------------------------
    @api
    set candidates(value) {
        if (value && Array.isArray(value)) {
            this._candidates = value.map(c => ({
                ...c,
                recordUrl: `/lightning/r/Contact/${c.Id}/view`,
                linkedInUrl: c.LinkedIn_Profile__c,
                linkedInClass: c.LinkedIn_Profile__c
                    ? 'linkedin-icon'
                    : 'linkedin-icon linkedin-disabled',
                linkedInTitle: c.LinkedIn_Profile__c
                    ? 'View LinkedIn Profile'
                    : 'No LinkedIn Profile',
                photoUrl: photoCache.get(c.Id) || null
            }));

            this.loadCandidatePhotos();
            this._candidates = this.getSortedCandidates([...this._candidates]);
        }
    }

    get candidates() {
        return this._candidates;
    }

    get hasCandidates() {
        return this._candidates && this._candidates.length > 0;
    }

    // -----------------------------
    // Load profile photos via Apex
    // -----------------------------
    async loadCandidatePhotos() {
        const uncached = this._candidates?.filter(c => !photoCache.has(c.Id)) || [];

        for (const candidate of uncached) {
            try {
                const base64 = await getCandidateProfilePhotoBase64({ candidateId: candidate.Id });
                if (base64) {
                    const photo = 'data:image/webp;base64,' + base64;
                    photoCache.set(candidate.Id, photo);
                    candidate.photoUrl = photo;
                } else {
                    candidate.photoUrl = null;
                }
            } catch (err) {
                console.error(`Error fetching photo for candidate ${candidate.Id}`, err);
                candidate.photoUrl = null;
            }
        }

        // Force re-render
        this._candidates = [...this._candidates];
    }

    // -----------------------------
    // Checkbox selection
    // -----------------------------
    handleCheckboxChange(event) {
        const candidateId = event.target.dataset.id;
        const isChecked = event.target.checked;

        if (isChecked && !this.selectedCandidateIds.includes(candidateId)) {
            this.selectedCandidateIds.push(candidateId);
        } else if (!isChecked) {
            this.selectedCandidateIds = this.selectedCandidateIds.filter(id => id !== candidateId);
        }

        this.showShortlistButton = this.selectedCandidateIds.length > 0;
    }

    // -----------------------------
    // Shortlist modal
    // -----------------------------
    handleShortlist() {
        if (this.selectedCandidateIds.length >= 1) {
            this.isLoading = true;

            //setTimeout(() => {
                this.isLoading = false;
                const jobCard = this.template.querySelector('c-jobposition-card');
                if (jobCard) {
                    jobCard.selectedCandidateIds = [...this.selectedCandidateIds];
                    jobCard.openModal();
                } else {
                    console.error('Job Position Card component not found');
                }
            //}, 1500);
        }
    }

    handlecloseModal() {
        this.showModal = false;
    }

    handleJobAssign() {
        console.log('Shortlisted Candidates:', JSON.stringify(this.selectedCandidateIds));
    }

    get isShortlistDisabled() {
        return !this.showShortlistButton;
    }

    get buttonVariant() {
        return this.isShortlistDisabled ? 'neutral' : 'brand';
    }

    handleLinkedInClick(event) {
        const url = event.currentTarget.dataset.url;
        if (url) {
            window.open(url, '_blank');
        } else {
            console.log('No LinkedIn URL available for this candidate.');
        }
    }

    // -----------------------------
    // Sorting
    // -----------------------------
    handleSortChange(event) {
        this.sortOption = event.detail.value;
        this.sortCandidates();
    }

    sortCandidates() {
        this._candidates = this.getSortedCandidates([...this._candidates]);
    }

    getSortedCandidates(list) {
        switch (this.sortOption) {
            case 'matched':
                return list.sort((a, b) => {
                    const aMatch = this.skillMatchCount(a.Skills__c);
                    const bMatch = this.skillMatchCount(b.Skills__c);
                    return bMatch - aMatch;
                });

            case 'recent':
                return list.sort(
                    (a, b) => new Date(b.LastModifiedDate) - new Date(a.LastModifiedDate)
                );

            case 'notice':
                return list.sort(
                    (a, b) =>
                        this.getNoticePeriodValue(a.Notice_Period__c) -
                        this.getNoticePeriodValue(b.Notice_Period__c)
                );

            case 'rating':
                return list.sort(
                    (a, b) =>
                        this.getRatingValue(b.Rating__c) - this.getRatingValue(a.Rating__c)
                );

            default:
                return list;
        }
    }

    // -----------------------------
    // Helpers
    // -----------------------------
    skillMatchCount(candidateSkills) {
        if (!candidateSkills || !this.searchSkills) return 0;
        const lower = candidateSkills.toLowerCase();
        return this.searchSkills.filter(skill => lower.includes(skill.toLowerCase())).length;
    }

    getNoticePeriodValue(notice) {
        const map = {
            'Immediate Joiner': 0,
            'Currently serving Notice Period': 1,
            '7 Days': 2,
            '15 days or less': 3,
            '1 month': 4,
            '45 Days': 5,
            '2 Months': 6,
            '3 Months': 7,
            '--None--': 8
        };
        return map[notice] ?? 9;
    }

    getRatingValue(rating) {
        const map = {
            Excellent: 5,
            Good: 4,
            Average: 3,
            'Below Average': 2,
            'Not Rated': 1,
            '--None--': 0
        };
        return map[rating] ?? 0;
    }

    // -----------------------------
    // Submit to Client Modal
    // -----------------------------
    handleSubmitToCLient() {
        this.showSubmitToClient = true;
        console.log('OUTPUT : ', JSON.stringify(this.selectedCandidateIds));
    }

    closeSubmitToClientModal() {
        this.showSubmitToClient = false;
    }

    handleExportButtonClick() {
        const exportComp = this.template.querySelector('c-export-to-excel');
        if (exportComp) {
            const candidateIds = this.selectedCandidateIds || [];
            if (candidateIds.length === 0) {
                console.warn('No candidate IDs found for export');
                return;
            }
            exportComp.triggerExport(candidateIds);
        } else {
            console.error('Export component not found!');
        }
    }
}