// import { LightningElement, track } from 'lwc';
// import uploadResumeToRChilli from '@salesforce/apex/RChilliIntegration.uploadResumeToRChilli';

// export default class ResumeUploader extends LightningElement {
//     @track response;

//     handleUpload(event) {
//         const uploadedFiles = event.detail.files;
//         if (uploadedFiles.length > 0) {
//             const contentDocumentId = uploadedFiles[0].documentId;
//             this.uploadFileToApex(contentDocumentId);
//         }
//     }

//     uploadFileToApex(contentDocumentId) {
//         uploadResumeToRChilli({ contentDocumentId })
//             .then(result => {
//                 this.response = result;
//             })
//             .catch(error => {
//                 console.error(error);
//                 this.response = 'Error uploading file';
//             });
//     }
// }
import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import uploadResumeToRChilli from '@salesforce/apex/RChilliIntegrationNew.uploadResumeToRChilli';

export default class ResumeUploader extends LightningElement {
    @track response;
    @track showParseButton = false;
    @track isParsing = false;
    contentDocumentId; 

    handleUpload(event) {
        const uploadedFiles = event.detail.files;
        if (uploadedFiles.length > 0) {
            this.contentDocumentId = uploadedFiles[0].documentId;
            this.showParseButton = true;
            this.showToast('Success', 'File uploaded successfully. Ready to parse.', 'success');
        }
    }

    handleParse() {
        if (this.contentDocumentId) {
            this.isParsing = true;
            this.response = ''; 

            uploadResumeToRChilli({ contentDocumentId: this.contentDocumentId })
                .then(result => {
                    this.response = result;
                    this.showToast('Success', 'Resume parsed successfully.', 'success');
                })
                .catch(error => {
                    console.error(error);
                    this.response = 'Error uploading file';
                    this.showToast('Error', 'Error parsing resume.', 'error');
                })
                .finally(() => {
                    this.isParsing = false;
                });
        }
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
    }
}
