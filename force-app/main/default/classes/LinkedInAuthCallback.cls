public without sharing class LinkedInAuthCallback {
    
    @AuraEnabled
    public static Map<String, String> handleAuthCallback() {
        try {
            // Get the auth provider
            AuthProvider provider = [SELECT Id, DeveloperName FROM AuthProvider 
                                     WHERE DeveloperName = 'LinkedinAuth' LIMIT 1];
            
            // Get the current session ID from the auth provider
            List<NamedCredential> namedCreds = [SELECT Id FROM NamedCredential 
                                                WHERE DeveloperName = 'Linkedin_Named' LIMIT 1];
            
            if (namedCreds.isEmpty()) {
                throw new AuraHandledException('Named Credential not found');
            }
            
            // Call LinkedIn to get user info
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Linkedin_Named/v2/userinfo');
            req.setMethod('GET');
            req.setHeader('X-Restli-Protocol-Version', '2.0.0');
            
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() != 200) {
                throw new AuraHandledException('Failed to get user info: ' + res.getBody());
            }
            
            // Parse user info
            Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            String sub = (String) data.get('sub');
            String name = (String) data.get('name');
            String email = (String) data.get('email');
            String picture = (String) data.get('picture');
            String userId = UserInfo.getUserId();
            
            // Create record name
            String shortUserId = userId.substring(0, 15);
            String shortSub = sub.length() > 20 ? sub.substring(sub.length() - 20) : sub;
            String recName = (shortUserId + '_' + shortSub)
                .replaceAll('[^a-zA-Z0-9_]', '')
                .left(38);
            
            // Deactivate all other accounts for this user
            List<LinkedIn_Account_Setting__c> toDeactivate = new List<LinkedIn_Account_Setting__c>();
            for (LinkedIn_Account_Setting__c s : LinkedIn_Account_Setting__c.getAll().values()) {
                if (s.User_Id__c == userId && s.Is_Active__c && s.Name != recName) {
                    s.Is_Active__c = false;
                    toDeactivate.add(s);
                }
            }
            
            if (!toDeactivate.isEmpty()) {
                update toDeactivate;
            }
            
            // Get the existing record if it exists
            LinkedIn_Account_Setting__c existing = LinkedIn_Account_Setting__c.getInstance(recName);
            
            if (existing != null && existing.Id != null) {
                // Update existing
                existing.Account_Name__c = name != null ? name.left(255) : 'LinkedIn User';
                existing.Email__c = email != null ? email.left(255) : '';
                existing.Profile_Picture_URL__c = picture != null ? picture.left(255) : '';
                existing.Is_Active__c = true;
                existing.Token_Expiry__c = String.valueOf(DateTime.now().addDays(60).getTime());
                // Store sub in token parts (as a marker)
                existing.Access_Token_Part_1__c = sub.length() > 0 ? sub.substring(0, Math.min(255, sub.length())) : '';
                existing.Access_Token_Part_2__c = sub.length() > 255 ? sub.substring(255, Math.min(510, sub.length())) : '';
                existing.Access_Token_Part_3__c = sub.length() > 510 ? sub.substring(510, Math.min(765, sub.length())) : '';
                update existing;
            } else {
                // Create new
                LinkedIn_Account_Setting__c newSetting = new LinkedIn_Account_Setting__c(
                    Name = recName,
                    User_Id__c = userId,
                    LinkedIn_Sub_ID__c = sub.left(100),
                    Account_Name__c = name != null ? name.left(255) : 'LinkedIn User',
                    Email__c = email != null ? email.left(255) : '',
                    Profile_Picture_URL__c = picture != null ? picture.left(255) : '',
                    Is_Active__c = true,
                    Token_Expiry__c = String.valueOf(DateTime.now().addDays(60).getTime())
                );
                newSetting.Access_Token_Part_1__c = sub.length() > 0 ? sub.substring(0, Math.min(255, sub.length())) : '';
                newSetting.Access_Token_Part_2__c = sub.length() > 255 ? sub.substring(255, Math.min(510, sub.length())) : '';
                newSetting.Access_Token_Part_3__c = sub.length() > 510 ? sub.substring(510, Math.min(765, sub.length())) : '';
                insert newSetting;
            }
            
            return new Map<String, String>{
                'name' => recName,
                'label' => name,
                'email' => email,
                'picture' => picture != null ? picture : '',
                'sub' => sub,
                'isActive' => 'true'
            };
            
        } catch (Exception e) {
            System.debug('Error in handleAuthCallback: ' + e.getMessage() + ' ' + e.getStackTraceString());
            throw new AuraHandledException('Error saving LinkedIn account: ' + e.getMessage());
        }
    }
    
    
    
    
    
}