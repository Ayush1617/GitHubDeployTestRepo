// File: availabilityRequester.js
import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
//import requestAvailability from '@salesforce/apex/PanelistAvailabilityControllers.requestAvailability';
import createAvailability from '@salesforce/apex/PanelistAvailabilityControllers.createAvailability';

export default class AvailabilityRequester extends LightningElement {
    @api recordId; // Contact Id when placed on contact page

    currentDate = new Date();
    currentMonth;
    currentYear;

    calendarDays = [];
    selectedDates = [];

    fromTime;
    toTime;
    timeOptions = [];
    timeSlots = [];
    
    generatedLink = '';
    message = '';
    messageType = ''; // 'success' or 'error'
    isLoading = false;

    connectedCallback() {
        this.currentMonth = this.currentDate.getMonth();
        this.currentYear = this.currentDate.getFullYear();
        this.generateCalendar();
        this.generateTimeOptions();
    }

    /* ================= CALENDAR METHODS ================= */
    get monthLabel() {
        return new Date(this.currentYear, this.currentMonth)
            .toLocaleString('default', { month: 'long', year: 'numeric' });
    }

    generateCalendar() {
        this.calendarDays = [];

        const firstDay = new Date(this.currentYear, this.currentMonth, 1).getDay();
        const totalDays = new Date(this.currentYear, this.currentMonth + 1, 0).getDate();

        const today = new Date();
        today.setHours(0,0,0,0);

        for (let i = 0; i < firstDay; i++) {
            this.calendarDays.push({
                key: `e-${i}`,
                empty: true,
                cssClass: 'day-box empty'
            });
        }

        for (let d = 1; d <= totalDays; d++) {
            const dateObj = new Date(this.currentYear, this.currentMonth, d);
            dateObj.setHours(0,0,0,0);

            const isoDate = `${this.currentYear}-${String(this.currentMonth+1).padStart(2,'0')}-${String(d).padStart(2,'0')}`;

            let cssClass = 'day-box';
            if (dateObj < today) cssClass += ' disabled';
            if (this.selectedDates.includes(isoDate)) cssClass += ' selected';

            this.calendarDays.push({
                key: isoDate,
                day: d,
                isoDate,
                empty: false,
                cssClass
            });
        }
    }

    prevMonth() {
        this.currentMonth--;
        if (this.currentMonth < 0) {
            this.currentMonth = 11;
            this.currentYear--;
        }
        this.generateCalendar();
    }

    nextMonth() {
        this.currentMonth++;
        if (this.currentMonth > 11) {
            this.currentMonth = 0;
            this.currentYear++;
        }
        this.generateCalendar();
    }

    handleDateClick(e) {
        const date = e.currentTarget.dataset.date;
        if (!date) return;

        if (this.selectedDates.includes(date)) {
            this.selectedDates = this.selectedDates.filter(d => d !== date);
        } else {
            this.selectedDates = [...this.selectedDates, date];
        }
        this.generateCalendar();
    }

    /* ================= TIME METHODS ================= */
    get hasSlots() {
        return this.timeSlots.length > 0;
    }

    get canSave() {
        return this.selectedDates.length > 0 && this.timeSlots.length > 0;
    }

    generateTimeOptions() {
        const options = [];
        let minutes = 0;

        while (minutes < 1440) {
            const h = Math.floor(minutes / 60);
            const m = minutes % 60;
            options.push({
                label: this.formatTimeLabel(h, m),
                value: `${String(h).padStart(2,'0')}:${String(m).padStart(2,'0')}`
            });
            minutes += 15;
        }
        this.timeOptions = options;
    }

    formatTimeLabel(h, m) {
        const period = h >= 12 ? 'PM' : 'AM';
        const dh = h % 12 || 12;
        return `${String(dh).padStart(2,'0')}:${String(m).padStart(2,'0')} ${period}`;
    }

    formatTime(value) {
        const [h, m] = value.split(':');
        return this.formatTimeLabel(Number(h), Number(m));
    }

    handleFromTimeChange(e) {
        this.fromTime = e.detail.value;
    }

    handleToTimeChange(e) {
        this.toTime = e.detail.value;
    }

    /* ================= SLOT MANAGEMENT ================= */
    handleAddSlot() {
        if (!this.fromTime || !this.toTime) {
            this.showMessage('Please select both start and end times', 'error');
            return;
        }

        if (this.fromTime >= this.toTime) {
            this.showMessage('Start time must be before end time', 'error');
            return;
        }

        const overlap = this.timeSlots.some(
            s => this.fromTime < s.to && this.toTime > s.from
        );
        if (overlap) {
            this.showMessage('This time slot overlaps with an existing slot', 'error');
            return;
        }

        const newSlot = {
            id: Date.now(),
            from: this.fromTime,
            to: this.toTime,
            label: `${this.formatTime(this.fromTime)} – ${this.formatTime(this.toTime)}`
        };

        this.timeSlots = [...this.timeSlots, newSlot];
        this.fromTime = null;
        this.toTime = null;
        
        this.showMessage('Time slot added', 'success');
    }

    handleRemoveSlot(event) {
        const slotId = parseInt(event.currentTarget.dataset.id);
        this.timeSlots = this.timeSlots.filter(slot => slot.id !== slotId);
    }

    handleClearAll() {
        this.selectedDates = [];
        this.timeSlots = [];
        this.generatedLink = '';
        this.message = '';
        this.generateCalendar();
    }

    /* ================= SAVE METHODS ================= */
    handleSaveDirectly() {
        if (!this.canSave) {
            this.showMessage('Please select dates and add time slots', 'error');
            return;
        }

        this.isLoading = true;
        
        const payload = this.preparePayload();
        
        createAvailability({
            contactId: this.recordId,
            slots: payload
        })
        .then(() => {
            this.showMessage('Availability saved directly as events', 'success');
            this.showToast('Success', 'Events created successfully', 'success');
            this.handleClearAll();
        })
        .catch(err => {
            this.showMessage('Error: ' + (err.body?.message || 'Unknown error'), 'error');
            this.showToast('Error', err.body?.message || 'Error', 'error');
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    handleRequestLink() {
        if (!this.canSave) {
            this.showMessage('Please select dates and add time slots', 'error');
            return;
        }

        this.isLoading = true;
        
        const payload = this.preparePayload();
        
        requestAvailability({
            contactId: this.recordId,
            slots: payload
        })
        .then(link => {
            this.generatedLink = link;
            this.showMessage('Link generated successfully! Share it with the contact.', 'success');
            this.showToast('Success', 'Availability link generated', 'success');
        })
        .catch(err => {
            this.showMessage('Error: ' + (err.body?.message || 'Unknown error'), 'error');
            this.showToast('Error', err.body?.message || 'Error', 'error');
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    preparePayload() {
        const payload = [];
        this.selectedDates.forEach(date => {
            this.timeSlots.forEach(slot => {
                payload.push({
                    availabilityDate: date,
                    startTime: slot.from,
                    endTime: slot.to
                });
            });
        });
        return payload;
    }

    /* ================= LINK MANAGEMENT ================= */
    copyToClipboard() {
        navigator.clipboard.writeText(this.generatedLink)
            .then(() => {
                this.showToast('Copied!', 'Link copied to clipboard', 'success');
            })
            .catch(() => {
                // Fallback
                const input = this.template.querySelector('lightning-input');
                input.select();
                document.execCommand('copy');
                this.showToast('Copied!', 'Link copied to clipboard', 'success');
            });
    }

    sendEmail() {
        // Simple email template
        const subject = 'Interview Availability Request';
        const body = `Dear Contact,\n\nPlease use the link below to provide your availability:\n${this.generatedLink}\n\nThank you!`;
        window.location.href = `mailto:?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
    }

    /* ================= UTILITY METHODS ================= */
    showMessage(msg, type) {
        this.message = msg;
        this.messageType = type;
        
        // Clear message after 5 seconds
        setTimeout(() => {
            this.message = '';
            this.messageType = '';
        }, 5000);
    }

    get messageClass() {
        return this.messageType === 'success' ? 'message-success' : 'message-error';
    }

    get messageIcon() {
        return this.messageType === 'success' ? 'utility:success' : 'utility:error';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ 
            title, 
            message, 
            variant 
        }));
    }
}