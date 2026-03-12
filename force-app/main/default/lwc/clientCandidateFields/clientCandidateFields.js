import { LightningElement, api, track, wire } from 'lwc';
import getCandidateFieldOptions from '@salesforce/apex/ClientCandidateFieldsController.getCandidateFieldOptions';
import getClientCandidateFields from '@salesforce/apex/ClientCandidateFieldsController.getClientCandidateFields';
import saveClientCandidateFields from '@salesforce/apex/ClientCandidateFieldsController.saveClientCandidateFields';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { FlowNavigationFinishEvent } from 'lightning/flowSupport';


export default class ClientCandidateFields extends LightningElement {
    @api recordId;

    @track options = [];
    @track filteredOptions = [];
    @track selectedValues = [];
    @track selectedLabels = [];

    optionsLoaded = false;
    valuesLoaded = false;


    isLoading = true;
    isSaving = false;
    showModal = false;
    searchTerm = '';

    wiredSelectedResult;
    dragIndex = null;

    // Fetch available candidate fields
    @wire(getCandidateFieldOptions)
    wiredOptions({ data, error }) {
        if (data) {
            this.options = data.map(f => ({
                label: f.label,
                value: f.value
            }));
            this.filteredOptions = [...this.options];
            this.optionsLoaded = true;

            this.tryUpdateSelectedLabels();
        } else if (error) {
            this.showToast('Error', error.body?.message, 'error');
        }
    }



    // Fetch selected fields for the client
    @wire(getClientCandidateFields, { clientId: '$recordId' })
    wiredSelected(result) {
        this.wiredSelectedResult = result;
        const { data, error } = result;

        if (data) {
            this.selectedValues = data.split(',');
            this.valuesLoaded = true;

            this.tryUpdateSelectedLabels();
        } else if (error) {
            this.showToast('Error', error.body?.message, 'error');
        }

        this.isLoading = false;
    }


    // Open / Close Modal
    openModal() {
        this.showModal = true;
        this.searchTerm = '';
        this.filteredOptions = this.getFilteredOptions();
    }

    closeModal() {
        this.showModal = false;
    }

    saveModalSelection() {
        this.showModal = false;
        this.updateSelectedLabels();
    }

    handleChange(event) {
        this.selectedValues = event.detail.value;
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value.toLowerCase();
        this.filteredOptions = this.getFilteredOptions();
    }

    getFilteredOptions() {
        const selectedSet = new Set(this.selectedValues);

        // Unselected options that match search
        const filteredUnselected = this.options.filter(opt =>
            !selectedSet.has(opt.value) &&
            opt.label.toLowerCase().includes(this.searchTerm)
        );

        // Selected options always visible
        const selectedOptions = this.options.filter(opt => selectedSet.has(opt.value));

        return [...selectedOptions, ...filteredUnselected];
    }

    tryUpdateSelectedLabels() {
        if (!this.optionsLoaded || !this.valuesLoaded) {
            return;
        }

        this.selectedLabels = this.selectedValues.map(val => {
            const match = this.options.find(opt => opt.value === val);
            return match ? match.label : val;
        });
    }


    // Drag & Drop
    handleDragStart(event) {
        this.dragIndex = event.target.dataset.index;
    }

    handleDragOver(event) {
        event.preventDefault();
    }

    handleDrop(event) {
        const dropIndex = event.target.dataset.index;
        if (this.dragIndex === null || dropIndex === undefined) return;

        const tempLabels = [...this.selectedLabels];
        const tempValues = [...this.selectedValues];

        const movedLabel = tempLabels.splice(this.dragIndex, 1)[0];
        tempLabels.splice(dropIndex, 0, movedLabel);

        const movedValue = tempValues.splice(this.dragIndex, 1)[0];
        tempValues.splice(dropIndex, 0, movedValue);

        this.selectedLabels = tempLabels;
        this.selectedValues = tempValues;
        this.dragIndex = null;
    }

    handleSave() {
        this.isSaving = true;
        saveClientCandidateFields({
            clientId: this.recordId,
            selectedFields: this.selectedValues.join(',')
        })
            .then(() => {
                this.showToast('Success', 'Configuration saved successfully.', 'success');
                this.dispatchEvent(new FlowNavigationFinishEvent());
                return refreshApex(this.wiredSelectedResult);
            })
            .catch(err => {
                this.showToast('Error', err.body?.message, 'error');
            })
            .finally(() => {
                this.isSaving = false;
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}