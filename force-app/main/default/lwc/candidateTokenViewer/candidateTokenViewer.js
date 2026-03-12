// candidateTokenViewer.js
import { LightningElement, track, api } from 'lwc';
//import getCandidatesByToken from '@salesforce/apex/CandidateShareController.getCandidatesByToken';
//import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CandidateTokenViewer extends LightningElement {
  /*  @track candidates = [];
    @track isLoading = true;
    @track errorMessage = '';
    @track expiryDate = '';

    @api token;
    
    connectedCallback() {
        // Use token from attribute if provided, otherwise get from URL
        if (this.token) {
            console.log('Token from attribute:', this.token);
            this.loadCandidates();
        } else {
            this.loadTokenFromUrl();
        }
    }
    
    loadTokenFromUrl() {
        const urlParams = new URLSearchParams(window.location.search);
        this.token = urlParams.get('token');
        
        if (!this.token) {
            this.errorMessage = 'Invalid access token. Please use the link provided in your email.';
            this.isLoading = false;
            return;
        }
        
        this.loadCandidates();
    }
    
    loadCandidates() {
        if (!this.token) return;
        
        getCandidatesByToken({ token: this.token })
            .then(result => {
                this.candidates = result.map(candidate => {
                    // Format notice period badge
                    const noticePeriod = candidate.NoticePeriod || '';
                    let noticePeriodClass = 'slds-theme_warning';
                    
                    if (noticePeriod.includes('Immediate') || noticePeriod.includes('0') || noticePeriod.includes('15')) {
                        noticePeriodClass = 'slds-theme_success';
                    } else if (noticePeriod.includes('30') || noticePeriod.includes('60') || noticePeriod.includes('90')) {
                        noticePeriodClass = 'slds-theme_warning';
                    }
                    
                    return {
                        ...candidate,
                        noticePeriodClass: noticePeriodClass
                    };
                });
                
                // Calculate expiry date (7 days from today)
                const expiry = new Date();
                expiry.setDate(expiry.getDate() + 7);
                this.expiryDate = expiry.toLocaleDateString('en-US', {
                    weekday: 'long',
                    year: 'numeric',
                    month: 'long',
                    day: 'numeric'
                });
                
                this.isLoading = false;
            })
            .catch(error => {
                this.errorMessage = error.body?.message || error.message || 'Failed to load candidate data';
                this.isLoading = false;
                console.error('Error loading candidates:', error);
            });
    }
    
    get showCandidates() {
        return !this.isLoading && !this.errorMessage && this.candidates.length > 0;
    }
    
    downloadCSV() {
        if (this.candidates.length === 0) return;
        
        // Define CSV headers
        const headers = [
            'Name', 'Email', 'Phone', 'Current Location', 
            'Source', 'Experience', 'Skills', 'Current CTC', 
            'Expected CTC', 'Notice Period', 'Resume Link'
        ];
        
        // Prepare CSV rows
        const rows = this.candidates.map(candidate => {
            return [
                `"${(candidate.Name || '').replace(/"/g, '""')}"`,
                `"${(candidate.Email || '').replace(/"/g, '""')}"`,
                `"${(candidate.Phone || '').replace(/"/g, '""')}"`,
                `"${(candidate.CurrentLocation || '').replace(/"/g, '""')}"`,
                `"${(candidate.Source || '').replace(/"/g, '""')}"`,
                `"${(candidate.Experience || '').replace(/"/g, '""')}"`,
                `"${(candidate.Skills || '').replace(/"/g, '""')}"`,
                `"${(candidate.CurrentCTC || '').replace(/"/g, '""')}"`,
                `"${(candidate.ExpectedCTC || '').replace(/"/g, '""')}"`,
                `"${(candidate.NoticePeriod || '').replace(/"/g, '""')}"`,
                `"${(candidate.ResumeLink || '').replace(/"/g, '""')}"`
            ].join(',');
        });
        
        // Create CSV content
        const csvContent = [headers.join(','), ...rows].join('\n');
        
        // Create download link
        const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
        const link = document.createElement('a');
        const url = URL.createObjectURL(blob);
        
        link.setAttribute('href', url);
        link.setAttribute('download', `candidates_${new Date().getTime()}.csv`);
        link.style.visibility = 'hidden';
        
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        
        // Show success toast
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: 'CSV file downloaded successfully',
            variant: 'success'
        }));
    }*/
}