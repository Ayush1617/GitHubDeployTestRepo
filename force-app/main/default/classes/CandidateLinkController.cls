public with sharing class CandidateLinkController {
    
    // Store tokens temporarily (in production, use Custom Settings or Custom Metadata)
    private static Map<String, CandidateLinkData> tokenCache = new Map<String, CandidateLinkData>();
    
    public class CandidateLinkData {
        public List<Id> candidateIds;
        public Id clientId;
        public Id jobId;
        public DateTime expiryDate;
    }
    
    @AuraEnabled
    public static String generateCandidateLink(List<Id> candidateIds, Id clientId, Id jobId) {
        try {
            // Generate unique token
            String token = generateUniqueToken();
            
            // Store data temporarily
            CandidateLinkData data = new CandidateLinkData();
            data.candidateIds = candidateIds;
            data.clientId = clientId;
            data.jobId = jobId;
            data.expiryDate = DateTime.now().addDays(7); // Link expires in 7 days
            
            tokenCache.put(token, data);
            
            // Get community base URL
            String communityUrl = getCommunityBaseUrl();
            
            // Return full URL
            return communityUrl + '/candidate-details?token=' + token;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error generating link: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static List<Map<String, Object>> getCandidateDetailsFromToken(String token) {
        try {
            // Validate token
            if (!tokenCache.containsKey(token)) {
                throw new AuraHandledException('Invalid or expired link');
            }
            
            CandidateLinkData data = tokenCache.get(token);
            
            // Check expiry
            if (data.expiryDate < DateTime.now()) {
                tokenCache.remove(token);
                throw new AuraHandledException('Link has expired');
            }
            
            // Fetch candidate details
            return getCandidateDetails(data.candidateIds, data.clientId);
            
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving candidate details: ' + e.getMessage());
        }
    }
    
    private static List<Map<String, Object>> getCandidateDetails(List<Id> candidateIds, Id clientId) {
        // Reuse the existing method from SubmitCandidateController
        return SubmitCandidateController.getMultipleCandidatesForClient(candidateIds, clientId);
    }
    
    private static String generateUniqueToken() {
        Blob hash = Crypto.generateDigest('SHA256', Blob.valueOf(String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.random())));
        return EncodingUtil.convertToHex(hash).substring(0, 32);
    }
    
    private static String getCommunityBaseUrl() {
        try {
            String communityUrl = System.Label.Request_panelist_availability;
            return communityUrl;
            
        } catch (Exception e) {
            System.debug('Error getting community URL: ' + e.getMessage());
            // Fallback URL - you should replace this with your actual community URL
            return 'https://your-org-name.force.com';
        }
    }
}