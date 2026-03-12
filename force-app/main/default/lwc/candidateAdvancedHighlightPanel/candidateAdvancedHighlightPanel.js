import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import NAME from '@salesforce/schema/Contact.Name';
import EMAIL from '@salesforce/schema/Contact.Email';
import PHONE from '@salesforce/schema/Contact.Phone';
import EXP from '@salesforce/schema/Contact.Total_Experience__c';
import SKILLS from '@salesforce/schema/Contact.Skills__c';
import DESIGNATION from '@salesforce/schema/Contact.Designation__c';
import RATING from '@salesforce/schema/Contact.Rating__c';
import LINKEDIN from '@salesforce/schema/Contact.LinkedIn_Profile__c';
import BILLABLE from '@salesforce/schema/Contact.IsBillable__c';
import RESUME from '@salesforce/schema/Contact.Resume_Link__c';

import getCandidateProfilePhotoBase64 from '@salesforce/apex/CandidatePhotoService.getCandidateProfilePhotoBase64';

const FIELDS = [
    NAME, EMAIL, PHONE,
    EXP, SKILLS, DESIGNATION,
    RATING, LINKEDIN, BILLABLE, RESUME
];


// Client-side photo cache
const photoCache = new Map();

export default class CandidateHighlight extends LightningElement {
    @api recordId;

    photoUrl;




    // ------------------------------
    // Wire for candidate fields
    // ------------------------------
    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    candidate;

    // ------------------------------
    // Wire for candidate photo with cache
    // ------------------------------
    @wire(getCandidateProfilePhotoBase64, { candidateId: '$recordId' })
    wiredPhoto({ data, error }) {
        if (data) {
            // Store in client-side cache if not already
            if (!photoCache.has(this.recordId)) {
                photoCache.set(this.recordId, 'data:image/webp;base64,' + data);
            }
            this.photoUrl = photoCache.get(this.recordId);
        } else if (error) {
            const msg = error?.body?.message || 'Unable to fetch candidate photo.';
            this.showToast('Error loading photo', msg, 'error');
            console.error('Error fetching photo:', JSON.stringify(error));
        }

    }

    // ------------------------------
    // Toast helper
    // ------------------------------
    showToast(title, message, variant = 'error') {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant,
            mode: 'dismissable'
        }));
    }

    // ------------------------------
    // Utility
    // ------------------------------
    formatValue(value) {
        return value ? value : 'N/A';
    }

    // ------------------------------
    // Basic fields
    // ------------------------------
    get name() { return this.formatValue(getFieldValue(this.candidate.data, NAME)); }
    get designation() { return this.formatValue(getFieldValue(this.candidate.data, DESIGNATION)); }
    get experience() { 
        const exp = getFieldValue(this.candidate.data, EXP);
        return exp ? `${exp} yrs experience` : 'N/A';
    }
    get email() { return this.formatValue(getFieldValue(this.candidate.data, EMAIL)); }
    get phone() { return this.formatValue(getFieldValue(this.candidate.data, PHONE)); }
    get rating() { return this.formatValue(getFieldValue(this.candidate.data, RATING)); }

    // Resume & LinkedIn
    get resume() { return getFieldValue(this.candidate.data, RESUME); }
    get linkedin() { return getFieldValue(this.candidate.data, LINKEDIN); }

    get isResumeAvailable() {
        const link = getFieldValue(this.candidate.data, RESUME);
        return !!link;
    }

    get isLinkedinAvailable() {
        const link = getFieldValue(this.candidate.data, LINKEDIN);
        return !!link;
    }

    // Billable
    get billable() { 
        const val = getFieldValue(this.candidate.data, BILLABLE);
        if (val === true) return 'Billable';
        if (val === false) return 'Not Billable';
        return 'N/A';
    }

    // Skills
    get skillsToDisplay() {
        const skills = getFieldValue(this.candidate.data, SKILLS);
        if (!skills) return [];
        return skills.split(',').map(v => v.trim()).slice(0, 3);
    }

    get hasSkills() {
        const s = getFieldValue(this.candidate.data, SKILLS);
        return s && s.trim().length > 0;
    }

    get extraSkillsCount() {
        const skills = getFieldValue(this.candidate.data, SKILLS);
        if (!skills) return 0;
        const arr = skills.split(',');
        return arr.length > 3 ? arr.length - 3 : 0;
    }

    get allSkills() {
    const skills = getFieldValue(this.candidate.data, SKILLS);
    if (!skills) return '';

    const arr = skills.split(',').map(v => v.trim());

    if (arr.length > 3) {
        return arr.slice(3).join(', ');
    }

    return '';
}


    
}