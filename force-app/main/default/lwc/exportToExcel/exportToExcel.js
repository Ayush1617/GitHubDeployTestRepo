import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import exportCandidatesToExcel from '@salesforce/apex/ExportToExcel.exportCandidatesToExcel';


export default class ExportToExcel extends LightningElement {
    @api recordIds;
    @api done;
   
    connectedCallback() {
        console.log('OUTPUT : ', this.recordIds);

        if (this.recordIds && this.recordIds.length > 0) {
            // If recordIds is a string, convert to array
            const candidateIdsArray = Array.isArray(this.recordIds)
                ? this.recordIds
                : this.recordIds.split(',').map(id => id.trim());

            this.triggerExport(candidateIdsArray);
        }
    }
    
    @api
    async triggerExport(candidateIds) {
        if (!candidateIds || candidateIds.length === 0) {
            this.showToast('Warning', 'No candidates found for export.', 'warning');
            return;
        }

        try {
            console.log('Exporting candidate IDs:', candidateIds);
            const base64File = await exportCandidatesToExcel({ candidateIds });

            const link = document.createElement('a');
            link.href = 'data:text/csv;base64,' + base64File;
            const now = new Date().toISOString().replace(/[:.]/g, '-');
            link.download = `CandidateData_${now}.csv`;
            link.click();

            this.showToast('Success', 'Candidate data exported successfully.', 'success');
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Error exporting data.', 'error');
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}