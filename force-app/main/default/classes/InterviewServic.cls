public without sharing class InterviewServic {

    public static CandidatePublicController.CandidateResponse createInterview(
        Id candidateId,
        Id jobId
    ) {
        CandidatePublicController.CandidateResponse resp =
            new CandidatePublicController.CandidateResponse();

        try {
            if (candidateId == null || jobId == null) {
                resp.success = false;
                resp.message = 'CandidateId and JobId are required';
                return resp;
            }

            Interview__c interview = new Interview__c();
            interview.Candidate_Name__c = candidateId;
            interview.Job_Position__c = jobId;
           

            insert interview;

            resp.success = true;
            resp.message = 'Interview created successfully';
            resp.interviewCreated = true;
            resp.interviewId = interview.Id;

        } catch (Exception ex) {
            resp.success = false;
            resp.message = ex.getMessage();
            resp.interviewCreated = false;
        }

        return resp;
    }
}