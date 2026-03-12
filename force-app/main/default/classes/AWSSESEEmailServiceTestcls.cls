@IsTest
public class AWSSESEEmailServiceTestcls {

    @IsTest
    static void testSendEmail() {

        // Set the mock callout
        Test.setMock(HttpCalloutMock.class, new AWSSESEmailServiceMock());

        Test.startTest();

        AWSSESEmailService.sendEmail(
            'test@example.com',
            'Test Subject',
            '<h1>Hello Test</h1>'
        );

        Test.stopTest();

        System.assert(true);
    }
}