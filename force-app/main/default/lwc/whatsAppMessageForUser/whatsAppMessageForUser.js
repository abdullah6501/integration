import { LightningElement, api, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import sendImageToWhatsApp from '@salesforce/apex/WhatsAppImageSenderController.sendImageToWhatsApp';
import docPreview from '@salesforce/apex/WhatsAppImageSenderController.docPreview';
import imagePreview from '@salesforce/apex/WhatsAppImageSenderController.imagePreview';
import videoPreview from '@salesforce/apex/WhatsAppImageSenderController.videoPreview';
import sendMessage from '@salesforce/apex/WhatsAppOutMessage.sendMessage';
import getPhoneNumberForRecord from '@salesforce/apex/WhatsAppOutMessage.getPhoneNumberForRecord';
import getMessagesForPhoneNumber from '@salesforce/apex/WhatsAppOutMessage.getMessagesForPhoneNumber';
import getTemplateNames from '@salesforce/apex/WhatsAppTemplateController.getTemplateNames';
import getTemplateParameters from '@salesforce/apex/WhatsAppTemplateController.getTemplateParameters';
import sendTemplateMessage from '@salesforce/apex/WhatsAppTemplateController.sendTemplateMessage';

export default class WhatsAppMessageForUser extends LightningElement {
    @api recordId;
    @api contactName;
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

    get contactInitials() {
        if (!this.contactName) return 'WA';
        return this.contactName.split(' ').map(n => n[0]).join('').substring(0, 2).toUpperCase();
    }

    get hasPendingAttachment() {
        return !!(this.uploadedImageUrl || this.uploadedVideoUrl || this.uploadedDocUrl);
    }

    get sendButtonClass() {
        return (this.messageBody.trim() || this.hasPendingAttachment) ? 'send-button-active' : 'send-button-disabled';
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
            this.messages = result.data.map((message) => {
                const dateObj = new Date(message.CreatedDate);
                const formattedTime = isNaN(dateObj.getTime())
                    ? message.CreatedDate
                    : dateObj.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

                const isMe = message.Sender__c === 'Me';

                return {
                    ...message,
                    formattedTime: formattedTime,
                    cssClass: isMe ? 'message message-right' : 'message message-left',
                    isMe: isMe,
                    isImage: message.Type__c === 'image' && message.File_Show__c ? true : false,
                    isVideo: message.Type__c === 'video' && message.File_Show__c ? true : false,
                    isDocument: message.Type__c === 'document' && message.File_Show__c ? true : false,
                    isText: (message.Type__c === 'text' || !message.Type__c) && message.Message_Body__c ? true : false,
                    fileName: message.File_Name__c || 'Document'
                };
            });
            this.scrollToBottom();
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

    scrollToBottom() {
        setTimeout(() => {
            const container = this.template.querySelector('.chat-messages');
            if (container) {
                container.scrollTop = container.scrollHeight;
            }
        }, 100);
    }

    togglePopup() {
        this.showPopup = !this.showPopup;
    }

    closePopup() {
        this.showPopup = false;
    }

    async handleImageUpload(event) {
        const uploadedFiles = event.detail.files;
        if (uploadedFiles.length > 0) {
            this.fileId = uploadedFiles[0].documentId;
            this.previewId = uploadedFiles[0].documentId;
            const fileExtension = uploadedFiles[0].name.split('.').pop().toLowerCase();

            try {
                if (['jpg', 'jpeg', 'png', 'gif'].includes(fileExtension)) {
                    const previewUrl = await imagePreview({ previewId: this.previewId });
                    this.uploadedImageUrl = previewUrl;
                    this.uploadedVideoUrl = null;
                } else if (['mp4', 'avi', 'mov', 'mkv'].includes(fileExtension)) {
                    const previewUrl = await videoPreview({ previewId: this.previewId });
                    this.uploadedVideoUrl = previewUrl;
                    this.uploadedImageUrl = null;
                }
            } catch (error) {
                console.error('Error previewing media:', error);
                this.showToast('Error', 'Error previewing media', 'error');
            }
            this.showPopup = false;
        }
    }

    async handleDocUpload(event) {
        const uploadedFiles = event.detail.files;
        if (uploadedFiles.length > 0) {
            this.docId = uploadedFiles[0].documentId;
            try {
                const previewDocUrl = await docPreview({ docId: this.docId });
                this.uploadedDocUrl = previewDocUrl;
            } catch (error) {
                console.error('Error uploading document:', error);
                this.showToast('Error', 'Error previewing document', 'error');
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
        const imageUrl = event.currentTarget.dataset.imageUrl;
        if (imageUrl) {
            this.selectedImage = imageUrl;
            this.showImageModal = true;
        }
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
            this.showToast('Notice', 'Please enter a message or select a file to send', 'warning');
            return;
        }

        try {
            if (this.fileId) {
                await sendImageToWhatsApp({ phoneNumber: this.phoneNumber, fileId: this.fileId });
                this.fileId = null;
                this.uploadedImageUrl = null;
                this.uploadedVideoUrl = null;
                this.showToast('Success', 'Media sent successfully', 'success');
            }

            if (this.docId) {
                await sendImageToWhatsApp({ phoneNumber: this.phoneNumber, fileId: this.docId });
                this.docId = null;
                this.uploadedDocUrl = null;
                this.showToast('Success', 'Document sent successfully', 'success');
            }

            if (this.messageBody && this.messageBody.trim()) {
                await sendMessage({ phoneNumber: this.phoneNumber, message: this.messageBody });
                this.messageBody = '';
                this.showToast('Success', 'Message sent successfully', 'success');
            }

            await refreshApex(this.wiredMessagesResult);
            this.scrollToBottom();
        } catch (error) {
            console.error('Error sending message:', error);
            this.showToast('Error', 'Failed to send message', 'error');
        }
    }

    openTemplateModal() {
        this.showTemplateModal = true;
        this.showPopup = false;
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
                    name: param.trim(),
                    type: 'any'
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
        if (this.parameters[index]) {
            this.parameters[index].value = event.target.value;
        }
    }

    async sendTemplateMessage() {
        if (!this.templateName) {
            this.showToast('Warning', 'Please select a template first', 'warning');
            return;
        }

        try {
            const bodyParams = this.parameters.map(param => param.value);
            const buttonParams = this.parameters.map(param => param.value);
            await sendTemplateMessage({
                phoneNumber: this.phoneNumber,
                templateName: this.templateName,
                language: this.language,
                bodyParams: bodyParams,
                buttonParams: buttonParams
            });

            this.showToast('Success', 'Template message sent successfully', 'success');
            this.closeTemplateModal();
            await refreshApex(this.wiredMessagesResult);
            this.scrollToBottom();
        } catch (error) {
            console.error('Error sending template message:', error);
            this.showToast('Error', 'Failed to send template message', 'error');
        }
    }

    subscribeToMessages() {
        const channel = '/data/Message__ChangeEvent';
        subscribe(channel, -1, (message) => {
            this.handleCDCEvent(message);
        })
        .then((response) => {
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
            this.scrollToBottom();
        }
    }

    disconnectedCallback() {
        if (this.subscription) {
            unsubscribe(this.subscription);
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant,
        }));
    }
}