//Abdullah VS 26-May-2025 manages Project Cost with versioned cost data, supporting CRUD operations, version cloning
import { LightningElement, api, wire, track} from 'lwc';
import getActualList from '@salesforce/apex/ProjectActualController.getActualList';
import saveActualList from '@salesforce/apex/ProjectActualController.saveProjectActualList';
import deleteCost from '@salesforce/apex/ProjectActualController.deleteActual';
import saveCost from '@salesforce/apex/ProjectActualController.updateProjectActualList';
import getPicklistValues from '@salesforce/apex/ProjectActualController.getPicklistValues';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import {ProjectActualWrapper} from 'c/wrapper';
import getNslog from '@salesforce/apex/ProjectActualController.getNslog';
export default class ProjectCosting extends LightningElement {
    @api recordId;
    rows = [];
    @track updateRows = [];
    @track newRecord= {};

    @track labor = true;
    @track material;
    @track equipment;
    @track laborRateType = [];
    @track laborCostType = [];
    @track equipmentRateType = [];
    @track equipmentCostType = [];
    @track isAddModalOpen = false;
    @track wiredResult;
    selectedFilter = 'labor';
    @track isDeleteModalOpen = false;
    @track deleteRecordId;
    @track deleteRecordName;  
    @track isRequired = true;          
    @track employeeObjectApiName = 'Employee__c';
    @track employeeFieldApiName = 'First_Name__c';
    @track employeeAdditionalFieldApiName = 'Designation__c';
    @track employeeOtherFieldApiName = 'Name';

    @track productObjectApiName = 'Product__c';
    @track productFieldApiName = 'Name';
    @track productAdditionalFieldApiName = 'SKU__c';
    @track productOtherFieldApiName = 'ProductCode__c';

    @track assetObjectApiName = 'Asset';
    @track assetFieldApiName = 'Name';
    @track assetAdditionalFieldApiName = 'Price';
    @track assetOtherFieldApiName = 'Quantity';
    // Get the all records of Project budget from database
    @wire(getActualList, { Id: "$recordId"})
    readCostList(result) {
        const { data, error } = result;
        this.wiredResult = result;
        if (data) {
            console.log('inside wiredRows');
            console.log('data: ' + JSON.stringify(data));
            this.putRows(data);
            console.log('Current ',JSON.stringify(this.rows));
            this.error = undefined;
        } else if (error) {
            console.log('wiredRows error: ' + JSON.stringify(error));
            this.error = error;
        }
    }
    @wire(getNslog)
        managedNamespacewire({ error, data }) {
        if (data) {
            this.ns = data.nameSpace != 'null' ? data.nameSpace  : '';
            this.employeeObjectApiName = data.nameSpace != 'null' ? data.nameSpace + this.employeeObjectApiName : this.employeeObjectApiName;
            this.employeeAdditionalFieldApiName = data.nameSpace != 'null' ? data.nameSpace + this.employeeAdditionalFieldApiName : this.employeeAdditionalFieldApiName;
            this.employeeFieldApiName = data.nameSpace != 'null' ? data.nameSpace + this.employeeFieldApiName : this.employeeFieldApiName;
            this.productObjectApiName = data.nameSpace != 'null' ? data.nameSpace + this.productObjectApiName : this.productObjectApiName;
            this.productAdditionalFieldApiName = data.nameSpace != 'null' ? data.nameSpace + this.productAdditionalFieldApiName : this.productAdditionalFieldApiName;
            this.productOtherFieldApiName = data.nameSpace != 'null' ? data.nameSpace + this.productOtherFieldApiName : this.productOtherFieldApiName;
         }
     }
    //  get pickList values of Cost Type and Rate Type
    @wire(getPicklistValues)
    wiredPicklists({ error, data }) {
        if (data) {
            this.laborRateType = data.laborRateType.map(value => ({ label: value, value: value }));
            this.laborCostType = data.laborCostType.map(value => ({ label: value, value: value }));
            this.equipmentRateType = data.equipmentRateType.map(value => ({ label: value, value: value }));
            this.equipmentCostType = data.equipmentCostType.map(value => ({ label: value, value: value }));
        } else if (error) {
            console.error('Error loading picklists:', error);
        }
    }

    //  Put the data in the rows
    putRows(data) {
        this.rows = [];
        const { peopleList = [], materialList = [], equipmentList = [], billList = [] } = data;
        this.rows = [
            ...peopleList.map(item => new ProjectActualWrapper(item)),
            ...materialList.map(item => new ProjectActualWrapper(item)),
            ...equipmentList.map(item => new ProjectActualWrapper(item)),
            ...billList.map(item => new ProjectActualWrapper(item))
        ];
    }
    handleAddInputChange(event) {
        const field = event.target.dataset.field;
        console.log(field);
        if(field == 'employeeId' || field == 'productId' || field == 'assetId'){
            const selectedItem = event.detail;
            console.log(JSON.stringify(selectedItem));
            if (selectedItem && event.detail.id) {
                this.newRecord = {
                    ...this.newRecord,
                    [field]: selectedItem.id,
                    name: selectedItem.mainField || '',
                };
            }
            else{
                this.newRecord = {
                    ...this.newRecord,
                    [field]: null
                };
            }
        }
        else if(field == 'isBillable') {
            console.log('Checkbox field isBilling', event.target.checked);
            
            this.newRecord = {
                ...this.newRecord,
                [field]: event.target.checked
            };
        }
        else{
            this.newRecord = {
                ...this.newRecord,
                [field]: event.target.value
            };
        }
        console.log(JSON.stringify(this.newRecord));
    }

    //  Add Record in the selected Version
    handleAddRecord() {
        console.log('newRecord', JSON.stringify(this.newRecord));
        if (!this.newRecord || Object.keys(this.newRecord).length === 0) {
            this.showToast('Error', "Record Should not empty", 'error');
            return;
        }
        const inputs = this.template.querySelectorAll('.validate');
        let isValid = true;
        console.log('Validating inputs:', inputs);
        inputs.forEach(input => {
            if (!input.checkValidity()) {
                input.reportValidity();
                isValid = false;
            }
        });
        if(this.selectedFilter == 'labor' && (!this.newRecord.employeeId || this.newRecord.employeeId == '')){
            this.showToast('Error','Please select Employee','error');
            return;
        }
        if(this.selectedFilter == 'material' && (!this.newRecord.productId || this.newRecord.productId == '')){
            this.showToast('Error','Please select Product','error');
            return;
        }
        if(this.selectedFilter == 'equipment' && (!this.newRecord.assetId || this.newRecord.assetId == '')){
            this.showToast('Error','Please select Asset','error');
            return;
        }
        console.log('Validation result:', isValid);
        
        if (!isValid) {
            this.showToast('Error', "Please fill all required fields", 'error');
            return;
        }
        this.isAddModalOpen = false;
        this.newRecord = {
                ...this.newRecord,
                grp: this.selectedFilter
            };
        let newRecordList = [];
        newRecordList.push(this.newRecord);
        if (this.recordId) {
            saveActualList({ joId: this.recordId, joActualData: JSON.stringify(newRecordList)})
            .then((resp) => {
                console.log(resp); 
                this.rows = []; 
                this.putRows(resp);
                this.handleCloseModal();
            })
            .catch((error) => { console.log(error); });
        }
        this.newRecord = {};
    }

    handleFilterChange(event) {
        this.selectedFilter = event.detail;
        this.labor = this.selectedFilter == 'labor' ? true : false;
        this.material = this.selectedFilter =='material' ? true : false;
        this.equipment = this.selectedFilter =='equipment' ? true : false;
    }

    handleDeleteCost(event) {
        const { id } = event.detail;
        const record = this.rows.find(row => row.id === id);
        this.deleteRecordId = id;
        console.log('Deleting record:', JSON.stringify(record), id);
        this.deleteRecordName = record?.name || '';
        this.isDeleteModalOpen = true;
    }

    closeDeleteModal() {
        this.isDeleteModalOpen = false;
        this.deleteRecordId = null;
        this.deleteRecordName = '';
    }

    // Deletes the selected record via Apex and refreshes the list.
    confirmDelete() {
        deleteCost({ recordId: this.deleteRecordId , grp: this.selectedFilter })
            .then(() => {
                this.showToast('Deleted', `"${this.deleteRecordName}" has been deleted.`, 'success');
                this.closeDeleteModal();
                this.rows = this.rows.filter(row => row.id !== this.deleteRecordId);
                return refreshApex(this.wiredResult);
            })
            .catch(error => {
                this.showToast('Error deleting', error.body.message, 'error');
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    // Call it from the child component
    handleSaveCosts(event) {
        console.log('Calling jsSaveCost from parent', JSON.stringify(event.detail));
        this.jsSaveCost(event.detail);
    }

    // send update the cost values to the apex method 
    jsSaveCost(updateRows) {
        if (!updateRows.length) return;
        console.log('Sending cost data:', JSON.stringify(updateRows));
        saveCost({joId: this.recordId, joActualData: JSON.stringify(updateRows) }) 
            .then((resp) => {
                console.log('Saved costs:', resp);
                this.putRows(resp);
                console.log('Updated rows:', this.rows);
            })
            .catch((error) => {
                console.error('Error saving costs:', error);
            })
            .finally(() => {
                this.updateRows = [];
                console.log('All rows saved and updateRows cleared.');
            });
    }

    // Open the model for create the new version
    handleAddOpenModal() {
        this.newRecord = new ProjectActualWrapper();
        this.isAddModalOpen = true;
    }

    // Close the model for create the new version
    handleCloseModal() {
        this.newRecord = {};
        this.isAddModalOpen = false;
    }
}