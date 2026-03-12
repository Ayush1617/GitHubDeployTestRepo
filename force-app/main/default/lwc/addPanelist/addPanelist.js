import { LightningElement, wire, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { encodeDefaultFieldValues } from 'lightning/pageReferenceUtils';
import { getRecord } from 'lightning/uiRecordApi';
import { updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';


// Apex
import getPanelistsWithEventCount from '@salesforce/apex/AddPanelist.getPanelistsWithEventCount';
import getEventsByPanelist from '@salesforce/apex/AddPanelist.getEventsByPanelist';
import { CurrentPageReference } from 'lightning/navigation';

const FIELDS = [
    'Interview_Request__c.Candidate_Name__c',
    'Interview_Request__c.Job_Position__c',
    'Interview_Request__c.Feedback__c',
     'Interview_Request__c.Interview_Status__c'
];

export default class AddPanelist extends NavigationMixin(LightningElement) {
    @api recordId;
    groupedEvents = [];
    panelists = [];
    events = [];
    selectedSlotId = null;
selectedSlotDateTime = null;

    isModalOpen = false;
    isRequestSlotsModalOpen = false;
    
    selectedPanelistId;
    selectedPanelistName;
    candidateId;
    jobPositionId;
     interviewFeedback;
    interviewStatus;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredParent({ data, error }) {
        if (data) {
            this.candidateId = data.fields.Candidate_Name__c?.value;
            console.log('this.candidateId => ', this.candidateId);
            this.jobPositionId = data.fields.Job_Position__c?.value;
            console.log('this.jobPositionId => ', this.jobPositionId);
             this.interviewFeedback = data.fields.Feedback__c?.value;
             this.interviewStatus  = data.fields.Interview_Status__c?.value;
            console.log('this.interviewFeedback : ',this.interviewFeedback);
        } else if (error) {
            console.error('Parent fetch error', error);
        }
    }

     @wire(CurrentPageReference)
getStateParameters(pageRef) {
    if (pageRef) {
        this.recordId = pageRef.attributes?.recordId 
                     || pageRef.state?.recordId;

    }
}

handleFeedbackChange(event) {
    this.interviewFeedback = event.target.value;
}
get helpTextMessage() {
    return `Please provide the feedback of current interview status — ${this.interviewStatus}`;
}
get isInterviewLocked() {
    const lockedStatuses = [
        'Internal Assessment',
        'Shortlisted',
        'Interviewing',
        'Offered',
        'Hired',
        'Rejected'
    ];

    return lockedStatuses.includes(this.interviewStatus);
}


    @wire(getPanelistsWithEventCount)
    wiredPanelists({ data, error }) {
        if (data) {
            this.panelists = data;
        } else if (error) {
            console.error('Panelist load error', error);
        }
    }

    // Open modal to view existing slots
    openModal(event) {
        this.selectedPanelistId = event.currentTarget.dataset.id;
        this.selectedPanelistName = event.currentTarget.dataset.name;
        this.isModalOpen = true;
        this.events = [];
        
         console.log('this.selectedPanelistId : ',this.selectedPanelistId);

        getEventsByPanelist({ panelistId: this.selectedPanelistId })
            .then(result => {
                this.events = result;
                console.log('this.events print' , this.events);
                this.groupedEvents = this.groupByDate(result);
                console.log('  this.groupedEventsprint' ,  this.groupedEvents);

            })
            .catch(error => {
                console.error('Slot fetch error', error);
                this.events = [];
            });
    }

    // Open modal to request new slots
    openRequestSlotsModal(event) {
        this.selectedPanelistId = event.currentTarget.dataset.id;
        this.selectedPanelistName = event.currentTarget.dataset.name;
        this.isRequestSlotsModalOpen = true;
    }

    // Book existing slot
    handleBook(event) {
        console.log('Book : ');
        const eventDate = event.currentTarget.dataset.date;
        const eventDateTime = event.currentTarget.dataset.datetime;
        console.log('eventDateTime : ',this.selectedSlotDateTime);
        console.log('eventDate : ',this.selectedSlotDateTime);
         console.log('this.selectedPanelistId : ',this.selectedPanelistId);
          console.log('eventDate : ',eventDate);
         console.log('this.selectedPanelistName : ',this.selectedPanelistName);

          if ( 
            !this.selectedPanelistName || !this.selectedSlotDateTime  ) {
            console.error('Missing required data');
            return;
        }

        console.log('eventDateTime : ',eventDateTime);
        console.log('eventDate : ',eventDate);
         console.log('this.selectedPanelistId : ',this.selectedPanelistName);

             

    const selectedDate = new Date(this.selectedSlotDateTime);
    const now = new Date();

    // Past date check
    if (selectedDate <= now) {

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Warning',
                message: 'Interview Date cannot be a past date/time',
                variant: 'warning'
            })
        );

        return; // 🚫 Stop execution
    }


let dt = new Date(this.selectedSlotDateTime);

        // fields to update
    let fields = {};
    fields['Id'] = this.recordId;
    fields['Interviewer__c'] = this.selectedPanelistName;
    //fields['Interview_Date_Time__c'] = eventDateTime;
    fields['Interview_Date__c'] = dt.toISOString();
    fields['Interview_Status__c'] = 'Internal Assessment';
    fields['Interview_Mode__c'] = 'Online';
    fields['Feedback__c'] = this.interviewFeedback;

    let recordInput = { fields };
     console.log('recordInput : ',JSON.stringify(recordInput));

    updateRecord(recordInput)
        .then(() => {

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Interview updated successfully',
                    variant: 'success'
                })
            );

            // open record after update
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.recordId,
                    objectApiName: 'Interview__c',
                    actionName: 'view'
                }
            });

           this.isModalOpen = false; 

        })
        
        .catch(error => {
            console.error('FULL ERROR => ', JSON.stringify(error));
    console.error('BODY => ', JSON.stringify(error.body));
    console.error('MESSAGE => ', error.body?.message);
        });
    }

    /*if (!this.candidateId || !this.jobPositionId || 
        !this.selectedPanelistId || !this.selectedSlotDateTime) {
        console.error('Missing required data');
        return;
    }

    const defaultValues = encodeDefaultFieldValues({
        Candidate_Name__c: this.candidateId,
        Job_Position__c: this.jobPositionId,
        Interviewer__c: this.selectedPanelistId,
        Interview_Date_Time__c: this.selectedSlotDateTime,
        Interview_Date__c: this.selectedSlotDateTime,
        Interview_Status__c: 'Internal Assessment',
        Interview_Mode__c: 'Online'
    });

    this.isModalOpen = false;

    this[NavigationMixin.Navigate]({
        type: 'standard__objectPage',
        attributes: {
            objectApiName: 'Interview__c',
            actionName: 'new'
        },
        state: {
            defaultFieldValues: defaultValues
        }
    });
 }*/
    
    // Close view slots modal
    closeModal() {
        this.isModalOpen = false;
        this.events = [];
        this.groupedEvents = [];  

        this.selectedPanelistId = null;
        this.selectedPanelistName = null;
    }

    // Close request slots modal
    closeRequestSlotsModal() {
        this.isRequestSlotsModalOpen = false;
        this.selectedPanelistId = null;
        this.selectedPanelistName = null;
    }
formatTime(start, end) {
    const s = new Date(start);
    const e = new Date(end);

    return `${s.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })} - 
            ${e.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`;
}
groupByDate(events) {
    const map = {};

    events.forEach(e => {
        if (!map[e.ActivityDate]) {
            map[e.ActivityDate] = {
                date: e.ActivityDate,
                subject: e.Subject,
                slots: []
            };
        }

        map[e.ActivityDate].slots.push({
            Id: e.Id,
            StartDateTime: e.StartDateTime,
            EndDateTime: e.EndDateTime,
            timeLabel: this.formatTime(e.StartDateTime, e.EndDateTime),
            variant: 'outline-brand',
            showFeedback: false  
        });
    });

    return Object.values(map);
}
   handleSelectSlot(event) {
    const selectedId = event.currentTarget.dataset.id;
    const selectedDateTime = event.currentTarget.dataset.datetime;

    this.selectedSlotId = selectedId;
    this.selectedSlotDateTime = selectedDateTime;

    // Update button styles
    this.groupedEvents = this.groupedEvents.map(group => {
        return {
            ...group,
            slots: group.slots.map(slot => {
                return {
                    ...slot,
                    variant: slot.Id === selectedId ? 'brand' : 'outline-brand',
                    showFeedback: slot.Id === selectedId
                };
            })
        };
    });
}

}