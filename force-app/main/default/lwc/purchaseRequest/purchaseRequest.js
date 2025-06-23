import { LightningElement, track } from 'lwc';
import searchProjects from '@salesforce/apex/search.searchProjects';
import searchLocations from '@salesforce/apex/search.searchLocations';
import searchProducts from '@salesforce/apex/search.searchProducts';
import searchEmployees from '@salesforce/apex/search.searchEmployees';
import getProductQuantity from '@salesforce/apex/search.getProductQuantity';
import sendEmail from '@salesforce/apex/search.sendEmail';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAllEmployees from '@salesforce/apex/search.getAllEmployees';
export default class ProjectLookup extends LightningElement {
    @track projectkey = '';
    @track sitekey = '';
    @track requestKey = '';
    @track approverKey = '';
    @track projects = [];
    @track sites = [];
    @track requests = [];
    @track approvers = [];
    @track selectedProjectName = '';
    @track selectedSiteName = '';
    @track selectedRequestName = '';
    @track selectedApproverName = '';
    @track selectedRequestId = '';
    @track tableData = [];
    handleInputProject(event) {
        this.projectkey = event.target.value;
        if (this.projectkey.length >= 1) {
            this.handleSearchProject();
        } else {
            this.projects = [];
        }
    }
    handleInputSite(event) {
        this.sitekey = event.target.value;
        if (this.sitekey.length >= 1) {
            this.handleSearchSite();
        } else {
            this.sites = [];
        }
    }
    handleInputRequest(event) {
        this.requestKey = event.target.value;
        if (this.requestKey.length >= 1) {
            this.handleSearchRequest();
        } else {
            this.requests = [];
        }
    }
    handleInputApprover(event) {
        this.approverKey = event.target.value;
        if (this.approverKey.length >= 1) {
            this.handleSearchApprover();
        } else {
            this.approvers = [];
        }
    }
    handleSearchProject() {
        searchProjects({ projectkey: this.projectkey })
            .then(result => {
                this.projects = result;
            })
            .catch(error => {
                console.error('Error in searchProjects:', error);
            });
    }
    handleSearchSite() {
        searchLocations({ sitekey: this.sitekey })
            .then(result => {
                this.sites = result;
            })
            .catch(error => {
                console.error('Error in searchLocations:', error);
            });
    }
    handleSearchRequest() {
        searchEmployees({ searchTerm: this.requestKey })
            .then(result => {
                console.log('requests', JSON.stringify(result));
                this.requests = result;
            })
            .catch(error => {
                console.error('Error in searchEmployees:', error);
            });
    }
    handleSearchApprover() {
        searchEmployees({ searchTerm: this.approverKey })
            .then(result => {
                console.log('approvers', result);
                this.approvers = result;
            })
            .catch(error => {
                console.error('Error in searchEmployees:', error);
            });
    }
    handleProjectSelect(event) {
        this.selectedProjectName = event.target.dataset.name;
        this.projectkey = this.selectedProjectName;
        this.projects = [];
    }
    handleSiteSelect(event) {
        this.selectedSiteName = event.target.dataset.name;
        this.sitekey = this.selectedSiteName;
        this.sites = [];
    }
    handleRequestSelect(event) {
        this.selectedRequestName = event.target.dataset.name;
        console.log('selectedRequestName', this.selectedRequestName);
        this.selectedRequestId = event.target.dataset.id;
        console.log('selectedRequestId', this.selectedRequestId);
        this.requestKey = this.selectedRequestName;
        console.log('requestKey', this.requestKey);
        this.requests = [];
    }
    handleApproverSelect(event) {
        this.selectedApproverName = event.target.dataset.name;
        this.approverKey = this.selectedApproverName;
        this.approvers = [];
    }
    handleAddRow() {
        const newRow = {
            id: this.tableData.length + 1,
            product: '',
            productSearchResults: [],
            productAvailability: '',
            quantity: '',
            date: '',
            comments: ''
        };
        this.tableData = [...this.tableData, newRow];
    }
    handleProductInputChange(event) {
        const { id, field } = event.target.dataset;
        const value = event.target.value;
        this.tableData = this.tableData.map(row => {
            if (row.id === parseInt(id, 10)) {
                return { ...row, [field]: value };
            }
            return row;
        });
        if (value.length >= 1) {
            this.handleSearchProduct(id, value);
        } else {
            this.clearProductSearchResults(id);
        }
    }
    handleSearchProduct(rowId, searchKey) {
        searchProducts({ searchKey })
            .then(result => {
                this.tableData = this.tableData.map(row => {
                    if (row.id === parseInt(rowId, 10)) {
                        return { ...row, productSearchResults: result };
                    }
                    return row;
                });
            })
            .catch(error => {
                console.error('Error in searchProducts:', error);
            });
    }
    clearProductSearchResults(rowId) {
        this.tableData = this.tableData.map(row => {
            if (row.id === parseInt(rowId, 10)) {
                return { ...row, productSearchResults: [] };
            }
            return row;
        });
    }
    handleProductSelect(event) {
        const rowId = event.target.dataset.id;
        const productName = event.target.dataset.name;
        this.tableData = this.tableData.map(row => {
            if (row.id === parseInt(rowId, 10)) {
                return { ...row, product: productName, productSearchResults: [] };
            }
            return row;
        });
        this.updateProductAvailability(rowId, productName);
    }
    updateProductAvailability(rowId, productName) {
        getProductQuantity({ productName })
            .then(result => {
                this.tableData = this.tableData.map(row => {
                    if (row.id === parseInt(rowId, 10)) {
                        return { ...row, productAvailability: result.Product_Quantity__c };
                    }
                    return row;
                });
            })
            .catch(error => {
                console.error('Error in getProductQuantity:', error);
            });
    }
    handleInputChange(event) {
        const { id, field } = event.target.dataset;
        const value = event.target.value;
        this.tableData = this.tableData.map(row => {
            if (row.id === parseInt(id, 10)) {
                return { ...row, [field]: value };
            }
            return row;
        });
    }
    handleSubmit() {
        if (!this.selectedRequestId) {
            console.error('Request employee ID is invalid or not found.');
            return;
        }
        const emailData = {
            project: this.selectedProjectName,
            location: this.selectedSiteName,
            tableData: this.tableData.map(row => ({
                product: row.product,
                productAvailability: row.productAvailability,
                quantity: row.quantity,
                date: row.date,
                comments: row.comments
            })),
            requestId: this.selectedRequestId
        };
        sendEmail({ emailData })
            .then(() => {
                console.log('Email sent successfully');
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: 'Email sent!',
                    variant: 'success'
                }));
            })
            .catch(error => {
                console.error('Error in sending email:', error);
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: 'Error sending email!',
                    variant: 'error'
                }));
            });
    }
}
 