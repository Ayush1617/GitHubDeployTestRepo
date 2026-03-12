/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : DummyCandidateController
 * Author          : <YourName>
 * Created Date    : Jan 30, 2026
 * Last Modified By: <YourName>
 * Last Modified On: Jan 30, 2026
 * Description     : This class implements for......
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Jan 30, 2026  │ <YourName>   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */

public with sharing class DummyCandidateController {

    @AuraEnabled(cacheable=true)
    public static List<CandidateWrapper> getDummyCandidates() {
        
        List<CandidateWrapper> candidates = new List<CandidateWrapper>();

        candidates.add(new CandidateWrapper('1', 'Washim R', 4.1, false));
        candidates.add(new CandidateWrapper('2', 'Vijeta P', 4.7, false));
        candidates.add(new CandidateWrapper('3', 'Santosh S', 4.6, true));
        candidates.add(new CandidateWrapper('4', 'Rahul K', 5.2, false));
        candidates.add(new CandidateWrapper('5', 'Anjali M', 3.8, false));

        return candidates;
    }

    public class CandidateWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public Decimal experience;
        @AuraEnabled public Boolean isFinalDecision;

        public CandidateWrapper(String id, String name, Decimal exp, Boolean finalDecision) {
            this.id = id;
            this.name = name;
            this.experience = exp;
            this.isFinalDecision = finalDecision;
        }
    }
}