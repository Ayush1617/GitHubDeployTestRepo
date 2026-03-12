import { LightningElement, api } from 'lwc';

export default class EmailWrapper extends LightningElement {
    @api recordId;
    @api recordIds;

    handleOpenEmailComposer(event) {
        console.log("📨 EVENT RECEIVED IN WRAPPER → ", JSON.stringify(event.detail));

        const composer = this.template.querySelector('c-custom-email-composer');
        console.log("🎯 composer found? → ", composer);

        if (composer) {
            composer.openWithPrefill(event.detail);
        } else {
            console.error("❌ composer NOT found inside wrapper DOM");
        }
    }
}