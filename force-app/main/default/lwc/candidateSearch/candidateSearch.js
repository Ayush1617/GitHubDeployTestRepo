/**
 * @File Name      : CandidateSearch.js
 * @Description    : LWC component that provides advanced search functionality for candidates. 
 * @Author         : Yuvraj Singh
 * @Last Modified By : Yuvraj Singh
 * @Last Modified On : September 23, 2025
 * @Modification Log : Refactored for consistency (skills case, Any vs All, duplicate getter, input parsing)
 * -------------------------------------------------------------------------------
 * Ver   | Date           | Author             | Modification
 * -------------------------------------------------------------------------------
 * 1.02  | Sep 23, 2025   | Yuvraj Singh       | Refactored for consistency
 * 1.01  | Aug 25, 2025   | Yuvraj Singh       | Added error toast handling
 * 1.00  | Aug 19, 2025   | Yuvraj Singh       | Initial Version 
 */

import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchCandidates from '@salesforce/apex/CandidateSearchController.searchCandidates';
import fetchSkills from '@salesforce/apex/LightcastSkillService.fetchSkills';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import CANDIDATE_OBJECT from '@salesforce/schema/Contact';
import GENDER_FIELD from '@salesforce/schema/Contact.Gender__c';
import NOTICE_FIELD from '@salesforce/schema/Contact.Notice_Period__c';

export default class CandidateSearch extends LightningElement {
    @track candidates = [];
    @track searchFlag = false;
    @track skills = [];
    @track currentSkillInput = '';
    @track gender = 'Any';
    @track noticePeriod = 'Any';
    @track error;
    @track isLoading = false;
    @track extendedFlag = false;
    @track suggestions = [];
    @track isSkillLoading = false;

    skillCache = new Map();

    @track searchParams = {
        minExperience: null,
        maxExperience: null,
        minSalary: null,
        maxSalary: null,
        phone: '',
        currentLocation: '',
        gender: 'Any',
        noticePeriod: 'Any',
        highestQualification: '',
        instituteName: '',
        languageKnown: '',
        preferredLocation: '',
        expectedCTC: null,
        canJoinIn: null
    };
    

    //===========================Picklist Options===================================
    @wire(getObjectInfo, { objectApiName: CANDIDATE_OBJECT })
    objectInfo;

    @wire(getPicklistValues, { recordTypeId: '$objectInfo.data.defaultRecordTypeId', fieldApiName: GENDER_FIELD })
    wiredGenderValues({ data, error }) {
        if (data) {
            this.genderOptions = [{ label: 'Any', value: 'Any' }, ...data.values];
        } else if (error) {
            console.error('Error fetching Gender picklist values:', error);
        }
    }

    @wire(getPicklistValues, { recordTypeId: '$objectInfo.data.defaultRecordTypeId', fieldApiName: NOTICE_FIELD })
    wiredNoticeValues({ data, error }) {
        if (data) {
            this.noticeOptions = [{ label: 'Any', value: 'Any' }, ...data.values];
        } else if (error) {
            console.error('Error fetching Notice Period picklist values:', error);
        }
    }

    //=========================Getter For CSS=======================================
    get containerClass() {
        return this.searchFlag ? 'container' : 'centered-container';
    }

    get searchPanelClass() {
        return this.searchFlag ? 'search-panel scrollable-filter-panel' : 'centered-search-panel';
    }

    //==========================Methods=======================================
    handleSkillInputChange(event) {
        this.currentSkillInput = event.target.value;

        if (this.currentSkillInput.length < 3) {
            this.suggestions = [];
            return;
        }

       
        this.fetchSkillSuggestions(this.currentSkillInput);
        
    }

    // fetchSkillSuggestions(query) {
    //     this.isSkillLoading = true; 
    //     fetchSkills({ query })
    //         .then(result => {
    //             this.suggestions = result || [];
    //         })
    //         .catch(error => {
    //             console.error('Error fetching skill suggestions:', error);
    //             this.suggestions = [];
    //         })
    //         .finally(() => {
    //             this.isSkillLoading = false;  // hide spinner
    //         });
    // }

    fetchSkillSuggestions(query) {
        
        if (this.skillCache.has(query)) {
            this.suggestions = this.skillCache.get(query);
            return;
        }

        this.isSkillLoading = true;
        fetchSkills({ query })
            .then(result => {
                this.suggestions = result || [];
                
                this.skillCache.set(query, this.suggestions);
            })
            .catch(error => {
                console.error('Error fetching skill suggestions:', error);
                this.suggestions = [];
            })
            .finally(() => {
                this.isSkillLoading = false;
            });
    }

    handleSuggestionClick(event) {
        const selectedSkill = event.target.dataset.skill;
        const normalized = selectedSkill.toLowerCase();
        if (selectedSkill && !this.skills.includes(normalized)) {
            this.skills = [...this.skills, normalized];
        }
        this.currentSkillInput = '';
        this.suggestions = [];
    }

    handleSkillKeyDown(event) {
        if (event.key === 'Enter') {
            event.preventDefault();
            const trimmedSkill = this.currentSkillInput.trim();
            const normalized = trimmedSkill.toLowerCase();
            if (trimmedSkill && !this.skills.includes(normalized)) {
                this.skills = [...this.skills, normalized];
            }
            this.currentSkillInput = '';
            this.suggestions = [];
        }
    }

    removeSkill(event) {
        const skillToRemove = event.target.dataset.skill.toLowerCase();
        this.skills = this.skills.filter(skill => skill !== skillToRemove);
    }

    handleInputChange(event) {
        const field = event.target.name;
        let value = event.target.value;

        const numericFields = [
            'phone',
            'minExperience',
            'maxExperience',
            'minSalary',
            'maxSalary',
            'expectedCTC',
            'canJoinIn'
        ];

        if (numericFields.includes(field)) {
            const inputCmp = event.target;
            const numericValue = Number(value);

            if (value !== "" && !isNaN(numericValue)) {
                if (numericValue < 0) {
                    inputCmp.setCustomValidity(field + ' cannot be negative');
                    inputCmp.reportValidity();
                    return;
                } else {
                    inputCmp.setCustomValidity("");
                    inputCmp.reportValidity();
                    value = numericValue;
                }
            } else {
                inputCmp.setCustomValidity("");
                inputCmp.reportValidity();
                value = null;
            }
        }

        if (field === 'skillInput') {
            this.currentSkillInput = value;
        } else {
            this.searchParams = { ...this.searchParams, [field]: value };
            if (field === 'gender') this.gender = value;
            if (field === 'noticePeriod') this.noticePeriod = value;
        }
    }

    get isSearchDisabled() {
        const hasSkills = this.skills.length > 0;
        const hasParams = Object.entries(this.searchParams).some(([key, val]) => {
            if (key === 'gender' || key === 'noticePeriod') {
                return val && val !== 'Any';
            }
            if (typeof val === 'string') {
                return val.trim() !== '';
            }
            if (typeof val === 'number') {
                return !isNaN(val);
            }
            return val !== null && val !== undefined;
        });
        return !(hasSkills || hasParams);
    }
    handleReset() {
        // Clear skills
        this.skills = [];
        this.currentSkillInput = '';
        this.suggestions = [];

        // Reset search parameters
        this.searchParams = {
            minExperience: null,
            maxExperience: null,
            minSalary: null,
            maxSalary: null,
            phone: '',
            currentLocation: '',
            gender: 'Any',
            noticePeriod: 'Any',
            highestQualification: '',
            instituteName: '',
            languageKnown: '',
            preferredLocation: '',
            expectedCTC: null,
            canJoinIn: null
        };

        // Reset picklist fields
        this.gender = 'Any';
        this.noticePeriod = 'Any';
    }
    handleSearch() {
        this.isLoading = true;

        searchCandidates({
            params: {
                skillQuery: this.skills.join(','),
                minExperience: this.searchParams.minExperience,
                maxExperience: this.searchParams.maxExperience,
                minSalary: this.searchParams.minSalary,
                maxSalary: this.searchParams.maxSalary,
                phone: this.searchParams.phone,
                currentLocation: this.searchParams.currentLocation,
                gender: this.searchParams.gender,
                noticePeriod: this.searchParams.noticePeriod,
                highestQualification: this.searchParams.highestQualification,
                instituteName: this.searchParams.instituteName,
                languageKnown: this.searchParams.languageKnown,
                preferredLocation: this.searchParams.preferredLocation,
                expectedCTC: this.searchParams.expectedCTC,
                canJoinIn: this.searchParams.canJoinIn
            }
        })
            .then(result => {
                this.candidates = result;
                this.error = undefined;
            })
            .catch(error => {
                this.error = error;
                this.candidates = [];
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Search Failed',
                        message: error.body ? error.body.message : 'An unexpected error occurred',
                        variant: 'error',
                        mode: 'sticky'
                    })
                );
            })
            .finally(() => {
                this.isLoading = false;
            });

        this.searchFlag = true;
        this.extendedFlag = true;
    }
}