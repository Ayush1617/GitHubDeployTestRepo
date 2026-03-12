import { LightningElement, api, track } from 'lwc';
import getFromAddresses from '@salesforce/apex/CustomEmailComposerController.getFromAddresses';
import sendEmailNow from '@salesforce/apex/CustomEmailComposerController.sendEmailNow';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CustomEmailComposer extends LightningElement {
    @api recordId;
    //@track showModal = false;
    @api childstep;
    @api showInternalFooter = false;
   

    // FROM
    @track fromOptions = [];
    @track selectedFrom = null;
    @track showFromPopup = false;

    // RECIPIENTS
    @track toInput = '';
    @track ccInput = '';
    @track bccInput = '';
    @track toChips = [];
    @track ccChips = [];
    @track bccChips = [];
    showCc = false;
    showBcc = false;

    // SUBJECT & BODY
    @track subject = '';
    @track htmlBody = '';
    @track sendLabel = 'Send';

    // RELATED TO & JOB
    @track relatedToId = null;
    @track relatedToName = '';
    @track jobId = null;
    @track jobTitle = '';
    @track jobLocation = '';
    @track jobType = '';
    @track jobDescription = '';

    connectedCallback() {
        this.loadFromAddresses();
    }

    /* ---------------------------
       FROM ADDRESS LOGIC
    ---------------------------- */
    get selectedFromDisplay() {
        return this.selectedFrom
            ? `${this.selectedFrom.displayName} <${this.selectedFrom.address}>`
            : 'Select From Address';
    }

    buildRecipients(chips, inputValue) {
        const emails = [...chips];

        if (inputValue && inputValue.trim()) {
            const parsed = inputValue
                .split(/[,;]+/)
                .map(e => e.trim())
                .filter(e => e);

            parsed.forEach(e => {
                if (!emails.includes(e)) {
                    emails.push(e);
                }
            });
        }
        return emails;
    }

    loadFromAddresses() {
        getFromAddresses()
            .then(res => {
                this.fromOptions = res || [];
                const org = this.fromOptions.find(f => f.type === 'OrgWide');
                this.selectedFrom = org || this.fromOptions[0] || null;
            })
            .catch(err => {
                // Replaced console.error with a toast to handle error cleanly without violating lint rules
                this.toast('Error loading From addresses', err?.body?.message || err.message, 'error');
            });
    }

    toggleFromPopup() {
        this.showFromPopup = !this.showFromPopup;
    }

    handleFromSelect(e) {
        const id = e.currentTarget.dataset.id;
        this.selectedFrom = this.fromOptions.find(x => x.id === id);
        this.showFromPopup = false;
    }

    /* ---------------------------
       INPUT HANDLERS
    ---------------------------- */
    focusToInput() {
        const input = this.template.querySelector('.pill-input');
        if (input) {
            input.focus();
        }
    }

    handleToInputChange(e) {
        this.toInput = e.target.value;
    }
    handleCcInputChange(e) {
        this.ccInput = e.target.value;
    }
    handleBccInputChange(e) {
        this.bccInput = e.target.value;
    }

    handleToInputKeyUp(e) {
        if (e.key === 'Enter' || e.key === ',') {
            this.addChips('to');
        }
    }
    handleCcInputKeyUp(e) {
        if (e.key === 'Enter' || e.key === ',') {
            this.addChips('cc');
        }
    }
    handleBccInputKeyUp(e) {
        if (e.key === 'Enter' || e.key === ',') {
            this.addChips('bcc');
        }
    }

    addChips(type) {
        // Map the type to the correct input value
        const inputs = {
            to: this.toInput,
            cc: this.ccInput,
            bcc: this.bccInput
        };

        // Use const to satisfy the linter
        const raw = inputs[type];

        if (!raw || !raw.trim()) {
            return;
        }

        const emails = raw
            .split(/[,;]+/)
            .map(e => e.trim())
            .filter(e => e);

        if (type === 'to') {
            const newEmails = emails.filter(e => !this.toChips.includes(e));
            this.toChips = [...this.toChips, ...newEmails];
            this.toInput = '';

        } else if (type === 'cc') {
            const newEmails = emails.filter(e => !this.ccChips.includes(e));
            this.ccChips = [...this.ccChips, ...newEmails];
            this.ccInput = '';

        } else if (type === 'bcc') {
            const newEmails = emails.filter(e => !this.bccChips.includes(e));
            this.bccChips = [...this.bccChips, ...newEmails];
            this.bccInput = '';
        }
    }

    removeChip(e) {
        const type = e.currentTarget.dataset.type;
        const value = e.currentTarget.dataset.value;

        if (type === 'to') {
            this.toChips = this.toChips.filter(c => c !== value);
        } else if (type === 'cc') {
            this.ccChips = this.ccChips.filter(c => c !== value);
        } else if (type === 'bcc') {
            this.bccChips = this.bccChips.filter(c => c !== value);
        }
    }

    toggleCc() {
        this.showCc = !this.showCc;
    }
    toggleBcc() {
        this.showBcc = !this.showBcc;
    }

    handleSubjectChange(e) {
        this.subject = e.target.value;
    }

    handleBodyChange(e) {
        this.htmlBody = e.detail?.value || e.target.value;
    }

    /* ---------------------------
       PREFILL FROM PARENT
    ---------------------------- */
    @api
    openWithPrefill(prefill = {}) {
        this.resetForm(false);

        if (prefill.toAddresses) {
            const arr =
                typeof prefill.toAddresses === 'string'
                    ? prefill.toAddresses.split(/[,;]+/).map(e => e.trim())
                    : prefill.toAddresses;
            this.toChips = arr;
        }

        if (prefill.subject) this.subject = prefill.subject;
        if (prefill.htmlBody) this.htmlBody = prefill.htmlBody;

        if (prefill.relatedToId) this.relatedToId = prefill.relatedToId;
        if (prefill.relatedToName) this.relatedToName = prefill.relatedToName;

        this.jobId = prefill.jobId || null;
        this.jobTitle = prefill.jobTitle || '';
        this.jobLocation = prefill.jobLocation || '';
        this.jobType = prefill.jobType || '';
        this.jobDescription = prefill.jobDescription || '';

       // this.showModal = true;
    }

    /* ---------------------------
       RESET & CLOSE
    ---------------------------- */
   

    resetForm(resetFrom = true) {
        this.toInput = '';
        this.ccInput = '';
        this.bccInput = '';
        this.toChips = [];
        this.ccChips = [];
        this.bccChips = [];

        this.subject = '';
        this.htmlBody = '';

        if (resetFrom) {
            this.selectedFrom =
                this.fromOptions.find(f => f.type === 'OrgWide') ||
                this.fromOptions[0] ||
                null;
        }

        this.showFromPopup = false;
        this.showCc = false;
        this.showBcc = false;

        this.relatedToId = null;
        this.relatedToName = '';
    }

    /* ---------------------------
       SEND EMAIL
    ---------------------------- */
    handleSend() {
        //remove console log statements

    this.addChips('to');
    this.addChips('cc');
    this.addChips('bcc');

    if (!this.toChips.length && !this.ccChips.length && !this.bccChips.length) {
        this.toast('Error', 'Please add at least one recipient', 'error');
        return;
    }

    if (!this.selectedFrom) {
        this.toast('Error', 'From address not selected', 'error');
        return;
    }

    const payload = {
        toAddresses: this.toChips,
        ccAddresses: this.ccChips,
        bccAddresses: this.bccChips,
        subject: this.subject,
        htmlBody: this.htmlBody,
        relatedRecordId: this.relatedToId,
        fromType: this.selectedFrom.type,
        fromId: this.selectedFrom.id,
        fromAddress: this.selectedFrom.address
    };

    console.log('payload @@##@ : ',JSON.stringify(payload));
     console.log('payload @@##@ : ',JSON.stringify(payload.htmlBody));

    sendEmailNow({
        payloadJson: JSON.stringify(payload)
    })
        .then(res => {
            this.toast('Success', res || 'Email sent', 'success');

            //this.closeModal(); // existing — child close

            // 🔥 ADD ONLY THIS — parent ko close signal
            this.dispatchEvent(
                new CustomEvent('closeall', {
                    bubbles: true,
                    composed: true
                })
            );
        })
        .catch(err => {
            this.toast(
                'Error',
                err?.body?.message || err.message,
                'error'
            );
        });
}

  

//    @api sendEmailFromFooter() {
//     this.sendEmail(); // existing logic
// }

@api sendEmailFromParent() {
   
    console.log('true @@@@22');
    this.handleSend();
}





    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}