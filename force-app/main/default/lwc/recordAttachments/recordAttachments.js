//AB 26JUN25 Reusable Attachment View Component
import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getJournalEntryAttachments from '@salesforce/apex/JournalEntryController.getJournalEntryAttachments';
import deleteFileFromJE from '@salesforce/apex/JournalEntryController.deleteFileFromJE';
import getAttachments from '@salesforce/apex/billItemsTabHandler.getAttachments';
import deleteAttachment from '@salesforce/apex/billItemsTabHandler.deleteAttachment';

const columns = [
    {
        label: 'File Name',
        fieldName: 'fileName',
        type: 'button',
        typeAttributes: {
            label: { fieldName: 'fileName' },
            name: 'preview',
            variant: 'base'
        },
        sortable: true
    },
    {
        label: 'Created Date',
        fieldName: 'createdDate',
        type: 'date',
        typeAttributes: {
            year: 'numeric',
            month: 'short',
            day: '2-digit'
        },
        sortable: true
    },
    {
        label: 'Actions',
        type: 'button-icon',
        fixedWidth: 75,
        typeAttributes: {
            iconName: 'utility:delete',
            name: 'delete',
            title: 'Delete',
            variant: 'border-filled',
            alternativeText: 'Delete'
        }
    }
];

export default class RecordAttachments extends NavigationMixin(LightningElement) {
    @api recordId;
    @api fetchAttachmentsMethod; // Apex method name as string
    @api deleteAttachmentMethod; // Apex method name as string
    @api cardTitle = 'Attachments';
    @track attachments = [];
    @track selectedFileId;
    @track selectedFileName;
    @track selectedFileType;
    @track fileContent;
    @track isImageFile = false;
    @track isPdfFile = false;
    @track isPreviewLoading = false;
    @track isLoading = false;
    @track error;
    @track showPreview = false;
    @track showDeleteModal = false;
    @track fileToDelete = null;
    @track isDeleting = false;
    columns = columns;

    connectedCallback() {
        this.loadAttachments();
    }

    async loadAttachments() {
        if (!this.recordId || !this.fetchAttachmentsMethod) return;
        this.isLoading = true;
        this.error = null;
        try {
            // Use a static method map for Apex methods
            const fetchMethodMap = {
                'JournalEntryController.getJournalEntryAttachments': getJournalEntryAttachments,
                'billItemsTabHandler.getAttachments': getAttachments
            };
            const method = fetchMethodMap[this.fetchAttachmentsMethod];
            if (!method) throw new Error('Invalid fetchAttachmentsMethod');
            let result;
            if (this.fetchAttachmentsMethod === 'JournalEntryController.getJournalEntryAttachments') {
                result = await method({ journalEntryIds: [this.recordId] });
                this.attachments = Array.isArray(result) ? result.map(doc => ({
                    id: doc.fileId,
                    fileName: doc.fileName,
                    createdDate: doc.billDate || doc.entryDate || new Date(),
                    fileId: doc.fileId,
                    fileType: doc.fileExtension ? doc.fileExtension.toLowerCase() : 'unknown'
                })) : [];
            } else if (this.fetchAttachmentsMethod === 'billItemsTabHandler.getAttachments') {
                result = await method({ billIds: [this.recordId] });
                // billItemsTabHandler.getAttachments returns a list of BillWrapper, each with a .document property (list of DocumentWrapper)
                this.attachments = [];
                if (Array.isArray(result) && result.length > 0) {
                    const billWrapper = result[0];
                    if (billWrapper.document && Array.isArray(billWrapper.document)) {
                        this.attachments = billWrapper.document.map(doc => ({
                            id: doc.fileId,
                            fileName: doc.fileName,
                            createdDate: doc.billDate || new Date(),
                            fileId: doc.fileId,
                            fileType: doc.fileExtension ? doc.fileExtension.toLowerCase() : 'unknown'
                        }));
                    }
                }
            } else {
                this.attachments = [];
            }
        } catch (error) {
            this.error = error;
            this.showToast('Error', 'Failed to load attachments: ' + (error.body?.message || error.message), 'error');
        }
        this.isLoading = false;
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        if (actionName === 'preview') {
            this.selectedFileId = row.fileId;
            this.selectedFileName = row.fileName;
            this.selectedFileType = row.fileType;
            this.showPreview = true;
            this.loadFilePreview();
        } else if (actionName === 'delete') {
            this.fileToDelete = row;
            this.showDeleteModal = true;
        }
    }

    async handleDeleteConfirm() {
        if (this.fileToDelete && this.deleteAttachmentMethod) {
            this.isDeleting = true;
            try {
                // Use a static method map for delete methods
                const deleteMethodMap = {
                    'JournalEntryController.deleteFileFromJE': deleteFileFromJE,
                    'billItemsTabHandler.deleteAttachment': deleteAttachment
                };
                const method = deleteMethodMap[this.deleteAttachmentMethod];
                if (!method) throw new Error('Invalid deleteAttachmentMethod');
                // Pass correct params for each method
                if (this.deleteAttachmentMethod === 'JournalEntryController.deleteFileFromJE') {
                    await method({ contentDocumentId: this.fileToDelete.fileId, journalEntryId: this.recordId });
                } else if (this.deleteAttachmentMethod === 'billItemsTabHandler.deleteAttachment') {
                    await method({ contentDocumentId: this.fileToDelete.fileId });
                }
                if (this.selectedFileId === this.fileToDelete.fileId) {
                    this.handlePreviewClose();
                }
                this.showToast('Success', 'File deleted successfully', 'success');
                await this.loadAttachments();
                this.handleDeleteCancel();
                // window.location.reload(); // Refresh the page to reflect changes
            } catch (error) {
                this.showToast('Error', 'Failed to delete file: ' + (error.body?.message || error.message), 'error');
                this.isDeleting = false;
            }
        }
    }

    handleDeleteCancel() {
        this.showDeleteModal = false;
        this.fileToDelete = null;
        this.isDeleting = false;
    }

    loadFilePreview() {
        this.isPreviewLoading = true;
        this.fileContent = null;
        this.isImageFile = false;
        this.isPdfFile = false;
        const fileType = this.selectedFileType;
        if (["jpg", "jpeg", "png", "gif", "bmp", "svg"].includes(fileType)) {
            this.isImageFile = true;
            this.fileContent = `/sfc/servlet.shepherd/document/download/${this.selectedFileId}`;
            this.isPreviewLoading = false;
        } else if (fileType === "pdf") {
            this.isPdfFile = true;
            this[NavigationMixin.Navigate]({
                type: "standard__namedPage",
                attributes: { pageName: "filePreview" },
                state: { recordIds: this.selectedFileId }
            });
            this.isPreviewLoading = false;
        } else {
            this.isPreviewLoading = false;
        }
    }

    handlePreviewInNewTab() {
        if (this.selectedFileId) {
            this[NavigationMixin.Navigate]({
                type: "standard__namedPage",
                attributes: { pageName: "filePreview" },
                state: { recordIds: this.selectedFileId }
            });
        }
    }

    handleDownloadFile() {
        if (this.selectedFileId) {
            const downloadUrl = `/sfc/servlet.shepherd/document/download/${this.selectedFileId}`;
            window.open(downloadUrl, "_blank");
        }
    }

    handlePreviewClose() {
        this.showPreview = false;
        this.selectedFileId = null;
        this.selectedFileName = null;
        this.selectedFileType = null;
        this.fileContent = null;
        this.isImageFile = false;
        this.isPdfFile = false;
        this.isPreviewLoading = false;
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({ title, message, variant });
        this.dispatchEvent(evt);
    }

    get hasAttachments() {
        return this.attachments && this.attachments.length > 0;
    }

    get noAttachmentsMessage() {
        return this.isLoading ? 'Loading attachments...' : 'No attachments found';
    }

    get deleteModalTitle() {
        return `Delete ${this.fileToDelete?.fileName || 'File'}`;
    }

    get errorMessage() {
        return this.error && this.error.body && this.error.body.message ? this.error.body.message : 'Unknown error';
    }
}