/**
 * @description  This class exports Candidate records into an Excel-friendly CSV format.
 * @author     ayush
 * @lastModified ajay kaurav
 * @date
 */
public with sharing class ExportToExcel {
     /**
     * @description  Exports the provided Contact record IDs into a Base64-encoded CSV string
     *               which can be downloaded and opened in Excel.
     *
     * @param        candidateIds  List of Contact record Ids to be exported.
     * @return       Base64 encoded CSV content as String.
     *
     * @throws       AuraHandledException if input IDs are empty or if no data is found.
     *
     * @author       ayush
     * @lastModified  Ayush Agrawal
     * @date         08-Dec-2025
     */
    @AuraEnabled(cacheable=false)
    public static String exportCandidatesToExcel(List<Id> candidateIds) {
        if (candidateIds == null || candidateIds.isEmpty()) {
            throw new AuraHandledException('No records available for export.');
        }

        // Query candidate fields
        List<Contact> candidates = [
            SELECT Id, Name, Email, Phone, Total_Experience__c, 
                    Source__c, CreatedDate FROM Contact
            WHERE Id IN :candidateIds WITH USER_MODE
        ];

        if (candidates.isEmpty()) {
            throw new AuraHandledException('No candidate data found.');
        }

        // Build CSV-style string (Excel can open .csv easily)
        String header = 'Candidate Name,Email,Phone Number,Experience,Source,Created Date\n';
        String rows = '';
        for (Contact c : candidates) {
            rows += '"' + c.Name + '","' + c.Email + '","' + c.Phone + '","' +
                    c.Total_Experience__c  + '","' +
                    c.Source__c + '","' + String.valueOf(c.CreatedDate) + '"\n';
        }
        String csvContent = header + rows;

        // Encode content to Base64 for download
        Blob csvBlob = Blob.valueOf(csvContent);
        return EncodingUtil.base64Encode(csvBlob);
    }
}