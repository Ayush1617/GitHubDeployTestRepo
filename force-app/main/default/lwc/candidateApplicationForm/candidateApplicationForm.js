import { LightningElement, track } from 'lwc';
import searchJobPositions from '@salesforce/apex/CandidatePublicController.searchJobPositions';
import getJobDetails from '@salesforce/apex/CandidatePublicController.getJobDetails';
import checkExistingCandidate from '@salesforce/apex/CandidatePublicController.checkExistingCandidate';
import submitCandidateForm from '@salesforce/apex/CandidatePublicController.submitCandidateForm';
import fetchSkills from '@salesforce/apex/LightcastSkillService.fetchSkills';

const MAX_FILE_BYTES = 5 * 1024 * 1024;
const PAGE_SIZE = 10;

export default class CandidateApplicationForm extends LightningElement {

    // ---------- DATA ----------
    @track jobs = [];
    @track loadingJobs = false;
    @track jobsError = '';
    @track noJobsMessage = '';

    @track selectedJob = null;
    currentView = 'LIST';           // 'LIST' | 'DETAIL'
    @track showFormModal = false;

    // ---------- SKILL AUTOCOMPLETE ----------
    @track skillInput = '';
    @track skillSuggestions = [];
    @track selectedSkills = [];

    @track softSkillInput = '';
    @track softSkillSuggestions = [];
    @track selectedSoftSkills = [];


    debounceTimeout;


    // ---------- Filters / pagination ----------
    searchKey = '';
    cityFilter = '';
    experienceRange = 'ANY'; // ANY | 0-1 | 1-3 | 3-5 | 5-10 | 10+
    minExperience = null;
    maxExperience = null;

    pageNumber = 1;
    pageSize = PAGE_SIZE;
    totalRecords = 0;

    experienceOptions = [
        { label: 'Any', value: 'ANY' },
        { label: '0 – 1 years', value: '0-1' },
        { label: '1 – 3 years', value: '1-3' },
        { label: '3 – 5 years', value: '3-5' },
        { label: '5 – 10 years', value: '5-10' },
        { label: '10+ years', value: '10+' }
    ];

    // ---------- FORM DATA ----------
    @track formData = {
        firstName: '',
        lastName: '',
        email: '',
        phone: '',
        experienceYears: null,
        skills: '',
        currentCompany: '',
        currentLocation: '',
        jobTitle: '',
        expectedSalary: null,
        noticePeriod: ''
    };

    @track resume = {
        fileName: '',
        contentType: '',
        base64Body: ''
    };

    @track isSubmitting = false;
    @track showSuccess = false;
    @track successMessage = '';
    @track globalErrorMessage = '';

    // candidate detection
    @track isExistingCandidate = false;
    @track existingCandidateId = null;
    @track emailCheckMessage = '';

    // list of jobIds applied in this session
    appliedJobIds = [];

    // notice options
    noticeOptions = [
        { label: 'Immediate Joiner', value: 'Immediate Joiner' },
        { label: '7 Days', value: '7 Days' },
        { label: '15 days or less', value: '15 days or less' },
        { label: '45 Days', value: '45 Days' },
        { label: '1 month', value: '1 month' },
        { label: '2 month', value: '2 month' },
        { label: '3 month', value: '3 month' }
    ];

    // ---------- GETTERS ----------
    get isListView() {
        return this.currentView === 'LIST';
    }

    get isDetailView() {
        return this.currentView === 'DETAIL';
    }

    get noticeOptionsComputed() {
        return this.noticeOptions.map(opt => ({
            ...opt,
            selected: opt.value === this.formData.noticePeriod
        }));
    }
    get experienceOptionsComputed() {
        return this.experienceOptions.map(opt => ({
            ...opt,
            selected: opt.value === this.experienceRange
        }));
    }

    get appliedForSelectedJob() {
        return this.selectedJob
            ? this.appliedJobIds.includes(this.selectedJob.Id)
            : false;
    }

    get applyButtonLabel() {
        return this.appliedForSelectedJob ? 'Applied' : 'Apply';
    }

    get applyButtonClass() {
        return this.appliedForSelectedJob
            ? 'btn-primary btn-disabled'
            : 'btn-primary';
    }

    // Pagination computed
    get totalPages() {
        return this.totalRecords
            ? Math.ceil(this.totalRecords / this.pageSize)
            : 1;
    }

    get disablePrev() {
        return this.pageNumber <= 1;
    }

    get disableNext() {
        return this.pageNumber >= this.totalPages;
    }

    get firstRecordIndex() {
        if (!this.totalRecords) return 0;
        return (this.pageNumber - 1) * this.pageSize + 1;
    }

    get lastRecordIndex() {
        if (!this.totalRecords) return 0;
        return Math.min(
            this.firstRecordIndex + this.jobs.length - 1,
            this.totalRecords
        );
    }

    // NOTE: used in template: isJobApplied(job.Id) – still available if needed
    isJobApplied(jobId) {
        return this.appliedJobIds.includes(jobId);
    }

    // ---------- LIFECYCLE ----------
    connectedCallback() {
        this.loadJobs();
    }

    // -------------------------------------------------
    //               JOB LIST (SEARCH + FILTER)
    // -------------------------------------------------
    updateExperienceBounds() {
        this.minExperience = null;
        this.maxExperience = null;

        switch (this.experienceRange) {
            case '0-1':
                this.minExperience = 0;
                this.maxExperience = 1;
                break;
            case '1-3':
                this.minExperience = 1;
                this.maxExperience = 3;
                break;
            case '3-5':
                this.minExperience = 3;
                this.maxExperience = 5;
                break;
            case '5-10':
                this.minExperience = 5;
                this.maxExperience = 10;
                break;
            case '10+':
                this.minExperience = 10;
                this.maxExperience = null;
                break;
            default:
                // ANY
                this.minExperience = null;
                this.maxExperience = null;
        }
    }

    loadJobs() {
        console.log(' loadJobs() called');
        console.log('Filters:', {
            searchKey: this.searchKey,
            cityFilter: this.cityFilter,
            experienceRange: this.experienceRange,
            minExperience: this.minExperience,
            maxExperience: this.maxExperience,
            pageNumber: this.pageNumber
        });

        this.loadingJobs = true;
        this.jobsError = '';
        this.noJobsMessage = '';

        this.updateExperienceBounds();

        console.log(' After updateExperienceBounds():', {
            minExperience: this.minExperience,
            maxExperience: this.maxExperience
        });

        searchJobPositions({
            pageNumber: this.pageNumber,
            pageSize: this.pageSize,
            searchKey: this.searchKey,
            cityFilter: this.cityFilter,
            minExperience: this.minExperience,
            maxExperience: this.maxExperience
        })
            .then(res => {
                console.log(' Apex Response:', JSON.parse(JSON.stringify(res)));

                this.jobs = (res && res.jobs) ? res.jobs : [];
                this.totalRecords = res ? res.totalRecords : 0;
                console.log('this.jobs  : ',JSON.stringify(this.jobs ));

                console.log(' parsed:', {
                    jobsCount: this.jobs.length,
                    totalRecords: this.totalRecords,
                    pageNumber: this.pageNumber,
                    totalPages: this.totalPages
                });

                if (!this.jobs.length) {
                    this.noJobsMessage = 'No job positions found for selected filters.';
                }
            })
            .catch(err => {
                console.error(' Apex Error =>', err);
                this.jobsError = 'Unable to load job positions. Please try again later.';
            })
            .finally(() => {
                this.loadingJobs = false;
                console.log('loadJobs() finished, loadingJobs = false');
            });
    }


    // Filters handlers
    handleSearchKeyChange(event) {
        this.searchKey = event.target.value;
        this.pageNumber = 1;
        this.loadJobs();
    }

    handleCityChange(event) {
        this.cityFilter = event.target.value;
        this.pageNumber = 1;
        this.loadJobs();
    }

    handleExperienceChange(event) {
        this.experienceRange = event.target.value;
        this.pageNumber = 1;
        this.loadJobs();
    }

    handleResetFilters() {
        this.searchKey = '';
        this.cityFilter = '';
        this.experienceRange = 'ANY';
        this.minExperience = null;
        this.maxExperience = null;
        this.pageNumber = 1;
        this.loadJobs();
    }

    // Pagination click handlers
    handlePrevPage() {
        if (this.pageNumber > 1) {
            this.pageNumber -= 1;
            this.loadJobs();
        }
    }

    handleNextPage() {
        if (this.pageNumber < this.totalPages) {
            this.pageNumber += 1;
            this.loadJobs();
        }
    }

    // --------------------------------------------
    // SKILL AUTOCOMPLETE
    // --------------------------------------------

    handleSkillTyping(event) {
        this.skillInput = event.target.value;

        clearTimeout(this.debounceTimeout);

        if (this.skillInput.length < 2) {
            this.skillSuggestions = [];
            return;
        }

        this.debounceTimeout = setTimeout(() => {
            fetchSkills({ query: this.skillInput })
                .then(result => {
                    this.skillSuggestions = result;
                })
                .catch(error => {
                    console.error('Skill search error:', error);
                });
        }, 400);
    }

    handleSkillSelect(event) {
        const value = event.target.dataset.value;

        if (value && !this.selectedSkills.includes(value)) {
            this.selectedSkills = [...this.selectedSkills, value];
        }

        this.skillInput = '';
        this.skillSuggestions = [];
    }

    handleSkillKeyDown(event) {
        if (event.key === 'Enter') {
            event.preventDefault();

            const value = this.skillInput.trim();

            if (value && !this.selectedSkills.includes(value)) {
                this.selectedSkills = [...this.selectedSkills, value];
            }

            this.skillInput = '';
            this.skillSuggestions = [];
        }
    }

    removeSkill(event) {
        const value = event.target.dataset.value;
        this.selectedSkills =
            this.selectedSkills.filter(skill => skill !== value);
    }


    handleSoftSkillTyping(event) {
        this.softSkillInput = event.target.value;

        if (this.softSkillInput.length < 2) {
            this.softSkillSuggestions = [];
            return;
        }

        fetchSkills({ query: this.softSkillInput })
            .then(result => {
                this.softSkillSuggestions = result;
            })
            .catch(error => {
                console.error(error);
            });
    }

    handleSoftSkillSelect(event) {
        const value = event.target.dataset.value;

        if (value && !this.selectedSoftSkills.includes(value)) {
            this.selectedSoftSkills = [...this.selectedSoftSkills, value];
        }

        this.softSkillInput = '';
        this.softSkillSuggestions = [];
    }

    handleSoftSkillKeyDown(event) {
        if (event.key === 'Enter') {
            event.preventDefault();

            const value = this.softSkillInput.trim();

            if (value && !this.selectedSoftSkills.includes(value)) {
                this.selectedSoftSkills = [...this.selectedSoftSkills, value];
            }

            this.softSkillInput = '';
            this.softSkillSuggestions = [];
        }
    }

    removeSoftSkill(event) {
        const value = event.target.dataset.value;
        this.selectedSoftSkills =
            this.selectedSoftSkills.filter(skill => skill !== value);
    }


    // ---------- NAVIGATION ----------
    openJobDetails(event) {
        const jobId = event.currentTarget.dataset.id;

        this.showSuccess = false;
        this.successMessage = '';
        this.globalErrorMessage = '';

        getJobDetails({ jobId })
            .then(job => {
                this.selectedJob = job;
                this.currentView = 'DETAIL';
            })
            .catch(() => {
                this.globalErrorMessage = 'Unable to load job details.';
            });
    }

    backToList() {
        this.currentView = 'LIST';
        this.selectedJob = null;
        this.showSuccess = false;
        this.successMessage = '';
        this.globalErrorMessage = '';
        this.loadJobs();
    }

    // ---------- APPLY MODAL ----------
    openApplyModal() {
        if (this.appliedForSelectedJob) {
            return;
        }

        // Every time we open form: fresh form + fresh candidate state
        this.formData = {
            firstName: '',
            lastName: '',
            email: '',
            phone: '',
            experienceYears: null,
            skills: '',
            currentLocation: '',
            currentCompany: '',
            jobTitle: '',
            expectedSalary: null,
            noticePeriod: ''
            
        };
        this.resume = { fileName: '', contentType: '', base64Body: '' };
        this.isExistingCandidate = false;
        this.existingCandidateId = null;
        this.emailCheckMessage = '';
        this.globalErrorMessage = '';

        this.showFormModal = true;

        this.selectedSkills = [];
        this.skillInput = '';
        this.skillSuggestions = [];

        this.selectedSoftSkills = [];
        this.softSkillInput = '';
        this.softSkillSuggestions = [];

    }

    closeFormModal() {
        this.showFormModal = false;
        this.globalErrorMessage = '';
    }

    stopModalBubble(event) {
        event.stopPropagation();
    }

    // ---------- FORM / EMAIL CHECK ----------
    handleInputChange(e) {
        const field = e.target.name;
        let value = e.target.value;

        if (['experienceYears', 'expectedSalary'].includes(field)) {
            value = value ? Number(value) : null;
        }


        // reset messages when email changes
        if (field === 'email') {
            this.emailCheckMessage = '';
            this.isExistingCandidate = false;
            this.existingCandidateId = null;
        }

        this.formData = { ...this.formData, [field]: value };

        console.log('this.formData  : ',JSON.stringify(this.formData ));
    }

    async handleEmailBlur(e) {
        const email = (e.target.value || '').trim();

        if (!email) {
            this.emailCheckMessage = '';
            this.isExistingCandidate = false;
            this.existingCandidateId = null;
            return;
        }

        if (!email.includes('@')) {
            this.emailCheckMessage = 'Please enter a valid email address.';
            this.isExistingCandidate = false;
            this.existingCandidateId = null;
            return;
        }

        try {
            const res = await checkExistingCandidate({ email, phone: null });

            if (res && res.Id) {
                this.isExistingCandidate = true;
                this.existingCandidateId = res.Id;

                 // 🔥 SET SELECTED SKILLS ARRAY
                this.selectedSkills = res.Skills__c
                    ? res.Skills__c.split(',').map(s => s.trim())
                    : [];

                // 🔥 Soft Skills
                this.selectedSoftSkills = res.Industrial_Knowledge__c
                    ? res.Industrial_Knowledge__c.split(',').map(s => s.trim())
                    : [];

                this.formData = {
                    ...this.formData,
                    firstName: res.FirstName || '',
                    lastName: res.LastName || '',
                    email: res.Email || email,
                    phone: res.Phone || '',
                    experienceYears: res.Experience_Year__c || null,
                    currentCompany: res.Current_Company__c || '',
                    currentLocation: res.Current_Location__c || '',
                    currentCTC: res.Current_CTC__c || null,
                    jobTitle: res.Designation__c || '',
                    expectedSalary: res.Expected_CTC__c || null,
                    noticePeriod: res.Notice_Period__c || ''
                };
                console.log(' this.formData : ', this.formData);

                this.emailCheckMessage = 'Existing Candidate Found.';
            } else {
                this.isExistingCandidate = false;
                this.existingCandidateId = null;
                this.emailCheckMessage = 'New candidate — please continue filling the form.';
            }
        } catch  {
            this.emailCheckMessage = 'Error while checking candidate.';
        }
    }

    // ---------- FILE ----------
    handleFileChange(e) {
        const file = e.target.files[0];
        if (!file) return;

        if (file.size > MAX_FILE_BYTES) {
            this.globalErrorMessage = 'File size exceeds 5 MB.';
            return;
        }

        const ext = file.name.split('.').pop().toLowerCase();
        if (!['pdf', 'doc', 'docx'].includes(ext)) {
            this.globalErrorMessage = 'Allowed formats are PDF, DOC, DOCX.';
            return;
        }

        this.resume.fileName = file.name;
        this.resume.contentType = file.type;

        const reader = new FileReader();
        reader.onload = () => {
            this.resume.base64Body = reader.result.split(',')[1];
        };
        reader.readAsDataURL(file);
    }

    removeResume() {
        this.resume = { fileName: '', contentType: '', base64Body: '' };
        const input = this.template.querySelector('input[type="file"]');
        if (input) {
            input.value = '';
        }
    }

    // ---------- VALIDATION ----------
    validateClientSide() {
        if (!this.formData.firstName ||
            !this.formData.lastName ||
            !this.formData.email ||
            !this.formData.phone) {

            this.globalErrorMessage =
                'First Name, Last Name, Email and Phone are required.';
            return false;
        }
        return true;
    }

    // ---------- SUBMIT ----------
    async handleSubmit(e) {
        e.preventDefault();
        this.globalErrorMessage = '';

        if (!this.validateClientSide()) {
            return;
        }

        const jobId = this.selectedJob ? this.selectedJob.Id : null;

        this.isSubmitting = true;
    console.log('this.formData@@@@@ : ',JSON.stringify(this.formData));

        try {
            const resp = await submitCandidateForm({
                firstName: this.formData.firstName,
                lastName: this.formData.lastName,
                email: this.formData.email,
                phone: this.formData.phone,
                experienceYears: this.formData.experienceYears,
                skills: this.selectedSkills.join(', '),
                softSkills: this.selectedSoftSkills.join(', '),
                currentCompany: this.formData.currentCompany,
                jobTitle: this.formData.jobTitle,
                expectedSalary: this.formData.expectedSalary,
                noticePeriod: this.formData.noticePeriod,
                resumeFileName: this.resume.fileName,
                resumeContentType: this.resume.contentType,
                resumeBase64Body: this.resume.base64Body,
                jobId: jobId,
                currentLocation: this.formData.currentLocation,
                currentCTC: this.formData.currentCTC
            });

            console.log('Selected Skills:', this.selectedSkills);
            console.log('industrial Skills:', this.selectedSoftSkills);

            console.log('resp : ',JSON.stringify(resp));

            if (resp && resp.success) {
                // mark this job as applied for this session
                if (jobId && !this.appliedJobIds.includes(jobId)) {
                    this.appliedJobIds = [...this.appliedJobIds, jobId];
                }

                this.showFormModal = false;
                this.showSuccess = true;
                this.successMessage =
                    resp.message || 'Application submitted successfully.';

                // only clear resume; form anyway reset next time
                this.resume = { fileName: '', contentType: '', base64Body: '' };
            } else {
                this.globalErrorMessage = (resp && resp.message)
                    ? resp.message
                    : 'Submission failed.';
                    console.log(' this.globalErrorMessage@@@ : ', this.globalErrorMessage);
            }
        } catch (error) {
            console.error('❌ submitCandidateForm error:', error);
            this.globalErrorMessage = 'Error during submission.';
        } finally {
            this.isSubmitting = false;
        }
    }
}