import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import WORK_ORDER_OBJECT from '@salesforce/schema/Work_Order__c';
import STATUS_FIELD from '@salesforce/schema/Work_Order__c.Status__c';
import getAllFieldsValue from '@salesforce/apex/ExtendWorkOrderController.getAllFieldsValue';
import createWorkOrder from '@salesforce/apex/ExtendWorkOrderController.createWorkOrder';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class ExtendWorkOrders extends LightningElement {
    _recordId;
    @track workOrder = {};
    @track parentWorkOrderName = '';
    @track projectName = '';
    @track candidateName = '';
    @track recruiterName = '';
    @track isModalOpen = true;
    @track isLoading = false;  
    @track statusOptions = []; 
    
    @track roleOnProject = '';
    @track startDate = '';
    @track endDate = '';
    @track selectedStatus = '--None--';    
    @track salaryOffered = '';

    @api
    get recordId() {
        return this._recordId;
    }
    
    set recordId(value) {
        this._recordId = value;
        if (value) {
            this.loadWorkOrderData();
        }
    }

    @wire(getObjectInfo, { objectApiName: WORK_ORDER_OBJECT })
    workOrderObjectInfo;

    @wire(getPicklistValues, {
        recordTypeId: '$workOrderObjectInfo.data.defaultRecordTypeId',
        fieldApiName: STATUS_FIELD
    })
    wiredStatusPicklist({ error, data }) {
        if (data) {
            this.statusOptions = [
                { label: '--None--', value: '--None--' },
                ...data.values.map(item => ({
                    label: item.label,
                    value: item.value
                }))
            ];
            this.selectedStatus = '--None--';
        } else if (error) {
            this.statusOptions = [{ label: '--None--', value: '--None--' }];
            this.selectedStatus = '--None--';
            this.showError('Failed to load Status picklist values.');
        }
    }

    loadWorkOrderData() {
        if (!this._recordId) return;
        
        this.isLoading = true;
        
        getAllFieldsValue({ recordId: this._recordId })
            .then(result => {
                if (result.Status__c !== 'Working') {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Action Not Allowed',
                            message: 'Work Order can be extended only when status is Working.',
                            variant: 'error'
                        })
                    );
                    this.closeModal();
                    return;
                }
                
                this.workOrder = result;
                
                // Get Parent Work Order Name
                if (result.Name) {
                    this.parentWorkOrderName = result.Name;
                } else {
                    this.parentWorkOrderName = 'No Parent Work Order';
                }
                
                // Get Project Name
                if (result.Project__r && result.Project__r.Name) {
                    this.projectName = result.Project__r.Name;
                } else {
                    this.projectName = result.Project__c || 'No Project';
                }
                
                // Get Candidate Name
                if (result.Candidate_Name__r && result.Candidate_Name__r.Name) {
                    this.candidateName = result.Candidate_Name__r.Name;
                } else {
                    this.candidateName = result.Candidate_Name__c || 'No Candidate';
                }
                
                // Get Recruiter Name
                if (result.Recruiter_Name__r && result.Recruiter_Name__r.Name) {
                    this.recruiterName = result.Recruiter_Name__r.Name;
                } else {
                    this.recruiterName = result.Recruiter_Name__c || 'No Recruiter';
                }
                
                this.roleOnProject = result.Role_on_Project__c || '';
                this.selectedStatus = '--None--';
                this.isLoading = false;
            })
            .catch(error => {
                this.showError(error);
                this.isLoading = false;
                this.closeModal();
            });
    }

    @api
    invoke() {
        console.log('Invoke called');
    }

    handleRoleChange(event) {
        this.roleOnProject = event.target.value;
    }

    handleStartDateChange(event) {
        this.startDate = event.target.value;
    }

    handleEndDateChange(event) {
        this.endDate = event.target.value;
    }

    handleStatusChange(event) {
        this.selectedStatus = event.target.value;
    }

    handleSalaryChange(event) {
        this.salaryOffered = event.target.value;
    }

    validateForm() {
        if (!this.startDate) {
            this.showError('Start Date is required');
            return false;
        }
        if (!this.endDate) {
            this.showError('End Date is required');
            return false;
        }
        if (this.startDate && this.endDate) {
            const start = new Date(this.startDate);
            const end = new Date(this.endDate);
            if (end <= start) {
                this.showError('End Date must be after Start Date');
                return false;
            }
        }
        return true;
    }

    saveWorkOrder() {
        if (!this.validateForm()) {
            return;
        }

        this.isLoading = true;

        const newWorkOrder = {
            Parent_Work_OrderId__c: this._recordId,
            Project__c: this.workOrder.Project__c,
            Role_on_Project__c: this.roleOnProject,
            Candidate_Name__c: this.workOrder.Candidate_Name__c,
            Recruiter_Name__c: this.workOrder.Recruiter_Name__c,
            Start_Date__c: this.startDate,
            End_Date__c: this.endDate,
            Renewed__c: true,
            Status__c: this.selectedStatus === '--None--' ? null : this.selectedStatus,
            Salary_Offered__c: this.salaryOffered || ''
        };

        createWorkOrder({ workOrderData: JSON.stringify(newWorkOrder) })
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Work Order Extended Successfully',
                        variant: 'success'
                    })
                );
                
                this.dispatchEvent(new CustomEvent('refreshtable'));
                this.closeModal();
            })
            .catch(error => {
                this.showError(error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    closeModal() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    showError(error) {
        let message = 'Unexpected Error';
        if (typeof error === 'string') {
            message = error;
        } else if (error && error.body) {
            if (error.body.message) {
                message = error.body.message;
            } else if (error.body.pageErrors && error.body.pageErrors[0]) {
                message = error.body.pageErrors[0].message;
            } else if (error.body.fieldErrors) {
                const fieldErrors = error.body.fieldErrors;
                const firstField = Object.keys(fieldErrors)[0];
                if (firstField && fieldErrors[firstField][0]) {
                    message = fieldErrors[firstField][0].message;
                }
            }
        } else if (error && error.message) {
            message = error.message;
        }
        
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: message,
                variant: 'error'
            })
        );
    }

    handleCancel() {
        this.closeModal();
    }
}