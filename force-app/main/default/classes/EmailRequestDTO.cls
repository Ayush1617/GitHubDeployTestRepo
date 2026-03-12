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