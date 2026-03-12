import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { FlowNavigationFinishEvent} from 'lightning/flowSupport';
import getJobDetails from '@salesforce/apex/JobDescriptionController.getJobDetails';
import generateJobDescription from '@salesforce/apex/JobDescriptionController.generateJobDescription';
import saveJobDescription from '@salesforce/apex/JobDescriptionController.saveJobDescription';
 
export default class JobDescriptionGenerator extends LightningElement {
    @api recordId;
 
    @track skills;
    @track additionalskill;
    @track qualification;
    @track experienceRequired;
    @track softskill;
    @track tone;
    @track length;
    @track jobDescription;
    @track isLoading = false;
    @track jobDescriptionEdited = false;
 
    toneOptions = [
        { label: 'Formal', value: 'Formal' },
        { label: 'Informal', value: 'Informal' },
        { label: 'Persuasive', value: 'Persuasive' },
        { label: 'Subjective', value: 'Subjective' }
    ];
    lengthOptions = [
        { label: 'Concise', value: 'Concise' },
        { label: 'Medium', value: 'Medium' },
        { label: 'Comprehensive', value: 'Comprehensive' }
    ];
 
    connectedCallback() {
        this.loadJobData();
        console.log(this.recordId);
    }
 
    async loadJobData() {
       
        try {
            const data = await getJobDetails({ jobId: this.recordId });
            this.skills = data.Skills_Required__c;
            this.additionalskill = data.Aditional_Skills__c;
            this.qualification = data.Qualification__c;
            this.experienceRequired = data.Required_Experience_Range__c;
            this.softskill = data.Soft_skills__c;
        } catch (error) {
            console.error(error);
        }
    }
 
handleChange(event) {
    const { label, value } = event.target;
    const fieldMap = {
        'Skills Required': () => this.skills = value,
        'Additional skills': () => this.additionalskill = value,
        'Qualification': () => this.qualification = value,
        'Experience Required': () => this.experienceRequired = value,
        'Soft skills': () => this.softskill = value,
        'Select Tone of the content': () => this.tone = value,
        'Select Length of the content': () => this.length = value,
        'Job Description': () => {
            this.jobDescription = value;
            this.jobDescriptionEdited = true;
        }
    };
 
    fieldMap[label]?.();
}
 
    async generateDescription() {
        this.isLoading = true;
        if (!this.tone || !this.length) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: 'Please select Tone and Length before generating the job description.',
            variant: 'error'
        }));
         this.isLoading = false;
        return;
       
    }
         let lengthText;
    switch(this.length) {
        case 'Concise':
            lengthText = 'approximately 300-400 characters';
            break;
        case 'Medium':
            lengthText = 'approximately 600-800 characters';
            break;
        case 'Comprehensive':
            lengthText = 'approximately 1000-1200 characters';
            break;
        default:
            lengthText = 'around 600 characters';
    }
        try {
             const requestData = {
                jobId: this.recordId,
                skillsData: this.skills || '',
                additional: this.additionalskill || '',
                qualification: this.qualification || '',
                experience: this.experienceRequired || '',
                soft: this.softskill || '',
                tone: this.tone,
                length: this.length,
                lengthsize: lengthText
 
            };          
            const requestJson = JSON.stringify(requestData);
            const response = await generateJobDescription({
                requestJson: requestJson
            });

            console.log('response : ',response);
            this.jobDescription = response;
            this.jobDescriptionEdited = true;
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Failed to generate job description: ' + (error.body?.message || error.message),
                variant: 'error'
            }));
        }finally {
            this.isLoading = false;
        }
    }
 
    async saveDescription() {
        this.isLoading = true;
        const jobDesc = this.jobDescription ? this.jobDescription.trim() : '';
    if (!this.jobDescriptionEdited || jobDesc === '' || jobDesc === null ) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Info',
            message: 'No changes to save. Record remains unchanged.',
            variant: 'info'
        }));
 
        this.isLoading = false;
        this.dispatchEvent(new FlowNavigationFinishEvent());
        return;
    }
       
        try {
            await saveJobDescription({
                jobId: this.recordId,
                description: this.jobDescription
            });
 
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'Job Description saved successfully!',
                variant: 'success'
            }));
 
           this.dispatchEvent(new FlowNavigationFinishEvent());
        } catch (error) {
            let message = 'An unexpected error occurred.';
   
    if (error && error.body && error.body.message) {
        message = error.body.message;   // Apex AuraHandledException message
    }
 
    this.dispatchEvent(
        new ShowToastEvent({
            title: 'Error',
            message: message,
            variant: 'error'
        })
    );
        }finally {
            this.isLoading = false;
        }
    }
     handleCancel() {
        this.dispatchEvent(new FlowNavigationFinishEvent());
    }
}