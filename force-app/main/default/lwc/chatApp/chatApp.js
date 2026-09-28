import { LightningElement, track, wire } from 'lwc';
import getContactsWithLastMessages from '@salesforce/apex/WhatsAppOutMessage.getContactsWithLastMessages';

export default class ChatApp extends LightningElement {
    @track contacts = [];
    @track filteredContacts = [];
    @track error;
    @track selectedContactId;
    @track selectedContactName;
    @track searchTerm = '';
    @track activeFilter = 'all';

    @wire(getContactsWithLastMessages)
    wiredContacts({ data, error }) {
        if (data) {
            try {
                const contactData = JSON.parse(data);
                this.contacts = contactData.map(c => ({
                    Id: c.Id,
                    Name: c.Name,
                    MobilePhone: c.MobilePhone,
                    className: 'contact-item',
                    Initials: this.getInitials(c.Name),
                    LastMessagePreview: c.preview || '',
                    isFromMe: c.isFromMe || false,
                    LastMessageTime: this.formatTime(c.time),
                    UnreadCount: c.unreadCount || 0
                }));
                this.applyFilters();
            } catch (e) {
                console.error('Error parsing contact data', e);
                this.error = e;
            }
        } else if (error) {
            console.error('Error loading contacts', error);
            this.error = error;
        }
    }

    handleSearch(event) {
        this.searchTerm = event.target.value.toLowerCase();
        this.applyFilters();
    }

    handleFilterSelect(event) {
        this.activeFilter = event.currentTarget.dataset.filter;
        this.applyFilters();
    }

    applyFilters() {
        let result = [...this.contacts];

        if (this.activeFilter === 'unread') {
            result = result.filter(c => c.UnreadCount > 0);
        }

        if (this.searchTerm) {
            result = result.filter(contact =>
                contact.Name.toLowerCase().includes(this.searchTerm) ||
                (contact.MobilePhone && contact.MobilePhone.includes(this.searchTerm))
            );
        }

        this.filteredContacts = result.map(c => ({
            ...c,
            className: c.Id === this.selectedContactId ? 'contact-item active' : 'contact-item',
            filterAllClass: this.activeFilter === 'all' ? 'filter-pill active' : 'filter-pill',
            filterUnreadClass: this.activeFilter === 'unread' ? 'filter-pill active' : 'filter-pill'
        }));
    }

    get filterAllClass() {
        return this.activeFilter === 'all' ? 'filter-pill active' : 'filter-pill';
    }

    get filterUnreadClass() {
        return this.activeFilter === 'unread' ? 'filter-pill active' : 'filter-pill';
    }

    get showNoResults() {
        return this.filteredContacts.length === 0 && !this.error;
    }

    getInitials(name) {
        if (!name) return 'WA';
        return name.split(' ')
            .map(n => n[0])
            .join('')
            .substring(0, 2)
            .toUpperCase();
    }

    formatTime(dateString) {
        if (!dateString) return '';
        const date = new Date(dateString);
        const now = new Date();
        
        if (isNaN(date.getTime())) return dateString;

        if (date.toDateString() === now.toDateString()) {
            return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
        }
        
        const yesterday = new Date(now);
        yesterday.setDate(yesterday.getDate() - 1);
        if (date.toDateString() === yesterday.toDateString()) {
            return 'Yesterday';
        }

        const diffDays = Math.floor((now - date) / (1000 * 60 * 60 * 24));
        if (diffDays < 7) {
            return date.toLocaleDateString([], { weekday: 'short' });
        }

        return date.toLocaleDateString([], { month: 'numeric', day: 'numeric', year: '2-digit' });
    }

    handleContactClick(event) {
        const contactId = event.currentTarget.dataset.id;
        const contact = this.contacts.find(c => c.Id === contactId);
        
        if (contact) {
            this.selectedContactId = contactId;
            this.selectedContactName = contact.Name;
            this.updateActiveState(contactId);
        }
    }

    updateActiveState(activeId) {
        this.filteredContacts = this.filteredContacts.map(c => ({
            ...c,
            className: c.Id === activeId ? 'contact-item active' : 'contact-item'
        }));
    }
}


