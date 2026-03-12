/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : AWSSESEmailService
 * Author          : AJay Kaurav
 * Created Date    : Feb 23, 2026
 * Last Modified By: 
 * Last Modified On: Feb 23, 2026
 * Description     : This class implements for......
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Feb 23, 2026  │ Ajay Kaurav   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */

public class AWSSESEmailService {

    public static void sendEmail(String toAddress, String subject, String htmlBody){

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:AmazonSES');
        req.setMethod('POST');
        req.setHeader('Content-Type','application/x-www-form-urlencoded');

        String body = 'Action=SendEmail'
            + '&Source=agrawalayush721@gmail.com' // verified SES email
            + '&Destination.ToAddresses.member.1=' + EncodingUtil.urlEncode(toAddress,'UTF-8')
            + '&Message.Subject.Data=' + EncodingUtil.urlEncode(subject,'UTF-8')
            + '&Message.Body.Html.Data=' + EncodingUtil.urlEncode(htmlBody,'UTF-8');

        req.setBody(body);

        Http http = new Http();
        HTTPResponse res = http.send(req);

        System.debug('AWS SES Response: '+res.getBody());
    }
}