import { LightningElement, wire, track } from 'lwc';
import getDummyCandidates from '@salesforce/apex/DummyCandidateController.getDummyCandidates';

export default class DummyCandidateParent extends LightningElement {

    @track candidates = [];
    showModal = false;

    selectedCandidateId;
    selectedFinalDecision = false;
    selectedFeedbackList = [];

    @wire(getDummyCandidates)
    wiredCandidates({ data, error }) {
        if (data) {
            this.candidates = data.map((item, index) => {
                return {
                    ...item,
                    serialNumber: index + 1,
                    decisionIcon: item.isFinalDecision
                        ? 'utility:lock'
                        : 'utility:unlock',
                    feedbackList: [] // 👈 each candidate has own list
                };
            });
        } else if (error) {
            console.error(error);
        }
    }

    openFeedback(event) {
        const candidateId = event.target.dataset.id;

        const selectedCandidate = this.candidates.find(
            cand => cand.id === candidateId
        );

        this.selectedCandidateId = candidateId;
        this.selectedFinalDecision = selectedCandidate.isFinalDecision;
        this.selectedFeedbackList = [...selectedCandidate.feedbackList];

        this.showModal = true;
    }

    closeModal() {
        this.showModal = false;
    }

    handleFeedbackSaved(event) {
        const { candidateId, feedbackList } = event.detail;

        this.candidates = this.candidates.map(candidate => {
            if (candidate.id === candidateId) {
                return { ...candidate, feedbackList: feedbackList };
            }
            return candidate;
        });

        this.showModal = false;
    }
}