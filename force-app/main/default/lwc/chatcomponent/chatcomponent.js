// AT 10MAY25 Ai_chatbot componenet -->
import { LightningElement, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import extract_doc_url from '@salesforce/apex/Document_Extract_Helper.extract_doc_url';



export default class ChatComponent extends LightningElement {
    @api ischatvisible = false;
    @track messages = [];
    newMessage = '';
    @api chatmessages;
    @api chatloading = false
    @track uploadedFiles = [];
    @track attachment_url = '';


    renderedCallback() {
        const container = this.template.querySelector('.chat-messages');
        if (container) {
            container.scrollTop = container.scrollHeight;
        }
    }

    handleInputChange(event) {
        this.newMessage = event.target.value;
    }
    async handleDocUpload(event) {
        const uploadedFiles = event.detail.files;
        if (this.uploadedFiles.length > 1) {
            this.showToast('Warning', 'You can upload only one document per message.', 'warning');
            return;
        }
        if (uploadedFiles.length > 0) {
            let docId = uploadedFiles[0].documentId;
            console.log('doc id : ' + docId);
            try {
                this.attachment_url = await extract_doc_url({
                    docId: docId,
                });
                console.log('doc url : ' + this.attachment_url);

            } catch (error) {
                console.error('Error on attaching document:', error);
            }
        uploadedFiles.forEach(file => {
            this.uploadedFiles.push({
                name: file.name,
                documentId: file.documentId
            });
        });
        }
    }
    removeFile(event) {
    const docIdToRemove = event.currentTarget.dataset.id;
    this.uploadedFiles = this.uploadedFiles.filter(file => file.documentId !== docIdToRemove);
}
checkFileLimit(event) {
    if (this.uploadedFiles.length >= 1) {
        event.preventDefault(); // Prevent the file selector from opening
        this.showToast('Warning', 'You can upload only one document per message.', 'warning');
    }
}


    sendMessage() {
        if (this.newMessage.trim() !== '') {
            this.uploadedFiles =[];
            const newMsg = {
                id: Date.now(),
                senderName: 'You',
                message: this.newMessage,
                class: 'message sent',
                attachments: this.uploadedFiles,
                attachment_url: this.attachment_url
            };
            const history = {
                role: "user", 
                content: [{"type": "text", "text": this.newMessage}]
            }
            this.messages = [...this.messages, newMsg];
            const sendEvent = new CustomEvent('newmessage', {
                detail: { message: newMsg,
                            history: history}
            });
            this.dispatchEvent(sendEvent);
            this.newMessage = '';
        }
    }

    msgClass(msg) {
        return msg.isSender ? 'message sender' : 'message receiver';
    }
    showToast(title, message, variant) {
    const event = new ShowToastEvent({
        title: title,
        message: message,
        variant: variant,
        mode: 'dismissable'
    });
    this.dispatchEvent(event);
}
}