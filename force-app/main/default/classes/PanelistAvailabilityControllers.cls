public without sharing class PanelistAvailabilityControllers {
    
    // === FOR INTERNAL USER: Generate link and send email ===
    @AuraEnabled
    public static String sendAvailabilityLink(
        Id contactId,
        List<Map<String, String>> slots
    ) {
        try {
            if (contactId == null || slots == null || slots.isEmpty()) {
                throw new AuraHandledException('Select at least one date and time slot');
            }
            
            // Query contact with email
            Contact con = [SELECT Id, Name, Email FROM Contact WHERE Id = :contactId LIMIT 1];
            
            if (String.isBlank(con.Email)) {
                throw new AuraHandledException('Contact does not have an email address');
            }
            
            // Generate secure token
            String token = generateSecureToken();
            
            // Prepare slots data with unique IDs
            List<Map<String, Object>> slotsWithIds = new List<Map<String, Object>>();
            Integer slotId = 1;
            for (Map<String, String> slot : slots) {
                Map<String, Object> slotData = new Map<String, Object>{
                    'id' => 'slot_' + slotId++,
                    'date' => slot.get('availabilityDate'),
                    'startTime' => slot.get('startTime'),
                    'endTime' => slot.get('endTime'),
                    'selected' => false
                };
                slotsWithIds.add(slotData);
            }
            
            // Store as JSON in Long Text Area field
            String slotsJson = JSON.serialize(slotsWithIds);
            
            // Update contact with token, expiry, and slots data
            con.Availability_Token__c = token;
            con.Token_Expiry__c = System.now().addDays(7);
            con.Availability_Link_Used__c = false;
            con.Availability_Data__c = slotsJson;
            
            update con;
            
            String siteUrl = getCommunityUrl();
            
            String fullUrl = siteUrl + '?token=' + EncodingUtil.urlEncode(token, 'UTF-8');
            
            // Send email to contact with the tokenized link
            sendEmailToContact(con, fullUrl, token);
            
            return 'Email sent successfully to ' + con.Email;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }
    
    // === METHOD TO SEND EMAIL ===
    private static void sendEmailToContact(Contact con, String link, String token) {
        try {
            // Create email template content
            String subject = 'Interview Availability Request';
            
            String body = '<html><body style="font-family: Arial, sans-serif;">' +
                '<div style="max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 10px;">' +
                '<h2 style="color: #2c3e50;">Interview Availability Request</h2>' +
                '<p>Dear ' + con.Name + ',</p>' +
                '<p>You have been requested to provide your interview availability for upcoming interviews.</p>' +
                '<p>Please click the button below to select your preferred time slots:</p>' +
                '<div style="text-align: center; margin: 30px 0;">' +
                '<a href="' + link + '" style="background-color: #0070d2; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; font-weight: bold; display: inline-block;">Select My Availability</a>' +
                '</div>' +
                '<p>Or copy and paste this URL into your browser:</p>' +
                '<div style="background-color: #f5f5f5; padding: 10px; border-radius: 5px; word-break: break-all; font-family: monospace; font-size: 12px; margin: 10px 0;">' +
                link +
                '</div>' +
                '<div style="background-color: #fff8e1; padding: 10px; border-radius: 5px; border-left: 4px solid #ffc107; margin: 20px 0;">' +
                '<strong>Important:</strong> This link is personalized for you and will expire in 7 days.' +
                '</div>' +
                '<p>Best regards,<br/>' +
                '<strong>Interview Scheduling Team</strong></p>' +
                '</div>' +
                '</body></html>';
            
            // Create single email message
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            
            // Set email addresses
            email.setToAddresses(new List<String>{con.Email});
            email.setSubject(subject);
            email.setHtmlBody(body);
            
            // Set sender display name
            //email.setSenderDisplayName('Interview Scheduling System');
            email.setOrgWideEmailAddressId(ATSControllerHelper.getOrgWideEmailIdForCurrentUser());
            
            // Send email
            Messaging.SendEmailResult[] results = Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{email});
            
            if (!results[0].isSuccess()) {
                throw new AuraHandledException('Failed to send email: ' + results[0].getErrors()[0].getMessage());
            }
            
        } catch (Exception e) {
            System.debug('Error sending email: ' + e.getMessage());
            throw new AuraHandledException('Failed to send email: ' + e.getMessage());
        }
    }
    
    // === GET COMMUNITY/SITE URL ===
    private static String getCommunityUrl() {
        try {
            String communityUrl = System.Label.Request_panelist_availability;
            return communityUrl;
            
        } catch (Exception e) {
            System.debug('Error getting community URL: ' + e.getMessage());
            // Fallback URL - you should replace this with your actual community URL
            return 'https://your-org-name.force.com';
        }
    }
    
    // === FOR EXTERNAL USER: Get requested slots from contact field ===
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getAvailabilityRequest(String token) {
        try {
            System.debug('=== getAvailabilityRequest called ===');
            System.debug('Token received: ' + token);
            
            if (String.isBlank(token)) {
                return new Map<String, Object>{
                    'isValid' => false,
                    'message' => 'No token provided'
                };
            }
            
            // Find contact with valid token
            List<Contact> contacts = [
                SELECT Id, Name, Email, Availability_Data__c, 
                       Availability_Link_Used__c, Token_Expiry__c, Availability_Token__c
                FROM Contact 
                WHERE Availability_Token__c = :token
                AND Token_Expiry__c > :System.now()
                AND Availability_Link_Used__c = false
                LIMIT 1
            ];
            
            System.debug('Number of contacts found: ' + contacts.size());
            
            if (contacts.isEmpty()) {
                // Check if token exists but expired or already used
                List<Contact> expiredContacts = [
                    SELECT Id, Token_Expiry__c, Availability_Link_Used__c 
                    FROM Contact 
                    WHERE Availability_Token__c = :token
                    LIMIT 1
                ];
                
                if (!expiredContacts.isEmpty()) {
                    Contact expiredCon = expiredContacts[0];
                    if (expiredCon.Availability_Link_Used__c) {
                        return new Map<String, Object>{
                            'isValid' => false,
                            'message' => 'This link has already been used'
                        };
                    } else if (expiredCon.Token_Expiry__c < System.now()) {
                        return new Map<String, Object>{
                            'isValid' => false,
                            'message' => 'This link has expired. Please request a new one.'
                        };
                    }
                }
                
                return new Map<String, Object>{
                    'isValid' => false,
                    'message' => 'Invalid link'
                };
            }
            
            Contact con = contacts[0];
            String slotsJson = con.Availability_Data__c;
            
            System.debug('Contact found: ' + con.Name);
            System.debug('Slots JSON present: ' + (String.isNotBlank(slotsJson)));
            
            if (String.isBlank(slotsJson)) {
                return new Map<String, Object>{
                    'isValid' => false,
                    'message' => 'No availability data found. Please contact the sender.'
                };
            }
            
            // Parse the JSON data
            List<Object> slotsData = (List<Object>)JSON.deserializeUntyped(slotsJson);
            
            System.debug('Number of slots parsed: ' + slotsData.size());
            
            return new Map<String, Object>{
                'isValid' => true,
                'contactName' => con.Name,
                'contactEmail' => con.Email,
                'token' => token,
                'slots' => slotsData
            };
            
        } catch (Exception e) {
            System.debug('Exception in getAvailabilityRequest: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error loading availability request: ' + e.getMessage());
        }
    }
    
    // === FOR EXTERNAL USER: Submit selected slots ===
    @AuraEnabled
    public static String submitSelectedSlots(String token, List<String> selectedSlotIds) {
        try {
            if (String.isBlank(token) || selectedSlotIds == null || selectedSlotIds.isEmpty()) {
                throw new AuraHandledException('Invalid request data');
            }
            
            // Validate token and get contact
            List<Contact> contacts = [
                SELECT Id, Name, Availability_Data__c, Availability_Link_Used__c
                FROM Contact 
                WHERE Availability_Token__c = :token
                AND Token_Expiry__c > :System.now()
                AND Availability_Link_Used__c = false
                LIMIT 1
            ];
            
            if (contacts.isEmpty()) {
                return 'Invalid or expired link. Please request a new one.';
            }
            
            Contact con = contacts[0];
            String slotsJson = con.Availability_Data__c;
            
            if (String.isBlank(slotsJson)) {
                return 'No availability data found.';
            }
            
            // Parse slots data
            List<Object> slotsData = (List<Object>)JSON.deserializeUntyped(slotsJson);
            
            // Filter selected slots
            List<Map<String, Object>> selectedSlots = new List<Map<String, Object>>();
            for (Object slotObj : slotsData) {
                Map<String, Object> slot = (Map<String, Object>)slotObj;
                if (selectedSlotIds.contains((String)slot.get('id'))) {
                    selectedSlots.add(slot);
                }
            }
            
            if (selectedSlots.isEmpty()) {
                return 'No slots selected. Please select at least one time slot.';
            }
            
            // Create events for selected slots
            List<Event> eventsToInsert = new List<Event>();
            for (Map<String, Object> slot : selectedSlots) {
                String dateStr = (String)slot.get('date');
                String startStr = (String)slot.get('startTime');
                String endStr = (String)slot.get('endTime');
                
                Datetime startDt = buildDateTime(dateStr, startStr);
                Datetime endDt = buildDateTime(dateStr, endStr);
                
                eventsToInsert.add(new Event(
                    WhoId = con.Id,
                    Subject = 'Interview Availability - ' + con.Name,
                    StartDateTime = startDt,
                    EndDateTime = endDt,
                    ShowAs = 'Free',
                    IsAllDayEvent = false,
                    Description = 'Submitted via availability link\n' +
                                'Contact: ' + con.Name + '\n' +
                                'Selected slots: ' + selectedSlotIds.size()
                ));
            }
            
            // Mark link as used to prevent reuse
            con.Availability_Link_Used__c = true;
            
            // Perform DML operations
            update con;
            insert eventsToInsert;
            
            // Send confirmation email to contact
            sendConfirmationEmail(con, selectedSlotIds.size());
            
            return 'Thank you! Your availability has been submitted successfully. ' + 
                   selectedSlotIds.size() + ' time slot(s) have been confirmed.';
            
        } catch (Exception e) {
            System.debug('Error submitting slots: ' + e.getMessage());
            throw new AuraHandledException('Error submitting availability: ' + e.getMessage());
        }
    }
    
    // === SEND CONFIRMATION EMAIL ===
    private static void sendConfirmationEmail(Contact con, Integer numberOfSlots) {
        try {
            String subject = 'Interview Availability Confirmation';
            
            String body = '<html><body style="font-family: Arial, sans-serif;">' +
                '<div style="max-width: 600px; margin: 0 auto; padding: 20px;">' +
                '<h2 style="color: #2c3e50;">Availability Submitted Successfully</h2>' +
                '<p>Dear ' + con.Name + ',</p>' +
                '<p>Thank you for submitting your interview availability.</p>' +
                '<div style="background-color: #e8f5e9; padding: 15px; border-radius: 5px; margin: 20px 0;">' +
                '<strong>Confirmation:</strong> You have successfully submitted ' + numberOfSlots + ' time slot(s) for interviews.' +
                '</div>' +
                '<p>An interviewer will contact you shortly to schedule the interviews.</p>' +
                '<p>Best regards,<br/>' +
                '<strong>Interview Scheduling Team</strong></p>' +
                '</div>' +
                '</body></html>';
            
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new List<String>{con.Email});
            email.setSubject(subject);
            email.setHtmlBody(body);
            
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{email});
            
        } catch (Exception e) {
            System.debug('Error sending confirmation email: ' + e.getMessage());
            // Don't throw error - this shouldn't fail the main transaction
        }
    }
    
    // === FOR INTERNAL USER: Direct save (existing functionality) ===
    @AuraEnabled
    public static void createAvailability(
        Id contactId,
        List<Map<String, String>> slots
    ) {
        if (contactId == null || slots == null || slots.isEmpty()) {
            throw new AuraHandledException('Invalid input data');
        }

        List<Event> eventsToInsert = new List<Event>();

        for (Map<String, String> slot : slots) {
            String dateStr = slot.get('availabilityDate');
            String startStr = slot.get('startTime');
            String endStr = slot.get('endTime');

            if (String.isBlank(dateStr) || String.isBlank(startStr) || String.isBlank(endStr)) {
                throw new AuraHandledException('Invalid availability payload');
            }

            Datetime startDt = buildDateTime(dateStr, startStr);
            Datetime endDt = buildDateTime(dateStr, endStr);

            if (startDt >= endDt) {
                throw new AuraHandledException('Invalid time range');
            }

            eventsToInsert.add(new Event(
                WhoId = contactId,
                Subject = 'Interviewer Availability',
                StartDateTime = startDt,
                EndDateTime = endDt,
                ShowAs = 'Free',
                IsAllDayEvent = false
            ));
        }

        insert eventsToInsert;
    }
    
    // === HELPER METHODS ===
    private static Datetime buildDateTime(String dateStr, String timeStr) {
        Date d = Date.valueOf(dateStr);
        List<String> t = timeStr.split(':');
        return Datetime.newInstance(
            d,
            Time.newInstance(
                Integer.valueOf(t[0]),
                Integer.valueOf(t[1]),
                0,
                0
            )
        );
    }
    
    private static String generateSecureToken() {
        Blob key = Crypto.generateAesKey(128);
        return EncodingUtil.convertToHex(key).substring(0, 32);
    }
}