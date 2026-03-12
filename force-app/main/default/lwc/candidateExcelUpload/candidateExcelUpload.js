// Updated JavaScript
import { LightningElement } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import SHEETJS from '@salesforce/resourceUrl/SheetJS';
import createCandidates from '@salesforce/apex/CandidateUploadController.createCandidates';

export default class CandidateExcelUpload extends LightningElement {
    file;
    isUploading = false;
    sheetJsInitialized = false;
    isOpen = true; // Main upload page is always open
    uploadResult = null;
    showResultModal = false;

    /* ================= GETTERS ================= */

    get showPreviousResult() {
        return this.uploadResult && !this.showResultModal;
    }

    get hasWarnings() {
        return this.uploadResult &&
            this.uploadResult.warnings &&
            this.uploadResult.warnings.length > 0;
    }

    get hasFailedRecords() {
        return this.uploadResult &&
            this.uploadResult.failedRecords &&
            this.uploadResult.failedRecords.length > 0;
    }

    get disableUpload() {
        return !this.file || this.isUploading;
    }

    get fileSize() {
        return this.file
            ? `${(this.file.size / 1024).toFixed(2)} KB`
            : '';
    }

    /* ================= LIFECYCLE ================= */

    renderedCallback() {
        if (this.sheetJsInitialized) return;
        this.sheetJsInitialized = true;

        loadScript(this, SHEETJS)
            .then(() => {
                console.log('SheetJS loaded successfully');
            })
            .catch(error => {
                console.error('SheetJS load error', error);
                this.showToast('Error', 'Failed to load Excel library', 'error');
            });
    }

    /* ================= FILE HANDLING ================= */

    handleFileUpload(event) {
        this.file = event.target.files[0];
        this.uploadResult = null;
        this.showResultModal = false;
    }

    removeFile() {
        this.file = null;
        this.uploadResult = null;
        const fileInput = this.template.querySelector('lightning-input');
        if (fileInput) {
            fileInput.value = null;
        }
    }

    handleUploadAnother() {
        this.showResultModal = false;
        this.file = null;
        this.uploadResult = null;
        const fileInput = this.template.querySelector('lightning-input');
        if (fileInput) {
            fileInput.value = null;
        }
    }

    /* ================= UPLOAD LOGIC ================= */

    async handleUpload() {
        if (!this.file) {
            this.showToast('Error', 'Please upload an Excel file', 'error');
            return;
        }

        this.isUploading = true;
        const reader = new FileReader();

        reader.onload = async () => {
            try {
                // Use window.XLSX
                const workbook = window.XLSX.read(reader.result, { type: 'binary' });
                const sheetName = workbook.SheetNames[0];
                const worksheet = workbook.Sheets[sheetName];

                const rows = window.XLSX.utils.sheet_to_json(worksheet, {
                    defval: null,
                    raw: false
                });

                const jsonData = rows
                    .map((row, index) => {
                        const cleanRow = {};
                        Object.keys(row).forEach(key => {
                            const cleanKey = key.replace(/\s+/g, ' ').trim();
                            const value = row[key];
                            cleanRow[cleanKey] = value !== null
                                ? String(value).trim()
                                : null;
                        });
                        cleanRow.rowNumber = index + 2;
                        return cleanRow;
                    })
                    .filter(row =>
                        Object.values(row).some(val => val && val !== 'rowNumber')
                    );

                if (!confirm(`You are about to process ${jsonData.length} candidate(s). Do you want to continue?`)) {
                    this.isUploading = false;
                    return;
                }

                createCandidates({ candidateData: jsonData })
                    .then(result => {
                        this.uploadResult = result;
                        this.showResultModal = true;

                        this.showToast(
                            'Upload Complete',
                            `Processed ${result.totalRecords} records`,
                            'success'
                        );
                    })
                    .catch(error => {
                        console.error('Upload error:', error);
                        this.showToast(
                            'Upload Failed',
                            error.body?.message || 'An error occurred during upload',
                            'error'
                        );
                    })
                    .finally(() => {
                        this.isUploading = false;
                        this.file = null;
                        const fileInput = this.template.querySelector('lightning-input');
                        if (fileInput) {
                            fileInput.value = null;
                        }
                    });

            } catch (e) {
                console.error('Excel parse error:', e);
                this.isUploading = false;
                this.showToast('Error', 'Failed to parse Excel file', 'error');
            }
        };

        reader.readAsBinaryString(this.file);
    }

    /* ================= TOAST ================= */

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }

    handleResultClose() {
        this.showResultModal = false;
        // Don't close the main page, just the result modal
    }

    /* ================= ERROR CSV DOWNLOAD ================= */

    downloadErrorReport() {
        if (!this.hasFailedRecords) {
            this.showToast('No Errors', 'There are no failed records to download', 'info');
            return;
        }

        try {
            const csvString = this.createCSVString(this.uploadResult.failedRecords);
            this.triggerCSVDownload(csvString, 'Candidate_Upload_Errors.csv');
        } catch (error) {
            console.error('Download error report failed:', error);
            this.showToast('Download Failed', 'Unable to download error report', 'error');
        }
    }

    createCSVString(errors) {
        let csv = 'Row Number,Email,Field,Error\n';

        errors.forEach(error => {
            csv += [
                error.rowNumber || '',
                this.escapeCSVField(error.email || ''),
                this.escapeCSVField(error.field || ''),
                this.escapeCSVField(error.error || '')
            ].join(',') + '\n';
        });

        return csv;
    }

    escapeCSVField(field) {
        if (field.includes(',') || field.includes('"') || field.includes('\n')) {
            return `"${field.replace(/"/g, '""')}"`;
        }
        return field;
    }

    triggerCSVDownload(csvContent, fileName) {
        const element = document.createElement('a');
        element.href = 'data:text/csv;charset=utf-8,' + encodeURI(csvContent);
        element.download = fileName;
        document.body.appendChild(element);
        element.click();
        document.body.removeChild(element);
    }
}