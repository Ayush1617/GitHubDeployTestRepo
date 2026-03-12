global class WeeklyPanelistAvailabilityMailer implements Schedulable {

    global void execute(SchedulableContext sc) {
        sendEmails();
    }

    public static void sendEmails() {

        List<Contact> panelists = [
            SELECT Id, Email, FirstName 
            FROM Contact
            WHERE Panelist__c = true
            AND Email != null
        ];

        if (panelists.isEmpty()) {
            return;
        }

        List<Messaging.SingleEmailMessage> emails =
            new List<Messaging.SingleEmailMessage>();

        // Dynamic, org-safe base URL
        String siteBaseUrl = System.Label.Interview_Availability_Site_URL;
        
        for (Contact c : panelists) {

            String link = siteBaseUrl +
                '/InterviewAvailability/s/panelist-interview-availability' +
                '?contactId=' + c.Id;

            Messaging.SingleEmailMessage mail =
                new Messaging.SingleEmailMessage();

            mail.setToAddresses(new String[] { c.Email });
            mail.setSubject(
                'Please share your interview availability for this week'
            );

            mail.setHtmlBody(
                'Hi ' + c.FirstName + ',<br/><br/>' +
                'Please click the button below to add your interview availability for this week:<br/><br/>' +
            
                '<a href="' + link + '" ' +
                'style="display:inline-block;' +
                'padding:12px 24px;' +
                'background-color:#0176d3;' +
                'color:#ffffff;' +
                'text-decoration:none;' +
                'font-size:14px;' +
                'font-weight:bold;' +
                'border-radius:4px;">' +
                'Add Availability</a><br/><br/>' +
            
                'Thanks,<br/>' +
                'Recruitment Team'
            );
            
            emails.add(mail);
        }

        // Send emails with partial success allowed
        if (!emails.isEmpty()) {
            Messaging.SendEmailResult[] results =
                Messaging.sendEmail(emails, false);

            // Optional: log failures
            for (Integer i = 0; i < results.size(); i++) {
                if (!results[i].isSuccess()) {
                    for (Messaging.SendEmailError err :
                        results[i].getErrors()) {
                        System.debug(
                            'Email failed for: ' + panelists[i].Email +
                            ' | Error: ' + err.getMessage()
                        );
                    }
                }
            }
        }
    }
}