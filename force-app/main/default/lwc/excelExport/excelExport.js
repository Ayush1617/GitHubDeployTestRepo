import { LightningElement, api } from 'lwc';
import FinishRedirectUrl from '@salesforce/label/c.FinishRedirectUrl';
import exportCandidatesToExcel from '@salesforce/apex/ExportToExcel.exportCandidatesToExcel';


export default class ExcelExport extends LightningElement {
    @api recordIds;
   
    connectedCallback() {
        console.log('OUTPUT : ', this.recordIds);

        if (this.recordIds && this.recordIds.length > 0) {
            // If recordIds is a string, convert to array
            const candidateIdsArray = Array.isArray(this.recordIds)
                ? this.recordIds
                : this.recordIds.split(',').map(id => id.trim());
                console.log('candidateIdsArray : ', candidateIdsArray);
            
            this.triggerExport(candidateIdsArray);
        }
    }
    get hasRecords() {
        return this.recordIds && this.recordIds.length > 0;
    }
    get buttonLabel() {
    return this.hasRecords ? 'Finish' : 'Back';
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
            window.location.href = FinishRedirectUrl;

        } catch (error) {
            console.error('Error exporting candidates:', error);

        }
    }

    handleBack() {
       
        window.location.href = FinishRedirectUrl;
    }
}