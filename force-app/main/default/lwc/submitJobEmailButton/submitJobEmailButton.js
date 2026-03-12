import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getJobAndCandidates from '@salesforce/apex/SendJobPositionToCandidateController.getJobAndCandidates';

export default class SubmitJobEmailButton extends LightningElement {

    @api recordId;
    @api recordIds = [];
    @track isLoading = false;

    get isDisabled() {
        return !(this.recordIds && this.recordIds.length > 0);
    }

    async handleSendEmail() {

        if (!this.recordIds?.length) {
            this.showToast('Warning', 'Select at least one interview', 'warning');
            return;
        }

        this.isLoading = true;

        try {
            const result = await getJobAndCandidates({
                jobPositionId: this.recordId,
                interviewIds: this.recordIds
            });

            const job = result.jobPosition;
            const candidates = result.candidates || [];

            if (!job) {
                this.showToast('Info', 'Job details not found', 'info');
                return;
            }

            const emails = candidates
                .map(c => c.Email)
                .filter(e => e);

            if (!emails.length) {
                this.showToast('Info', 'No candidate emails found', 'info');
                return;
            }

            /* -----------------------
               BUILD EMAIL BODY EXACT SAME
            ------------------------ */
            const body = `
<div style="font-family: Arial, sans-serif; border: 1px solid #e0e0e0; border-radius: 12px; padding: 20px; background: #fff; box-shadow: 0 2px 6px rgba(0,0,0,0.1); max-width: 600px; margin: 20px auto; text-align: center;">
<h2 style="margin: 0 0 15px 0; color: #444;">Job Summary</h2>
<p>🏢 <b>Company:</b> ${job?.Client_Name__r.Name || 'NA'}</p>
<p>💼 <b>Job Title:</b> ${job?.Job_Title__c || 'NA'}</p>
<p>📍 <b>Location:</b> ${job?.Job_Location__c?.city || 'NA'}</p>
<p>⏳ <b>Experience:</b> ${job?.Required_Experience_Range__c || 'NA'}</p>
<p>₹ <b>Salary:</b> ${job?.Salary_Range__c || 'NA'}</p>
</div>

<h2 style="font-family: Arial, sans-serif; color: #444;">Job Specifications</h2>
<table border="1" cellpadding="8" cellspacing="0" style="border-collapse: collapse; width: 100%; font-family: Arial, sans-serif;">
<tr style="background-color: #f2f2f2;">
    <th>Field</th>
    <th>Details</th>
</tr>
<tr><td>Shift</td><td>${job?.Shift_Time__c || 'NA'}</td></tr>
<tr><td>Key Responsibility</td><td>${job?.Key_Responsibility__c || 'NA'}</td></tr>
<tr><td>Skills Required</td><td>${job?.Skills_Required__c || 'NA'}</td></tr>
<tr><td>Educational Background</td><td>${job?.Education_Background__c || 'Any Graduate...'}</td></tr>
<tr><td>Employment Type</td><td>${job?.Employment_Type__c || 'NA'}</td></tr>
<tr><td>Website</td><td>${job?.Client_Name__r.Website || 'NA'}</td></tr>

</table>
<div style="margin-top:20px; font-family: Arial, sans-serif;">
    <h3 style="color:#444; margin-bottom:8px;">Job Description</h3>
    <div style="border:1px solid #e0e0e0; border-radius:8px; padding:12px; background:#fafafa;">
        ${job?.Job_Description__c || 'NA'}
    </div>
</div>
`;
            /* -----------------------
               PREFILL FOR CUSTOM COMPOSER
            ------------------------ */
            const prefill = {
                toAddresses: emails.join(";"),
                subject: `Job | ${job?.Name || ''} based in ${job?.Job_Location__c?.city || 'NA'}`,
                htmlBody: body,
                relatedToId: this.recordId,
                relatedToName: job?.Name
            };

            console.log("Opening composer with:", JSON.stringify(prefill));

            /* -----------------------
               OPEN CUSTOM COMPOSER
            ------------------------ */

            const composer = this.template.querySelector('c-custom-email-composer');

            if (composer) {
                composer.openWithPrefill(prefill);
                    setTimeout(() => {

        composer.sendEmailFromParent();

    }, 500);
            } else {
                this.showToast("Error", "Composer component not found", "error");
            }

        } catch (error) {
            console.error('🔥 ERROR:', JSON.stringify(error));
            this.showToast('Error', error?.body?.message || error?.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}