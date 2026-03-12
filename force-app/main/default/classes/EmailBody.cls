/**
 *#####################################################
 * @created by (Date)   : Kshitiz (20 Aug, 2025)
 * @description         : This class hold email body of other classes.
 * @modifications Log   :
 * Ver    Date              Author           Modification
 * 1.0    20 Aug, 2025      Kshitiz          Initial Version
 *####################################################
 */
public class EmailBody {
	/**
     * @description Creates the email body used to request feedback from the client.
     * @param data Map<> of Strings containing:
     *         Recepient Name,
     *         Candidate Name,
     *         Job Position,
     *         Interview Round,
     *         Organization Name.
     * @return Email body string in HTML format.
     */
   /*public static String feedbackEmailBody(Map<String, String> data) {

    String recipientName  = data.get('clientName');
    String candidateName  = data.get('candidateName');
    String jobPosition    = data.get('jobPosition');
    String interviewRound = data.get('interviewRound');
    String orgName        = data.get('orgName');

        String emailBody = ''
            + '<p>Hello ' + recipientName + ',</p>'
            + '<p>We kindly request your feedback for the interview conducted. '
            + 'Please review the interview details below:</p>'
            + '<p>'
            + '<b>Candidate Name:</b> ' + candidateName + '<br/>'
            + '<b>Job Position:</b> ' + jobPosition + '<br/>'
            + '<b>Interview Round:</b> ' + interviewRound + '<br/>'
            + '</p>'
            + '<p><b>Feedback Request:</b></p>'
            + '<p>Your feedback is essential in helping us make an informed decision about '
            + 'the candidate’s progression in the hiring process. We would greatly appreciate it '
            + 'if you could share your observations and assessment by submitting your feedback.</p>'
            + '<p>Thank you for your time and valuable input.</p>'
            + '<p>Best regards,<br/>' + orgName + '</p>';

        return emailBody;
    }*/

    
     public static String feedbackEmailBody(Map<String, String> data) {
        system.debug('data@@@'+data);

        String recipientName  = data.get('clientName');
        String orgName        = data.get('orgName');
        String tableRows      = data.get('tableRows'); // 🔥 multiple candidates rows
        String jobPosition    = data.get('jobPosition');

        String emailBody = ''
            + '<p>Hello ' + recipientName + ',</p>'
            + '<p>We kindly request your feedback for the interviews conducted. '
            + 'Please review the interview details for Job Position: <strong>' 
          + jobPosition + 
         '</strong> below:</p>'

            // 🔥 TABLE START
            + '<table style="width:100%; border-collapse:collapse; font-family:Arial;">'

            // HEADER
            + '<tr style="background-color:#f2f2f2;">'
            + '<th style="border:1px solid #ddd; padding:10px; text-align:left;">Candidate Name</th>'
            + '<th style="border:1px solid #ddd; padding:10px; text-align:left;">Interview Round</th>'
            + '</tr>'

            // 🔥 MULTIPLE ROWS FROM CONTROLLER
            + tableRows

            + '</table>'

            + '<p><b>Feedback Request:</b></p>'
            + '<p>Your feedback is essential in helping us make an informed decision about '
            + 'the candidate’s progression in the hiring process. We would greatly appreciate it '
            + 'if you could share your observations and assessment.</p>'

            + '<p>Thank you for your time and valuable input.</p>'
            + '<p>Best regards,<br/>' + orgName + '</p>';
             system.debug('emailBody@@@'+emailBody);

        return emailBody;
    }
}