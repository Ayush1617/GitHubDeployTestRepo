import { LightningElement, track, api } from 'lwc';
import submitCandidateForm from '@salesforce/apex/NewSupplierCandidateController.submitCandidateForm';

export default class AddNewSupplierCandidate extends LightningElement {
    @api recordId;

    @track formData = {
        firstName: '',
        lastName: '',
        email: '',
        phone: '',
        experienceYears: null,
        skills: '',
        currentCompany: '',
        jobTitle: '',
        expectedSalary: null,
        noticePeriod: ''
    };

    @track resume = {
        fileName: '',
        contentType: '',
        base64Body: ''
    };

    @track isSubmitting = false;
    @track errorMessage = '';
    @track showSuccess = false;

    noticeOptions = [
        { label: 'Immediate Joiner', value: 'Immediate Joiner' },
        { label: '7 Days', value: '7 Days' },
        { label: '15 days or less', value: '15 days or less' },
        { label: '45 Days', value: '45 Days' },
        { label: '1 month', value: '1 month' },
        { label: '2 month', value: '2 month' },
        { label: '3 month', value: '3 month' }
    ];

    // unified input handler for lightning components and native inputs
    handleInputChange(event) {
        const field = event.target.name;
        const value = (event.detail && event.detail.value !== undefined) ? event.detail.value : event.target.value;

        if (field === 'experienceYears' || field === 'expectedSalary') {
            this.formData = { ...this.formData, [field]: value ? Number(value) : null };
        } else {
            this.formData = { ...this.formData, [field]: value };
        }
    }

    handleFileChange(event) {
        const file = event.target.files && event.target.files[0];
        if (!file) return;

        this.resume.fileName = file.name;
        this.resume.contentType = file.type;

        const reader = new FileReader();
        reader.onload = () => {
            const base64 = reader.result.split(',')[1];
            this.resume.base64Body = base64;
        };
        reader.readAsDataURL(file);
    }

    validateClientSide() {
        this.errorMessage = '';

        if (
            !this.formData.firstName ||
            !this.formData.lastName ||
            !this.formData.email ||
            !this.formData.phone
        ) {
            this.errorMessage = 'First name, last name, email and phone are required.';
            return false;
        }

        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(this.formData.email)) {
            this.errorMessage = 'Please enter a valid email address.';
            return false;
        }

        const phoneDigits = this.formData.phone.replace(/\D/g, '');
        if (phoneDigits.length < 10) {
            this.errorMessage = 'Please enter a valid phone number.';
            return false;
        }

        return true;
    }

    resetForm() {
        // reset reactive state
        this.formData = {
            firstName: '',
            lastName: '',
            email: '',
            phone: '',
            experienceYears: null,
            skills: '',
            currentCompany: '',
            jobTitle: '',
            expectedSalary: null,
            noticePeriod: ''
        };

        this.resume = { fileName: '', contentType: '', base64Body: '' };
        this.errorMessage = '';
        this.showSuccess = true;

        // clear lightning-input file (by data-id)
        const fileComp = this.template.querySelector('lightning-input[data-id="resumeFile"]');
        if (fileComp) {
            try {
                fileComp.value = null;
            } catch (e) {
                console.warn('File input reset failed. This can occur due to browser security restrictions.', e);
            }
        }
    }

    async handleSubmit(event) {
        event.preventDefault();

        if (!this.validateClientSide()) return;

        this.isSubmitting = true;
        this.errorMessage = '';
        this.showSuccess = false;

        const payload = {
            firstName: this.formData.firstName,
            lastName: this.formData.lastName,
            email: this.formData.email,
            phone: this.formData.phone,
            experienceYears: this.formData.experienceYears,
            skills: this.formData.skills,
            currentCompany: this.formData.currentCompany,
            jobTitle: this.formData.jobTitle,
            expectedSalary: this.formData.expectedSalary,
            noticePeriod: this.formData.noticePeriod,
            recaptchaToken: null,
            resumeFileName: this.resume.fileName 
                ? 'Resume.' + this.resume.fileName.split('.').pop() 
                : null,
            resumeContentType: this.resume.contentType,
            resumeBase64Body: this.resume.base64Body,
            jobPositionId: this.recordId
        };

        console.log('PAYLOAD BEFORE STRINGIFY =>', payload);
        console.log('PAYLOAD JSON =>', JSON.stringify(payload));

        try {
            const res = await submitCandidateForm({ 
                requestJson: JSON.stringify(payload)
            });

            if (res && res.success) {
                this.resetForm();
            } else {
                this.errorMessage = (res && res.message) ? res.message : 'Something went wrong. Please try again.';
            }
        } catch (err) {            
            this.errorMessage = 'We could not submit your application right now. Please try again later.';
            console.log('File input reset failed. This can occur due to browser security restrictions.', err);
        } finally {
            this.isSubmitting = false;
        }
    }
}