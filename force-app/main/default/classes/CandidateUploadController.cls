/**
* @File Name : CandidateUploadController.cls
* @Description : Dynamically creates/updates  Contact records from Excel upload
*                and creates Interview__c records when Job Position is provided
* @Last Modified On : January 9, 2026
*/

public with sharing class CandidateUploadController {
    
    public class UploadResult {
        @AuraEnabled public Integer totalRecords {get; set;}
        @AuraEnabled public Integer candidatesCreated {get; set;}
        @AuraEnabled public Integer candidatesUpdated {get; set;}
        @AuraEnabled public Integer interviewsCreated {get; set;}
        @AuraEnabled public Integer duplicateInterviewsSkipped {get; set;}
        @AuraEnabled public Decimal processingTime {get; set;}
        @AuraEnabled public List<Warning> warnings {get; set;}
        @AuraEnabled public List<FailedRecord> failedRecords {get; set;}
    }
    
    public class Warning {
        @AuraEnabled public String id {get; set;}
        @AuraEnabled public Integer rowNumber {get; set;}
        @AuraEnabled public String message {get; set;}
        @AuraEnabled public String email {get; set;}
    }
    
    public class FailedRecord {
        @AuraEnabled public String id {get; set;}
        @AuraEnabled public Integer rowNumber {get; set;}
        @AuraEnabled public String email {get; set;}
        @AuraEnabled public String field {get; set;}
        @AuraEnabled public String error {get; set;} 
    }
    
    @AuraEnabled
    public static UploadResult createCandidates(List<Map<String, Object>> candidateData) {
        Long startTime = System.currentTimeMillis();
        UploadResult result = new UploadResult();
        result.totalRecords = candidateData != null ? candidateData.size() : 0;
        result.candidatesCreated = 0;
        result.candidatesUpdated = 0;
        result.interviewsCreated = 0;
        result.duplicateInterviewsSkipped = 0;
        result.warnings = new List<Warning>();
        result.failedRecords = new List<FailedRecord>();
        
        if (candidateData == null || candidateData.isEmpty()) {
            return result;
        }
        
        try {
            /* =====================================================
               1. Prepare Data Structures
               ===================================================== */
            Map<String, Schema.SObjectField> apiFieldMap = 
                Schema.SObjectType.Contact.fields.getMap();
            
            Map<String, String> labelToApiMap = new Map<String, String>();
            for (String apiName : apiFieldMap.keySet()) {
                Schema.DescribeFieldResult d = apiFieldMap.get(apiName).getDescribe();
                labelToApiMap.put(d.getLabel().toLowerCase(), apiName);
            }
            
            /* =====================================================
               2. Collect Emails, Phones & Job Positions
               ===================================================== */
            Set<String> emailSet = new Set<String>();
            Set<String> phoneSet = new Set<String>();
            Set<String> jobPositionNames = new Set<String>();
            Map<Integer, String> rowNumberToEmail = new Map<Integer, String>();
            
            for (Map<String, Object> row : candidateData) {
                Object rowNumObj = row.get('rowNumber');
                Integer rowNumber = convertToInteger(rowNumObj);
                
                String email = extractValue(row, 'Email', 'Email', labelToApiMap);
                String phone = extractValue(row, 'Phone', 'Phone', labelToApiMap);
                String jobPos = getExcelValue(row, new List<String>{ 'Job Position' });
                
                if (!String.isBlank(email)) {
                    emailSet.add(email.toLowerCase());
                    if (rowNumber != null) {
                        rowNumberToEmail.put(rowNumber, email);
                    }
                }
                if (!String.isBlank(phone)) {
                    phoneSet.add(phone);
                }
                if (!String.isBlank(jobPos)) {
                    jobPositionNames.add(jobPos);
                }
            }
            
            /* =====================================================
               3. Query Existing Records
               ===================================================== */
            Map<String, Contact> existingByEmail = new Map<String, Contact>();
            Map<String, Contact> existingByPhone = new Map<String, Contact>();
            
            if (!emailSet.isEmpty() || !phoneSet.isEmpty()) {
                String query = 'SELECT Id, Name, Email, Phone ' +
                              'FROM Contact ' +
                              'WHERE Email IN :emailSet ';
                
                if (!phoneSet.isEmpty()) {
                    query += 'OR Phone IN :phoneSet';
                }
                
                for (Contact c : Database.query(query)) {
                    if (!String.isBlank(c.Email)) {
                        existingByEmail.put(c.Email.toLowerCase(), c);
                    }
                    if (!String.isBlank(c.Phone)) {
                        existingByPhone.put(c.Phone, c);
                    }
                }
            }
            
            /* =====================================================
               4. Resolve Job Positions
               ===================================================== */
            Map<String, Id> jobPositionByName = new Map<String, Id>();
            if (!jobPositionNames.isEmpty()) {
                for (Job_Position__c jp : [
                    SELECT Id, Name FROM Job_Position__c 
                    WHERE Name IN :jobPositionNames
                ]) {
                    jobPositionByName.put(jp.Name, jp.Id);
                }
            }
            
            
            // Fetch Recruiter Record Type Id for Contact
            Id candidateRecordTypeId;
            try {
                candidateRecordTypeId = [
                    SELECT Id 
                    FROM RecordType 
                    WHERE SObjectType = 'Contact' 
                    AND Name = 'Candidate' 
                    LIMIT 1
                ].Id;
            } catch (Exception e) {
                throw new AuraHandledException('Candidate Record Type not found for Contact');
            }
            
            /* =====================================================
               5. Build Candidates for Upsert
               ===================================================== */
            List<Contact> candidatesToUpsert = new List<Contact>();
            Map<Integer, Contact> rowNumberToCandidate = new Map<Integer, Contact>();
            Map<Integer, String> rowNumberToJobPosition = new Map<Integer, String>();
            Map<Integer, Boolean> rowHasErrors = new Map<Integer, Boolean>();
            
            for (Integer i = 0; i < candidateData.size(); i++) {
                Map<String, Object> row = candidateData[i];
                Object rowNumObj = row.get('rowNumber');
                Integer rowNumber = convertToInteger(rowNumObj);
                
                try {
                    String email = extractValue(row, 'Email', 'Email', labelToApiMap);
                    String phone = extractValue(row, 'Phone', 'Phone', labelToApiMap);
                    String jobPos = getExcelValue(row, new List<String>{ 'Job Position' });
                    
                    // Validate required fields
                    if (String.isBlank(email)) {
                        String emailValue = rowNumberToEmail.containsKey(rowNumber) ? 
                                           rowNumberToEmail.get(rowNumber) : 'N/A';
                        addFailedRecord(result, rowNumber, emailValue, 
                                       'Email', 'Email is required');
                        rowHasErrors.put(rowNumber, true);
                        continue;
                    }
                    
                    // Find existing candidate
                    Contact candidate = null;
                    Boolean isUpdate = false;
                    
                    if (!String.isBlank(email) && existingByEmail.containsKey(email.toLowerCase())) {
                        candidate = existingByEmail.get(email.toLowerCase());
                        isUpdate = true;
                    } else if (!String.isBlank(phone) && existingByPhone.containsKey(phone)) {
                        candidate = existingByPhone.get(phone);
                        isUpdate = true;
                    } else {
                        candidate = new Contact();
                    }
                    
                    // Always enforce Recruiter record type
                    candidate.RecordTypeId = candidateRecordTypeId;
                    
                    // Set candidate fields dynamically
                    for (String excelColumn : row.keySet()) {
                        if (excelColumn == 'rowNumber') continue;
                        
                        String apiName = resolveApiName(excelColumn, apiFieldMap, labelToApiMap);
                        if (apiName == null) continue;
                        
                        Schema.DescribeFieldResult fieldDesc = apiFieldMap.get(apiName).getDescribe();
                        if (!fieldDesc.isCreateable() || !fieldDesc.isUpdateable()) continue;
                        
                        Object rawValue = row.get(excelColumn);
                        if (rawValue == null) continue;
                        
                        Object converted = convertValue(rawValue, fieldDesc.getType());
                        candidate.put(apiName, converted);
                    }
                    
                    candidatesToUpsert.add(candidate);
                    if (rowNumber != null) {
                        rowNumberToCandidate.put(rowNumber, candidate);
                        if (!String.isBlank(jobPos)) {
                            rowNumberToJobPosition.put(rowNumber, jobPos);
                        }
                        if (isUpdate) {
                            result.candidatesUpdated++;
                        } else {
                            result.candidatesCreated++;
                        }
                    }
                    
                } catch (Exception e) {
                    String emailValue = rowNumber != null && rowNumberToEmail.containsKey(rowNumber) ? 
                                      rowNumberToEmail.get(rowNumber) : 'N/A';
                    addFailedRecord(result, rowNumber, emailValue, 
                                   'General', e.getMessage());
                    rowHasErrors.put(rowNumber, true);
                }
            }
            
            /* =====================================================
               6. Upsert Candidates with Error Handling
               ===================================================== */
            if (!candidatesToUpsert.isEmpty()) {
                Database.UpsertResult[] upsertResults = Database.upsert(candidatesToUpsert, false);
                
                // Process upsert results and adjust counters
                Integer successfulCreates = 0;
                Integer successfulUpdates = 0;
                
                for (Integer i = 0; i < upsertResults.size(); i++) {
                    Database.UpsertResult ur = upsertResults[i];
                    Contact candidate = candidatesToUpsert[i];
                    
                    if (!ur.isSuccess()) {
                        // Find row number for this candidate
                        Integer rowNumber = null;
                        for (Integer rn : rowNumberToCandidate.keySet()) {
                            if (rowNumberToCandidate.get(rn) == candidate) {
                                rowNumber = rn;
                                break;
                            }
                        }
                        
                        String emailValue = rowNumber != null && rowNumberToEmail.containsKey(rowNumber) ? 
                                          rowNumberToEmail.get(rowNumber) : 
                                          candidate.Email != null ? candidate.Email : 'N/A';
                        
                        for (Database.Error err : ur.getErrors()) {
                            addFailedRecord(result, rowNumber, emailValue, 
                                           err.getFields().size() > 0 ? 
                                           String.join(err.getFields(), ', ') : 'General',
                                           err.getMessage());
                            if (rowNumber != null) {
                                rowHasErrors.put(rowNumber, true);
                            }
                        }
                    } else {
                        if (ur.isCreated()) {
                            successfulCreates++;
                        } else {
                            successfulUpdates++;
                        }
                    }
                }
                
                // Update counters based on successful upserts
                result.candidatesCreated = successfulCreates;
                result.candidatesUpdated = successfulUpdates;
            }
            
            /* =====================================================
               7. Create Interviews with Duplicate Prevention
               ===================================================== */
            /*List<Interview__c> interviewsToInsert = new List<Interview__c>();
            
            // Query existing interviews for successful candidates
            Set<Id> successfulCandidateIds = new Set<Id>();
            for (Contact c : candidatesToUpsert) {
                if (c.Id != null) {
                    // Check if this candidate had any errors
                    Boolean hasError = false;
                    for (Integer rowNumber : rowNumberToCandidate.keySet()) {
                        if (rowNumberToCandidate.get(rowNumber) == c && 
                            rowHasErrors.containsKey(rowNumber)) {
                            hasError = true;
                            break;
                        }
                    }
                    if (!hasError) {
                        successfulCandidateIds.add(c.Id);
                    }
                }
            }
            
            Map<String, Interview__c> existingInterviews = new Map<String, Interview__c>();
            if (!successfulCandidateIds.isEmpty()) {
                for (Interview__c iRec : [
                    SELECT Id, Candidate_Name__c , Job_Position__c 
                    FROM Interview__c 
                    WHERE Candidate_Name__c IN :successfulCandidateIds
                ]) {
                    String key = iRec.Candidate_Name__c + '-' + iRec.Job_Position__c;
                    existingInterviews.put(key, iRec);
                }
            }
            
            // Create new interviews
            for (Integer rowNumber : rowNumberToJobPosition.keySet()) {
                if (rowHasErrors.containsKey(rowNumber)) continue;
                
                Contact cand = rowNumberToCandidate.get(rowNumber);
                if (cand == null || cand.Id == null) continue;
                
                String jobPosName = rowNumberToJobPosition.get(rowNumber);
                Id jobPosId = jobPositionByName.get(jobPosName);
                
                if (jobPosId == null) {
                    String emailValue = rowNumberToEmail.containsKey(rowNumber) ? 
                                      rowNumberToEmail.get(rowNumber) : 'N/A';
                    addWarning(result, rowNumber, emailValue,
                              'Job Position "' + jobPosName + '" not found');
                    continue;
                }
                
                String key = cand.Id + '-' + jobPosId;
                
                if (existingInterviews.containsKey(key)) {
                    result.duplicateInterviewsSkipped++;
                    String emailValue = rowNumberToEmail.containsKey(rowNumber) ? 
                                      rowNumberToEmail.get(rowNumber) : 'N/A';
                    addWarning(result, rowNumber, emailValue,
                              'Candidate already has interview for this job position. Interview not created.');
                } else {
                    Interview__c interview = new Interview__c(
                        Candidate_Name__c = cand.Id,
                        Job_Position__c = jobPosId,
                        Interview_Date__c = System.today().addDays(7)
                    );
                    interviewsToInsert.add(interview);
                }
            }
            
            // Insert interviews
            if (!interviewsToInsert.isEmpty()) {
                Database.SaveResult[] insertResults = Database.insert(interviewsToInsert, false);
                for (Database.SaveResult sr : insertResults) {
                    if (sr.isSuccess()) {
                        result.interviewsCreated++;
                    }
                }
            }*/
            
            /* =====================================================
                7. Create Interviews with Duplicate Prevention
               ===================================================== */
            List<Interview__c> interviewsToInsert = new List<Interview__c>();
            Map<Interview__c, Integer> interviewToRowNumber = new Map<Interview__c, Integer>();
            
            // Query existing interviews for successful candidates
            Set<Id> successfulCandidateIds = new Set<Id>();
            for (Contact c : candidatesToUpsert) {
                if (c.Id != null) {
                    // Check if this candidate had any errors
                    Boolean hasError = false;
                    for (Integer rowNumber : rowNumberToCandidate.keySet()) {
                        if (rowNumberToCandidate.get(rowNumber) == c && 
                            rowHasErrors.containsKey(rowNumber)) {
                                hasError = true;
                                break;
                            }
                    }
                    if (!hasError) {
                        successfulCandidateIds.add(c.Id);
                    }
                }
            }
            
            Map<String, Interview__c> existingInterviews = new Map<String, Interview__c>();
            if (!successfulCandidateIds.isEmpty()) {
                for (Interview__c iRec : [
                    SELECT Id, Candidate_Name__c , Job_Position__c 
                    FROM Interview__c 
                    WHERE Candidate_Name__c IN :successfulCandidateIds
                ]) {
                    String key = iRec.Candidate_Name__c + '-' + iRec.Job_Position__c;
                    existingInterviews.put(key, iRec);
                }
            }
            
            // Create new interviews
            for (Integer rowNumber : rowNumberToJobPosition.keySet()) {
                if (rowHasErrors.containsKey(rowNumber)) continue;
                
                Contact cand = rowNumberToCandidate.get(rowNumber);
                if (cand == null || cand.Id == null) continue;
                
                String jobPosName = rowNumberToJobPosition.get(rowNumber);
                Id jobPosId = jobPositionByName.get(jobPosName);
                
                if (jobPosId == null) {
                    String emailValue = rowNumberToEmail.containsKey(rowNumber) ? 
                        rowNumberToEmail.get(rowNumber) : 'N/A';
                    addWarning(result, rowNumber, emailValue,
                               'Job Position "' + jobPosName + '" not found');
                    continue;
                }
                
                String key = cand.Id + '-' + jobPosId;
                system.debug('key---'+key);
                
                if (existingInterviews.containsKey(key)) {
                    system.debug('Existing Interviews-------');
                    result.duplicateInterviewsSkipped++;
                    String emailValue = rowNumberToEmail.containsKey(rowNumber) ? 
                        rowNumberToEmail.get(rowNumber) : 'N/A';
                    addWarning(result, rowNumber, emailValue,
                               'Candidate already has interview for this job position. Interview not created.');
                } else {
                    system.debug('Not Existing Interviews-- Created-----');
                    Interview__c interview = new Interview__c(
                        Candidate_Name__c = cand.Id,
                        Job_Position__c = jobPosId
                    );
                    interviewsToInsert.add(interview);
                    interviewToRowNumber.put(interview, rowNumber);
                    system.debug('interviewsToInsert------'+interviewsToInsert);
                }
            }
            
            // Insert interviews with error handling
            if (!interviewsToInsert.isEmpty()) {
                Database.SaveResult[] insertResults = Database.insert(interviewsToInsert, false);
                system.debug('insertResults---->>--'+insertResults);
                
                for (Integer i = 0; i < insertResults.size(); i++) {
                    Database.SaveResult sr = insertResults[i];
                    Interview__c interview = interviewsToInsert[i];
                    
                    if (sr.isSuccess()) {
                        result.interviewsCreated++;
                    } else {
                        // Find the row number for this interview
                        Integer rowNumber = interviewToRowNumber.get(interview);
                        String emailValue = rowNumber != null && rowNumberToEmail.containsKey(rowNumber) ? 
                            rowNumberToEmail.get(rowNumber) : 'N/A';
                        
                        // Add each error to failed records
                        for (Database.Error err : sr.getErrors()) {
                            addFailedRecord(
                                result, 
                                rowNumber, 
                                emailValue,
                                'Interview',  // field name
                                err.getMessage()  // error message
                            );
                            
                            // Mark this row as having errors for any follow-up processing
                            if (rowNumber != null) {
                                rowHasErrors.put(rowNumber, true);
                            }
                        }
                    }
                }
            }
            
        } catch (Exception e) {
            System.debug('Upload failed: ' + e.getMessage() + ' ' + e.getStackTraceString());
            throw new AuraHandledException('Upload failed: ' + e.getMessage());
        }
        
        // Calculate processing time
        result.processingTime = (System.currentTimeMillis() - startTime) / 1000.0;
        
        return result;
    }
    
    // NEW HELPER METHOD: Convert any numeric type to Integer
    private static Integer convertToInteger(Object value) {
        if (value == null) return null;
        
        try {
            if (value instanceof Integer) {
                return (Integer)value;
            } else if (value instanceof Decimal) {
                return ((Decimal)value).intValue();
            } else if (value instanceof Double) {
                return ((Double)value).intValue();
            } else if (value instanceof Long) {
                return ((Long)value).intValue();
            } else if (value instanceof String) {
                return Integer.valueOf((String)value);
            } else {
                // Try to convert via string
                return Integer.valueOf(String.valueOf(value));
            }
        } catch (Exception e) {
            System.debug('Error converting to Integer: ' + value + ' - ' + e.getMessage());
            return null;
        }
    }
    
    private static void addWarning(UploadResult result, Integer rowNumber, String email, String message) {
        Warning w = new Warning();
        w.id = String.valueOf(result.warnings.size());
        w.rowNumber = rowNumber;
        w.email = email;
        w.message = message;
        result.warnings.add(w);
    }
    
    private static void addFailedRecord(UploadResult result, Integer rowNumber, String email, String field, String error) {
        FailedRecord fr = new FailedRecord();
        fr.id = String.valueOf(result.failedRecords.size());
        fr.rowNumber = rowNumber;
        fr.email = email;
        fr.field = field;
        fr.error = error;
        result.failedRecords.add(fr);
    }
    
    // Rest of the helper methods remain the same...
    private static String resolveApiName(
        String excelColumn,
        Map<String, Schema.SObjectField> apiFieldMap,
        Map<String, String> labelToApiMap
    ) {
        if (apiFieldMap.containsKey(excelColumn)) {
            return excelColumn;
        }
        
        String normalized = excelColumn != null ? excelColumn.trim().toLowerCase() : null;
        return labelToApiMap.get(normalized);
    }
    
    private static String extractValue(
        Map<String, Object> row,
        String apiName,
        String label,
        Map<String, String> labelToApiMap
    ) {
        if (row.containsKey(apiName)) {
            Object val = row.get(apiName);
            return val != null ? String.valueOf(val).trim() : null;
        }
        
        for (String key : row.keySet()) {
            if (key != null && key.trim().equalsIgnoreCase(label)) {
                Object val = row.get(key);
                return val != null ? String.valueOf(val).trim() : null;
            }
        }
        return null;
    }
    
    private static String getExcelValue(
        Map<String, Object> row,
        List<String> possibleKeys
    ) {
        if (row == null || possibleKeys == null) return null;
        
        for (String key : possibleKeys) {
            for (String excelKey : row.keySet()) {
                if (excelKey != null && excelKey.trim().equalsIgnoreCase(key)) {
                    Object val = row.get(excelKey);
                    return val != null ? String.valueOf(val).trim() : null;
                }
            }
        }
        return null;
    }
    
    private static Object convertValue(Object val, Schema.DisplayType type) {
        try {
            switch on type {
                when String, TextArea, Email, Phone, Url {
                    return String.valueOf(val).trim();
                }
                when Boolean {
                    String strVal = String.valueOf(val).toLowerCase();
                    return strVal == 'true' || strVal == '1' || strVal == 'yes';
                }
                when Integer {
                    return convertToInteger(val);
                }
                when Double, Currency, Percent {
                    // Handle decimal conversion
                    if (val instanceof String) {
                        return Decimal.valueOf((String)val);
                    } else if (val instanceof Decimal) {
                        return (Decimal)val;
                    } else if (val instanceof Double) {
                        return Decimal.valueOf(String.valueOf(val));
                    } else {
                        return Decimal.valueOf(String.valueOf(val));
                    }
                }
                when Date {
                    if (val instanceof String) {
                        return Date.valueOf((String)val);
                    }
                    return Date.valueOf(String.valueOf(val));
                }
                when DateTime {
                    if (val instanceof String) {
                        return Datetime.valueOf((String)val);
                    }
                    return Datetime.valueOf(String.valueOf(val));
                }
                when else {
                    return val;
                }
            }
        } catch (Exception e) {
            System.debug('Error converting value: ' + val + ' to type: ' + type + ' - ' + e.getMessage());
            return null;
        }
    }
}