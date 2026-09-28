import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import extract_doc_url from '@salesforce/apex/Document_Extract_Helper.extract_doc_url';

export default class ChatBot extends LightningElement {
    @api chatloading = false;
    @api isVisible = false;
    @api 
    get messages() {
        return this._messages || [];
    }
    
    set messages(value) {
        console.log('Messages setter called with:', value);
        this._messages = value;
        
        // Process new messages when the array is updated
        setTimeout(() => {
            this.processIncomingMessages();
        }, 0);
    }
    
    _messages = [];
    @track isExpanded = false;
    @track _lastProcessedMessageLength = 0;
    @track newMessage = '';
    @track uploadedFiles = [];
    @track attachment_url = '';
    @track showTemplate = false;
    
    @track _chatHistory = [];
    @track currentChatId = null;
    @track currentChat = null;
    @track nextChatId = 1;

    get chatContainerClass() {
        return `chat-container ${this.isExpanded ? 'expanded' : ''}`;
    }

    get mainChatClass() {
        return `main-chat ${this.isExpanded ? 'with-sidebar' : ''}`;
    }

    get chatStyle() {
        return this.isExpanded ? 'height: 80vh; width: 80%;' : '';
    }

    get expandIcon() {
        return this.isExpanded ? 'utility:contract' : 'utility:expand';
    }

    get expandCollapseTitle() {
        return this.isExpanded ? 'Minimize' : 'Expand';
    }

    get currentMessages() {
        return this.currentChat ? this.currentChat.messages : [];
    }

    get chatHistory() {
        return this._chatHistory.map(chat => ({
            ...chat,
            chatItemClass: chat.isActive ? 'chat-item active' : 'chat-item'
        }));
    }

    connectedCallback() {
        this.loadChatHistory();
        
        if (this._chatHistory.length === 0) {
            this.createNewChat();
        }
        
        // Process any existing messages
        this.processIncomingMessages();
    }

    renderedCallback() {
        // Process new messages if any
        this.processIncomingMessages();
        
        // Auto-scroll to bottom when new messages are added
        const messagesContainer = this.template.querySelector('.chat-messages');
        if (messagesContainer) {
            messagesContainer.scrollTop = messagesContainer.scrollHeight;
        }
    }

    // Process messages from parent component
    // processIncomingMessages() {
    //     const messages = this.messages;
    //     if (!messages || !Array.isArray(messages)) {
    //         return;
    //     }

    //     // Check if we have new messages to process
    //     if (messages.length > this._lastProcessedMessageLength) {
    //         const newMessages = messages.slice(this._lastProcessedMessageLength);
            
    //         newMessages.forEach(message => {
    //             if (message && (message.message || typeof message === 'string')) {
    //                 const messageText = message.message || message;
    //                 this.addMessageToCurrentChat({ message: messageText }, 'received');
    //             }
    //         });
            
    //         this._lastProcessedMessageLength = messages.length;
    //         console.log('Processed new messages:', newMessages);
    //     }
    // }
    // Process messages from parent component
processIncomingMessages() {
    const messages = this.messages;
    if (!messages || !Array.isArray(messages)) {
        return;
    }

    // Check if we have new messages to process
    if (messages.length > this._lastProcessedMessageLength) {
        const newMessages = messages.slice(this._lastProcessedMessageLength);
        
        newMessages.forEach(message => {
            if (message && (message.message || typeof message === 'string')) {
                const messageText = message.message || message;
                
                // Only add messages that are from the assistant/bot
                // Skip user messages to avoid duplication
                if (message.role === 'assistant' || message.sender === 'assistant' || 
                    (!message.role && !message.sender)) {
                    // Only process if it's clearly a response from the assistant
                    this.addMessageToCurrentChat({ message: messageText }, 'received');
                }
            }
        });
        
        this._lastProcessedMessageLength = messages.length;
        console.log('Processed new messages:', newMessages);
    }
}

    // Helper method to add message to current chat
    addMessageToCurrentChat(messageData, messageType = 'received') {
        if (!this.currentChat) {
            this.createNewChat();
        }

        const newMsg = {
            id: Date.now() + Math.random(),
            senderName: messageType === 'received' ? 'Assistant' : 'You',
            message: messageData.message || messageData,
            class: `message ${messageType}`,
            timestamp: this.formatTimestamp(new Date())
        };

        // Add message to current chat
        this.currentChat.messages.push(newMsg);
        
        // Update chat metadata
        this.currentChat.lastMessage = newMsg.message.length > 50 ? 
            newMsg.message.substring(0, 50) + '...' : newMsg.message;
        this.currentChat.timestamp = this.formatTimestamp(new Date());
        
        // Save and force reactivity
        this.saveChatHistory();
        this._chatHistory = [...this._chatHistory];
        
        console.log('Message added to current chat:', newMsg);
    }

    loadChatHistory() {
        try {
            // Using sessionStorage instead of localStorage for LWC compatibility
            const stored = sessionStorage.getItem('chatHistory');
            if (stored) {
                this._chatHistory = JSON.parse(stored);
                if (this._chatHistory.length > 0) {
                    const mostRecent = this._chatHistory.find(chat => chat.isActive) || this._chatHistory[0];
                    this.selectChatById(mostRecent.id);
                }
            }
        } catch (error) {
            console.error('Error loading chat history:', error);
            this._chatHistory = [];
        }
    }

    saveChatHistory() {
        try {
            // Using sessionStorage instead of localStorage for LWC compatibility
            sessionStorage.setItem('chatHistory', JSON.stringify(this._chatHistory));
        } catch (error) {
            console.error('Error saving chat history:', error);
        }
    }

    createNewChat() {
        const newChat = {
            id: this.nextChatId++,
            title: `Chat ${this.nextChatId - 1}`,
            messages: [],
            lastMessage: 'New conversation',
            timestamp: this.formatTimestamp(new Date()),
            isActive: false,
            createdAt: new Date()
        };

        // Mark all existing chats as inactive
        this._chatHistory.forEach(chat => {
            chat.isActive = false;
        });

        // Add new chat to the beginning of the array
        this._chatHistory.unshift(newChat);
        newChat.isActive = true;
        this.currentChatId = newChat.id;
        this.currentChat = newChat;
        
        this.saveChatHistory();
        
        // Force reactivity
        this._chatHistory = [...this._chatHistory];
        
        console.log('New chat created:', newChat);
    }

    selectChat(event) {
        const chatId = parseInt(event.currentTarget.dataset.chatId);
        this.selectChatById(chatId);
    }

    selectChatById(chatId) {
        console.log('Selecting chat with ID:', chatId);
        
        // Mark all chats as inactive
        this._chatHistory.forEach(chat => {
            chat.isActive = false;
        });

        const selectedChat = this._chatHistory.find(chat => chat.id === chatId);
        if (selectedChat) {
            selectedChat.isActive = true;
            this.currentChatId = chatId;
            this.currentChat = selectedChat;
            this.saveChatHistory();
            
            // Force reactivity
            this._chatHistory = [...this._chatHistory];
            
            console.log('Selected chat:', selectedChat);
        } else {
            console.error('Chat not found with ID:', chatId);
        }
    }

    deleteChat(event) {
        event.stopPropagation();
        const chatId = parseInt(event.currentTarget.dataset.chatId);
        
        if (this._chatHistory.length === 1) {
            this.showToast('Warning', 'Cannot delete the last chat. Create a new one first.', 'warning');
            return;
        }

        this._chatHistory = this._chatHistory.filter(chat => chat.id !== chatId);
        
        // If we deleted the current chat, select another one
        if (this.currentChatId === chatId) {
            if (this._chatHistory.length > 0) {
                this.selectChatById(this._chatHistory[0].id);
            } else {
                this.currentChat = null;
                this.currentChatId = null;
            }
        }
        
        this.saveChatHistory();
        console.log('Chat deleted:', chatId);
    }

    expandChat() {
        this.isExpanded = !this.isExpanded;
        
        if (this.isExpanded && this._chatHistory.length === 0) {
            this.createNewChat();
        }
    }

    closeChat() {
        this.isExpanded = false;
        this.dispatchEvent(new CustomEvent('closechat'));
    }

    handleMessageChange(event) {
        this.newMessage = event.target.value;
    }

    handleKeyPress(event) {
        if (event.key === 'Enter' && !event.shiftKey) {
            event.preventDefault();
            this.sendMessage();
        }
    }

    async handleFileUpload(event) {
        const uploadedFiles = event.detail.files;
        if (this.uploadedFiles.length > 0) {
            this.showToast('Warning', 'You can upload only one document per message.', 'warning');
            return;
        }
        if (uploadedFiles.length > 0) {
            let docId = uploadedFiles[0].documentId;
            try {
                this.attachment_url = await extract_doc_url({ docId });
            } catch (error) {
                console.error('Error on attaching document:', error);
            }
            this.uploadedFiles = [...this.uploadedFiles, {
                name: uploadedFiles[0].name,
                documentId: uploadedFiles[0].documentId
            }];
        }
    }

    removeFile(event) {
        const docIdToRemove = event.currentTarget.dataset.id;
        this.uploadedFiles = this.uploadedFiles.filter(file => file.documentId !== docIdToRemove);
    }

    checkFileLimit(event) {
        if (this.uploadedFiles.length >= 1) {
            event.preventDefault();
            this.showToast('Warning', 'You can upload only one document per message.', 'warning');
        }
    }

    sendMessage() {
        if (this.newMessage.trim() !== '') {
            // Ensure we have a current chat
            if (!this.currentChat) {
                this.createNewChat();
            }

            const newMsg = {
                id: Date.now(),
                senderName: 'You',
                message: this.newMessage,
                class: 'message sent',
                attachments: this.uploadedFiles.length > 0 ? [...this.uploadedFiles] : null,
                attachment_url: this.attachment_url,
                timestamp: this.formatTimestamp(new Date())
            };

            // Add message to current chat
            this.currentChat.messages.push(newMsg);
            
            // Update chat metadata
            this.currentChat.lastMessage = this.newMessage.length > 50 ? 
                this.newMessage.substring(0, 50) + '...' : this.newMessage;
            this.currentChat.timestamp = this.formatTimestamp(new Date());
            
            // Update chat title if it's the first message
            if (this.currentChat.title.startsWith('Chat ') && this.currentChat.messages.length === 1) {
                this.currentChat.title = this.newMessage.length > 30 ? 
                    this.newMessage.substring(0, 30) + '...' : this.newMessage;
            }

            const history = {
                role: "user",
                content: [{ type: "text", text: this.newMessage }]
            };

            // Dispatch event to parent component
            this.dispatchEvent(new CustomEvent('newmessage', {
                detail: {
                    message: newMsg,
                    history: history
                }
            }));

            // Clear input fields
            this.newMessage = '';
            this.uploadedFiles = [];
            this.attachment_url = '';
            
            // Save and force reactivity
            this.saveChatHistory();
            this._chatHistory = [...this._chatHistory];
            
            console.log('Message sent:', newMsg);
        }
    }

    @api
    handleResponse(response) {
        console.log('Handling response:', response);
        
        this.showTemplate = response && response.isTemplate;
        
        if (response && response.message && this.currentChat) {
            this.addMessageToCurrentChat(response, 'received');
            console.log('Response processed via handleResponse');
        } else {
            console.error('Invalid response or no current chat:', response, this.currentChat);
        }
    }

    handleFormSubmit(event) {
        const formData = event.detail;
        
        if (!this.currentChat) {
            this.createNewChat();
        }
        
        const newMsg = {
            id: Date.now(),
            senderName: 'You',
            message: 'Form submitted with data: ' + JSON.stringify(formData),
            class: 'message sent',
            timestamp: this.formatTimestamp(new Date())
        };

        this.currentChat.messages.push(newMsg);
        this.currentChat.lastMessage = 'Form submitted';
        this.currentChat.timestamp = this.formatTimestamp(new Date());
        
        this.saveChatHistory();
        this._chatHistory = [...this._chatHistory];

        this.dispatchEvent(new CustomEvent('newmessage', {
            detail: {
                message: newMsg,
                history: {
                    role: "user",
                    content: [{ type: "form", data: formData }]
                }
            }
        }));

        this.showTemplate = false;
    }

    handleVoiceInput() {
        this.showToast('Info', 'Voice input feature coming soon!', 'info');
    }

    formatTimestamp(date) {
        const now = new Date();
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const messageDate = new Date(date.getFullYear(), date.getMonth(), date.getDate());
        
        if (messageDate.getTime() === today.getTime()) {
            return date.toLocaleTimeString('en-US', { 
                hour: '2-digit', 
                minute: '2-digit' 
            });
        } else {
            return date.toLocaleDateString('en-US', { 
                month: 'short', 
                day: 'numeric' 
            });
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant,
            mode: 'dismissable'
        }));
    }

    renderedCallback() {
        // Process new messages if any
        this.processIncomingMessages();
        
        // Auto-scroll to bottom when new messages are added
        const messagesContainer = this.template.querySelector('.chat-messages');
        if (messagesContainer) {
            messagesContainer.scrollTop = messagesContainer.scrollHeight;
        }
    }
}





// import { LightningElement, api, track } from 'lwc';
// import { ShowToastEvent } from 'lightning/platformShowToastEvent';
// import extract_doc_url from '@salesforce/apex/Document_Extract_Helper.extract_doc_url';

// export default class ChatBot extends LightningElement {
//     @api chatloading = false;
//     @api isVisible = false;
//     @api messages = [];
//     @track isExpanded = false;
//     @track newMessage = '';
//     @track uploadedFiles = [];
//     @track attachment_url = '';
//     @track showTemplate = false;
    
//     @track _chatHistory = [];
//     @track currentChatId = null;
//     @track currentChat = null;
//     @track nextChatId = 1;

//     get chatContainerClass() {
//         return `chat-container ${this.isExpanded ? 'expanded' : ''}`;
//     }

//     get mainChatClass() {
//         return `main-chat ${this.isExpanded ? 'with-sidebar' : ''}`;
//     }

//     get chatStyle() {
//         return this.isExpanded ? 'height: 80vh; width: 80%;' : '';
//     }

//     get expandIcon() {
//         return this.isExpanded ? 'utility:contract' : 'utility:expand';
//     }

//     get expandCollapseTitle() {
//         return this.isExpanded ? 'Minimize' : 'Expand';
//     }

//     get currentMessages() {
//         return this.currentChat ? this.currentChat.messages : [];
//     }

//     get chatHistory() {
//         return this._chatHistory.map(chat => ({
//             ...chat,
//             chatItemClass: chat.isActive ? 'chat-item active' : 'chat-item'
//         }));
//     }

//     connectedCallback() {
//         this.loadChatHistory();
        
//         if (this._chatHistory.length === 0) {
//             this.createNewChat();
//         }
//     }

//     loadChatHistory() {
//         try {
//             const stored = sessionStorage.getItem('chatHistory');
//             if (stored) {
//                 this._chatHistory = JSON.parse(stored);
//                 if (this._chatHistory.length > 0) {
//                     const mostRecent = this._chatHistory.find(chat => chat.isActive) || this._chatHistory[0];
//                     this.selectChatById(mostRecent.id);
//                 }
//             }
//         } catch (error) {
//             console.error('Error loading chat history:', error);
//             this._chatHistory = [];
//         }
//     }

//     saveChatHistory() {
//         try {
//             // Using sessionStorage instead of localStorage for LWC compatibility
//             sessionStorage.setItem('chatHistory', JSON.stringify(this._chatHistory));
//         } catch (error) {
//             console.error('Error saving chat history:', error);
//         }
//     }

//     createNewChat() {
//         const newChat = {
//             id: this.nextChatId++,
//             title: `Chat ${this.nextChatId - 1}`,
//             messages: [],
//             lastMessage: 'New conversation',
//             timestamp: this.formatTimestamp(new Date()),
//             isActive: false,
//             createdAt: new Date()
//         };

//         // Mark all existing chats as inactive
//         this._chatHistory.forEach(chat => {
//             chat.isActive = false;
//         });

//         // Add new chat to the beginning of the array
//         this._chatHistory.unshift(newChat);
//         newChat.isActive = true;
//         this.currentChatId = newChat.id;
//         this.currentChat = newChat;
        
//         this.saveChatHistory();
        
//         // Force reactivity
//         this._chatHistory = [...this._chatHistory];
        
//         console.log('New chat created:', newChat);
//     }

//     selectChat(event) {
//         const chatId = parseInt(event.currentTarget.dataset.chatId);
//         this.selectChatById(chatId);
//     }

//     selectChatById(chatId) {
//         console.log('Selecting chat with ID:', chatId);
        
//         // Mark all chats as inactive
//         this._chatHistory.forEach(chat => {
//             chat.isActive = false;
//         });

//         const selectedChat = this._chatHistory.find(chat => chat.id === chatId);
//         if (selectedChat) {
//             selectedChat.isActive = true;
//             this.currentChatId = chatId;
//             this.currentChat = selectedChat;
//             this.saveChatHistory();
            
//             // Force reactivity
//             this._chatHistory = [...this._chatHistory];
            
//             console.log('Selected chat:', selectedChat);
//         } else {
//             console.error('Chat not found with ID:', chatId);
//         }
//     }

//     deleteChat(event) {
//         event.stopPropagation();
//         const chatId = parseInt(event.currentTarget.dataset.chatId);
        
//         if (this._chatHistory.length === 1) {
//             this.showToast('Warning', 'Cannot delete the last chat. Create a new one first.', 'warning');
//             return;
//         }

//         this._chatHistory = this._chatHistory.filter(chat => chat.id !== chatId);
        
//         // If we deleted the current chat, select another one
//         if (this.currentChatId === chatId) {
//             if (this._chatHistory.length > 0) {
//                 this.selectChatById(this._chatHistory[0].id);
//             } else {
//                 this.currentChat = null;
//                 this.currentChatId = null;
//             }
//         }
        
//         this.saveChatHistory();
//         console.log('Chat deleted:', chatId);
//     }

//     expandChat() {
//         this.isExpanded = !this.isExpanded;
        
//         if (this.isExpanded && this._chatHistory.length === 0) {
//             this.createNewChat();
//         }
//     }

//     closeChat() {
//         this.dispatchEvent(new CustomEvent('closechat'));
//     }

//     handleMessageChange(event) {
//         this.newMessage = event.target.value;
//     }

//     handleKeyPress(event) {
//         if (event.key === 'Enter' && !event.shiftKey) {
//             event.preventDefault();
//             this.sendMessage();
//         }
//     }

//     async handleFileUpload(event) {
//         const uploadedFiles = event.detail.files;
//         if (this.uploadedFiles.length > 0) {
//             this.showToast('Warning', 'You can upload only one document per message.', 'warning');
//             return;
//         }
//         if (uploadedFiles.length > 0) {
//             let docId = uploadedFiles[0].documentId;
//             try {
//                 this.attachment_url = await extract_doc_url({ docId });
//             } catch (error) {
//                 console.error('Error on attaching document:', error);
//             }
//             this.uploadedFiles = [...this.uploadedFiles, {
//                 name: uploadedFiles[0].name,
//                 documentId: uploadedFiles[0].documentId
//             }];
//         }
//     }

//     removeFile(event) {
//         const docIdToRemove = event.currentTarget.dataset.id;
//         this.uploadedFiles = this.uploadedFiles.filter(file => file.documentId !== docIdToRemove);
//     }

//     checkFileLimit(event) {
//         if (this.uploadedFiles.length >= 1) {
//             event.preventDefault();
//             this.showToast('Warning', 'You can upload only one document per message.', 'warning');
//         }
//     }

//     sendMessage() {
//         if (this.newMessage.trim() !== '') {
//             // Ensure we have a current chat
//             if (!this.currentChat) {
//                 this.createNewChat();
//             }

//             const newMsg = {
//                 id: Date.now(),
//                 senderName: 'You',
//                 message: this.newMessage,
//                 class: 'message sent',
//                 attachments: this.uploadedFiles.length > 0 ? [...this.uploadedFiles] : null,
//                 attachment_url: this.attachment_url,
//                 timestamp: this.formatTimestamp(new Date())
//             };

//             // Add message to current chat
//             this.currentChat.messages.push(newMsg);
            
//             // Update chat metadata
//             this.currentChat.lastMessage = this.newMessage.length > 50 ? 
//                 this.newMessage.substring(0, 50) + '...' : this.newMessage;
//             this.currentChat.timestamp = this.formatTimestamp(new Date());
            
//             // Update chat title if it's the first message
//             if (this.currentChat.title.startsWith('Chat ') && this.currentChat.messages.length === 1) {
//                 this.currentChat.title = this.newMessage.length > 30 ? 
//                     this.newMessage.substring(0, 30) + '...' : this.newMessage;
//             }

//             const history = {
//                 role: "user",
//                 content: [{ type: "text", text: this.newMessage }]
//             };

//             // Dispatch event to parent component
//             this.dispatchEvent(new CustomEvent('newmessage', {
//                 detail: {
//                     message: newMsg,
//                     history: history
//                 }
//             }));

//             this.newMessage = '';
//             this.uploadedFiles = [];
//             this.attachment_url = '';
            
//             this.saveChatHistory();
//             this._chatHistory = [...this._chatHistory];
            
//             console.log('Message sent:', newMsg);
//         }
//     }

//     @api
//     handleResponse(response) {
//         console.log('Handling response:', response);
        
//         this.showTemplate = response && response.isTemplate;
        
//         if (response && response.message && this.currentChat) {
//             const botMsg = {
//                 id: Date.now() + Math.random(),
//                 senderName: 'Assistant',
//                 message: response.message,
//                 class: 'message received',
//                 timestamp: this.formatTimestamp(new Date())
//             };
            
//             // Add response to current chat
//             this.currentChat.messages.push(botMsg);
//             this.currentChat.lastMessage = response.message.length > 50 ? 
//                 response.message.substring(0, 50) + '...' : response.message;
//             this.currentChat.timestamp = this.formatTimestamp(new Date());
            
//             // Save and force reactivity
//             this.saveChatHistory();
//             this._chatHistory = [...this._chatHistory];
            
//             console.log('Response added:', botMsg);
//         } else {
//             console.error('Invalid response or no current chat:', response, this.currentChat);
//         }
//     }

//     handleFormSubmit(event) {
//         const formData = event.detail;
        
//         if (!this.currentChat) {
//             this.createNewChat();
//         }
        
//         const newMsg = {
//             id: Date.now(),
//             senderName: 'You',
//             message: 'Form submitted with data: ' + JSON.stringify(formData),
//             class: 'message sent',
//             timestamp: this.formatTimestamp(new Date())
//         };

//         this.currentChat.messages.push(newMsg);
//         this.currentChat.lastMessage = 'Form submitted';
//         this.currentChat.timestamp = this.formatTimestamp(new Date());
        
//         this.saveChatHistory();
//         this._chatHistory = [...this._chatHistory];

//         this.dispatchEvent(new CustomEvent('newmessage', {
//             detail: {
//                 message: newMsg,
//                 history: {
//                     role: "user",
//                     content: [{ type: "form", data: formData }]
//                 }
//             }
//         }));

//         this.showTemplate = false;
//     }

//     handleVoiceInput() {
//         this.showToast('Info', 'Voice input feature coming soon!', 'info');
//     }

//     formatTimestamp(date) {
//         const now = new Date();
//         const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
//         const messageDate = new Date(date.getFullYear(), date.getMonth(), date.getDate());
        
//         if (messageDate.getTime() === today.getTime()) {
//             return date.toLocaleTimeString('en-US', { 
//                 hour: '2-digit', 
//                 minute: '2-digit' 
//             });
//         } else {
//             return date.toLocaleDateString('en-US', { 
//                 month: 'short', 
//                 day: 'numeric' 
//             });
//         }
//     }

//     showToast(title, message, variant) {
//         this.dispatchEvent(new ShowToastEvent({
//             title,
//             message,
//             variant,
//             mode: 'dismissable'
//         }));
//     }

//     renderedCallback() {
//         const messagesContainer = this.template.querySelector('.chat-messages');
//         if (messagesContainer) {
//             messagesContainer.scrollTop = messagesContainer.scrollHeight;
//         }
//     }
// }








// import { LightningElement, api, track } from 'lwc';
// import { ShowToastEvent } from 'lightning/platformShowToastEvent';
// import extract_doc_url from '@salesforce/apex/Document_Extract_Helper.extract_doc_url';

// export default class ChatBot extends LightningElement {
//     @api chatloading = false;
//     @api isVisible = false;
//     @api messages = [];
//     @track isExpanded = false;
//     @track newMessage = '';
//     @track uploadedFiles = [];
//     @track attachment_url = '';
//     @track showTemplate = false;
    
//     // Chat history management
//     @track chatHistory = [];
//     @track currentChatId = null;
//     @track currentChat = null;
//     @track nextChatId = 1;

//     get chatContainerClass() {
//         return `chat-container ${this.isExpanded ? 'expanded' : ''}`;
//     }

//     get mainChatClass() {
//         return `main-chat ${this.isExpanded ? 'with-sidebar' : ''}`;
//     }

//     get chatStyle() {
//         return this.isExpanded ? 'height: 80vh; width: 80%;' : '';
//     }

//     get expandIcon() {
//         return this.isExpanded ? 'utility:contract' : 'utility:expand';
//     }

//     get expandCollapseTitle() {
//         return this.isExpanded ? 'Minimize' : 'Expand';
//     }

//     get currentMessages() {
//         return this.currentChat ? this.currentChat.messages : [];
//     }

//     // Process chat history to add computed properties
//     get chatHistory() {
//         return this._chatHistory.map(chat => ({
//             ...chat,
//             chatItemClass: chat.isActive ? 'chat-item active' : 'chat-item'
//         }));
//     }

//     set chatHistory(value) {
//         this._chatHistory = value;
//     }

//     _chatHistory = [];

//     connectedCallback() {
//         // Load chat history from localStorage or initialize empty
//         this.loadChatHistory();
        
//         // Create initial chat if none exists
//         if (this._chatHistory.length === 0) {
//             this.createNewChat();
//         }
//     }

//     loadChatHistory() {
//         try {
//             const stored = localStorage.getItem('chatHistory');
//             if (stored) {
//                 this._chatHistory = JSON.parse(stored);
//                 // Set the most recent chat as active
//                 if (this._chatHistory.length > 0) {
//                     const mostRecent = this._chatHistory.find(chat => chat.isActive) || this._chatHistory[0];
//                     this.selectChatById(mostRecent.id);
//                 }
//             }
//         } catch (error) {
//             console.error('Error loading chat history:', error);
//             this._chatHistory = [];
//         }
//     }

//     saveChatHistory() {
//         try {
//             localStorage.setItem('chatHistory', JSON.stringify(this._chatHistory));
//         } catch (error) {
//             console.error('Error saving chat history:', error);
//         }
//     }

//     createNewChat() {
//         const newChat = {
//             id: this.nextChatId++,
//             title: `Chat ${this.nextChatId - 1}`,
//             messages: [],
//             lastMessage: 'New conversation',
//             timestamp: this.formatTimestamp(new Date()),
//             isActive: false,
//             createdAt: new Date()
//         };

//         // Deactivate all other chats
//         this._chatHistory.forEach(chat => {
//             chat.isActive = false;
//         });

//         // Add new chat and make it active
//         this._chatHistory.unshift(newChat);
//         this.selectChatById(newChat.id);
//         this.saveChatHistory();
//     }

//     selectChat(event) {
//         const chatId = parseInt(event.currentTarget.dataset.chatId);
//         this.selectChatById(chatId);
//     }

//     selectChatById(chatId) {
//         // Deactivate all chats
//         this._chatHistory.forEach(chat => {
//             chat.isActive = false;
//         });

//         // Activate selected chat
//         const selectedChat = this._chatHistory.find(chat => chat.id === chatId);
//         if (selectedChat) {
//             selectedChat.isActive = true;
//             this.currentChatId = chatId;
//             this.currentChat = selectedChat;
//             this.saveChatHistory();
//         }
//     }

//     deleteChat(event) {
//         event.stopPropagation();
//         const chatId = parseInt(event.currentTarget.dataset.chatId);
        
//         // Don't delete if it's the only chat
//         if (this._chatHistory.length === 1) {
//             this.showToast('Warning', 'Cannot delete the last chat. Create a new one first.', 'warning');
//             return;
//         }

//         // Remove the chat
//         this._chatHistory = this._chatHistory.filter(chat => chat.id !== chatId);
        
//         // If deleted chat was active, select another one
//         if (this.currentChatId === chatId) {
//             this.selectChatById(this._chatHistory[0].id);
//         }
        
//         this.saveChatHistory();
//     }

//     expandChat() {
//         this.isExpanded = !this.isExpanded;
        
//         // If expanding and no chat history, create one
//         if (this.isExpanded && this._chatHistory.length === 0) {
//             this.createNewChat();
//         }
//     }

//     closeChat() {
//         this.dispatchEvent(new CustomEvent('closechat'));
//     }

//     handleMessageChange(event) {
//         this.newMessage = event.target.value;
//     }

//     handleKeyPress(event) {
//         if (event.key === 'Enter' && !event.shiftKey) {
//             event.preventDefault();
//             this.sendMessage();
//         }
//     }

//     async handleFileUpload(event) {
//         const uploadedFiles = event.detail.files;
//         if (this.uploadedFiles.length > 1) {
//             this.showToast('Warning', 'You can upload only one document per message.', 'warning');
//             return;
//         }
//         if (uploadedFiles.length > 0) {
//             let docId = uploadedFiles[0].documentId;
//             try {
//                 this.attachment_url = await extract_doc_url({ docId });
//             } catch (error) {
//                 console.error('Error on attaching document:', error);
//             }
//             this.uploadedFiles = [...this.uploadedFiles, {
//                 name: uploadedFiles[0].name,
//                 documentId: uploadedFiles[0].documentId
//             }];
//         }
//     }

//     removeFile(event) {
//         const docIdToRemove = event.currentTarget.dataset.id;
//         this.uploadedFiles = this.uploadedFiles.filter(file => file.documentId !== docIdToRemove);
//     }

//     checkFileLimit(event) {
//         if (this.uploadedFiles.length >= 1) {
//             event.preventDefault();
//             this.showToast('Warning', 'You can upload only one document per message.', 'warning');
//         }
//     }

//     sendMessage() {
//         if (this.newMessage.trim() !== '') {
//             // Create new chat if none exists
//             if (!this.currentChat) {
//                 this.createNewChat();
//             }

//             const newMsg = {
//                 id: Date.now(),
//                 senderName: 'You',
//                 message: this.newMessage,
//                 class: 'message sent',
//                 attachments: this.uploadedFiles,
//                 attachment_url: this.attachment_url,
//                 timestamp: this.formatTimestamp(new Date())
//             };

//             // Add message to current chat
//             this.currentChat.messages.push(newMsg);
            
//             // Update chat metadata
//             this.currentChat.lastMessage = this.newMessage.length > 50 ? 
//                 this.newMessage.substring(0, 50) + '...' : this.newMessage;
//             this.currentChat.timestamp = this.formatTimestamp(new Date());
            
//             // Update chat title if it's still default
//             if (this.currentChat.title.startsWith('Chat ') && this.currentChat.messages.length === 1) {
//                 this.currentChat.title = this.newMessage.length > 30 ? 
//                     this.newMessage.substring(0, 30) + '...' : this.newMessage;
//             }

//             const history = {
//                 role: "user",
//                 content: [{ type: "text", text: this.newMessage }]
//             };

//             this.dispatchEvent(new CustomEvent('newmessage', {
//                 detail: {
//                     message: newMsg,
//                     history: history
//                 }
//             }));

//             // Clear input
//             this.newMessage = '';
//             this.uploadedFiles = [];
//             this.attachment_url = '';
            
//             // Save to localStorage
//             this.saveChatHistory();
//         }
//     }

//     @api
//     handleResponse(response) {
//         this.showTemplate = response && response.isTemplate;
        
//         // Add bot response to current chat
//         if (response && response.message && this.currentChat) {
//             const botMsg = {
//                 id: Date.now() + 1,
//                 senderName: 'Assistant',
//                 message: response.message,
//                 class: 'message received',
//                 timestamp: this.formatTimestamp(new Date())
//             };
            
//             this.currentChat.messages.push(botMsg);
//             this.currentChat.lastMessage = response.message.length > 50 ? 
//                 response.message.substring(0, 50) + '...' : response.message;
//             this.currentChat.timestamp = this.formatTimestamp(new Date());
            
//             this.saveChatHistory();
//         }
//     }

//     handleFormSubmit(event) {
//         const formData = event.detail;
//         const newMsg = {
//             id: Date.now(),
//             senderName: 'You',
//             message: 'Form submitted with data: ' + JSON.stringify(formData),
//             class: 'message sent',
//             timestamp: this.formatTimestamp(new Date())
//         };

//         if (this.currentChat) {
//             this.currentChat.messages.push(newMsg);
//             this.saveChatHistory();
//         }

//         this.dispatchEvent(new CustomEvent('newmessage', {
//             detail: {
//                 message: newMsg,
//                 history: {
//                     role: "user",
//                     content: [{ type: "form", data: formData }]
//                 }
//             }
//         }));

//         this.showTemplate = false;
//     }

//     handleVoiceInput() {
//         this.showToast('Info', 'Voice input feature coming soon!', 'info');
//     }

//     formatTimestamp(date) {
//         const now = new Date();
//         const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
//         const messageDate = new Date(date.getFullYear(), date.getMonth(), date.getDate());
        
//         if (messageDate.getTime() === today.getTime()) {
//             return date.toLocaleTimeString('en-US', { 
//                 hour: '2-digit', 
//                 minute: '2-digit' 
//             });
//         } else {
//             return date.toLocaleDateString('en-US', { 
//                 month: 'short', 
//                 day: 'numeric' 
//             });
//         }
//     }

//     showToast(title, message, variant) {
//         this.dispatchEvent(new ShowToastEvent({
//             title,
//             message,
//             variant,
//             mode: 'dismissable'
//         }));
//     }

//     renderedCallback() {
//         const messagesContainer = this.template.querySelector('.chat-messages');
//         if (messagesContainer) {
//             messagesContainer.scrollTop = messagesContainer.scrollHeight;
//         }
//     }
// }









// import { LightningElement, api, track } from 'lwc';
// import { ShowToastEvent } from 'lightning/platformShowToastEvent';
// import extract_doc_url from '@salesforce/apex/Document_Extract_Helper.extract_doc_url';

// export default class ChatBot extends LightningElement {
//     @api chatloading = false;
//     @api isVisible = false;
//     @api messages = [];
//     @track isExpanded = false;
//     @track newMessage = '';
//     @track uploadedFiles = [];
//     @track attachment_url = '';
//     @track showTemplate = false;

//     get chatContainerClass() {
//         return `chat-container ${this.isExpanded ? 'expanded' : ''}`;
//     }

//     get chatStyle() {
//         return this.isExpanded ? 'height: 80vh; width: 80%;' : '';
//     }

//     get expandIcon() {
//         return this.isExpanded ? 'utility:contract' : 'utility:expand';
//     }

//     expandChat() {
//         this.isExpanded = !this.isExpanded;
//     }

//     closeChat() {
//         this.dispatchEvent(new CustomEvent('closechat'));
//     }

//     handleMessageChange(event) {
//         this.newMessage = event.target.value;
//     }

//     async handleFileUpload(event) {
//         const uploadedFiles = event.detail.files;
//         if (this.uploadedFiles.length > 1) {
//             this.showToast('Warning', 'You can upload only one document per message.', 'warning');
//             return;
//         }
//         if (uploadedFiles.length > 0) {
//             let docId = uploadedFiles[0].documentId;
//             try {
//                 this.attachment_url = await extract_doc_url({ docId });
//             } catch (error) {
//                 console.error('Error on attaching document:', error);
//             }
//             this.uploadedFiles = [...this.uploadedFiles, {
//                 name: uploadedFiles[0].name,
//                 documentId: uploadedFiles[0].documentId
//             }];
//         }
//     }

//     removeFile(event) {
//         const docIdToRemove = event.currentTarget.dataset.id;
//         this.uploadedFiles = this.uploadedFiles.filter(file => file.documentId !== docIdToRemove);
//     }

//     checkFileLimit(event) {
//         if (this.uploadedFiles.length >= 1) {
//             event.preventDefault();
//             this.showToast('Warning', 'You can upload only one document per message.', 'warning');
//         }
//     }

//     sendMessage() {
//         if (this.newMessage.trim() !== '') {
//             const newMsg = {
//                 id: Date.now(),
//                 senderName: 'You',
//                 message: this.newMessage,
//                 class: 'message sent',
//                 attachments: this.uploadedFiles,
//                 attachment_url: this.attachment_url
//             };
//             const history = {
//                 role: "user",
//                 content: [{ type: "text", text: this.newMessage }]
//             };

//             this.dispatchEvent(new CustomEvent('newmessage', {
//                 detail: {
//                     message: newMsg,
//                     history: history
//                 }
//             }));

//             this.newMessage = '';
//             this.uploadedFiles = [];
//             this.attachment_url = '';
//         }
//     }

//     @api
//     handleResponse(response) {
//         this.showTemplate = response && response.isTemplate;
//     }

//     handleFormSubmit(event) {
//         const formData = event.detail;
//         const newMsg = {
//             id: Date.now(),
//             senderName: 'You',
//             message: 'Form submitted with data: ' + JSON.stringify(formData),
//             class: 'message sent'
//         };

//         this.dispatchEvent(new CustomEvent('newmessage', {
//             detail: {
//                 message: newMsg,
//                 history: {
//                     role: "user",
//                     content: [{ type: "form", data: formData }]
//                 }
//             }
//         }));

//         this.showTemplate = false;
//     }

//     handleVoiceInput() {
//         this.showToast('Info', 'Voice input feature coming soon!', 'info');
//     }

//     showToast(title, message, variant) {
//         this.dispatchEvent(new ShowToastEvent({
//             title,
//             message,
//             variant,
//             mode: 'dismissable'
//         }));
//     }

//     renderedCallback() {
//         const messagesContainer = this.template.querySelector('.chat-messages');
//         if (messagesContainer) {
//             messagesContainer.scrollTop = messagesContainer.scrollHeight;
//         }
//     }
// }