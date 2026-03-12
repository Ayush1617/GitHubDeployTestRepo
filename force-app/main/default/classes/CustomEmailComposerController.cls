/**
 * @description Controller class for the Custom Email Composer LWC/Aura component.
 * Handles fetching organization-wide email addresses and sending emails.
 * @Created By Shivam 
 * @Last Modified By Raghav      
 * @date        12/24/2025
 */
public with sharing class CustomEmailComposerController {

    /**
     * @description Data Transfer Object (DTO) to map the JSON payload from the client side.
     */
    public class EmailRequestDTO {
        @AuraEnabled public List<String> toAddresses;
        @AuraEnabled public List<String> ccAddresses;
        @AuraEnabled public List<String> bccAddresses;
        @AuraEnabled public String subject;
        @AuraEnabled public String htmlBody;
        @AuraEnabled public Id relatedRecordId;
        @AuraEnabled public String fromType;
        @AuraEnabled public String fromId;
        @AuraEnabled public String fromAddress;
    }

    /**
     * @description Helper class to structure recipient lists internally.
     */
    public class RecipientInfo {
        public List<String> to;
        public List<String> cc;
        public List<String> bcc;
    }

    /* ============================
       SEND EMAIL
       ============================ */

    /**
     * @description Fetches available Org-Wide Email Addresses for the current user to use as 'From' addresses.
     * Currently filters by the logged-in user's email.
     * @return      List<Map<String,String>> A list of maps containing ID, Address, and DisplayName of available sender identities.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String,String>> getFromAddresses() {
        List<Map<String,String>> out = new List<Map<String,String>>();
        String userEmail = UserInfo.getUserEmail();
        
        try {
            for (OrgWideEmailAddress ow : [
                 SELECT Id, Address, DisplayName
                 FROM OrgWideEmailAddress
                 WHERE Address = :userEmail 
                 WITH SYSTEM_MODE

                 
            ]) {
                out.add(new Map<String,String>{
                    'id' => ow.Id,
                    'address' => ow.Address,
                    'displayName' => ow.DisplayName != null ? ow.DisplayName : ow.Address,
                    'type' => 'OrgWide'
                });
            }
        } catch (Exception ex) {
            //System.debug(LoggingLevel.ERROR, 'Error fetching OrgWideEmailAddress: ' + ex.getMessage());
            throw new AuraHandledException('Unable to fetch email addresses: ' + ex.getMessage());
        
        }
        
        return out;
    }

    /**
     * @description Deserializes the payload and sends a SingleEmailMessage.
     * @param payloadJson The JSON string representation of the EmailRequestDTO.
     * @return            String A success message if the email is queued successfully.
     * @throws            AuraHandledException if validation fails or email sending errors occur.
     */
    @AuraEnabled
    public static String sendEmailNow(String payloadJson) {
     // System.debug(LoggingLevel.DEBUG, 'Payload JSON => ' + payloadJson);

        EmailRequestDTO req = (EmailRequestDTO) JSON.deserialize(
            payloadJson,
            EmailRequestDTO.class
        );
        system.debug('req @@@@@: '+req.htmlBody);
        String description = req.htmlBody;

if(description != null){
    description = description.replace('\n','<br/>');
}



        RecipientInfo recipients = new RecipientInfo();
        recipients.to  = req.toAddresses;
        recipients.cc  = req.ccAddresses;
        recipients.bcc = req.bccAddresses;

        validateRecipients(recipients);

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setSubject(req.subject);
        mail.setHtmlBody(description);
        mail.setSaveAsActivity(false);

        setRecipients(mail, recipients);
        setSenderIdentity(mail, req.fromType, req.fromId);
        setRelatedRecord(mail, req.relatedRecordId);

        if (req.relatedRecordId != null) {
            mail.setWhatId(req.relatedRecordId);
        }

        return transmitEmail(mail);
    }

    /* ============================
       HELPERS
       ============================ */

    /**
     * @description Validates that at least one recipient (To, CC, or BCC) is present.
     * @param recipients The RecipientInfo object containing lists of email addresses.
     * @throws           AuraHandledException if no recipients are provided.
     */
    private static void validateRecipients(RecipientInfo recipients) {
        if ((recipients.to == null || recipients.to.isEmpty()) &&
            (recipients.cc == null || recipients.cc.isEmpty()) &&
            (recipients.bcc == null || recipients.bcc.isEmpty())) {
            throw new AuraHandledException('At least one recipient required.');
        }
    }

    /**
     * @description Sets the To, CC, and BCC addresses on the email message.
     * @param mail       The SingleEmailMessage instance to populate.
     * @param recipients The RecipientInfo object containing address lists.
     */
    private static void setRecipients(
        Messaging.SingleEmailMessage mail,
        RecipientInfo recipients
    ) {
        if (recipients.to != null && !recipients.to.isEmpty()) {
            mail.setToAddresses(recipients.to);
        }
        if (recipients.cc != null && !recipients.cc.isEmpty()) {
            mail.setCcAddresses(recipients.cc);
        }
        if (recipients.bcc != null && !recipients.bcc.isEmpty()) {
            mail.setBccAddresses(recipients.bcc);
        }
    }

    /**
     * @description Sets the sender identity using OrgWideEmailAddress.
     * @param mail     The SingleEmailMessage instance to populate.
     * @param fromType The type of sender (must be 'OrgWide').
     * @param fromId   The Salesforce ID of the OrgWideEmailAddress.
     * @throws         AuraHandledException if the type is not 'OrgWide'.
     */
    private static void setSenderIdentity(
        Messaging.SingleEmailMessage mail,
        String fromType,
        String fromId
    ) {
        if (fromType == 'OrgWide' && !String.isBlank(fromId)) {
            mail.setOrgWideEmailAddressId(Id.valueOf(fromId));
           
        } else {
            throw new AuraHandledException(
                'Only Org-Wide Email Address is allowed.'
            );
        }
    }

    /**
     * @description Sets the 'WhatId' for the email message to link it to a record.
     * @param mail     The SingleEmailMessage instance.
     * @param recordId The ID of the record to relate the email to.
     */
    private static void setRelatedRecord(
        Messaging.SingleEmailMessage mail,
        Id recordId) {
        //system.debug('recordId'+recordId); 
        mail.setWhatId(recordId);
    }

    /**
     * @description Transmits the constructed email message.
     * @param mail The configured SingleEmailMessage to send.
     * @return     String 'Email sent successfully' on success.
     * @throws     AuraHandledException if the send operation returns an error.
     */
    private static String transmitEmail(
        Messaging.SingleEmailMessage mail
    ) {
        Messaging.SendEmailResult[] results =
            Messaging.sendEmail(
                new Messaging.SingleEmailMessage[]{ mail },
                false
            );

        if (results[0].isSuccess()) {
            return 'Email sent successfully';
        }
        throw new AuraHandledException('Email failed.');
    }
}