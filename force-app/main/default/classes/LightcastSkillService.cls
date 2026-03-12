/**
 * @description Service class responsible for invoking the Lightcast Skills API using a Named Credential
 *              and returning a list of matching skill names for a given query string.
 *              This class is designed for use by Lightning Web Components and other callers that require
 *              skill auto-complete or suggestion functionality.
 *
 * @author      Yuvraj
 * @createdDate
 * @version     1.0
 */
public with sharing class LightcastSkillService {


    private static final String SKILLS_URL = 'callout:Lightcast/skills/versions/latest/skills';

    /**
        * @description Fetches a set of skills from the Lightcast API filtered by the user-provided query.
        *              The method performs an HTTP GET callout through a Named Credential and returns up to
        *              10 matching skill names. Only the "name" field from each skill object is included
        *              in the response.
        *
        * @param query The partial or complete text used to search for matching skills.
        *
        * @return List<String> A list containing up to 10 skill names that match the provided query.
        */
        @AuraEnabled(cacheable=true)
        public static List<String> fetchSkills(String query) {
            List<String> results = new List<String>();

            try {
                // Prepare HTTP request
                HttpRequest req = new HttpRequest();
                req.setEndpoint(SKILLS_URL + '?q=' + EncodingUtil.urlEncode(query, 'UTF-8') + '&limit=10');
                req.setMethod('GET');
                req.setHeader('Content-Type', 'application/json');

                // Send request
                Http http = new Http();
                HttpResponse res = http.send(req);

                // Return early if response is not OK
                if (res.getStatusCode() != 200) {
                    return results;
                }

                // Parse response
                Map<String, Object> responseBody =
                    (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

                // Return early if no data element
                if (!responseBody.containsKey('data')) {
                    return results;
                }

                // Extract skill list
                List<Object> skills = (List<Object>) responseBody.get('data');

                for (Object s : skills) {
                    Map<String, Object> skillData = (Map<String, Object>) s;

                    String skillName = (String) skillData.get('name');
                    if (skillName != null) {
                        results.add(skillName);
                    }
                }

            } catch (Exception e) {
                throw new AuraHandledException(e.getMessage());
            }

            return results;
        }
}