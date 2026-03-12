public class SendEmailAWS {

     public static void sendEmail(String toAddress, String subject, String bodyText){

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:AmazonSES');
        req.setMethod('POST');
        req.setHeader('Content-Type','application/x-www-form-urlencoded');

        String body = 'Action=SendEmail'
            + '&Source=ajaykaurav2020@gmail.com'
            + '&Destination.ToAddresses.member.1=' + EncodingUtil.urlEncode(toAddress,'UTF-8')
            + '&Message.Subject.Data=' + EncodingUtil.urlEncode(subject,'UTF-8')
            + '&Message.Body.Text.Data=' + EncodingUtil.urlEncode(bodyText,'UTF-8');

        req.setBody(body);

        Http http = new Http();
        HTTPResponse res = http.send(req);

        System.debug('Response: '+res.getBody());
    }
}