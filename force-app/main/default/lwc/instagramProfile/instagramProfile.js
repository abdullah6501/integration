import { LightningElement, wire, track } from 'lwc';
import getInstagramProfile from '@salesforce/apex/InstagramController.getInstagramProfile';
import getInstagramMedia from '@salesforce/apex/InstagramController.getInstagramMedia';
// import uploadInstagramPost from '@salesforce/apex/InstagramController.uploadInstagramPost';
import uploadInstagramMedia from '@salesforce/apex/InstagramController.uploadInstagramMedia';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class InstagramProfile extends LightningElement {
    @track username;
    @track userId;
    @track mediaCount;
    @track accountType;
    @track error;
    @track mediaList = [];
    @track showProfile = false;
    // @track imageUrl = '';
    // @track caption = '';
    // @track postSuccess = false;
    // @track postError = '';
    // @track previewUrl;
    // @track fileData;
    // @track isUploading = false;
    @track previewUrl;
    caption = '';
    fileData;

    connectedCallback() {
        getInstagramMedia()
            .then(result => {
                this.mediaList = result;
            })
            .catch(error => {
                console.error('Error loading media:', error);
            });
    }

    @wire(getInstagramProfile)
    wiredProfile({ error, data }) {
        if (data) {
            this.username = data.username;
            this.userId = data.id;
            this.mediaCount = data.media_count;
            this.accountType = data.account_type;
            this.showProfile = true;
        } else if (error) {
            this.error = error.body.message;
            this.showProfile = false;
        }
    }

    handleLogin() {
        window.open(
            // 'https://api.instagram.com/oauth/authorize?client_id=1395033111913501&redirect_uri=https://rangertechnologies38-dev-ed.develop.my.salesforce-sites.com/whatsappwebhook/services/apexrest/instagram-callback&scope=user_profile&response_type=code',
            // '_self'
            'https://www.instagram.com/oauth/authorize?enable_fb_login=0&force_authentication=1&client_id=1395033111913501&redirect_uri=https://rangertechnologies38-dev-ed.develop.my.salesforce-sites.com/whatsappwebhook/services/apexrest/instagram-callback&response_type=code&scope=instagram_business_basic%2Cinstagram_business_manage_messages%2Cinstagram_business_manage_comments%2Cinstagram_business_content_publish%2Cinstagram_business_manage_insights'
        );
    }

    handleCaptionChange(event) {
        this.caption = event.target.value;
    }

    handleFileChange(event) {
        const file = event.target.files[0];
        const reader = new FileReader();

        reader.onload = () => {
            const base64 = reader.result.split(',')[1];
            this.fileData = {
                filename: file.name,
                base64: base64,
                caption: this.caption
            };
            console.log('File data:', JSON.stringify(this.fileData));
            
        };

        if (file) {
            this.previewUrl = URL.createObjectURL(file);
            reader.readAsDataURL(file);
        }
    }

    handleUpload() {
        if (!this.fileData || !this.caption) {
            this.showToast('Error', 'Please select an image and enter a caption.', 'error');
            return;
        }

        uploadInstagramMedia({ base64Data: this.fileData.base64, fileName: this.fileData.filename, caption: this.caption })
            .then(result => {
                console.log('Upload result:', result);
                this.showToast('Success', 'Image posted to Instagram successfully!', 'success');
            })
            .catch(error => {
                console.error(error);
                this.showToast('Error', error.body.message, 'error');
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }


    // handleCaptionChange(event) {
    //     this.caption = event.target.value;
    // }

    // handleFileUpload(event) {
    //     const file = event.target.files[0];
    //     if (file) {
    //         this.previewUrl = URL.createObjectURL(file);
            
    //         const reader = new FileReader();
    //         reader.onload = () => {
    //             this.fileData = reader.result.split(',')[1]; 
    //         };
    //         reader.readAsDataURL(file);
    //     }
    // }

    // handleUploadPost() {
    //     if (!this.fileData || !this.caption) {
    //         this.postError = 'Image and Caption are required';
    //         return;
    //     }
    //     this.postError = '';
    //     this.postSuccess = false;
    //     this.isUploading = true;
    //     console.log('Image data:', this.fileData);
    //     console.log('Uploading post with caption:', this.caption);
    //     uploadInstagramPost({
    //         imageUrl: this.fileData,
    //         caption: this.caption
    //     })
    //     .then(() => {
    //         console.log('Post uploaded successfully');
            
    //         this.postSuccess = true;
    //         this.fileData = null;
    //         this.previewUrl = null;
    //         this.caption = '';
    //         // Reset the file input
    //         this.template.querySelector('lightning-input[type="file"]').value = '';
    //     })
    //     .catch(error => {
    //         this.postError = error.body.message || 'Failed to post to Instagram';
    //     })
    //     .finally(() => {
    //         this.isUploading = false;
    //     });
    // }
}
