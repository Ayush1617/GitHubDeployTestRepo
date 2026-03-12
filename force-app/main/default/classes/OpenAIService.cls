/**
* @File Name : OpenAIService.cls
* @Description : Apex class works as a controller for LWC/Flow to integrate Salesforce with OpenAI (ChatGPT).
*                Provides utility methods to dynamically generate job descriptions and LinkedIn text posts
*                based on user-provided skills or prompts.
* @Author : AJay Kaurav
* @Last Modified By :
* @Last Modified On : September 25, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | September 25, 2025 |   | Initial Version
**/

/**
 * @description
 * Service class to integrate Salesforce with OpenAI (ChatGPT)
 * for generating job descriptions and related content.
 */

public with sharing class OpenAIService {
    
    /**
     * @description
     * Generates a job description using OpenAI based on provided skills.
     *
     * @param skills Skills or keywords used to generate the job description
     * @return Generated job description text
     */
    public static String generateJobDescription(String skills) {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        
        req.setEndpoint('callout:' + 'Salesforce_With_ChatGPT_Named' +'/v1/chat/completions');
        req.setTimeout(1000*120); 
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        // Request Body
        String body = JSON.serialize(new Map<String, Object>{
            'model' => 'gpt-4o-mini',
            'messages' => new List<Object>{
                
                new Map<String, Object>{
                    'role' => 'user',
                    'content' => 'Create a job description for these skills: ' + skills
                }
            },
            'temperature' => 0.7
        });
        
        req.setBody(body);        
        HttpResponse res = http.send(req);
        system.debug('res.getStatusCode'+res.getStatusCode());
        if(res.getStatusCode() == 200) {
            Map<String,Object> result = (Map<String,Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> choices = (List<Object>) result.get('choices');
            if(!choices.isEmpty()) {
                Map<String,Object> choice = (Map<String,Object>) choices[0];
                Map<String,Object> message = (Map<String,Object>) choice.get('message');
                return (String) message.get('content');
            }
        }
        return 'No description generated. Please try again.';
    }
}