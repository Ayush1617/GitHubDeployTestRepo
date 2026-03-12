@isTest
global class AWSSESEmailServiceMock implements HttpCalloutMock {

    global HTTPResponse respond(HTTPRequest req) {

        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/xml');
        res.setBody('<SendEmailResponse>Success</SendEmailResponse>');
        res.setStatusCode(200);

        return res;
    }
}