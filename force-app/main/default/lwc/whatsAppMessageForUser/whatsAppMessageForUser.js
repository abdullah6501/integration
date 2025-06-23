import { LightningElement, api, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import sendImageToWhatsApp from '@salesforce/apex/WhatsAppImageSenderController.sendImageToWhatsApp';
// import sendDocToWhatsApp from '@salesforce/apex/WhatsAppDocSender.sendDocToWhatsApp';
// import docPreview from '@salesforce/apex/WhatsAppDocSender.docPreview';
import docPreview from '@salesforce/apex/WhatsAppImageSenderController.docPreview';
import imagePreview from '@salesforce/apex/WhatsAppImageSenderController.imagePreview';
import videoPreview from '@salesforce/apex/WhatsAppImageSenderController.videoPreview';
import sendMessage from '@salesforce/apex/WhatsAppOutMessage.sendMessage';
import getPhoneNumberForRecord from '@salesforce/apex/WhatsAppOutMessage.getPhoneNumberForRecord';
import getMessagesForPhoneNumber from '@salesforce/apex/WhatsAppOutMessage.getMessagesForPhoneNumber';
import getTemplateNames from '@salesforce/apex/WhatsAppTemplateController.getTemplateNames';
import getTemplateParameters from '@salesforce/apex/WhatsAppTemplateController.getTemplateParameters';
import sendTemplateMessage from '@salesforce/apex/WhatsAppTemplateController.sendTemplateMessage';
// import { NavigationMixin } from 'lightning/navigation'; 

// export default class WhatsAppMessageForUser extends NavigationMixin(LightningElement) {
export default class WhatsAppMessageForUser extends LightningElement {
    @api recordId;
    @track phoneNumber;
    @track messages = [];
    @track messageBody = '';
    @track fileId = null;
    @track docId = null;
    @track previewId = null;
    @track showPopup = false;
    @track showImageModal = false;
    @track selectedImage = '';
    @track uploadedImageUrl = null;
    @track uploadedVideoUrl = null;
    @track uploadedDocUrl = null;
    @track showTemplateModal = false;
    @track templateOptions = [];
    @track templateName = '';
    @track parameters = [];
    @track language = '';
    messageListUpdated = false;
    subscription = null;
    wiredMessagesResult;

    renderedCallback() {
        console.log('before');
        if (this.messageListUpdated) {
            this.scrollToLastMessage();
            this.messageListUpdated = false;
        }
    }

    @wire(getPhoneNumberForRecord, { recordId: '$recordId' })
    wiredPhoneNumber({ error, data }) {
        if (data) {
            this.phoneNumber = data;
            this.subscribeToMessages();
        } else if (error) {
            console.error('Error fetching phone number:', error);
        }
    }

    @wire(getMessagesForPhoneNumber, { phoneNumber: '$phoneNumber' })
    wiredMessages(result) {
        this.wiredMessagesResult = result;
        if (result.data) {
            console.log('result.data : ' + JSON.stringify(result.data));
            
            this.messages = result.data.map((message) => ({
                ...message,
                CreatedDate: new Date(message.CreatedDate).toLocaleString(),
                cssClass: message.Sender__c === 'Me' ? 'message message-right' : 'message message-left',
                isImage: message.Type__c == 'image' && message.File_Show__c ? true : false,
                isVideo: message.Type__c == 'video' && message.File_Show__c ? true : false,
                isDocument: message.Type__c == 'document' && message.File_Show__c ? true : false,
                isText: message.Type__c == 'text' && message.Message_Body__c ? true : false,
                // documentTitle: message.File_Name__c,
                // documentId: message.ContentDocumentId,
            }));
            console.log('messages : ' + JSON.stringify(this.messages));

            this.messageListUpdated = true;
        } else if (result.error) {
            console.error('Error fetching messages:', result.error);
        }
    }

    @wire(getTemplateNames)
    wiredTemplateNames({ error, data }) {
        if (data) {
            this.templateOptions = data.map(record => ({
                label: record.name,
                value: record.name,
                language: record.language
            }));
        } else if (error) {
            console.error('Error fetching template names:', error);
        }
    }

    scrollToLastMessage() {
        console.log('enter to scroll');
        const chatContainer = this.template.querySelector('.chat-messages');
        if (chatContainer) {
            chatContainer.scrollTop = chatContainer.scrollHeight;
        }
    }

    togglePopup() {
        this.showPopup = !this.showPopup;
    }

    async handleImageUpload(event) {
        const uploadedFiles = event.detail.files;
        if (uploadedFiles.length > 0) {
            this.fileId = uploadedFiles[0].documentId;
            this.previewId = uploadedFiles[0].documentId;
            console.log('file preview id : ' + this.previewId);

            const fileExtension = uploadedFiles[0].name.split('.').pop().toLowerCase();

            try {
                if (['jpg', 'jpeg', 'png'].includes(fileExtension)) {
                    const previewUrl = await imagePreview({
                        previewId: this.previewId,
                    });
                    this.uploadedImageUrl = previewUrl;
                    this.uploadedVideoUrl = null;
                } else if (['mp4', 'avi', 'mov'].includes(fileExtension)) {
                    const previewUrl = await videoPreview({
                        previewId: this.previewId,
                    });
                    this.uploadedVideoUrl = previewUrl;
                    this.uploadedImageUrl = null;
                } else {
                    this.responseMessage = 'Unsupported file type.';
                }
            } catch (error) {
                console.error('Error previewing media:', error);
                this.responseMessage = 'Error previewing media. Please try again.';
            }
            this.showPopup = false;
        }
    }

    async handleDocUpload(event) {
        const uploadedFiles = event.detail.files;
        if (uploadedFiles.length > 0) {
            this.docId = uploadedFiles[0].documentId;
            console.log('doc id : ' + this.docId);
            try {
                const previewDocUrl = await docPreview({
                    docId: this.docId,
                });
                console.log('preview doc url : ' + previewDocUrl);

                this.uploadedDocUrl = previewDocUrl;
                console.log('uploaded doc url : ' + this.uploadedDocUrl);

            } catch (error) {
                console.error('Error sending image:', error);
                this.responseMessage = 'Error sending image. Please try again.';
            }
            this.showPopup = false;
        }
    }

    cancelImageUpload() {
        this.fileId = null;
        this.uploadedImageUrl = null;
    }

    cancelVideoUpload() {
        this.fileId = null;
        this.uploadedVideoUrl = null;
    }

    cancelDocUpload() {
        this.docId = null;
        this.uploadedDocUrl = null;
    }

    handleImageClick(event) {
        console.log(event);
        console.log(event.target.dataset.imageUrl);

        const imageUrl = event.target.dataset.imageUrl;
        this.selectedImage = imageUrl;
        this.showImageModal = true;
    }

    closeImageModal() {
        this.selectedImage = '';
        this.showImageModal = false;
    }

    handleMessageChange(event) {
        this.messageBody = event.target.value;
    }

    handleKeyPress(event) {
        if (event.key === 'Enter' && !event.shiftKey) {
            event.preventDefault();
            this.sendMessage();
        }
    }

    async sendMessage() {
        if (!this.messageBody && !this.fileId && !this.docId) {
            this.showToast('Error', 'Please enter a message or upload an image/document.', 'warning');
            return;
        }

        try {
            if (this.fileId) {
                await sendImageToWhatsApp({ phoneNumber: this.phoneNumber, fileId: this.fileId });
                this.fileId = null;
                this.uploadedImageUrl = null;
                this.uploadedVideoUrl = null;
                this.showToast('Success', 'Media Sent Successfully', 'success');
            }

            if (this.docId) {
                await sendImageToWhatsApp({ phoneNumber: this.phoneNumber, fileId: this.docId });
                this.docId = null;
                this.uploadedDocUrl = null;
                this.showToast('Success', 'Document Sent Successfully', 'success');
            }

            if (this.messageBody) {
                await sendMessage({ phoneNumber: this.phoneNumber, message: this.messageBody });
                this.messageBody = '';
                this.showToast('Success', 'Message Sent Successfully', 'success');
            }
            this.scrollToLastMessage();

            await refreshApex(this.wiredMessagesResult);
        } catch (error) {
            console.error('Error sending message or image:', error);
            this.showToast('Failed', 'Message Failed', 'error');
        }
    }

    openTemplateModal() {
        this.showTemplateModal = true;
    }

    closeTemplateModal() {
        this.showTemplateModal = false;
        this.templateName = '';
        this.parameters = [];
    }

    async handleTemplateSelection(event) {
        this.templateName = event.target.value;
        const selectedOption = this.templateOptions.find(option => option.value === this.templateName);
        this.language = selectedOption ? selectedOption.language : null;
        
        try {
            const paramString = await getTemplateParameters({ templateName: this.templateName });
            if (paramString) {
                const paramArray = paramString.split(',');
                this.parameters = paramArray.map((param, index) => ({ 
                    index, 
                    value: '', 
                    name: param.trim() 
                }));
            } else {
                this.parameters = [];
            }
        } catch (error) {
            console.error('Error fetching template parameters:', error);
            this.parameters = [];
        }
    }

    handleParameterChange(event) {
        const index = event.target.dataset.index;
        this.parameters[index].value = event.target.value;
    }

    async sendTemplateMessage() {
        try {
            const paramValues = this.parameters.map(param => param.value);
            await sendTemplateMessage({
                phoneNumber: this.phoneNumber,
                templateName: this.templateName,
                language: this.language,
                parameters: paramValues
            });

            this.showToast('Success', 'Template message sent successfully', 'success');
            this.closeTemplateModal();
            await refreshApex(this.wiredMessagesResult);
        } catch (error) {
            console.error('Error sending template message:', error);
            this.showToast('Error', 'Failed to send template message', 'error');
        }
    }

    subscribeToMessages() {
        const channel = '/data/Message__ChangeEvent';
        subscribe(channel, -1, (message) => {
            console.log('Received change event:', message);
            this.handleCDCEvent(message);
        })
            .then((response) => {
                console.log('Subscribed to CDC channel:', response.channel);
                this.subscription = response;
            })
            .catch((error) => {
                console.error('Error subscribing to CDC:', error);
            });

        onError((error) => {
            console.error('CDC error:', error);
        });
    }

    handleCDCEvent(message) {
        const changedRecord = message.data.payload;
        const receiver = changedRecord.Receiver__c;
        const sender = changedRecord.Sender__c;

        if (receiver === this.phoneNumber || sender === this.phoneNumber) {
            refreshApex(this.wiredMessagesResult);
        }
    }

    disconnectedCallback() {
        if (this.subscription) {
            unsubscribe(this.subscription, (response) => {
                console.log('Unsubscribed from CDC:', response);
            });
        }
    }

    showToast(title, message, variant) {
        const toastEvent = new ShowToastEvent({
            title,
            message,
            variant,
        });
        this.dispatchEvent(toastEvent);
    }

    // previewFile(event) {
    //     const contentDocumentId = event.currentTarget.dataset.id;
    //     this[NavigationMixin.Navigate]({
    //         type: 'standard__namedPage',
    //         attributes: {
    //             pageName: 'filePreview'
    //         },
    //         state: {
    //             selectedRecordId: contentDocumentId
    //         }
    //     });
    // }
}