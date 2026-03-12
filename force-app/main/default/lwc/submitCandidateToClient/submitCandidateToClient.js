import { LightningElement, track, api, wire } from 'lwc';

import getAllClients from '@salesforce/apex/SubmitCandidateController.getAllClients';
import getJobPositionsByClient from '@salesforce/apex/SubmitCandidateController.getJobPositionsByClient';
import getCandidateForClient from '@salesforce/apex/SubmitCandidateController.getCandidateForClient';
import getMultipleCandidatesForClient from '@salesforce/apex/SubmitCandidateController.getMultipleCandidatesForClient';
import sendCandidateExcelEmail from '@salesforce/apex/SubmitCandidateController.sendCandidateExcelEmail';
import generateAndSendShareLink from '@salesforce/apex/CandidateShareController.generateAndSendShareLink';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getJobWithClient from '@salesforce/apex/SubmitCandidateController.getJobWithClient';
import { FlowNavigationFinishEvent } from 'lightning/flowSupport';
import validateCandidateInterviews from '@salesforce/apex/SubmitCandidateController.validateCandidateInterviews';

export default class SubmitCandidateToClient extends LightningElement {
    @api recordId;    // single candidate id (optional)
    @api recordIds;   // multiple candidate ids (optional)
    @track clientOptions = [];
    @track jobPositionOptions = [];
    @track step = 1;
    childstep;
    @api jobPositionId;
    @track selectedJobName = '';
    @api sendEmailTrigger;
    @track validationError;
    @track invalidCandidateNames = [];
    @track validationError = false;
    @track selectedJobDetails = {};
    // Use a single selectedJobId because lightning-combobox is single-select by default
    @track selectedClientId = null;
    @track selectedClientName = '';   // for Related To display

    @track selectedJobId = null;      // single job id
    @track candidateList = [];
  
    clientEmail = ''; 
    @track showComposer = false;
    //shouldOpenComposer = false;
    @track showEmailComposer = false;
    //@track _sendEmailFlag;

    renderedCallback() {
        console.log('this.sendEmailTrigger : ',this.sendEmailTrigger);
        console.log('jobPositionId: ', this.jobPositionId);
    if (this.sendEmailTrigger) {
        this.sendEmailTrigger = false; // reset
        this.sendEmailFromParent();
    }
}
    


    @track sendType = 'body';
    sendTypeOptions = [
        { label: 'Email Body', value: 'body' },
        { label: 'Excel Attachment', value: 'excel' },
        { label: 'Secure Link', value: 'link' }
    ];

    get isStep1() {
         console.log('this.step1 : ',this.step);
    return this.step === 1;
}

get isStep2() {
    console.log('this.step2 : ',this.step);
    this.childstep = this.step
    return this.step === 2;
}
handleBack() {
    this.step = 1;
}


  

@api sendEmailFromParent() {
    const grandChild = this.template.querySelector('c-custom-email-composer');
    if(grandChild){
        grandChild.sendEmailFromParent();
    } else {
        console.log('grandchild not found');
    }
}
handleCloseAll() {
    this.step = 1;

    // Close Flow screen (Quick Action)
    this.dispatchEvent(new FlowNavigationFinishEvent());
}
 

  

   connectedCallback() {
    console.log('job idddddddddd----', this.jobPositionId);

    if (this.jobPositionId) {
        getJobWithClient({ jobId: this.jobPositionId })
            .then(result => {

                // Client auto set
                this.selectedClientId = result.Client_Name__c;
                this.selectedClientName = result.Client_Name__r?.Name;
                this.clientEmail = result.Client_Name__r?.Email__c;

                // Job auto set
                this.selectedJobId = result.Id;
                this.selectedJobName = result.Name;

                this.selectedJobDetails = {
                    value: result.Id,
                    title: result.Job_Title__c,
                    location: result.Job_Location__City__s,
                    type: result.Employment_Type__c,
                    jobDescription: result.Job_Description__c
                };

                this.jobPositionOptions = [{
                    label: result.Name,
                    value: result.Id,
                    title: result.Job_Title__c,
                    location: result.Job_Location__City__s,
                    type: result.Employment_Type__c,
                    jobDescription: result.Job_Description__c
                }];

                this.fetchCandidateData();

                console.log('job dataaa----', result);
            })
            .catch(error => {
                this.showToast('Error', error.body?.message || error.message, 'error');
            });
    }
}


    // -------------------- CLIENTS --------------------

    @wire(getAllClients)
    wiredClients({ data, error }) {
        if (data) {
            console.log('OUTPUT : ', JSON.stringify(data));

            this.clientOptions = data.map(c => ({
                label: c.Name,
                value: c.Id,
                email: c.Email__c,
                fields: c.Candidate_Fields__c
            }));

        } else if (error) {
            this.showToast('Error', error.body?.message || error.message, 'error');
        }
    }

    handleClientChange(event) {
        this.selectedClientId = event.detail.value;
        console.log('this.selectedClientId : ',this.selectedClientId);
        const selectedClient = this.clientOptions.find(c => c.value === this.selectedClientId);
        this.clientEmail = selectedClient ? selectedClient.email : '';
        this.selectedClientName = selectedClient ? selectedClient.label : '';

        if (this.selectedClientId) {
            console.log('this.selectedClientId11 : ',this.selectedClientId);
            this.fetchJobPositions();
            this.fetchCandidateData();
        } else {
            // clear job & candidates if no client
            this.jobPositionOptions = [];
            this.selectedJobId = null;
            this.candidateList = [];
        }
    }

async handleNext() {

    const candidateIds = (this.recordIds && this.recordIds.length)
        ? this.recordIds
        : (this.recordId ? [this.recordId] : []);

    if (!candidateIds.length || !this.selectedJobId) {
        this.showToast('Error', 'Candidate or Job not selected', 'error');
        return;
    }

    try {

        const isValid = await this.validateCandidates(candidateIds);

        if (!isValid) {
            return;
        }

        this.step = 2;

        this.dispatchEvent(
            new CustomEvent('shownextfooter', {
                bubbles: true,
                composed: true
            })
        );

        setTimeout(() => {
            this.openComposerWithBody();
        }, 0);

    } catch (error) {
        console.error(error);
        this.showToast('Error', error.body?.message || error.message, 'error');
    }
}

    // this.openComposerWithBody();   //  Direct component Open


   



//     handleNext() {
//         console.log(' Next button clickeddddd');
//         this.showComposer = true;
//         this.shouldOpenComposer = true;
//         }
        
//         renderedCallback() {
//             console.log('renderedCallback fired');
//         if (this.shouldOpenComposer) {
//             console.log('shouldOpenComposer is TRUE — composer open hoga');

//             this.shouldOpenComposer = false;
//             this.openComposerWithBody();
//         }
//     }

//     handleComposerClose() {
//     console.log('Composer closed & resetting parent');

//     this.showComposer = false;   // Reset krega Next works again 
// }

    // -------------------- JOB POSITIONS --------------------
    fetchJobPositions() {
        if (!this.selectedClientId) {
            this.jobPositionOptions = [];
            return;
        }

        getJobPositionsByClient({ clientId: this.selectedClientId })
            .then(result => {
                // Normalize keys and keep case-consistent properties
                this.jobPositionOptions = result.map(job => ({
                    label: job.Name,
                    value: job.Id,
                    title: job.Job_Title__c,
                    location: job.Job_Location__City__s,
                    type: job.Employment_Type__c,
                    jobDescription: job.Job_Description__c   // camelCase to avoid case issues
                }));
            })
            .catch(error => this.showToast('Error', error.body?.message || error.message, 'error'));
    }

    // -------------------- CANDIDATE FETCH --------------------
    fetchCandidateData() {
        if (!this.selectedClientId) return;

        if (this.recordIds && Array.isArray(this.recordIds) && this.recordIds.length > 0) {
            // multiple candidates
            getMultipleCandidatesForClient({ candidateIds: this.recordIds, clientId: this.selectedClientId })
                .then(result => {
                    this.candidateList = result || [];
                })
                .catch(error => this.showToast('Error', error.body?.message || error.message, 'error'));
        } else if (this.recordId) {
            // single candidate
            getCandidateForClient({ candidateId: this.recordId, clientId: this.selectedClientId })
                .then(result => {
                    this.candidateList = result ? [result] : [];
                })
                .catch(error => this.showToast('Error', error.body?.message || error.message, 'error'));
        } else {
            // no record context — clear
            this.candidateList = [];
        }
    }

    handleJobChange(event) {
           this.selectedJobId = event.detail.value || null;

    //console.log(' Selected JobId:', this.selectedJobId);
    //console.log(' All Jobs:', JSON.stringify(this.jobPositionOptions));

    }

    handleSendTypeChange(event) {
        this.sendType = event.detail.value;
    }

    // -------------------- SEND EMAIL --------------------
    /*sendEmail() {
        if (!this.selectedClientId) {
            this.showToast('Error', 'Please select a client', 'error');
            return;
        }
        if (!this.selectedJobId) {
            this.showToast('Error', 'Please select a job position', 'error');
            return;
        }

        if (this.sendType === 'body') {
            this.openComposerWithBody();
        } else {
            this.sendEmailWithExcel();
        }
    }*/

    async sendEmail() {

    if (!this.selectedClientId) {
        this.showToast('Error', 'Please select a client', 'error');
        return;
    }

    if (!this.selectedJobId) {
        this.showToast('Error', 'Please select a job position', 'error');
        return;
    }

    const candidateIds = (this.recordIds && Array.isArray(this.recordIds) && this.recordIds.length > 0)
        ? this.recordIds
        : (this.recordId ? [this.recordId] : []);

    if (candidateIds.length === 0) {
        this.showToast('Error', 'No candidate selected to send', 'error');
        return;
    }

    try {

        const isValid = await this.validateCandidates(candidateIds);

        if (!isValid) {
            return;
        }

        switch(this.sendType) {

            case 'body':
                this.openComposerWithBody();
                break;

            case 'excel':
                this.sendEmailWithExcel(candidateIds);
                break;

            case 'link':
                this.sendEmailWithLink(candidateIds, this.selectedJobId);
                break;

            default:
                this.showToast('Error', 'Invalid send type', 'error');
        }

    } catch(error) {
        console.error(error);
        this.showToast('Error', error.body?.message || error.message, 'error');
    }
}

    // Build body HTML and call custom composer's openWithPrefill()
    openComposerWithBody() {
    //console.log('================ EMAIL BODY BUILD START ================');

    //console.log('Selected JobId:', this.selectedJobId);
    //console.log('All Jobs Options:', JSON.stringify(this.jobPositionOptions));

    // Resolve selected job safely
    const selectedJob =
        (this.jobPositionOptions?.find(j => String(j.value) === String(this.selectedJobId))) ||
        this.selectedJobDetails ||
        {};

    //console.log(' Selected Job Object:', JSON.stringify(selectedJob));

    // FIND SELECTED CLIENT
    const client = this.clientOptions.find(c => c.value === this.selectedClientId) || {};
    //console.log(' Selected Client:', JSON.stringify(client));

    // CANDIDATE LIST DEBUG
    //console.log(' Candidate List:', JSON.stringify(this.candidateList));

    // Build table headers
    let tableHeaders = '';
    let tableRows = '';

    if (this.candidateList && this.candidateList.length > 0) {
        const fields = this.candidateList[0].fieldOrder || [];
        //console.log(' Candidate Fields:', JSON.stringify(fields));

        tableHeaders = fields.map(f => `<th style="padding:6px 10px;text-align:left;">${f.label}</th>`).join('');

        this.candidateList.forEach(cand => {
            const valuesMap = cand.values || {};
            //console.log(' Candidate Values:', JSON.stringify(valuesMap));

            const row = fields.map(f => {
                const v = valuesMap[f.value];
                return `<td style="padding:6px 10px">${v ? v : ''}</td>`;
            }).join('');
            tableRows += `<tr>${row}</tr>`;
        });
    }

    //console.log(' Table Headers:', tableHeaders);
    //console.log(' Table Rows:', tableRows);

    //console.log('------------ FINAL JOB DETAILS USED --------------');
    //console.log('Job Title:', selectedJob.title);
    //console.log('Job Location:', selectedJob.location);
    //console.log('Job Type:', selectedJob.type);
    //console.log('Job Description:', selectedJob.jobDescription);

const body = `
<div>
    <p>Hi ${client.label || ''},</p>

    <p>
        As discussed, submitting details of the candidate(s) for the 
        <b>${selectedJob.title || '-'}</b> position based in 
        <b>${selectedJob.location?.city || selectedJob.location || '-'}</b>.
    </p>

    <p><b>Employment Type:</b> ${selectedJob.type || '-'}</p>

    <table border="1" cellpadding="5" style="border-collapse:collapse; margin-top:12px; width:100%;">
        <thead><tr>${tableHeaders}</tr></thead>
        <tbody>${tableRows}</tbody>
    </table>

    <p style="margin-top:12px;">
        <b>Job Role:</b> ${selectedJob.title || '-'}<br/>
        <b>Location:</b> ${selectedJob.location?.city || selectedJob.location || '-'}<br/>
        <b>Job Type:</b> ${selectedJob.type || '-'}<br/>
        <b>Job Description:</b> ${selectedJob.jobDescription || '-'}
    </p>

    <p style="margin-top:12px;">
        Thanks,<br/> Recruitment Team
    </p>
</div>
`;

    //console.log('FINAL EMAIL BODY:', body);
    //console.log('================ EMAIL BODY BUILD END ================');

    const prefill = {
        toAddresses: this.clientEmail || '',
        subject: `Candidate Details: ${selectedJob.title || selectedJob.label || ''}`,
        htmlBody: body,
        relatedToId: this.selectedClientId,
        relatedToName: this.selectedClientName,
        jobId: selectedJob.value || null,
        jobTitle: selectedJob.title || '',
        jobLocation: selectedJob.location || '',
        jobType: selectedJob.type || '',
        jobDescription: selectedJob.jobDescription || ''
    };

    console.log(' Prefill Passed to Composer:', JSON.stringify(prefill));

    const composer = this.template.querySelector('c-custom-email-composer');
    if (composer) {
        composer.openWithPrefill(prefill);
    } else {
        this.showToast('Error', 'Email composer not available on page', 'error');
    }
}

    // -------------------- EMAIL WITH EXCEL --------------------

    // New method for sending with secure link
    // New method for sending with simple link
   sendEmailWithLink(candidateIds, selectedJobId) {
    this.isLoading = true;

    generateAndSendShareLink({
        candidateIds: candidateIds,
        clientId: this.selectedClientId,
        jobId: selectedJobId
    })
    .then(result => {
        this.showToast('Success', 'Secure link sent successfully', 'success');
        this.resetForm();
        this.dispatchEvent(new CustomEvent('closemodal'));
    })
    .catch(error => {
        console.error('Error sending link:', error);
        this.showToast('Error', error.body?.message || error.message || 'Failed to send link', 'error');
    })
    .finally(() => {
        this.isLoading = false;
    });
    }
   /* sendEmailWithLink(candidateIds) {
        this.isLoading = true;
        
        generateAndSendShareLink({
            candidateIds: candidateIds,
            clientId: this.selectedClientId,
            jobId: this.selectedJobId
        })
        .then(result => {
            this.showToast('Success', result.message || 'Secure link sent successfully', 'success');
            this.resetForm();
        })
        .catch(error => {
            console.error('Error sending link:', error);
            this.showToast('Error', error.body?.message || error.message || 'Failed to send link', 'error');
        })
        .finally(() => {
            this.isLoading = false;
        });
    }*/

    sendEmailWithExcel(candidateIds) {
        this.isLoading = true;
        
        sendCandidateExcelEmail({
            candidateIds: candidateIds,
            clientId: this.selectedClientId,
            jobId: this.selectedJobId
        })
        .then(() => {
            this.showToast('Success', 'Email with Excel sent successfully', 'success');
            this.resetForm();
            this.dispatchEvent(new CustomEvent('closemodal'));
        })
        .catch(error => this.showToast('Error', error.body?.message || error.message, 'error'))
        .finally(() => {
            this.isLoading = false;
        });
    }
   /* sendEmailWithExcel() {
        const candidateIds = (this.recordIds && Array.isArray(this.recordIds) && this.recordIds.length > 0)
            ? this.recordIds
            : (this.recordId ? [this.recordId] : []);

        if (!candidateIds || candidateIds.length === 0) {
            this.showToast('Error', 'No candidate selected to send', 'error');
            return;
        }

        const jobIdToSend = this.selectedJobId;

        sendCandidateExcelEmail({
            candidateIds: candidateIds,
            clientId: this.selectedClientId,
            jobId: jobIdToSend
        })
            .then(() => {
                this.showToast('Success', 'Email with Excel sent successfully', 'success');
                this.resetForm();
            })
            .catch(error => this.showToast('Error', error.body?.message || error.message, 'error'));
    }*/

    // -------------------- UTILITIES --------------------
    resetForm() {
        this.selectedClientId = null;
        this.selectedClientName = '';
        this.selectedJobId = null;
        this.clientEmail = '';
        this.candidateList = [];
        this.jobPositionOptions = [];
        this.sendType = 'body';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    get isJobLocked() {
    return !!this.jobPositionId;
}



get isContextMode() {
    return !!this.jobPositionId;
}

get isClientLocked() {
    return this.isContextMode;
}

// ===== BUTTON VISIBILITY (SAFE ADD) =====
get isEmailBody() {
    return this.sendType === 'body';
}

get isOtherOption() {
    return this.sendType === 'excel' || this.sendType === 'link';
}

async validateCandidates(candidateIds) {

    const invalidCandidates = await validateCandidateInterviews({
        candidateIds: candidateIds,
        jobId: this.selectedJobId
    });

    if (invalidCandidates && invalidCandidates.length > 0) {

        this.invalidCandidateNames = invalidCandidates;
        this.validationError = true;

        return false; // validation failed
    }

    this.validationError = false;
    this.invalidCandidateNames = [];

    return true; // validation passed
}
}