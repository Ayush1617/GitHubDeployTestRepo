import { LightningElement, track, api, wire } from 'lwc';
import { FlowNavigationFinishEvent } from 'lightning/flowSupport';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';
import JOB_POSITION_OBJECT from '@salesforce/schema/Job_Position__c';

import EMPLOYMENT_TYPE from '@salesforce/schema/Job_Position__c.Employment_Type__c';
import INTERVIEW_MODE from '@salesforce/schema/Job_Position__c.Mode__c';
import WORK_MODE from '@salesforce/schema/Job_Position__c.Work_Mode__c';
import SHIFT_TIME from '@salesforce/schema/Job_Position__c.Shift_Time__c';
import isLinkedInConnected from '@salesforce/apex/LinkedInService.isLinkedInConnected';


import createPost from '@salesforce/apex/LinkedInService.createPost';
import getCompanyName from '@salesforce/apex/LinkedInService.getCompanyName';
import getJobDetailsForLinkedin from '@salesforce/apex/LinkedInService.getJobDetailsForLinkedin';

export default class LinkedInPostGenerator extends LightningElement {

    @api recordId;
    @track promptData;
    @track companyName;
    @track isLinkedInConnected = false;

    @track email;
    @track generatedContent;

    @track skills;
    @track additionalskill;
    @track qualification;
    @track experienceRequired;
    @track softskill;


    @track employmentType;
    @track employmentOptions = [];

    @track interview_Mode;
    @track interviewOptions = [];

    @track work_Mode;
    @track workModeOptions = [];

    @track shift_Time;
    @track shiftTimeOptions = [];

    @track job_Title;
    @track length;

    @track isLoading = false;
    @track generatedContentEditable = false;

    /*loginWithLinkedIn() {
         window.open('/services/auth/oauth/LinkedinAuth' , '_blank');

 
        //window.open('/services/auth/oauth/LinkedinAuth', '_blank');
    //window.open('/services/auth/oauth/LinkedinAuth', '_self');
   // window.open('/services/auth/authorize/Linkedin_Named', '_self'); 
    }*/

        connectedCallback() {
        this.loadJobData();
        this.checkLinkedInStatus();
        }

        async checkLinkedInStatus() {
        try {
            const connected = await isLinkedInConnected();
            this.isLinkedInConnected = connected;
        } catch(e) {
            this.isLinkedInConnected = false;
        }
        }

        switchLinkedInAccount() {
    // Revoke current token then re-login
    this.isLinkedInConnected = false;
    this.loginWithLinkedIn();
} 
    loginWithLinkedIn() {
    const authUrl = '/services/auth/oauth/LinkedinAuth';
    const popup = window.open(
        authUrl,
        'LinkedIn Login',
        'width=600,height=700,scrollbars=yes,resizable=yes'
    );

    // Poll to detect when popup closes
    const pollTimer = setInterval(() => {
        if (popup && popup.closed) {
            clearInterval(pollTimer);
            this.handleLoginComplete();
        }
    }, 500);
   }

    handleLoginComplete() {
    this.showToast('Success', 'LinkedIn account connected! You can now post.', 'success');
    this.isLinkedInConnected = true;
   }

    

    @wire(getCompanyName)
    wiredCompanyName({ data, error }) {
        if (data) {
            this.companyName = data;
        } else if (error) {
            this.showToast('Error', 'Failed to load company name.', 'error');
        }
    }

    // -------- Picklist Metadata --------
    @wire(getObjectInfo, { objectApiName: JOB_POSITION_OBJECT })
    objectInfo;

    @wire(getPicklistValues, { recordTypeId: '$objectInfo.data.defaultRecordTypeId', fieldApiName: EMPLOYMENT_TYPE })
    wiredEmploymentValues({ error, data }) {
        if (data) {
            this.employmentOptions  = [
            { label: '--None--', value: '' },
            ...data.values
        ];
        }else if (error) {
            this.showToast('Error', 'Failed to load Employment Type values.', 'error');
        }
    }

    @wire(getPicklistValues, { recordTypeId: '$objectInfo.data.defaultRecordTypeId', fieldApiName: INTERVIEW_MODE })
    wiredInterviewValues({ error, data }) {
        if (data) {
            this.interviewOptions  = [
            { label: '--None--', value: '' },
            ...data.values
        ];
        }else if (error) {
            this.showToast('Error', 'Failed to load Interview Mode values.', 'error');
        }
    }

    @wire(getPicklistValues, { recordTypeId: '$objectInfo.data.defaultRecordTypeId', fieldApiName: WORK_MODE })
    wiredWorkModeValues({ error, data }) {
        if (data) {
            this.workModeOptions  = [
            { label: '--None--', value: '' },
            ...data.values
        ];
        }else if (error) {
            this.showToast('Error', 'Failed to load Work Mode values.', 'error');
        }
    }

    @wire(getPicklistValues, { recordTypeId: '$objectInfo.data.defaultRecordTypeId', fieldApiName: SHIFT_TIME })
    wiredShiftTimeValues({ error, data }) {
        if (data) {
            this.shiftTimeOptions  = [
            { label: '--None--', value: '' },
            ...data.values
        ];
        }else if (error) {
            this.showToast('Error', 'Failed to load Shift Time values.', 'error');
        }
    }

    // -------- Load record values --------
    connectedCallback() {
        this.loadJobData();
    }

    async loadJobData() {
        try {
            const data = await getJobDetailsForLinkedin({ jobId: this.recordId });
            this.skills = data.Skills_Required__c;
            this.additionalskill = data.Aditional_Skills__c;
            this.qualification = data.Qualification__c;
            this.experienceRequired = data.Experience_Required__c;
            this.softskill = data.Soft_skills__c;
            this.employmentType = data.Employment_Type__c;
            this.interview_Mode = data.Mode__c;
            this.work_Mode = data.Work_Mode__c;
            this.job_Title = data.Job_Title__c;
            this.shift_Time = data.Shift_Time__c;
        } catch (error) {
                console.error('Error loading job details:', error);
        this.showToast('Error', 'Failed to load job details.', 'error');

        }
    }

    handleChange(event) {
        const { label, value } = event.target;
        console.log('label : ',label);
        console.log('value : ',value);
      
        const fieldMap = {
            'Email': () => this.email = value,
            'Skill Required': () => this.skills = value,
            'Additional Skill': () => this.additionalskill = value,
            'Qualification': () => this.qualification = value,
            'Experience Required': () => this.experienceRequired = value,
            'Soft Skill': () => this.softskill = value,
            'Employment Type': () => this.employmentType = value,
            'Interview Mode': () => this.interview_Mode = value,
            'Work Mode': () => this.work_Mode = value,
            'Job Title': () => this.job_Title = value,
            'Shift Time': () => this.shift_Time = value,
            'Generated Post Content': () => {
                this.generatedContent = value;
                 console.log('this.generatedContent : ',this.generatedContent);
                this.generatedContentEditable = true;
                 console.log('generatedContentEditable : ',this.generatedContentEditable);
            }
        };

        fieldMap[label] && fieldMap[label]();
    }


    buildLinkedInPost() {

        const employmentTypeTag = this.sanitizeHashtag(this.employmentType);
        this.promptData = `🚀 We’re Hiring: ${this.job_Title} (${this.employmentType}) 🚀

   ${this.companyName} is looking for ${this.job_Title} with strong hands-on experience to join us on a ${this.employmentType} basis. 

✨ What We’re Looking For 
🔹 Role: ${this.job_Title}  
🔹 Skill Required: ${this.skills} 
🔹 Additional skills: ${this.additionalskill}  


🎓 Qualifications Required 
✔️ Qualification: ${this.qualification}  
✔️ Experience: ${this.experienceRequired}+ years of experience  

🤝 Soft Skills (Optional)  
✔️ ${this.softskill}  

📌 Job Details:  
🔹 Employment Type: ${this.employmentType}
🔹 Interview Mode: ${this.interview_Mode}  
🔹 Work Mode: ${this.work_Mode}  
🔹 Shift Time: ${this.shift_Time}
🔹 Join: Immediate

   If you have the right expertise and are interested in exploring this opportunity, we’d love to connect!

   Ready to apply? https://cloudespacio.com/career/
📩Send your CV to 👉 ${this.email} 
 
#${this.job_Title.replace(/\s+/g, '')} #JobOpening #${employmentTypeTag} #${this.sanitizeHashtag(this.companyName)} #ITJobs #NowHiring`;

        return this.promptData;
    }
    sanitizeHashtag(text) {
        return text.replace(/[^a-zA-Z0-9]/g, '');
    }

    generateTextPost() {
        this.isLoading = true;
         this.showFieldErrors();

        // Collect missing fields
        const missingFields = [];

        if (!this.skills) missingFields.push('Skill Required');
        if (!this.additionalskill) missingFields.push('Additional Skill');
        if (!this.qualification) missingFields.push('Qualification');
        if (!this.experienceRequired) missingFields.push('Experience Required');
        if (!this.softskill) missingFields.push('Soft Skill');
        if (!this.employmentType) missingFields.push('Employment Type');
        if (!this.interview_Mode) missingFields.push('Interview Mode');
        if (!this.work_Mode) missingFields.push('Work Mode');
        if (!this.job_Title) missingFields.push('Job Title');
        if (!this.shift_Time) missingFields.push('Shift Time');
        if (!this.email) missingFields.push('Email');

        // If any missing field found, show error toast and stop
        if (missingFields.length > 0) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Missing Required Fields',
                message: '⚠️ Please fill the following fields: ' + missingFields.join(', '),
                variant: 'error',
            }));
            this.isLoading = false;
            return;
        }

        // If all fields filled, continue generating post
        this.buildLinkedInPost();
        const content = this.promptData;
        this.generatedContent = content;

        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: 'Post has been generated successfully.',
            variant: 'success'
        }));

        this.isLoading = false;
    }


    async createPostonLinkedin() {
        this.isLoading = true;
        if (this.generatedContent === '' || this.generatedContent === null || this.generatedContent === undefined) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Info',
                message: 'Please Generate the Post Content.',
                variant: 'info'
            }));

            this.isLoading = false;
            return;
        }

        try {
            console.log('this.generatedContent : ',this.generatedContent);
            await createPost({ content: this.generatedContent })
            
          this.showToast(
                'Success',
                'Post has been published successfully on LinkedIn.',
                'success'
            );

            this.close();
            console.log('OUTPUT  chal gaya: ',);

            
        } catch (error) {
             this.showToast(
                'Error',
                error?.body?.message || 'Failed to publish post on LinkedIn.',
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }




    close() {
    this.dispatchEvent(new FlowNavigationFinishEvent());

    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
    }

    showFieldErrors() {
    const fields = this.template.querySelectorAll(
        'lightning-input, lightning-combobox'
    );

    fields.forEach(field => {
        field.reportValidity(); // 🔥 FORCE show error if invalid
    });
}

}