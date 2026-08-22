import { LightningElement, api, track } from 'lwc';

export default class ChatWindow extends LightningElement {
    @api selectedContactId;
    @track messages = [];
    @track contactName;
    newMessage = '';

    renderedCallback() {
        if (this.selectedContactId) {
            // Simulate loading messages for this contact
            this.contactName = 'Contact ' + this.selectedContactId.substring(0, 5);
            this.messages = [
                { id: 1, text: 'Hello!', cssClass: 'msg received' },
                { id: 2, text: 'Hi there!', cssClass: 'msg sent' }
            ];
        }
    }

    handleInputChange(event) {
        this.newMessage = event.target.value;
    }

    sendMessage() {
        if (this.newMessage.trim()) {
            this.messages = [
                ...this.messages,
                { id: Date.now(), text: this.newMessage, cssClass: 'msg sent' }
            ];
            this.newMessage = '';
        }
    }
}
