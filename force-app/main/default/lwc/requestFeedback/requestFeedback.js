import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import requestFeedbackFromClient from '@salesforce/apex/ATSController.collectFeedback';
export default class RequestFeedback extends LightningElement {
    @api recordId;
    @track isLoading = false;
    @api invoke() {
        this.runAction();
    }

    runAction() {
        this.isLoading = true;
        requestFeedbackFromClient({ interviewIds: [this.recordId] })
            .then(() => {
                this.showToast('Success', 'Feedback request sent successfully.', 'success');
            })
            .catch(error => {
                const msg = error?.body?.message || 'Failed to request feedback.';
                this.showToast('Error', msg, 'error');
            })
            .finally(() => {                
                this.resetLoadingState();
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant,
                mode: 'dismissable'
            })
        );
    }

     resetLoadingState() {
    this.isLoading = false;

    Promise.resolve().then(() => {
        this.dispatchEvent(new CloseActionScreenEvent());
    });
}
}