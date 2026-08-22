import { LightningElement, api } from 'lwc';

export default class PostForm extends LightningElement {
    message = '';
    comments = '';
    // recordId = '001XXXXXXXXXXXX'; // Optional: pass actual recordId or make it dynamic
    acceptedFormats = ['.jpg', '.png', '.jpeg'];

    handleMessageChange(event) {
        this.message = event.target.value;
    }

    handleCommentsChange(event) {
        this.comments = event.target.value;
    }

    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        console.log('Uploaded file:', uploadedFiles[0].name);
        // Optional: save the file Id or do something with it
    }

    handleSubmit() {
        console.log('Message:', this.message);
        console.log('Comments:', this.comments);
        // Add your submission logic (e.g., call Apex or toast)
    }
}
