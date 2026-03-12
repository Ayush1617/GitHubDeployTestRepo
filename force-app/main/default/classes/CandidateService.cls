public without sharing class CandidateService {

    public static CandidatePublicController.CandidateResponse submitCandidate(
        Contact candidate
    ) {
        CandidatePublicController.CandidateResponse resp =
            new CandidatePublicController.CandidateResponse();

        try {
            insert candidate;
            resp.success = true;
            resp.message = 'Candidate submitted successfully';
            resp.candidateId = candidate.Id;
        } catch (Exception ex) {
            resp.success = false;
            resp.message = ex.getMessage();
        }

        return resp;
    }
}