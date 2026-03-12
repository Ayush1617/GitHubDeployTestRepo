import { LightningElement, api, track } from 'lwc';

export default class CandidateFeedback extends LightningElement {

    @api candidateId;
    @api isFinalDecision = false;
    @api feedbackList = [];

    @track newFeedback = '';

    get characterCount() {
        return this.newFeedback ? this.newFeedback.length : 0;
    }

    get isSaveDisabled() {
        return (
            this.isFinalDecision ||
            !this.newFeedback ||
            this.newFeedback.length < 10 ||
            this.newFeedback.length > 500
        );
    }

    handleChange(event) {
        this.newFeedback = event.target.value;
    }

    handleAddFeedback() {
        const feedbackEntry = {
            id: Date.now(),
            comment: this.newFeedback,
            createdDate: new Date().toLocaleString(),
            createdBy: 'Client'
        };
    

        const updatedList = [...this.feedbackList, feedbackEntry];

        this.dispatchEvent(
            new CustomEvent('savefeedback', {
                detail: {
                    candidateId: this.candidateId,
                    feedbackList: updatedList,
                    action: 'add'   // 👈 add this
                }
            })
        );

        this.newFeedback = '';

    }


    handleDelete(event) {
        const idToDelete = Number(event.target.dataset.id);

        const updatedList = this.feedbackList.filter(
            item => item.id !== idToDelete
        );

        this.dispatchEvent(
            new CustomEvent('savefeedback', {
                detail: {
                    candidateId: this.candidateId,
                    feedbackList: updatedList,
                    action: 'delete'
                }
            })
        );

        
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }
    handleSubmitAndClose() {

    if (this.isSaveDisabled) {
        return;
    }

    // Save event send
    this.handleAddFeedback();

    // Tell Parent to close
    this.dispatchEvent(new CustomEvent('close'));
    }
}