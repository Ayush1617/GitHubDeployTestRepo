/**
 * @description Apex controller for LWC/Flow to integrate Salesforce with LinkedIn.
 *              Generates LinkedIn job posts dynamically using job data.
 * @author AJAY Kaurav
 * @since 2025-09-26
 */
/*public without sharing class LinkedInService {

    @AuraEnabled(cacheable=true)
    public static Job_Position__c getJobDetailsForLinkedin(Id jobId) {

        System.debug(' getJobDetailsForLinkedin START');
        System.debug(' Job Id Received: ' + jobId);

        Job_Position__c jobRecord = [
            SELECT Skills_Required__c, Employment_Type__c, Mode__c, Work_Mode__c,
                   Job_Title__c, Shift_Time__c, Qualification__c,
                   Experience_Required__c, Soft_skills__c, Aditional_Skills__c
            FROM Job_Position__c
            WHERE Id = :jobId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        System.debug(' Job Record Fetched: ' + jobRecord);
        System.debug(' getJobDetailsForLinkedin END');

        return jobRecord;
    }


    @AuraEnabled(cacheable=true)
    public static String getCompanyName() {

        System.debug(' getCompanyName START');

        String orgName = UserInfo.getOrganizationName();

        System.debug(' Organization Name: ' + orgName);
        System.debug(' getCompanyName END');

        return orgName;
    }


    @AuraEnabled
    public static String createPost(String content) {

        System.debug(' createPost START');
        System.debug(' Content Received: ' + content);

        Http http = new Http();

        try {

            // STEP 1 - Get Logged-in LinkedIn User Info
            System.debug('️ Step 1: Fetch LinkedIn User Info');

            HttpRequest meReq = new HttpRequest();
            meReq.setEndpoint('callout:Linkedin_Named/v2/userinfo');
            //meReq.setEndpoint('callout:Linkedin_Named/v2/me');
            meReq.setMethod('GET');
            meReq.setHeader('X-Restli-Protocol-Version', '2.0.0');
            meReq.setHeader('LinkedIn-Version', '202401');



            System.debug(' Sending GET Request to: ' + meReq.getEndpoint());

            HttpResponse meRes = http.send(meReq);

            System.debug(' Response Status Code (me): ' + meRes.getStatusCode());
            System.debug(' Response Body (me): ' + meRes.getBody());

            if (meRes.getStatusCode() != 200) {
                if (meRes.getStatusCode() == 401) {
                    throw new AuraHandledException('LinkedIn session expired. Please login again using the Login with LinkedIn button.');
                }
                throw new AuraHandledException('Please login with LinkedIn first. Click the "Login with LinkedIn" button.');
            }

            Map<String, Object> meData =
                (Map<String, Object>) JSON.deserializeUntyped(meRes.getBody());

            System.debug(' Parsed User Data: ' + meData);

            //String memberId = (String) meData.get('id');
            String memberId = (String) meData.get('sub');
            System.debug(' LinkedIn Member Id: ' + memberId);
            
            // Check if sub already contains the full URN
            String sub = (String) meData.get('sub');
            String authorUrn;
            if (sub.startsWith('urn:li:person:')) {
                authorUrn = sub;  // already a full URN
            } else {
                authorUrn = 'urn:li:person:' + sub;
            }


            // STEP 2 - Create Post
            System.debug('️ Step 2: Creating LinkedIn Post');

            HttpRequest postReq = new HttpRequest();
            postReq.setEndpoint('callout:Linkedin_Named/v2/ugcPosts');
            postReq.setMethod('POST');
            postReq.setHeader('Content-Type', 'application/json');
            postReq.setHeader('X-Restli-Protocol-Version', '2.0.0');
            postReq.setHeader('LinkedIn-Version', '202401');


            System.debug(' POST Endpoint: ' + postReq.getEndpoint());

            Map<String, Object> bodyMap = new Map<String, Object>{
                'author' => authorUrn,
                'lifecycleState' => 'PUBLISHED',
                'specificContent' => new Map<String, Object>{
                    'com.linkedin.ugc.ShareContent' => new Map<String, Object>{
                        'shareCommentary' => new Map<String, Object>{
                            'text' => content
                        },
                        'shareMediaCategory' => 'NONE'
                    }
                },
                'visibility' => new Map<String, Object>{
                    'com.linkedin.ugc.MemberNetworkVisibility' => 'PUBLIC'
                }
            };

            System.debug(' Request Body Map: ' + bodyMap);

            String requestBody = JSON.serialize(bodyMap);
            System.debug(' Serialized Request Body: ' + requestBody);

            postReq.setBody(requestBody);

            System.debug(' Sending POST Request...');

            HttpResponse postRes = http.send(postReq);

            System.debug(' Response Status Code (Post): ' + postRes.getStatusCode());
            System.debug(' Response Body (Post): ' + postRes.getBody());

            if (postRes.getStatusCode() >= 200 && postRes.getStatusCode() < 300) {

                System.debug(' LinkedIn Post Created Successfully');
                System.debug(' createPost END');

                return postRes.getBody();

            } else {

                System.debug(' LinkedIn Post Failed');
                throw new AuraHandledException(
                    'LinkedIn post failed: ' + postRes.getBody()
                );
            }

        } catch (Exception ex) {

            System.debug('❌ ERROR OCCURRED');
            System.debug('❌ Error Message: ' + ex.getMessage());
            System.debug('📍 Line Number: ' + ex.getLineNumber());
            System.debug(' Stack Trace: ' + ex.getStackTraceString());

            throw new AuraHandledException(
                'LinkedIn Error: ' + ex.getMessage()
            );
        }
    }

}*/
/**
 * @description Apex controller for LWC/Flow to integrate Salesforce with LinkedIn.
 *              Supports multi-account login, post creation, user info fetch, and logout.
 * @author AJAY Kaurav
 * @since 2025-09-26
 */



/**
 * @description Apex controller for LWC/Flow to integrate Salesforce with LinkedIn.
 *              Generates LinkedIn job posts dynamically using job data.
 * @author AJAY Kaurav
 * @since 2025-09-26
 */
/*public without sharing class LinkedInService {

    // ─────────────────────────────────────────────
    // GET JOB DETAILS
    // ─────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static Job_Position__c getJobDetailsForLinkedin(Id jobId) {
        System.debug('getJobDetailsForLinkedin START | Job Id: ' + jobId);

        Job_Position__c jobRecord = [
            SELECT Skills_Required__c, Employment_Type__c, Mode__c, Work_Mode__c,
                   Job_Title__c, Shift_Time__c, Qualification__c,
                   Experience_Required__c, Soft_skills__c, Aditional_Skills__c
            FROM Job_Position__c
            WHERE Id = :jobId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        System.debug('Job Record Fetched: ' + jobRecord);
        return jobRecord;
    }


    // ─────────────────────────────────────────────
    // GET COMPANY NAME
    // ─────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static String getCompanyName() {
        String orgName = UserInfo.getOrganizationName();
        System.debug('Organization Name: ' + orgName);
        return orgName;
    }


    // ─────────────────────────────────────────────
    // CHECK IF LINKEDIN IS CONNECTED
    // ─────────────────────────────────────────────
    @AuraEnabled
    public static Boolean isLinkedInConnected() {
        try {
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Linkedin_Named/v2/userinfo');
            req.setMethod('GET');
            req.setHeader('X-Restli-Protocol-Version', '2.0.0');
            req.setHeader('LinkedIn-Version', '202401');
            HttpResponse res = http.send(req);

            System.debug('isLinkedInConnected Status: ' + res.getStatusCode());
            return res.getStatusCode() == 200;
        } catch (Exception e) {
            System.debug('isLinkedInConnected Error: ' + e.getMessage());
            return false;
        }
    }


    // ─────────────────────────────────────────────
    // GET LINKEDIN USER INFO (name, email, picture)
    // ─────────────────────────────────────────────
    @AuraEnabled
    public static Map<String, String> getLinkedInUserInfo() {
        try {
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Linkedin_Named/v2/userinfo');
            req.setMethod('GET');
            req.setHeader('X-Restli-Protocol-Version', '2.0.0');
            req.setHeader('LinkedIn-Version', '202401');
            HttpResponse res = http.send(req);

            System.debug('getLinkedInUserInfo Status: ' + res.getStatusCode());
            System.debug('getLinkedInUserInfo Body: ' + res.getBody());

            if (res.getStatusCode() == 200) {
                Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                Map<String, String> userInfo = new Map<String, String>();
                userInfo.put('name',    data.get('name')    != null ? (String) data.get('name')    : '');
                userInfo.put('email',   data.get('email')   != null ? (String) data.get('email')   : '');
                userInfo.put('picture', data.get('picture') != null ? (String) data.get('picture') : '');
                System.debug('LinkedIn User Info: ' + userInfo);
                return userInfo;
            }
            return null;
        } catch (Exception e) {
            System.debug('getLinkedInUserInfo Error: ' + e.getMessage());
            return null;
        }
    }


    // ─────────────────────────────────────────────
    // CREATE POST ON LINKEDIN
    // ─────────────────────────────────────────────
    @AuraEnabled
    public static String createPost(String content) {
        System.debug('createPost START | Content: ' + content);

        Http http = new Http();

        try {
            // ── STEP 1: Get LinkedIn User Info ──
            System.debug('Step 1: Fetch LinkedIn User Info');

            HttpRequest meReq = new HttpRequest();
            meReq.setEndpoint('callout:Linkedin_Named/v2/userinfo');
            meReq.setMethod('GET');
            meReq.setHeader('X-Restli-Protocol-Version', '2.0.0');
            meReq.setHeader('LinkedIn-Version', '202401');

            HttpResponse meRes = http.send(meReq);
            System.debug('Response Status (userinfo): ' + meRes.getStatusCode());
            System.debug('Response Body (userinfo): ' + meRes.getBody());

            if (meRes.getStatusCode() == 401) {
                throw new AuraHandledException(
                    'LinkedIn session expired. Please click "Login with LinkedIn" to reconnect.'
                );
            }
            if (meRes.getStatusCode() != 200) {
                throw new AuraHandledException(
                    'Please login with LinkedIn first. Click the "Login with LinkedIn" button.'
                );
            }

            Map<String, Object> meData = (Map<String, Object>) JSON.deserializeUntyped(meRes.getBody());
            String sub = (String) meData.get('sub');
            System.debug('LinkedIn sub: ' + sub);

            // Build Author URN
            String authorUrn = sub.startsWith('urn:li:person:') ? sub : 'urn:li:person:' + sub;
            System.debug('Author URN: ' + authorUrn);


            // ── STEP 2: Create the Post ──
            System.debug('Step 2: Creating LinkedIn Post');

            HttpRequest postReq = new HttpRequest();
            postReq.setEndpoint('callout:Linkedin_Named/v2/ugcPosts');
            postReq.setMethod('POST');
            postReq.setHeader('Content-Type', 'application/json');
            postReq.setHeader('X-Restli-Protocol-Version', '2.0.0');
            postReq.setHeader('LinkedIn-Version', '202401');

            Map<String, Object> bodyMap = new Map<String, Object>{
                'author' => authorUrn,
                'lifecycleState' => 'PUBLISHED',
                'specificContent' => new Map<String, Object>{
                    'com.linkedin.ugc.ShareContent' => new Map<String, Object>{
                        'shareCommentary' => new Map<String, Object>{
                            'text' => content
                        },
                        'shareMediaCategory' => 'NONE'
                    }
                },
                'visibility' => new Map<String, Object>{
                    'com.linkedin.ugc.MemberNetworkVisibility' => 'PUBLIC'
                }
            };

            postReq.setBody(JSON.serialize(bodyMap));
            System.debug('Post Request Body: ' + JSON.serialize(bodyMap));

            HttpResponse postRes = http.send(postReq);
            System.debug('Post Response Status: ' + postRes.getStatusCode());
            System.debug('Post Response Body: ' + postRes.getBody());

            if (postRes.getStatusCode() >= 200 && postRes.getStatusCode() < 300) {
                System.debug('LinkedIn Post Created Successfully');
                return postRes.getBody();
            } else {
                throw new AuraHandledException('LinkedIn post failed: ' + postRes.getBody());
            }

        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception ex) {
            System.debug('ERROR: ' + ex.getMessage() + ' | Line: ' + ex.getLineNumber());
            System.debug('Stack: ' + ex.getStackTraceString());
            throw new AuraHandledException('LinkedIn Error: ' + ex.getMessage());
        }
    }
}*/

/**
 * @description Apex controller for LWC/Flow to integrate Salesforce with LinkedIn.
 *              Generates LinkedIn job posts dynamically using job data.
 * @author AJAY Kaurav
 * @since 2025-09-26
 */
public without sharing class LinkedInService {

    @AuraEnabled(cacheable=true)
    public static Job_Position__c getJobDetailsForLinkedin(Id jobId) {

        System.debug(' getJobDetailsForLinkedin START');
        System.debug(' Job Id Received: ' + jobId);

        Job_Position__c jobRecord = [
            SELECT Skills_Required__c, Employment_Type__c, Mode__c, Work_Mode__c,
                   Job_Title__c, Shift_Time__c, Qualification__c,
                   Experience_Required__c, Soft_skills__c, Aditional_Skills__c
            FROM Job_Position__c
            WHERE Id = :jobId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        System.debug(' Job Record Fetched: ' + jobRecord);
        System.debug(' getJobDetailsForLinkedin END');

        return jobRecord;
    }


    @AuraEnabled(cacheable=true)
    public static String getCompanyName() {

        System.debug(' getCompanyName START');

        String orgName = UserInfo.getOrganizationName();

        System.debug(' Organization Name: ' + orgName);
        System.debug(' getCompanyName END');

        return orgName;
    }


    @AuraEnabled
    public static String createPost(String content) {

        System.debug(' createPost START');
        System.debug(' Content Received: ' + content);

        Http http = new Http();

        try {

            // STEP 1 - Get Logged-in LinkedIn User Info
            System.debug('️ Step 1: Fetch LinkedIn User Info');

            HttpRequest meReq = new HttpRequest();
            meReq.setEndpoint('callout:Linkedin_Named/v2/userinfo');
            //meReq.setEndpoint('callout:Linkedin_Named/v2/me');
            meReq.setMethod('GET');
            meReq.setHeader('X-Restli-Protocol-Version', '2.0.0');
            meReq.setHeader('LinkedIn-Version', '202401');



            System.debug(' Sending GET Request to: ' + meReq.getEndpoint());

            HttpResponse meRes = http.send(meReq);

            System.debug(' Response Status Code (me): ' + meRes.getStatusCode());
            System.debug(' Response Body (me): ' + meRes.getBody());

            /*if (meRes.getStatusCode() != 200) {
                System.debug(' LinkedIn Login Required');
                throw new AuraHandledException('Please login with LinkedIn first.');
            }*/
            if (meRes.getStatusCode() != 200) {
                if (meRes.getStatusCode() == 401) {
                    throw new AuraHandledException('LinkedIn session expired. Please login again using the Login with LinkedIn button.');
                }
                throw new AuraHandledException('Please login with LinkedIn first. Click the "Login with LinkedIn" button.');
            }

            Map<String, Object> meData =
                (Map<String, Object>) JSON.deserializeUntyped(meRes.getBody());

            System.debug(' Parsed User Data: ' + meData);

            //String memberId = (String) meData.get('id');
            String memberId = (String) meData.get('sub');
            System.debug(' LinkedIn Member Id: ' + memberId);

            //String authorUrn = 'urn:li:person:' + memberId;
            //System.debug(' Author URN: ' + authorUrn);*/
            
            // Check if sub already contains the full URN
            String sub = (String) meData.get('sub');
            String authorUrn;
            if (sub.startsWith('urn:li:person:')) {
                authorUrn = sub;  // already a full URN
            } else {
                authorUrn = 'urn:li:person:' + sub;
            }


            // STEP 2 - Create Post
            System.debug('️ Step 2: Creating LinkedIn Post');

            HttpRequest postReq = new HttpRequest();
            postReq.setEndpoint('callout:Linkedin_Named/v2/ugcPosts');
            postReq.setMethod('POST');
            postReq.setHeader('Content-Type', 'application/json');
            postReq.setHeader('X-Restli-Protocol-Version', '2.0.0');
            postReq.setHeader('LinkedIn-Version', '202401');


            System.debug(' POST Endpoint: ' + postReq.getEndpoint());

            Map<String, Object> bodyMap = new Map<String, Object>{
                'author' => authorUrn,
                'lifecycleState' => 'PUBLISHED',
                'specificContent' => new Map<String, Object>{
                    'com.linkedin.ugc.ShareContent' => new Map<String, Object>{
                        'shareCommentary' => new Map<String, Object>{
                            'text' => content
                        },
                        'shareMediaCategory' => 'NONE'
                    }
                },
                'visibility' => new Map<String, Object>{
                    'com.linkedin.ugc.MemberNetworkVisibility' => 'PUBLIC'
                }
            };

            System.debug(' Request Body Map: ' + bodyMap);

            String requestBody = JSON.serialize(bodyMap);
            System.debug(' Serialized Request Body: ' + requestBody);

            postReq.setBody(requestBody);

            System.debug(' Sending POST Request...');

            HttpResponse postRes = http.send(postReq);

            System.debug(' Response Status Code (Post): ' + postRes.getStatusCode());
            System.debug(' Response Body (Post): ' + postRes.getBody());

            if (postRes.getStatusCode() >= 200 && postRes.getStatusCode() < 300) {

                System.debug(' LinkedIn Post Created Successfully');
                System.debug(' createPost END');

                return postRes.getBody();

            } else {

                System.debug(' LinkedIn Post Failed');
                throw new AuraHandledException(
                    'LinkedIn post failed: ' + postRes.getBody()
                );
            }

        } catch (Exception ex) {

            System.debug('❌ ERROR OCCURRED');
            System.debug('❌ Error Message: ' + ex.getMessage());
            System.debug('📍 Line Number: ' + ex.getLineNumber());
            System.debug(' Stack Trace: ' + ex.getStackTraceString());

            throw new AuraHandledException(
                'LinkedIn Error: ' + ex.getMessage()
            );
        }
    }
    
    
    @AuraEnabled
    public static Boolean isLinkedInConnected() {
        try {
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Linkedin_Named/v2/me');
            req.setMethod('GET');
            req.setHeader('X-Restli-Protocol-Version', '2.0.0');
            HttpResponse res = http.send(req);
            return res.getStatusCode() == 200;
        } catch (Exception e) {
            return false;
        }
    }
    /*@AuraEnabled
    public static String createPost(String content) { 
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Linkedin_Named/v2/ugcPosts'); // Salesforce Named Credential
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            String body = JSON.serialize(new Map<String, Object>{
                'author' => 'urn:li:person:gllxQyVs6B',
                'lifecycleState' => 'PUBLISHED',
                'specificContent' => new Map<String, Object>{
                    'com.linkedin.ugc.ShareContent' => new Map<String, Object>{
                        'shareCommentary' => new Map<String, Object>{ 'text' => content },
                        'shareMediaCategory' => 'NONE'
                    }
                },
                'visibility' => new Map<String, Object>{
                    'com.linkedin.ugc.MemberNetworkVisibility' => 'PUBLIC'
                }
            });
            req.setBody(body);
            Http http = new Http();
            HttpResponse res = http.send(req);
            return res.getBody();
        }
        catch (CalloutException ex) {
            throw new AuraHandledException('LinkedIn call failed. Please try later!');
        }  
    }*/
}