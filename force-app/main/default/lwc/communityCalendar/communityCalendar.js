import { LightningElement, wire,api } from 'lwc';
import getUserEvents from '@salesforce/apex/CommunityCalendarController.getUserEvents';
import { loadScript, loadStyle } from 'lightning/platformResourceLoader';
import FULL_CALENDAR from '@salesforce/resourceUrl/fullcalendar'; // Static Resource

export default class CommunityCalendar extends LightningElement {
     @api recordId; 
    events = [];
    calendarInitialized = false;

    @wire(getUserEvents)
    wiredEvents({ data, error }) {
        if (data) {
            this.events = data.map(e => ({
                id: e.Id,
                title: e.Subject,
                start: e.StartDateTime,
                end: e.EndDateTime
            }));
            this.initializeCalendar();
        } else if (error) {
            console.error('Error fetching events:', error);
        }
    }

    renderedCallback() {
        if (this.calendarInitialized) return;
        Promise.all([
            loadScript(this, FULL_CALENDAR + '/fullcalendar.min.js'),
            loadStyle(this, FULL_CALENDAR + '/fullcalendar.min.css')
        ])
        .then(() => {
            this.calendarInitialized = true;
            this.initializeCalendar();
        })
        .catch(error => {
            console.error('Error loading FullCalendar:', error);
        });
    }

    initializeCalendar() {
        if (this.calendarInitialized && this.events.length) {
            const calendarEl = this.template.querySelector('.calendar');
            const calendar = new FullCalendar.Calendar(calendarEl, {
                initialView: 'dayGridMonth',
                headerToolbar: {
                    left: 'prev,next today',
                    center: 'title',
                    right: 'dayGridMonth,timeGridWeek,timeGridDay'
                },
                events: this.events
            });
            calendar.render();
        }
    }
}