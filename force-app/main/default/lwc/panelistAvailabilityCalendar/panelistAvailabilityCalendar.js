import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CurrentPageReference } from 'lightning/navigation';


// Apex methods
import createAvailability from '@salesforce/apex/PanelistAvailabilityController.createAvailability';
import getLoggedInContactId from '@salesforce/apex/PanelistAvailabilityController.getLoggedInContactId';
import sendAvailabilityLink from '@salesforce/apex/PanelistAvailabilityControllers.sendAvailabilityLink';
export default class PanelistAvailabilityCalendar extends LightningElement {
    @api recordId;
    @api contactId; // From URL or logged-in user

    currentDate = new Date();
    currentMonth;
    currentYear;

    calendarDays = [];
    selectedDates = []; 

    fromTime;
    toTime;
    timeOptions = [];
    timeSlots = [];

    rangeMode = 'custom'; // 'custom' | '7' | '30'
    
    generatedLink = '';
    message = '';
    messageType = ''; // 'success' or 'error'
    isLoading = false;

    /* ================= EFFECTIVE CONTACT ID ================= */

    get effectiveContactId() {
        return this.contactId || this.recordId;
    }

     /* ================= PAGE REF (URL CONTACT ID) ================= */

    @wire(CurrentPageReference)
    handlePageRef(pageRef) {
        if (pageRef?.state?.contactId) {
            this.contactId  = pageRef.state.contactId;
            console.log('ContactId from URL 👉', this.contactId );
        }
    }

    /* ================= CONNECTED ================= */

    connectedCallback() {
        this.currentMonth = this.currentDate.getMonth();
        this.currentYear = this.currentDate.getFullYear();
        this.generateCalendar();
        this.generateTimeOptions();

        console.log('Initial contactId 👉', this.effectiveContactId);

        // If contactId NOT present in URL, fallback to logged-in user
        if (!this.contactId) {
            getLoggedInContactId()
                .then(id => {
                    this.contactId  = id;
                    console.log('Portal ContactId 👉', this.contactId);
                })
                .catch(error => {
                    console.error('Error getting logged-in contact 👉', error);
                    this.showToast(
                        'Error',
                        'Unable to identify contact',
                        'error'
                    );
                });
        }
    }

    /* ================= GETTERS ================= */

    get customVariant() {
        return this.rangeMode === 'custom' ? 'brand' : 'neutral';
    }

    get sevenVariant() {
        return this.rangeMode === '7' ? 'brand' : 'neutral';
    }

    get thirtyVariant() {
        return this.rangeMode === '30' ? 'brand' : 'neutral';
    }

    get hasSlots() {
        return this.timeSlots.length > 0;
    }

    get canSendLink() {
        return this.selectedDates.length > 0 && this.timeSlots.length > 0 && this.effectiveContactId;
    }

    get monthLabel() {
        return new Date(this.currentYear, this.currentMonth)
            .toLocaleString('default', { month: 'long', year: 'numeric' });
    }

    get messageClass() {
        return this.messageType === 'success' ? 'message-success' : 'message-error';
    }

    get messageIcon() {
        return this.messageType === 'success' ? 'utility:success' : 'utility:error';
    }

    /* ================= CALENDAR ================= */

    generateCalendar() {
        this.calendarDays = [];

        const firstDay = new Date(this.currentYear, this.currentMonth, 1).getDay();
        const totalDays = new Date(this.currentYear, this.currentMonth + 1, 0).getDate();

        const today = new Date();
        today.setHours(0, 0, 0, 0);

        for (let i = 0; i < firstDay; i++) {
            this.calendarDays.push({
                key: `e-${i}`,
                empty: true,
                cssClass: 'day-box empty'
            });
        }

        for (let d = 1; d <= totalDays; d++) {
            const dateObj = new Date(this.currentYear, this.currentMonth, d);
            dateObj.setHours(0, 0, 0, 0);

            const isoDate =
                `${this.currentYear}-${String(this.currentMonth + 1).padStart(2, '0')}-${String(d).padStart(2, '0')}`;

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

    selectNextDays(days) {
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        const dates = [];

        for (let i = 0; i < days; i++) {
            const d = new Date(today);
            d.setDate(today.getDate() + i);

            const iso =
                `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;

            dates.push(iso);
        }

        this.currentMonth = today.getMonth();
        this.currentYear = today.getFullYear();

        this.selectedDates = dates;
        this.generateCalendar();
    }

    handleCustomDates() {
        this.rangeMode = 'custom';
        this.selectedDates = [];
        this.generateCalendar();
    }

    handle7Days() {
        this.rangeMode = '7';
        this.selectNextDays(7);
    }

    handle30Days() {
        this.rangeMode = '30';
        this.selectNextDays(30);
    }

    handleDateClick(e) {
        const date = e.currentTarget.dataset.date;
        if (!date) return;

        this.rangeMode = 'custom';

        if (this.selectedDates.includes(date)) {
            this.selectedDates = this.selectedDates.filter(d => d !== date);
        } else {
            this.selectedDates = [...this.selectedDates, date];
        }

        this.generateCalendar();
    }

    /* ================= TIME ================= */

    generateTimeOptions() {
        const options = [];
        let minutes = 0;

        while (minutes < 1440) {
            const h = Math.floor(minutes / 60);
            const m = minutes % 60;

            options.push({
                label: this.formatTimeLabel(h, m),
                value: `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`
            });

            minutes += 15;
        }

        this.timeOptions = options;
    }

    formatTimeLabel(h, m) {
        const period = h >= 12 ? 'PM' : 'AM';
        const dh = h % 12 || 12;
        return `${String(dh).padStart(2, '0')}:${String(m).padStart(2, '0')} ${period}`;
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

    /* ================= ADD SLOT ================= */

    handleAddSlot() {
        if (!this.fromTime || !this.toTime) {
            this.showToast('Missing Time Selection', 'Select Please select both start time and end time before adding a slot.', 'error');
            return;
        }

        if (this.fromTime >= this.toTime) {
            this.showToast('Invalid Time Range', 'Start time must be earlier than end time. Please adjust your selection.', 'error');
            return;
        }

        const overlap = this.timeSlots.some(
            s => this.fromTime < s.to && this.toTime > s.from
        );

        if (overlap) {
            this.showToast('Overlapping Time Slot', 
                           'The selected time range overlaps with an existing slot. Please choose a different time.', 
                           'error');
            return;
        }

        this.timeSlots = [
            ...this.timeSlots,
            {
                id: Date.now(),
                from: this.fromTime,
                to: this.toTime,
                label: `${this.formatTime(this.fromTime)} – ${this.formatTime(this.toTime)}`
            }
        ];

        this.fromTime = null;
        this.toTime = null;
    }

    handleRemoveSlot(event) {
        const slotId = Number(event.currentTarget.dataset.id);
        this.timeSlots = this.timeSlots.filter(slot => slot.id !== slotId);
    }

    /* ================= SAVE AVAILABILITY ================= */

    handleSaveAvailability() {
        console.log('Final contactId before save 👉', this.effectiveContactId);

        if (!this.effectiveContactId) {
            this.showToast('Error', 'Contact not found for this user', 'error');
            return;
        }

        if (!this.selectedDates.length || !this.timeSlots.length) {
            this.showToast('Error', 'Select dates and slots', 'error');
            return;
        }

        const payload = this.preparePayload();

        createAvailability({
            contactId: this.effectiveContactId,
            slots: payload
        })
        .then(() => {
            this.showToast('Time Slot Added', 'Your availability slot has been added successfully.', 'success');
            this.showMessage('Availability saved successfully!', 'success');
            this.selectedDates = [];
            this.timeSlots = [];
            this.generateCalendar();
        })
        .catch(err => {
            console.error(err);
            this.showToast('Error', err.body?.message || 'Error', 'error');
            this.showMessage('Error: ' + (err.body?.message || 'Error'), 'error');
        });
    }

    /* ================= REQUEST LINK ================= */

    handleRequestLink() {
        console.log('Sending availability link via email for contactId 👉', this.contactId);

        if (!this.effectiveContactId) {
            this.showToast('Error', 'Contact not found', 'error');
            return;
        }

        if (!this.selectedDates.length || !this.timeSlots.length) {
            this.showToast('Error', 'Select dates and slots', 'error');
            return;
        }

        this.isLoading = true;

        const payload = this.preparePayload();

        sendAvailabilityLink({  
            contactId: this.effectiveContactId,
            slots: payload
        })
        .then(result => {
            this.showToast('Success', result, 'success');
            this.showMessage('Email sent successfully!', 'success');
            
            // Clear the form after successful email
            this.selectedDates = [];
            this.timeSlots = [];
            this.generateCalendar();
        })
        .catch(err => {
            console.error(err);
            this.showToast('Error', err.body?.message || 'Error sending email', 'error');
            this.showMessage('Error: ' + (err.body?.message || 'Error sending email'), 'error');
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

   
    /* ================= UTILITY METHODS ================= */

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

    showMessage(msg, type) {
        this.message = msg;
        this.messageType = type;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ 
            title, 
            message, 
            variant 
        }));
    }
}