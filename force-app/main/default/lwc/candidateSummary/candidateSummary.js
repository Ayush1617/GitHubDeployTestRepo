import { LightningElement, api } from 'lwc';
import generateSummary from '@salesforce/apex/CandidateSummaryService.generateSummary';

export default class CandidateSummary extends LightningElement {

    _recordId;

    summary = '';
    showModal = false;
    loading = false;
    error;

    @api
    set recordId(value) {
        this._recordId = value;

        if (value) {
            this.fetchSummary();
        }
    }

    get recordId() {
        return this._recordId;
    }

    fetchSummary() {

        this.loading = true;

        generateSummary({ recordId: this.recordId })
            .then(result => {
                this.summary = result;
                this.showModal = true;
            })
            .catch(err => {
                this.error = err;
                console.error('Error fetching summary:', err);
            })
            .finally(() => {
                this.loading = false;
            });
    }

    closeModal() {
        this.showModal = false;
    }
}