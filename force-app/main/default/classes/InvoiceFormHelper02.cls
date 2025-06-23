public with sharing class InvoiceFormHelper02 {
    public InvoiceFormHelper02() {
        System.debug('Inside the InvoiceFormHelper02 constr');

    }

    @future(callout=true)
	public static void sendInvoiceEmail(string invoiceId){
        try{
            //Get Invoice data
            Invoice__c inv=[SELECT Id,name,Email_Bcc__c ,Email_CC__c,Contact__C,Contact__r.email,
                                To_Email_Addresses__c from Invoice__c where id =:invoiceId WITH SECURITY_ENFORCED];

            List<String> toAddressList = new List<String>();
            if(inv.To_Email_Addresses__c != null){
                String tempToEmailAdd = inv.To_Email_Addresses__c.replace(' ','');
                toAddressList = tempToEmailAdd != null ? tempToEmailAdd.split(',') : new List<String>();
            }
            
            /*// Get the list of notes and attachments associated with the record
            List<Attachment> attachments = [SELECT Id, Name, Body FROM Attachment WHERE ParentId =:inv.id];
            // Find the attachment you want to include in the email (e.g. by name)
            Attachment attachment = null;
            for (Attachment a : attachments) {
                attachment = a;
                break;
            }*/

            PageReference pdf = Page.InvoicePDF;
            pdf.getParameters().put('id', inv.Id);
            Blob body = null;
            try {
                body = pdf.getContentAsPdf();
            } catch (VisualforceException e) {
                body = Blob.valueOf('No Data Available!!');
            }
            Attachment att = new Attachment(ParentId = inv.Id,
                                            Body = body,
                                            Name = inv.Name + '.pdf');
            
            try {
                if (Attachment.SObjectType.getDescribe().isCreateable() &&
                    Schema.sObjectType.Attachment.fields.ParentId.isCreateable() &&
                    Schema.sObjectType.Attachment.fields.Body.isCreateable() &&
                    Schema.sObjectType.Attachment.fields.Name.isCreateable()
                ) {
                    insert att;

                    Attachment attachment = [SELECT Id, ParentId, Name, Body, CreatedDate 
    										FROM Attachment 
  											WHERE ParentId = :invoiceId  
    										WITH SECURITY_ENFORCED 
    										ORDER BY CreatedDate DESC 
    										LIMIT 1];
                    ContentVersion contentVersion = createContentVersion(attachment.Name, attachment.Body);
                   // ContentVersion contentVersion = createContentVersion(inv.Name, body);
                    if (Schema.sObjectType.ContentVersion.isCreateable() &&
                    Schema.sObjectType.contentVersion.fields.ContentLocation.isCreateable() &&
                    Schema.sObjectType.contentVersion.fields.PathOnClient.isCreateable() &&
                    Schema.sObjectType.contentVersion.fields.Title.isCreateable() &&
                    Schema.sObjectType.contentVersion.fields.VersionData.isCreateable() 
                    ) {
                        insert contentVersion;
                    }
                    string conVersionId = contentVersion.id;
                   
                    ContentVersion contentVer = [SELECT Id,ContentDocumentId, Title FROM contentVersion WHERE Id =: conVersionId WITH SECURITY_ENFORCED LIMIT 1];
                    
                    ContentDocumentLink contentDocumentLink = new ContentDocumentLink();
                    contentDocumentLink.ContentDocumentId = contentVer.contentDocumentId;
                    contentDocumentLink.LinkedEntityId = invoiceId;
                    contentDocumentLink.ShareType = 'I'; // Inferred permission
                    contentDocumentLink.Visibility = 'AllUsers';
                    if (Schema.sObjectType.ContentDocumentLink.isCreateable() &&
                    Schema.sObjectType.ContentDocumentLink.fields.ContentDocumentId.isCreateable() &&
                    Schema.sObjectType.ContentDocumentLink.fields.LinkedEntityId.isCreateable() &&
                    Schema.sObjectType.ContentDocumentLink.fields.Visibility.isCreateable() &&
                    Schema.sObjectType.ContentDocumentLink.fields.ShareType.isCreateable()
                    ) {
                        insert contentDocumentLink;
                    }

                    ContentDistribution distribution = new ContentDistribution();
                    distribution.ContentVersionId = contentVer.Id;
                    distribution.Name = contentVer.Title;
                    distribution.PreferencesAllowViewInBrowser= true;
                    if (ContentDistribution.SObjectType.getDescribe().isCreateable() &&
                    Schema.sObjectType.ContentDistribution.fields.ContentVersionId.isCreateable() &&
                    Schema.sObjectType.ContentDistribution.fields.Name.isCreateable() &&
                    Schema.sObjectType.ContentDistribution.fields.PreferencesAllowViewInBrowser.isCreateable() 
                    ) {
                        insert distribution;
                    }
                    string distribuId = distribution.id;
                    ContentDistribution distri = [SELECT Id, Name, ContentDocumentId, RelatedRecordId, ContentVersionId, DistributionPublicUrl FROM ContentDistribution where id =: distribuId WITH SECURITY_ENFORCED LIMIT 1];
                    String fileURL = distri.DistributionPublicUrl;
                    inv.Attachment_URL__c = fileURL;
                    if(Invoice__c.SObjectType.getDescribe().isUpdateable() &&
                        Schema.sObjectType.Invoice__c.fields.Attachment_URL__c.isUpdateable()){
                        update inv;
                    }
                }

            } catch (Exception aie) {  
				System.debug('Inside the inner exception section '+aie.getMessage());
            }

            // Define the email template to use
           // if (att != null && toAddressList.size() > 0) {
            if (toAddressList.size() > 0) {
                Messaging.SingleEmailMessage email = InvoiceFormHelper02.prepareMessaging(inv,att,toAddressList);
                // Send the email
                Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
                inv.Invoice_status__c = 'Sent';
                if(Invoice__c.SObjectType.getDescribe().isUpdateable() &&
                    Schema.sObjectType.Invoice__c.fields.Invoice_status__c.isUpdateable() && 
                    Schema.sObjectType.Invoice__c.fields.Attachment_URL__c.isUpdateable()){
                    update inv;
                }

            }
        
        }catch(exception e){
            System.debug('Inside the exception section '+e.getMessage());
        }
    }
    public static ContentVersion createContentVersion(String name, Blob body) {
        ContentVersion contentVersion = new ContentVersion();
        contentVersion.ContentLocation = 'S'; // S = Stored in Salesforce
        contentVersion.PathOnClient = name;
        contentVersion.Title = name + '.pdf';
        contentVersion.VersionData = body;
        return contentVersion;
    }
    public static Messaging.SingleEmailMessage prepareMessaging(Invoice__c inv,Attachment att,List<String> toAddressList){

        EmailTemplate emailTemplate = [SELECT Id, Name, Body FROM EmailTemplate 
        WHERE Name = 'Invoice Email Template' WITH SECURITY_ENFORCED];

        // Messaging.EmailFileAttachment fileAttachment = new Messaging.EmailFileAttachment();
        // fileAttachment.setFileName(att.Name);
        // fileAttachment.setBody(att.Body);
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setTemplateId(emailTemplate.Id);
        email.setTargetObjectId(inv.Contact__C);
        email.setWhatId(inv.id);
       // email.setFileAttachments(new Messaging.EmailFileAttachment[] { fileAttachment });
        email.setToAddresses(toAddressList);
        if(inv.Email_CC__c != null){
            String tempEmailCC = inv.Email_CC__c.replace(' ','');
            List<String> ccAddressList = tempEmailCC != null ? tempEmailCC.split(',') : new List<String>();
            if(ccAddressList.size() > 0) {email.setCcAddresses(ccAddressList);}
        }
        if(inv.Email_Bcc__c != null){
            String tempEmailBCC = inv.Email_Bcc__c.replace(' ','');
            List<String> bccAddressList = tempEmailBCC != null ? tempEmailBCC.split(',') : new List<String>();
            if(bccAddressList.size() > 0) {email.setBccAddresses(bccAddressList);}
        }
        return email;
    }
}