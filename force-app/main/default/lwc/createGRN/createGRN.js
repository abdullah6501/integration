import { LightningElement, wire, api, track } from 'lwc';
import getPurchaseOrderData from '@salesforce/apex/GRNController.getPurchaseOrderData';
import searchLocation from '@salesforce/apex/GRNController.searchLocation';
import CreateGRNs from '@salesforce/apex/GRNController.CreateGRN';
import saveDraftGRN from '@salesforce/apex/GRNController.saveDraftGRN';
import getOrCreateDraftGRN from '@salesforce/apex/GRNController.getOrCreateDraftGRN';
import linkFilesToGRN from '@salesforce/apex/GRNController.linkFilesToGRN';
import updateFilesToGRN from '@salesforce/apex/GRNController.updateFilesToGRN';
import searchChartOfAccounts from '@salesforce/apex/GRNController.searchChartOfAccounts';
import uploadFileToServer from '@salesforce/apex/GRNController.uploadFileToServer';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import taxOptions from '@salesforce/apex/TaxUtility.getParentTaxes';
import { CloseActionScreenEvent } from 'lightning/actions';
import getTaxInfoFromPOItems from '@salesforce/apex/GRNController.getTaxInfoFromPOItems';

export default class CreateGRN extends NavigationMixin(LightningElement) {
    @track isButtonDisabled = false;
    @api recordId; // PO Record ID
    @track purchaseOrder = {};
    @track purchaseOrderItems = [];
    @track isPurchaseOrderCreated = false;
    @track accounts = [];
    @track searchResults = [];
    @track uploadedFiles = [];
    uploadedFileIds = [];
    @track isCreateEnabled = false;
    @track chartOfAccountResults = [];
    @track isModalOpen = false;
    @track selectedFiles = [];
    @track isTaxEnabled = true;
    @track selectedPreviewUrl = '';
    @track selectedRowIndex = null;
    @track showModal = false;
    @track previewFileUrl = '';
    
    // Initialize file tracking arrays
    @track grnUploadedFileIds = [];
    //@track grnRemovedFileIds = [];
    grnRemovedFileIds = [];
    
    // Draft GRN tracking
    @track existingGRNId = null;
    @track isDraftMode = false;
    @track isLoading = true;

    @track grnDeliveryDate = new Date().toISOString().split('T')[0]; // Initialize with today's date
    @track grnChartOfAccountId = '';
    @track grnChartOfAccountSearchKey = '';
    @track grnChartOfAccountResults = [];
    @track grnUploadedFileIds = [];
    @track grnUploadedFileCount = 0;
    @track grnFileMetadata = {};
    @track showGRNFileModal = false;
    @track grnSelectedFiles = [];
    @track grnPreviewFileUrl = '';
    @track grnRemovedFileIds = [];
    
    @track expenseItems = [
        { id: '1', Name: 'Freight Charges', RFAB__Date__c: '', RFAB__Description__c: '',RFAB__Amount_excluding__c:'', RFAB__Total_Amount__c: 0, Tax_Amount__c:0, RFAB__Chart_of_Accounts__c:'',chartOfAccountResults:[],uploadedFileIds: [], uploadedFileCount: 0, isNameEditable: true },
        { id: '2', Name: 'Additional Charges', RFAB__Date__c: '', RFAB__Description__c: '',RFAB__Amount_excluding__c:'', RFAB__Total_Amount__c: 0, Tax_Amount__c:0, RFAB__Chart_of_Accounts__c:'',chartOfAccountResults:[],uploadedFileIds: [],uploadedFileCount: 0, isNameEditable: false },
        { id: '3', Name: 'Bill of Entry', RFAB__Date__c: '', RFAB__Description__c: '',RFAB__Amount_excluding__c:'', RFAB__Total_Amount__c: 0, Tax_Amount__c:0, RFAB__Chart_of_Accounts__c:'',chartOfAccountResults:[],uploadedFileIds: [],uploadedFileCount: 0, isNameEditable: true }
    ];

    get acceptedFormats() {
        return '.jpg,.jpeg,.png,.pdf,.doc,.docx,.xls,.xlsx';
    }

    get isGRNImage() {
        if (!this.grnSelectedFiles || !this.grnPreviewFileUrl) return false;
        const currentFile = this.grnSelectedFiles.find(file => file.previewUrl === this.grnPreviewFileUrl);
        if (!currentFile || !currentFile.type) return false;
        return currentFile.type.startsWith('image/');
    }

    @wire(taxOptions)
    wiredTaxOptions({error, data}) {
        if (data) {
            console.log('Tax options loaded:', JSON.stringify(data));
            this.taxOptions = data.map(option => ({
                label: option.parentTaxName,
                value: option.parentTaxId,
                parentTaxId: option.parentTaxId,
                percentage: option.parentTaxPercentage,
                fullData: option
            }));
            this.taxOptionsLoaded = true;
        } else if (error) {
            console.error('Error fetching tax options:', error);
            this.taxOptions = [];
        }
    }

    // Load PO data and check for existing draft
    connectedCallback() {
        this.loadDraftGRN();
    }

    loadDraftGRN() {
        this.isLoading = true;
        getOrCreateDraftGRN({ poId: this.recordId })
            .then(result => {
                console.log('Draft GRN Result:', JSON.stringify(result));
                
                if (result.isDraft) {
                    // Draft exists, load it
                    this.isDraftMode = true;
                    this.existingGRNId = result.grnId;
                    this.loadDraftData(result);
                    this.showToast('Info', 'Existing Draft GRN loaded for editing', 'info');
                } else {
                    // No draft, proceed normally
                    this.isDraftMode = false;
                    this.existingGRNId = null;
                }
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Error loading draft GRN:', error);
                this.showToast('Error', 'Failed to load Draft GRN: ' + error.body.message, 'error');
                this.isLoading = false;
            });
    }

    loadDraftData(draftResult) {
        console.log('Debug - Loading Draft Data:', JSON.stringify(draftResult));
        
        // Reset file tracking
        this.grnRemovedFileIds = [];
        this.grnUploadedFileIds = [];
        this.grnFileMetadata = {};
        this.grnUploadedFileCount = 0;
        
        // NEW: Load GRN header fields
        if (draftResult.grn) {
            this.grnDeliveryDate = draftResult.grn.RFAB__Date__c || '';
            this.grnChartOfAccountId = draftResult.grn.Chart_of_Accounts__c || '';
            this.grnChartOfAccountSearchKey = draftResult.grn.Chart_of_Accounts__r?.Name || '';
            
            // Load GRN Files
            if (draftResult.grnFiles && draftResult.grnFiles.length > 0) {
                console.log('Debug - Loading GRN Files:', draftResult.grnFiles.length);
                
                // Get ContentDocumentIds from files
                const fileIds = draftResult.grnFiles
                    .filter(link => link && link.ContentDocumentId)
                    .map(link => link.ContentDocumentId);
                
                // Update the tracked arrays
                this.grnUploadedFileIds = [...fileIds];
                this.grnUploadedFileCount = fileIds.length;
                
                // Build metadata
                draftResult.grnFiles.forEach(link => {
                    if (link && link.ContentDocumentId) {
                        this.grnFileMetadata[link.ContentDocumentId] = {
                            name: link.ContentDocument?.Title || 'Unknown',
                            type: link.ContentDocument?.FileType || 'application/octet-stream'
                        };
                    }
                });
                
                console.log('Debug - Loaded Files State:');
                console.log('Uploaded files:', JSON.stringify(this.grnUploadedFileIds));
                console.log('Removed files:', JSON.stringify(this.grnRemovedFileIds));
            }
        }

        // Load stock records
        if (draftResult.stockRecords && draftResult.stockRecords.length > 0) {
            const poItemIds = draftResult.stockRecords
                .map(stock => stock.PO_Items__c)
                .filter(id => id);

            this.purchaseOrderItems = draftResult.stockRecords.map(stock => {
                const isSerial = stock.RFAB__Product__r?.RFAB__Is_Serial_Number__c || false;
                return {
                    Id: stock.PO_Items__c,
                    Name: stock.RFAB__Product__r?.Name || stock.Name,
                    RFAB__Product__c: stock.RFAB__Product__c,
                    RFAB__Quantity__c: stock.RFAB__Quantity__c || 0,
                    RFAB__Unit_Price__c: stock.RFAB__Purchase_Price__c || 0.00,
                    Serial_Number__c: stock.Serial_Number__c || '',
                    isSerial: isSerial,
                    isSerialDisabled: !isSerial,
                    SKU: stock.RFAB__Product__r?.RFAB__SKU__c || '',
                    RFAB__Location__c: stock.RFAB__Location__c,
                    RFAB__Tax__c: '',
                    RFAB__Tax_Percent__c: 0,
                    searchResults: []
                };
            });

            if (poItemIds.length > 0 && this.isTaxEnabled) {
                getTaxInfoFromPOItems({ poItemIds: poItemIds })
                    .then(taxInfoMap => {
                        this.purchaseOrderItems = this.purchaseOrderItems.map(item => {
                            const taxInfo = taxInfoMap[item.Id];
                            if (taxInfo && taxInfo.taxId) {
                                return {
                                    ...item,
                                    RFAB__Tax__c: taxInfo.taxId,
                                    RFAB__Tax_Percent__c: taxInfo.taxPercent || 0
                                };
                            }
                            return item;
                        });
                        this.purchaseOrderItems = [...this.purchaseOrderItems];
                    })
                    .catch(error => {
                        console.error('Error fetching tax info:', error);
                    });
            }
        }

        // Load expense records
        if (draftResult.expenseRecords && draftResult.expenseRecords.length > 0) {
            this.expenseItems = draftResult.expenseRecords.map((exp, index) => {
                const expenseFileIds = this.getExpenseFileIds(exp.Id, draftResult.expenseFiles);
                return {
                    id: (index + 1).toString(),
                    expenseRecordId: exp.Id,
                    Name: exp.Name,
                    RFAB__Date__c: exp.RFAB__Date__c,
                    RFAB__Description__c: exp.RFAB__Description__c,
                    RFAB__Amount_excluding__c: exp.RFAB__Amount_excluding__c,
                    RFAB__Total_Amount__c: exp.RFAB__Total_Amount__c,
                    Tax_Amount__c: exp.Tax_Amount__c,
                    RFAB__Chart_of_Accounts__c: exp.RFAB__Chart_of_Accounts__c,
                    Chart_of_Account_Name__c: exp.RFAB__Chart_of_Accounts__r?.Name,
                    chartOfAccountSearchKey: exp.RFAB__Chart_of_Accounts__r?.Name,
                    chartOfAccountResults: [],
                    uploadedFileIds: expenseFileIds,
                    uploadedFileCount: expenseFileIds.length,
                    fileMetadata: this.buildFileMetadata(expenseFileIds, draftResult.expenseFiles),
                    isNameEditable: false
                };
            });
        }
    }

    getExpenseFileIds(expenseId, expenseFilesMap) {
        if (!expenseFilesMap || !expenseFilesMap[expenseId]) {
            return [];
        }
        return expenseFilesMap[expenseId].map(link => link.ContentDocumentId);
    }

    buildFileMetadata(fileIds, expenseFilesMap) {
        const metadata = {};
        if (!expenseFilesMap) return metadata;
        Object.values(expenseFilesMap).forEach(linksList => {
            linksList.forEach(link => {
                if (fileIds.includes(link.ContentDocumentId)) {
                    metadata[link.ContentDocumentId] = {
                        name: link.ContentDocument?.Title || 'Unknown',
                        type: link.ContentDocument?.FileType || 'application/octet-stream'
                    };
                }
            });
        });
        return metadata;
    }
    
    // NEW: Handle GRN Field Changes
    handleGRNFieldChange(event) {
        const fieldName = event.target.name;
        const value = event.target.value;
        
        if (fieldName === 'RFAB__Date__c') {
            this.grnDeliveryDate = value;
        }
    }

    // NEW: Handle GRN Chart of Account Search
    handleGRNChartOfAccountSearch(event) {
        const searchKey = event.target.value;
        this.grnChartOfAccountSearchKey = searchKey;
        
        // Clear COA if search is emptied
        if (!searchKey || searchKey.trim() === '') {
            this.clearGRNChartOfAccount();
            return;
        }
        
        if (searchKey.length > 2) {
            searchChartOfAccounts({ searchKey })
                .then(data => {
                    this.grnChartOfAccountResults = data;
                })
                .catch(error => {
                    console.error('GRN Chart of Account search error', error);
                });
        } else {
            this.grnChartOfAccountResults = [];
        }
    }

    // NEW: Clear GRN Chart of Account
    clearGRNChartOfAccount() {
        this.grnChartOfAccountId = '';
        this.grnChartOfAccountSearchKey = '';
        this.grnChartOfAccountResults = [];
    }

    // NEW: Select GRN Chart of Account
    selectGRNChartOfAccount(event) {
        const coaId = event.currentTarget.dataset.id;
        const coaName = event.currentTarget.dataset.name;
        
        this.grnChartOfAccountId = coaId;
        this.grnChartOfAccountSearchKey = coaName;
        this.grnChartOfAccountResults = [];
    }

    // NEW: GRN File Upload Methods
    handleGRNUploadIconClick() {
        const inputEl = this.template.querySelector('.grn-upload-input');
        if (inputEl) {
            inputEl.click();
        }
    }

    handleGRNFileUpload(event) {
        const files = Array.from(event.target.files);
        
        files.forEach(file => {
            const reader = new FileReader();
            reader.onload = () => {
                const base64 = reader.result.split(',')[1];
                uploadFileToServer({
                    fileName: file.name,
                    base64Data: base64,
                    contentType: file.type
                })
                    .then(contentDocumentId => {
                        this.grnUploadedFileIds.push(contentDocumentId);
                        this.grnFileMetadata[contentDocumentId] = {
                            name: file.name,
                            type: file.type
                        };
                        this.grnUploadedFileCount = this.grnUploadedFileIds.length;
                        
                        // Update modal if open
                        if (this.showGRNFileModal) {
                            this.updateGRNFileModal();
                        }
                        
                        this.grnUploadedFileIds = [...this.grnUploadedFileIds];
                    })
                    .catch(error => {
                        console.error('Error uploading GRN file:', error);
                        this.showToast('Error', 'Failed to upload file', 'error');
                    });
            };
            reader.readAsDataURL(file);
        });
    }

    handleGRNFileBoxClick() {
        this.grnSelectedFiles = this.grnUploadedFileIds.map((id, index) => {
            const type = this.grnFileMetadata[id]?.type || '';
            const isImage = type.startsWith('image/');
            return {
                id,
                name: this.grnFileMetadata[id]?.name || 'Unknown',
                type: type,
                itemClass: `file-item ${index === 0 ? 'active' : ''}`,
                previewUrl: isImage 
                    ? `/sfc/servlet.shepherd/document/download/${id}` 
                    : `/sfc/servlet.shepherd/document/preview/${id}`
            };
        });
        
        if (this.grnUploadedFileIds.length > 0) {
            const firstFile = this.grnSelectedFiles[0];
            if (firstFile.type.startsWith('image/')) {
                this.grnPreviewFileUrl = firstFile.previewUrl;
            } else {
                this.grnPreviewFileUrl = '';
            }
        }
        
        this.showGRNFileModal = true;
    }

    handleGRNPreviewFile(event) {
        const index = event.currentTarget.dataset.index;
        
        // Update active state
        this.grnSelectedFiles = this.grnSelectedFiles.map((file, i) => ({
            ...file,
            itemClass: `file-item ${i === parseInt(index) ? 'active' : ''}`
        }));
        
        const selectedFile = this.grnSelectedFiles[index];
        const isImage = selectedFile.type.startsWith('image/');
        
        if (isImage) {
            this.grnPreviewFileUrl = `/sfc/servlet.shepherd/document/download/${selectedFile.id}`;
        } else {
            this.previewFile(selectedFile.id);
            this.grnPreviewFileUrl = '';
        }
    }

    updateGRNFileModal() {
        const activeFileIds = this.grnUploadedFileIds.filter(id => !this.grnRemovedFileIds.includes(id));
        const activeFile = this.grnSelectedFiles.find(file => file.itemClass?.includes('active'));
        
        this.grnSelectedFiles = activeFileIds.map((id, index) => {
            const metadata = this.grnFileMetadata[id];
            const type = metadata?.type || '';
            const isImage = type.startsWith('image/');
            const isNewFile = !this.grnSelectedFiles.find(f => f.id === id);
            const shouldBeActive = isNewFile || (activeFile?.id === id);
            
            return {
                id,
                name: metadata?.name || 'Unknown',
                type: type,
                itemClass: `file-item ${shouldBeActive && index === 0 ? 'active' : ''}`,
                previewUrl: isImage 
                    ? `/sfc/servlet.shepherd/document/download/${id}`
                    : `/sfc/servlet.shepherd/document/preview/${id}`
            };
        });
        
        this.grnUploadedFileCount = activeFileIds.length;
        
        const activeFileInModal = this.grnSelectedFiles.find(f => f.itemClass?.includes('active'));
        if (activeFileInModal && activeFileInModal.type.startsWith('image/')) {
            this.grnPreviewFileUrl = activeFileInModal.previewUrl;
        } else {
            this.grnPreviewFileUrl = '';
        }
        
        console.log('Modal updated. Active files:', activeFileIds.length);
    }

    handleFileBoxClick(event) {
        this.selectedRowIndex = event.currentTarget.dataset.index;
        const item = this.expenseItems[this.selectedRowIndex];
        const fileIds = item.uploadedFileIds || [];
        const metadata = item.fileMetadata || {};
        
        this.selectedFiles = fileIds.map((id, index) => {
            const type = metadata[id]?.type || '';
            const isImage = type.startsWith('image/');
            return {
                id,
                name: metadata[id]?.name || 'Unknown',
                type: type,
                itemClass: `file-item ${index === 0 ? 'active' : ''}`,
                previewUrl: isImage 
                    ? `/sfc/servlet.shepherd/document/download/${id}`
                    : `/sfc/servlet.shepherd/document/preview/${id}`
            };
        });
        
        if (fileIds.length > 0) {
            const firstFile = this.selectedFiles[0];
            if (firstFile.type.startsWith('image/')) {
                this.previewFileUrl = firstFile.previewUrl;
            } else {
                this.previewFileUrl = '';
            }
        } else {
            this.previewFileUrl = '';
        }

        this.showModal = true;
    }

    handleCloseGRNFileModal() {
        this.showGRNFileModal = false;
        this.grnPreviewFileUrl = '';
    }

    handleAddMoreGRNFiles() {
        const inputEl = this.template.querySelector('.grn-upload-input');
        if (inputEl) {
            inputEl.click();
        }
    }

    handleRemoveGRNFile(event) {
    event.stopPropagation();
    const fileId = event.target.dataset.id;
    
    console.log('Removing GRN file ID:', fileId);
    
    // CRITICAL FIX: Remove from uploaded files array (this was missing!)
    this.grnUploadedFileIds = this.grnUploadedFileIds.filter(id => id !== fileId);
    
    // Remove from selected files (modal display)
    this.grnSelectedFiles = this.grnSelectedFiles.filter(file => file.id !== fileId);
    
    // Remove from metadata
    if (this.grnFileMetadata[fileId]) {
        delete this.grnFileMetadata[fileId];
    }
    
    // Track as removed (for backend deletion)
    if (!this.grnRemovedFileIds.includes(fileId)) {
        this.grnRemovedFileIds.push(fileId);
    }
    
    // Update file count
    this.grnUploadedFileCount = this.grnUploadedFileIds.length;
    
    // Clear preview if it was the removed file
    if (this.grnPreviewFileUrl && this.grnPreviewFileUrl.includes(fileId)) {
        this.grnPreviewFileUrl = '';
    }
    
    // // If no files left, close modal
    // if (this.grnUploadedFileIds.length === 0) {
    //     this.showGRNFileModal = false;
    // }
    
    console.log('Updated state after removal:');
    console.log('Uploaded files:', JSON.stringify(this.grnUploadedFileIds));
    console.log('Removed files:', JSON.stringify(this.grnRemovedFileIds));
}

    wiredPurchaseOrderResult;

    @wire(getPurchaseOrderData, { poId: '$recordId' })
    wiredData(result) {
        this.wiredPurchaseOrderResult = result;
        const { error, data } = result;
        
        if (data) {
            if (data.errorMessage) {
                console.error('Error loading PurchaseOrder data', JSON.stringify(data));
                this.showToast('Error', data.errorMessage, 'error');
                this.isPurchaseOrderCreated = true;
                // this.handleClose();
                setTimeout(() => {
                    window.location.reload();
                }, 1000);
            }
            
            console.log('PO Data:', JSON.stringify(data.purchaseOrder));
            
            this.purchaseOrder = {
                ...data.purchaseOrder,
                Supplier: data.purchaseOrder.RFAB__Vendor_Account__c ? data.purchaseOrder.RFAB__Vendor_Account__r.Name : '',
            };
            
            if(data.purchaseOrder.RFAB__Discount_Type__c == 'Lumpsum Discount'){
                this.isTaxEnabled = false;
            }

            // Only load PO items if NOT in draft mode
            if (!this.isDraftMode) {
                this.purchaseOrderItems = data.items.map(item => {
                    const isSerial = item.RFAB__Is_Serial_Number__c;
                    let taxPercent = item.RFAB__Tax_Percent__c || item.Tax_Percentage__c || 0;
                    return {
                        ...item,
                        Name: item.Name,
                        RFAB__Quantity__c: item.RFAB__Quantity__c || 0,
                        RFAB__Unit_Price__c: item.RFAB__Unit_Price__c || 0.00,
                        Tax_Percentage__c: taxPercent,
                        RFAB__Tax__c: item.RFAB__Tax__c || 0.00,
                        RFAB__Tax_Percent__c: taxPercent,
                        RFAB__Total_Price__c: item.RFAB__Total_Price__c || 0.00,
                        Serial_Number__c: isSerial ? '' : null,
                        isSerial: isSerial,
                        isSerialDisabled: !isSerial,
                        SKU: item['RFAB__Product__r.RFAB__SKU__c'] 
                    };
                });
            }
        } else if (error) {
            console.error('Error loading PurchaseOrder data', error);
        }
    }

    handleAddNewExpense() {
        const maxId = this.expenseItems.reduce((max, item) => {
            const numId = parseInt(item.id, 10);
            return numId > max ? numId : max;
        }, 0);

        const newId = (maxId + 1).toString();

        const newExpense = {
            id: newId,
            Name: '',
            RFAB__Date__c: '',
            RFAB__Description__c: '',
            RFAB__Amount_excluding__c: '',
            RFAB__Total_Amount__c: 0,
            Tax_Amount__c: 0,
            RFAB__Chart_of_Accounts__c: '',
            isNameEditable: false,
            chartOfAccountResults:[],
            uploadedFileIds: [],
            uploadedFileCount: 0,
            fileMetadata: {}
        };

        this.expenseItems = [...this.expenseItems, newExpense];
    }

    handleDeleteExpenseRow(event) {
        const index = event.target.dataset.index;
        this.expenseItems = this.expenseItems.filter((_, i) => i != index);
    }

    handleChartOfAccountSearch(event) {
        const searchKey = event.target.value;
        const index = event.target.dataset.index;

        if (searchKey.length > 2) {
            searchChartOfAccounts({ searchKey })
                .then(data => {
                    this.expenseItems = this.expenseItems.map((item, i) => ({
                        ...item,
                        chartOfAccountSearchKey: i === parseInt(index) ? searchKey : item.chartOfAccountSearchKey,
                        chartOfAccountResults: i === parseInt(index) ? data : []
                    }));
                })
                .catch(error => {
                    console.error('Chart of Account search error', error);
                });
        } else {
            this.clearChartOfAccountResults(index);
        }
    }

    clearChartOfAccountResults(index) {
        this.expenseItems = this.expenseItems.map((item, i) => ({
            ...item,
            chartOfAccountResults: i === parseInt(index) ? [] : item.chartOfAccountResults
        }));
    }

    selectChartOfAccount(event) {
        const index = parseInt(event.currentTarget.dataset.index);
        const coaId = event.currentTarget.dataset.id;
        const coaName = event.currentTarget.dataset.name;

        this.expenseItems = this.expenseItems.map((item, i) => {
            if (i === index) {
                return {
                    ...item,
                    RFAB__Chart_of_Accounts__c: coaId,
                    Chart_of_Account_Name__c: coaName,
                    chartOfAccountSearchKey: coaName,
                    chartOfAccountResults: []
                };
            }
            return item;
        });
    }

    get isImage() {
        if (!this.selectedFiles || !this.previewFileUrl) return false;
        const currentFile = this.selectedFiles.find(file => file.previewUrl === this.previewFileUrl);
        if (!currentFile || !currentFile.type) return false;
        return currentFile.type.startsWith('image/');
    }

    previewFile(fileId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: {
                pageName: 'filePreview'
            },
            state: {
                selectedRecordId: fileId
            }
        });
    }

    handlePreviewFile(event) {
        const index = event.currentTarget.dataset.index;
        
        this.selectedFiles = this.selectedFiles.map((file, i) => ({
            ...file,
            itemClass: `file-item ${i === parseInt(index) ? 'active' : ''}`
        }));
        
        const selectedFile = this.selectedFiles[index];
        const isImage = selectedFile.type.startsWith('image/');
        
        if (isImage) {
            this.previewFileUrl = `/sfc/servlet.shepherd/document/download/${selectedFile.id}`;
        } else {
            this.previewFile(selectedFile.id);
            this.previewFileUrl = null;
        }
    }

    handleCloseModal() {
        this.showModal = false;
        this.previewFileUrl = '';
    }

    handleUploadIconClick(event) {
        const index = event.currentTarget.dataset.index;
        const inputs = this.template.querySelectorAll('.upload-input');
        const inputEl = Array.from(inputs).find(input => input.dataset.index === index);
        if (inputEl) {
            inputEl.click();
        }
    }

    handleAddMoreFiles() {
        const inputs = this.template.querySelectorAll('.upload-input');
        const inputEl = Array.from(inputs).find(input => input.dataset.index === this.selectedRowIndex);
        if (inputEl) {
            inputEl.click();
        }
    }

    handleFileUpload(event) {
        const index = event.target.dataset.index;
        const files = Array.from(event.target.files);

        files.forEach(file => {
            const reader = new FileReader();
            
            reader.onload = () => {
                const base64 = reader.result.split(',')[1];
                uploadFileToServer({
                    fileName: file.name,
                    base64Data: base64,
                    contentType: file.type
                })
                .then(contentDocumentId => {
                    if (!this.expenseItems[index].uploadedFileIds) {
                        this.expenseItems[index].uploadedFileIds = [];
                    }
                    if (!this.expenseItems[index].fileMetadata) {
                        this.expenseItems[index].fileMetadata = {};
                    }
                    
                    this.expenseItems[index].uploadedFileIds.push(contentDocumentId);
                    
                    this.expenseItems[index].fileMetadata[contentDocumentId] = {
                        name: file.name,
                        type: file.type,
                    };
                    
                    this.expenseItems[index].uploadedFileCount = this.expenseItems[index].uploadedFileIds.length;
                    
                    if (this.showModal && this.selectedRowIndex === index) {
                        const activeFile = this.selectedFiles.find(file => file.itemClass?.includes('active'));
                        
                        this.selectedFiles = this.expenseItems[index].uploadedFileIds.map(id => {
                            const isNewFile = id === contentDocumentId;
                            return {
                                id,
                                name: this.expenseItems[index].fileMetadata[id].name,
                                type: this.expenseItems[index].fileMetadata[id].type,
                                itemClass: `file-item ${isNewFile ? 'active' : activeFile?.id === id ? 'active' : ''}`,
                                previewUrl: `/sfc/servlet.shepherd/document/download/${id}`
                            };
                        });
                    }
                    
                    this.expenseItems = [...this.expenseItems];
                })
                .catch(error => {
                    console.error('Error uploading file:', error);
                    this.showToast('Error', 'Failed to upload file', 'error');
                });
            };

            reader.readAsDataURL(file);
        });
    }

    handleInputChange(event) {
        const fieldName = event.target.name;
        const index = event.target.dataset.index;
        const value = event.target.value;
        
        if (fieldName === 'RFAB__Tax_Percent__c') {
            return;
        }
        
        this.purchaseOrderItems = this.purchaseOrderItems.map((item, i) => {
            if (i == index) {
                return {
                    ...item,
                    [fieldName]: value,
                    RFAB__Tax_Percent__c: item.RFAB__Tax_Percent__c
                };
            }
            return item;
        });
        this.checkSerialNumbers();
    }

    checkSerialNumbers() {
        this.isCreateEnabled = this.purchaseOrderItems.every(item => {
            return item.Serial_Number__c && item.Serial_Number__c.trim() !== '';
        });
    }

    get isButtonDisabled() {
        return !this.isCreateEnabled;
    }

    handleDeleteRow(event) {
        const index = event.target.dataset.index;
        this.purchaseOrderItems = this.purchaseOrderItems.filter((_, i) => i != index);
    }

    handleInputExpenseChange(event) {
        const fieldName = event.target.name;
        const index = event.target.dataset.index;
        let value = event.target.value;

        if (['RFAB__Amount_excluding__c', 'Tax_Amount__c'].includes(fieldName)) {
            value = parseFloat(value) || 0;
        }

        this.expenseItems = this.expenseItems.map((item, i) => {
            if (i == index) {
                const updatedItem = { ...item, [fieldName]: value };
                const base = parseFloat(updatedItem.RFAB__Amount_excluding__c) || 0;
                const tax = parseFloat(updatedItem.Tax_Amount__c) || 0;
                updatedItem.RFAB__Total_Amount__c = parseFloat((base + tax).toFixed(2));
                return updatedItem;
            }
            return item;
        });
    }

    handleLocationSearch(event) {
        const searchKey = event.target.value;
        const index = event.target.dataset.index;
    
        if (searchKey.length > 2) {
            searchLocation({ searchKey })
                .then(data => {
                    this.purchaseOrderItems = this.purchaseOrderItems.map((item, i) => ({
                        ...item,
                        searchResults: i === parseInt(index) ? data : []
                    }));
                })
                .catch(error => {
                    console.error('Error Searching Location', error);
                });
        } else {
            this.clearSearchResults(index);
        }
    }
    
    selectLocation(event) {
        const index = event.target.dataset.index;
        const locationId = event.currentTarget.dataset.id;
    
        const selectedLocation = this.purchaseOrderItems[index].searchResults.find(l => l.Id === locationId);
        if (selectedLocation) {
            this.purchaseOrderItems[index] = {
                ...this.purchaseOrderItems[index],
                RFAB__Location__c: selectedLocation.Id,
                Name: RFAB__Location__c.Name,
                searchResults: []
            };
        }
    }

    clearSearchResults(index) {
        this.purchaseOrderItems = this.purchaseOrderItems.map((item, i) => ({
            ...item,
            searchResults: i === parseInt(index) ? [] : item.searchResults
        }));
    }

    
    handleSaveDraft() {
        this.isButtonDisabled = true;
        try {
            const missingSerial = this.purchaseOrderItems.some(item => 
                item.isSerial && (!item.Serial_Number__c || item.Serial_Number__c.trim() === '')
            );
            
            if (missingSerial) {
                this.showToast('Error', 'Please enter all required Serial Numbers before saving.', 'error');
                this.isButtonDisabled = false;
                return;
            }

            let serialNumbers = this.purchaseOrderItems.map(item => item.Serial_Number__c || '');
            const cleanedExpenseItems = this.expenseItems.map(exp => {
                const { fileMetadata, ...allowedFields } = exp;
                return allowedFields;
            });

            saveDraftGRN({
                purchaseOrderId: this.recordId,
                existingGRNId: this.existingGRNId,
                updatedpurchaseOrder: this.purchaseOrder,
                poItems: this.purchaseOrderItems,
                serialNumbers: serialNumbers,
                expenseItems: cleanedExpenseItems,
                expenseFileIdLists: this.expenseItems.map(exp => exp.uploadedFileIds || []),
                grnDeliveryDate: this.grnDeliveryDate,
                grnChartOfAccountId: this.grnChartOfAccountId || null,
                grnFileIds: this.grnUploadedFileIds,
                grnRemovedFileIds: this.grnRemovedFileIds
            })
                .then((grnId) => {
                    console.log('Draft GRN Saved with Id:', grnId);
                    this.existingGRNId = grnId;
                    this.isDraftMode = true;
                    this.grnRemovedFileIds = []; // Reset removed files array after successful save
                    this.showToast('Success', 'Draft GRN Saved Successfully', 'success');
                    this.isButtonDisabled = false;
                })
                .catch(error => {
                    console.error('Error saving draft:', error);
                    this.showToast('Error', error.body?.message || 'Failed to save draft', 'error');
                    this.isButtonDisabled = false;
                });
        } catch (error) {
            console.error('Error in handleSaveDraft:', error);
            this.showToast('Validation Error', error.message, 'error');
            this.isButtonDisabled = false;
        }
    }

    handleSave() {
        this.isButtonDisabled = true;
        try {
            const missingSerial = this.purchaseOrderItems.some(item => 
                item.isSerial && (!item.Serial_Number__c || item.Serial_Number__c.trim() === '')
            );
            
            // Initialize arrays if they don't exist
            if (!Array.isArray(this.grnUploadedFileIds)) {
                this.grnUploadedFileIds = [];
            }
            if (!Array.isArray(this.grnRemovedFileIds)) {
                this.grnRemovedFileIds = [];
            }
            
            console.log('Debug - Save Operation:');
            console.log('Removed Files:', JSON.stringify(this.grnRemovedFileIds));
            console.log('Current Files:', JSON.stringify(this.grnUploadedFileIds));
            
            if (missingSerial) {
                this.showToast('Error', 'Please enter all required Serial Numbers before saving.', 'error');
                this.isButtonDisabled = false;
                return;
            }
            
            const grnChartOfAccountId = this.grnChartOfAccountSearchKey.trim() === '' ? null : this.grnChartOfAccountId;
    
            let serialNumbers = this.purchaseOrderItems.map(item => item.Serial_Number__c || '');
            
            const cleanedExpenseItems = this.expenseItems.map(exp => {
                return {
                    id: exp.id,
                    expenseRecordId: exp.expenseRecordId || null, // Include existing record ID for updates
                    Name: exp.Name,
                    RFAB__Date__c: exp.RFAB__Date__c,
                    RFAB__Description__c: exp.RFAB__Description__c,
                    RFAB__Amount_excluding__c: exp.RFAB__Amount_excluding__c,
                    Tax_Amount__c: exp.Tax_Amount__c,
                    RFAB__Total_Amount__c: exp.RFAB__Total_Amount__c,
                    RFAB__Chart_of_Accounts__c: (exp.chartOfAccountSearchKey && exp.chartOfAccountSearchKey.trim() !== '') 
                        ? exp.RFAB__Chart_of_Accounts__c 
                        : null,
                    Purchase_Order__c: this.recordId,
                    uploadedFileIds: exp.uploadedFileIds || []
                };
            });
        
            const currentFiles = Array.isArray(this.grnUploadedFileIds) ? this.grnUploadedFileIds : [];
            const removedFiles = Array.isArray(this.grnRemovedFileIds) ? this.grnRemovedFileIds : [];
            
            console.log('About to save with files:', {
                current: currentFiles,
                removed: removedFiles,
                chartOfAccountId: grnChartOfAccountId
            });
    
            CreateGRNs({
                purchaseOrderId: this.recordId,
                existingGRNId: this.existingGRNId,
                updatedpurchaseOrder: this.purchaseOrder,
                poItems: this.purchaseOrderItems,
                serialNumbers: serialNumbers, 
                expenseItems: cleanedExpenseItems,
                expenseFileIdLists: this.expenseItems.map(exp => exp.uploadedFileIds || []),
                grnDeliveryDate: this.grnDeliveryDate,
                grnChartOfAccountId: grnChartOfAccountId || null,
                grnFileIds: currentFiles,
                grnRemovedFileIds: removedFiles
            })
                .then((grnId) => {
                    console.log('GRN Created/Updated with Id:', grnId);
                    const message = this.existingGRNId 
                        ? 'GRN Updated and Completed Successfully' 
                        : 'GRN Created Successfully';
                    this.grnRemovedFileIds = [];
                    this.showToast('Success', message, 'success');
                    
                    setTimeout(() => {
                        window.location.reload();
                    }, 1000);
                })
                .catch(error => {
                    this.showToast('Error', error.body.message, 'error');
                    this.isButtonDisabled = false;
                });
        } catch (error) {
            console.error('Error in handleSave:', error);
            this.showToast('Validation Error', error.message, 'error');
            this.isButtonDisabled = false;
        }
    }

    handleUploadFinished(event) {
        event.detail.files.forEach(file => {
            this.uploadedFileIds.push(file.documentId);
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }

    handleClose() {
        if (confirm('Are you sure you want to cancel? All unsaved changes will be lost.')) {
            this.isButtonDisabled = false;
            this.isLoading = true;
            
            this.expenseItems = [
                { id: '1', Name: 'Freight Charges', RFAB__Date__c: '', RFAB__Description__c: '',RFAB__Amount_excluding__c:'', RFAB__Total_Amount__c: 0, Tax_Amount__c:0, RFAB__Chart_of_Accounts__c:'',chartOfAccountResults:[],uploadedFileIds: [], uploadedFileCount: 0, isNameEditable: true },
                { id: '2', Name: 'Additional Charges', RFAB__Date__c: '', RFAB__Description__c: '',RFAB__Amount_excluding__c:'', RFAB__Total_Amount__c: 0, Tax_Amount__c:0, RFAB__Chart_of_Accounts__c:'',chartOfAccountResults:[],uploadedFileIds: [],uploadedFileCount: 0, isNameEditable: false },
                { id: '3', Name: 'Bill of Entry', RFAB__Date__c: '', RFAB__Description__c: '',RFAB__Amount_excluding__c:'', RFAB__Total_Amount__c: 0, Tax_Amount__c:0, RFAB__Chart_of_Accounts__c:'',chartOfAccountResults:[],uploadedFileIds: [],uploadedFileCount: 0, isNameEditable: true }
            ];
            
            this.purchaseOrderItems = [];
            
            refreshApex(this.wiredPurchaseOrderResult)
                .then(() => {
                    return getOrCreateDraftGRN({ poId: this.recordId });
                })
                .then(result => {
                    console.log('Reloaded Draft GRN Result:', JSON.stringify(result));
                    
                    if (result.isDraft) {
                        this.isDraftMode = true;
                        this.existingGRNId = result.grnId;
                        this.loadDraftData(result);
                    } else {
                        this.isDraftMode = false;
                        this.existingGRNId = null;
                    }
                    
                    this.isLoading = false;
                    this.showToast('Success', 'Changes have been reverted', 'success');
                })
                .catch(error => {
                    console.error('Error reverting changes:', error);
                    this.showToast('Error', 'Failed to revert changes: ' + (error.body?.message || error.message), 'error');
                    this.isLoading = false;
                });
        }
    }

    handleRemoveFile(event) {
        event.stopPropagation();
        const fileId = event.target.dataset.id;
        const index = this.selectedRowIndex;
        
        if (this.expenseItems[index]) {
            this.expenseItems[index].uploadedFileIds = this.expenseItems[index].uploadedFileIds.filter(id => id !== fileId);
            
            if (this.expenseItems[index].fileMetadata) {
                delete this.expenseItems[index].fileMetadata[fileId];
            }
            
            this.expenseItems[index].uploadedFileCount = this.expenseItems[index].uploadedFileIds.length;
            this.selectedFiles = this.selectedFiles.filter(file => file.id !== fileId);
            
            if (this.previewFileUrl && this.previewFileUrl.includes(fileId)) {
                this.previewFileUrl = '';
            }
            
            this.expenseItems = [...this.expenseItems];
        }
    }
}
