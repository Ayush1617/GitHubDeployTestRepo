/**
* @File Name : LetterController.cls
* @Description : Fetch template data, generate PDF & send email
* @Last Modified On : November 24, 2025
*/
public with sharing class LetterController {

    // ----------------------------------------
    // STEP 1 — Fetch template data for LWC
    // ----------------------------------------
    @AuraEnabled(cacheable=true)
    public static LetterTemplateWrapper getLetterData(Id recordId) {

        Work_Order__c wo = [
            SELECT Id,
                Candidate_Name__r.Name,
                Candidate_Name__r.Email,
                Project__r.Client_Name__r.Name,
                Project__r.Client_Name__r.Phone__c,
                Project__r.Client_Name__r.Email__c,
               Project__r.Client_Name__r.BillingStreet,
                Project__r.Client_Name__r.BillingCity,
                Project__r.Client_Name__r.BillingPostalCode,
                Project__r.Client_Name__r.BillingState,
                Project__r.Client_Name__r.BillingCountry,
                Name
            FROM Work_Order__c
            WHERE Id = :recordId LIMIT 1
        ];

        String templateBody =
            'Dear ' + wo.Candidate_Name__r.Name + ',<br/><br/>' +
            'This is to inform you that your client is ' + wo.Project__r.Client_Name__r.Name + '.<br/>' +
            'You can contact him at ' + wo.Project__r.Client_Name__r.Email__c +
            ' and ' + wo.Project__r.Client_Name__r.Phone__c + '.<br/><br/>' +
            'Regards,<br/>Company Team';

        return new LetterTemplateWrapper(wo.Candidate_Name__r.Name, templateBody);
    }


    // -------------------------------------------------
    // STEP 2 — Generate PDF correctly + Email it
    // -------------------------------------------------
    @AuraEnabled
    public static String createPdfAndSendEmail(String htmlContent, Id recordId) {

        Work_Order__c wo = [
            SELECT Candidate_Name__r.Email, Candidate_Name__r.Name
            FROM Work_Order__c
            WHERE Id = :recordId
            LIMIT 1
        ];

        // Encode HTML so VF page can receive it safely
        String encodedHtml = EncodingUtil.urlEncode(htmlContent, 'UTF-8');

        // Create reference to VF PDF page
        PageReference pdfPage = Page.LetterPdfPage;
        pdfPage.getParameters().put('html', encodedHtml);

        // Salesforce generates real PDF here
        Blob pdfBlob = pdfPage.getContentAsPDF();

        // Prepare Email attachment
        Messaging.EmailFileAttachment attach = new Messaging.EmailFileAttachment();
        attach.setContentType('application/pdf');
        attach.setFileName('Letter.pdf');
        attach.setBody(pdfBlob);

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[] { wo.Candidate_Name__r.Email });
        mail.setSubject('Letter PDF');
        mail.setPlainTextBody('Hello,' + wo.Candidate_Name__r.Name +
            '\n\nPlease find the attached aggrement form PDF workorder. Send a signed copy of this document to us.' +            
            '\n\nThanks & Regards,' +
            '\nYour Company');
        mail.setFileAttachments(new Messaging.EmailFileAttachment[]{ attach });

        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });

        return 'SUCCESS';
    }


    // Wrapper class for LWC
    public class LetterTemplateWrapper {
        @AuraEnabled public String candidateName;
        @AuraEnabled public String templateText;

        public LetterTemplateWrapper(String name, String text) {
            candidateName = name;
            templateText = text;
        }
    }
}