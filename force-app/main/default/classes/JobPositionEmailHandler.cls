global class JobPositionEmailHandler implements Messaging.InboundEmailHandler {

    global Messaging.InboundEmailResult handleInboundEmail(Messaging.InboundEmail email, Messaging.InboundEnvelope env) {
        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();
        
        String subject = email.subject != null ? email.subject : '';
        String body = email.plainTextBody != null ? email.plainTextBody : '';
        String fullText = subject + '\n' + body;

        List<Job_Position__c> jobsToInsert = new List<Job_Position__c>();

        // 1. SPLIT BLOCKS
        String splitRegex = '(?i)(?=\\b(Job Title|Job Role|Role|Position)\\b)';
        List<String> jobBlocks = fullText.split(splitRegex);

        // 2. GLOBAL CLIENT LOOKUP
        String globalClientName = extractField(fullText, 'Client|Customer|For');
        Id globalClientId = findClientId(globalClientName);

        System.debug('🔍 Global Client Extracted: "' + globalClientName + '" -> ID: ' + globalClientId);

        // 3. PROCESS BLOCKS
        for (String block : jobBlocks) {
            if (block.length() < 20) continue; 

            // Extract Job Title FIRST
            String jobTitle = extractField(block, 'Job Title|Job Role|Role|Position');

            // FIX: If no Job Title is found (e.g. it's just the "Hello Team" header), SKIP IT immediately.
            if (String.isBlank(jobTitle)) {
                continue; 
            }

            String employmentType = extractField(block, 'Employment Type|Emp Type|Type');
            String skillsRequired = extractField(block, 'Skills Required|Skills|Tech Stack');
            String localClientName = extractField(block, 'Client|Customer|For');

            // Determine Client (Local or Global)
            Id finalClientId = String.isNotBlank(localClientName) ? findClientId(localClientName) : globalClientId;

            // Safety Check for Client
            if (finalClientId == null) {
                System.debug('️ Skipping Job "' + jobTitle + '" - Client record not found in Salesforce.');
                continue; 
            }

            Job_Position__c jp = new Job_Position__c();
            jp.Job_Title__c = jobTitle;
            jp.Employment_Type__c = employmentType; 
            jp.Skills_Required__c = skillsRequired;
            jp.Client_Name__c = finalClientId;
            
            jobsToInsert.add(jp);
        }

        // 4. INSERT
        if (!jobsToInsert.isEmpty()) {
            Database.SaveResult[] results = Database.insert(jobsToInsert, false);
            for (Database.SaveResult sr : results) {
                if (sr.isSuccess()) {
                    System.debug('Job Created: ' + sr.getId());
                } else {
                    System.debug(' Insert Error: ' + sr.getErrors()[0].getMessage());
                }
            }
            result.success = true;
        }

        return result;
    }

    // ---------------------------------------------------------
    // REGEX EXTRACTOR (Standard)
    // ---------------------------------------------------------
    private static String extractField(String text, String keysRegex) {
        // Matches ":", "-", " is ", or just space as separators
        String separatorPattern = '(?:\\s*:\\s*|\\s*-\\s*|\\s+is\\s+|\\s+)';
        String patternString = '(?i)(?:' + keysRegex + ')' + separatorPattern + '([^,\\n\\r]+)';
        Pattern p = Pattern.compile(patternString);
        Matcher m = p.matcher(text);

        if (m.find()) {
            return m.group(1).trim();
        }
        return null;
    }

    // ---------------------------------------------------------
    // 🧠 SMART CLIENT FINDER (The Fix)
    // ---------------------------------------------------------
    private static Id findClientId(String clientName) {
        if (String.isBlank(clientName)) return null;

        // 1. Try Exact Match First
        List<Account> exact = [SELECT Id  FROM Account WHERE RecordType.Name  = 'Client' AND Name = :clientName LIMIT 1];
        if (!exact.isEmpty()) return exact[0].Id;

        // 2. Exact match failed? Try CLEANING the name.
        // This handles "our client Deloitte." -> "deloitte"
        String cleanName = clientName.toLowerCase();
        
        // Remove "noise words" often captured by regex
        cleanName = cleanName.removeStartIgnoreCase('our client');
        cleanName = cleanName.removeStartIgnoreCase('the client');
        cleanName = cleanName.removeStartIgnoreCase('client'); 
        cleanName = cleanName.removeStartIgnoreCase('for'); 
        
        // Remove trailing punctuation (dots, commas)
        cleanName = cleanName.removeEnd('.').removeEnd(',');
        cleanName = cleanName.trim();

        // 3. Try finding again with the cleaned name using LIKE
        try {
            return [SELECT Id  FROM Account WHERE RecordType.Name  = 'Client' AND Name LIKE :cleanName LIMIT 1].Id;
        } catch(Exception e) {
            System.debug('️ Client not found even after cleaning: "' + clientName + '" (Cleaned: "' + cleanName + '")');
            return null;
        }
    }
}