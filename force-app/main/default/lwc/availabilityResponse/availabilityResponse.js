// File: availabilityResponse.js
import { LightningElement, track } from 'lwc';
import getAvailabilityRequest from '@salesforce/apex/PanelistAvailabilityControllers.getAvailabilityRequest';
import submitSelectedSlots from '@salesforce/apex/PanelistAvailabilityControllers.submitSelectedSlots';

export default class AvailabilityResponse extends LightningElement {
    @track isLoading = true;
    @track showForm = false;
    @track showSuccess = false;
    @track showError = false;
    @track contactName = '';
    @track contactEmail = '';
    @track slots = [];
    @track groupedSlots = [];
    @track isSubmitting = false;
    @track successMessage = '';
    @track errorMessage = '';
    
    token = '';

    connectedCallback() {
        // Extract token from URL
        const urlParams = new URLSearchParams(window.location.search);
        this.token = urlParams.get('token');
        
        console.log('Extracted token:', this.token);
        if (!this.token) {
            this.showErrorState('Invalid link. Please use the link provided in your email.');
            return;
        }
        console.log('Calling loadAvailabilityRequest with token:', this.token);
        this.loadAvailabilityRequest();
    }
    
    loadAvailabilityRequest() {
        console.log('loadAvailabilityRequest → START');
        console.log('Token value:', this.token);

        getAvailabilityRequest({ token: this.token })
            .then(result => {
                console.log('Apex response received:', JSON.stringify(result));

                if (result.isValid) {
                    console.log('Link is valid');

                    this.contactName = result.contactName;
                    this.contactEmail = result.contactEmail;
                    console.log('Contact Name set:', this.contactName);
                    console.log('Contact Email set:', this.contactEmail);

                    console.log('Raw slots from Apex:', result.slots);
                    this.slots = this.processSlots(result.slots);
                    console.log('Processed slots:', this.slots);

                    console.log('Grouping slots by date...');
                    this.groupSlotsByDate();

                    this.showForm = true;
                    console.log('Form visibility set to TRUE');
                } else {
                    console.warn('Link is invalid or expired');
                    console.warn('Error message:', result.message);

                    this.showErrorState(result.message || 'Link is invalid or expired.');
                }

                this.isLoading = false;
                console.log('Loading set to FALSE');
            })
            .catch(error => {
                console.error('Error occurred in getAvailabilityRequest');
                console.error('Error details:', error);

                if (error?.body?.message) {
                    console.error('Apex error message:', error.body.message);
                }

                this.showErrorState('Unable to load availability request. Please try again.');
                this.isLoading = false;

                console.log('Loading set to FALSE after error');
            });

        console.log('loadAvailabilityRequest → END (async call started)');
    }

    
    processSlots(slotsData) {
        return slotsData.map(slot => {
            const dateStr = slot.date;
            const date = new Date(dateStr);
            
            return {
                id: slot.id,
                date: dateStr,
                formattedDate: this.formatDate(date),
                dayOfWeek: this.getDayOfWeek(date),
                startTime: slot.startTime,
                endTime: slot.endTime,
                timeRange: this.formatTimeRange(slot.startTime, slot.endTime),
                duration: this.calculateDuration(slot.startTime, slot.endTime),
                selected: false
            };
        });
    }
    
    groupSlotsByDate() {
        const groups = {};
        
        this.slots.forEach(slot => {
            if (!groups[slot.date]) {
                groups[slot.date] = {
                    date: slot.date,
                    formattedDate: slot.formattedDate,
                    slots: []
                };
            }
            groups[slot.date].slots.push(slot);
        });
        
        // Convert to array and sort by date
        this.groupedSlots = Object.values(groups).sort((a, b) => 
            new Date(a.date) - new Date(b.date)
        );
    }
    
    formatDate(date) {
        return date.toLocaleDateString('en-US', { 
            month: 'short',
            day: 'numeric',
            year: 'numeric'
        });
    }
    
    getDayOfWeek(date) {
        return date.toLocaleDateString('en-US', { weekday: 'long' });
    }
    
    formatTimeRange(start, end) {
        const format = (timeStr) => {
            const [h, m] = timeStr.split(':');
            const hours = parseInt(h);
            const minutes = parseInt(m);
            const period = hours >= 12 ? 'PM' : 'AM';
            const displayHours = hours % 12 || 12;
            return `${displayHours}:${String(minutes).padStart(2, '0')} ${period}`;
        };
        
        return `${format(start)} - ${format(end)}`;
    }
    
    calculateDuration(start, end) {
        const [startH, startM] = start.split(':').map(Number);
        const [endH, endM] = end.split(':').map(Number);
        
        const startMinutes = startH * 60 + startM;
        const endMinutes = endH * 60 + endM;
        const durationMinutes = endMinutes - startMinutes;
        
        if (durationMinutes >= 60) {
            const hours = Math.floor(durationMinutes / 60);
            const minutes = durationMinutes % 60;
            return minutes > 0 ? `${hours}h ${minutes}m` : `${hours}h`;
        }
        return `${durationMinutes}m`;
    }
    
    handleSlotToggle(event) {
        const slotId = event.target.dataset.id;
        const checked = event.target.checked;
        
        // Update slot selection
        this.slots = this.slots.map(slot => 
            slot.id === slotId ? {...slot, selected: checked} : slot
        );
        
        // Update grouped slots
        this.groupSlotsByDate();
    }
    
    toggleAllSelection(event) {
        const checked = event.target.checked;
        this.slots = this.slots.map(slot => ({...slot, selected: checked}));
        this.groupSlotsByDate();
    }
    
    selectAll() {
        this.slots = this.slots.map(slot => ({...slot, selected: true}));
        this.groupSlotsByDate();
    }
    
    deselectAll() {
        this.slots = this.slots.map(slot => ({...slot, selected: false}));
        this.groupSlotsByDate();
    }
    
    get totalSlots() {
        return this.slots.length;
    }
    
    get selectedCount() {
        return this.slots.filter(slot => slot.selected).length;
    }
    
    get hasSelection() {
        return this.selectedCount > 0;
    }
    
    get hasSlots() {
        return this.slots.length > 0;
    }
    
    get allSelected() {
        return this.slots.length > 0 && this.slots.every(slot => slot.selected);
    }
    
    handleSubmit() {
        if (!this.hasSelection) {
            return;
        }
        
        this.isSubmitting = true;
        
        const selectedSlotIds = this.slots
            .filter(slot => slot.selected)
            .map(slot => slot.id);
        
        console.log('Submitting slots with token:', this.token);
        console.log('Selected slot IDs:', selectedSlotIds);
        
        submitSelectedSlots({
            token: this.token,
            selectedSlotIds: selectedSlotIds
        })
        .then(result => {
            console.log('Submission successful:', result);
            this.showForm = false;
            this.showSuccess = true;
            this.successMessage = result;
        })
        .catch(error => {
            console.error('Submission error:', error);
            this.showForm = false;
            this.showError = true;
            this.errorMessage = error.body?.message || 'Error submitting availability';
        })
        .finally(() => {
            this.isSubmitting = false;
        });
    }
    
    showErrorState(message) {
        this.isLoading = false;
        this.showError = true;
        this.errorMessage = message;
    }
}