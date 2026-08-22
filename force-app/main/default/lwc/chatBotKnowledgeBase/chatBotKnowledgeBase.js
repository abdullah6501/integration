import { LightningElement, track } from 'lwc';
import shareKnowledge from '@salesforce/apex/ChatService.shareKnowledge';
import createCollection from '@salesforce/apex/KnowledgeBaseClient.createCollection'
import deleteCollection from '@salesforce/apex/KnowledgeBaseClient.deleteCollection'
import suggestMetadata from '@salesforce/apex/KnowledgeBaseClient.suggestMetadata'
import getDocumentBySource from '@salesforce/apex/KnowledgeBaseClient.getDocumentBySource'
import updateDocumentBySource from '@salesforce/apex/KnowledgeBaseClient.updateDocumentBySource'
import deleteDocumentBySource from '@salesforce/apex/KnowledgeBaseClient.deleteDocumentBySource'
import extract_doc_url from '@salesforce/apex/Document_Extract_Helper.extract_doc_url';



export default class KnowledgeDialog extends LightningElement {

    // variables for Knowledge Browsing tab
    originalContent ='';
    // variables for Knowledge sharing tab

    // Active tab
    @track activeTab = 'shareKnowledge';
    acceptedFormats = ['.pdf', '.doc', '.docx', '.txt', '.md']; 


    // Type selection
    @track knowledgeType = '';
    knowledgeTypeOptions = [
        { label: 'Manual', value: 'manual' },
        { label: 'URL', value: 'url' },
        { label: 'Document', value: 'document' }
    ];

    // Share knowledge input fields
    @track knowledgeTitle = '';
    @track knowledgeContent = '';
    @track knowledgeUrl = '';
    @track manualDocuments = [];
    @track urls = [];
    @track fileDocuments = [];

    // Browse knowledge
    @track searchText = '';
    @track allKnowledge = [
        { id: 1, title: 'Reset Password', content: 'Steps to reset your password' },
        { id: 2, title: 'Create a Case', content: 'How to create a new support case' }
    ];
    @track knowledgeList = []; 
    @track selectedItem = null;
    @track isEditing = false;
    @track editedTitle = '';
    @track editedContent = '';
    get showManualFields() {
        return this.knowledgeType === 'manual';
    }
    get showUrlField() {
        return this.knowledgeType === 'url';
    }
    get showDocumentField() {
        return this.knowledgeType === 'document';
    }
    get filteredKnowledge() {
        if (!this.searchText) return this.allKnowledge;
        return this.allKnowledge.filter(item =>
            item.title.toLowerCase().includes(this.searchText.toLowerCase())
        );
    }

    // to show buttons for submit and cancel to share knowledge
    get hasDataToSubmit() {
        return (
            (this.manualDocuments && this.manualDocuments.length > 0) ||
            (this.urls && this.urls.length > 0) ||
            (this.fileDocuments && this.fileDocuments.length > 0)
        );
    }
    // Tab navigation
    handleTabChange(event) {
        this.activeTab = event.target.value;
    }

    // Combobox change
    handleKnowledgeTypeChange(event) {
        this.knowledgeType = event.detail.value;
    }

    // Manual input changes
    handleKnowledgeTitleChange(event) {
        this.knowledgeTitle = event.detail.value;
    }
    handleKnowledgeContentChange(event) {
        this.knowledgeContent = event.detail.value;
    }

    // URL input change
    handleKnowledgeUrlChange(event) {
        this.knowledgeUrl = event.detail.value;
    }

    // Add manual knowledge item
    addKnowledgeItem() {
        if (this.knowledgeTitle && this.knowledgeContent) {
            this.manualDocuments.push({
                title: this.knowledgeTitle,
                content: this.knowledgeContent
            });
            this.knowledgeTitle = '';
            this.knowledgeContent = '';
            console.log('manual',JSON.stringify(this.manualDocuments))
        }
    }

    // Add URL item
    addUrl() {
        if (this.knowledgeUrl) {
            this.urls.push(this.knowledgeUrl);
            this.knowledgeUrl = '';
        }
    }
    resetKnowledgeForm() {
        this.knowledgeType = 'url';
        this.knowledgeTitle = '';
        this.knowledgeContent = '';
        this.knowledgeUrl = '';
        this.manualDocuments = [];
        this.fileDocuments = [];
        this.urls = [];
    }

    // Upload documents
    async handleDocumentUpload(event) {
        const uploadedFiles = event.detail.files;

        for (const file of uploadedFiles) {
            // Check if file name already exists
            const isDuplicate = this.fileDocuments.some(
                doc => doc.title === file.name
            );

            if (isDuplicate) {
                console.warn(`Duplicate file skipped: ${file.name}`);
                // Optionally show a toast here
                continue;
            }
            try {
                const attachment_url = await extract_doc_url({ docId: file.documentId });
                console.log('doc url:', attachment_url);

                this.fileDocuments.push({
                    documentId: file.documentId,
                    title: file.name,
                    Url: attachment_url
                });
            } catch (error) {
                console.error('Error on attaching document:', error);
            }
        }
    }

    // Remove items
    removeKnowledgeItem(event) {
    const index = event.currentTarget.dataset.index;
    this.manualDocuments.splice(index, 1);
    this.manualDocuments = [...this.manualDocuments];
    }

    removeUrl(event) {
        const index = event.currentTarget.dataset.index;
        this.urls.splice(index, 1);
        this.urls = [...this.urls];
    }

    removeDocument(event) {
        const index = event.currentTarget.dataset.index;
        this.fileDocuments.splice(index, 1);
        this.fileDocuments = [...this.fileDocuments];
    }

    // Knowledge Base search
    handleSearch(event) {
        this.searchText = event.target.value;
    }

    // Edit and delete handlers
    editItem(event) {
        const id = event.currentTarget.dataset.id;
        // Replace this with inline edit or modal
        alert(`Edit knowledge item with ID: ${id}`);
    }

    deleteItem(event) {
        const id = parseInt(event.currentTarget.dataset.id, 10);
        this.allKnowledge = this.allKnowledge.filter(item => item.id !== id);
    }

    // Submit all new data (share tab)
    submitData() {
        this.isLoading = true;
        shareKnowledge({ urls: this.urls, manualDocuments: this.manualDocuments, fileDocuments: this.fileDocuments })
            .then((result) => {
                alert('Knowledge shared successfully');
                this.isLoading = false;
                this.resetKnowledgeForm();
            })
            .catch(error => {
                this.isLoading = false;
                alert('Error: ' + error.body.message);
            });
    }

    // cancel all new data (share tab)
    cancelShare() {
    this.manualDocuments = [];
    this.urls = [];
    this.fileDocuments = [];
    }

    // Dialog control
    closeDialog() {
        this.dispatchEvent(new CustomEvent('closedialog'));
    }



    handleOverlayClick() {
        this.closeDialog();
    }

    handleSearch(event) {
        this.searchText = event.detail.value.trim();
        this.selectedItem = this.knowledgeList.find(item => item.title === this.searchText) || null;
        this.isEditing = false;
    }

    startEditing() {
        this.editedTitle = this.selectedItem.title;
        this.editedContent = this.selectedItem.content;
        this.isEditing = true;
    }

    handleEditedTitleChange(event) {
        this.editedTitle = event.detail.value;
    }

    handleEditedContentChange(event) {
        this.editedContent = event.detail.value;
    }

    saveEditedItem() {
        this.selectedItem.title = this.editedTitle;
        this.selectedItem.content = this.editedContent;
        this.isEditing = false;
    }

    deleteSelectedItem() {
        this.knowledgeList = this.knowledgeList.filter(item => item.id !== this.selectedItem.id);
        this.selectedItem = null;
        this.searchText = '';
    }

    cancelEditing() {
        this.content = this.originalContent;
        this.isEditing = false;
    }
  @track source = '';
    @track content = '';
    @track metadata = {};
    @track isNotEditing = false;
    @track documentFound = false;
    @track isLoading = false;
    @track error = '';

    handleSourceChange(event) {
        this.source = event.target.value;
    }

    handleKeyDown(event) {
        if (event.key === 'Enter') {
            this.fetchDocument();
        }
    }

    handleContentChange(event) {
        this.content = event.target.value;
    }

    handleEdit() {
        this.isEditing = true;
    }

    async handleSave() {
        this.isLoading = true;
        try {
            const payload = {
                document: this.content,
                metadata: this.metadata,
                forceVectorUpdate: true,
                forceVersionUpdate: true
            };
            await updateDocumentBySource({ browser: payload });
            this.isEditing = false;
            this.error = '';
        } catch (err) {
            this.error = 'Failed to save document';
            console.error(err);
        }
        this.isLoading = false;
    }

    handleCancel() {
        this.content = this.originalContent;
        this.isEditing = false;
    }

    async handleDelete() {
        this.isLoading = true;
        try {
            const response = await deleteDocumentBySource({ source: this.source });
            const result = JSON.parse(response);
        if (result.status === 'success') {
            this.resetUI();
        } else if (result.detail) {
            this.error = result.detail; 
        } else {
            this.error = 'Unknown error occurred while deleting the document.';
        }
        } catch (err) {
            this.error = 'Failed to delete document';
            console.error(err);
        }
        this.isLoading = false;
    }

    async fetchDocument() {
        this.isLoading = true;
        this.error = '';
        this.documentFound = false;
        try {
            const result = await getDocumentBySource({ source: this.source });
            this.content = result.document;
            this.error = result.error;
            this.originalContent = result.document;
            this.metadata = result.metadata;
            this.documentFound = true;
        } catch (err) {
            this.error = 'No document found for the given source';
            console.error(err);
        }
        this.isLoading = false;
    }

    resetUI() {
        this.source = '';
        this.content = '';
        this.metadata = {};
        this.documentFound = false;
        this.isEditing = false;
        this.error = '';
    }
}