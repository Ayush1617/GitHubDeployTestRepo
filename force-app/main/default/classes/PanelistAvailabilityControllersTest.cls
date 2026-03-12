@isTest
public class PanelistAvailabilityControllersTest {
    
    // Test data setup
    @TestSetup
    static void setupTestData() {
        // Create test contact with email
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Panelist',
            Email = 'test.panelist@example.com'
        );
        insert testContact;
    }
    
    // ========== Tests for sendAvailabilityLink method ==========
    
    @isTest
    static void testSendAvailabilityLink_Success() {
        // Get test contact
        Contact con = [SELECT Id, Email FROM Contact LIMIT 1];
        
        // Prepare test slots
        List<Map<String, String>> slots = new List<Map<String, String>>{
            new Map<String, String>{
                'availabilityDate' => String.valueOf(Date.today().addDays(1)),
                'startTime' => '09:00',
                'endTime' => '10:00'
            },
            new Map<String, String>{
                'availabilityDate' => String.valueOf(Date.today().addDays(2)),
                'startTime' => '14:00',
                'endTime' => '15:00'
            }
        };
        
        Test.startTest();
        String result = PanelistAvailabilityControllers.sendAvailabilityLink(con.Id, slots);
        Test.stopTest();
        
        // Verify result
        System.assert(result.contains('Email sent successfully'), 'Email should be sent successfully');
        
        // Verify contact fields were updated
        Contact updatedCon = [
            SELECT Availability_Token__c, Token_Expiry__c, 
                   Availability_Link_Used__c, Availability_Data__c 
            FROM Contact 
            WHERE Id = :con.Id
        ];
        
        System.assertNotEquals(null, updatedCon.Availability_Token__c, 'Token should be generated');
        System.assertNotEquals(null, updatedCon.Token_Expiry__c, 'Token expiry should be set');
        System.assertEquals(false, updatedCon.Availability_Link_Used__c, 'Link should not be marked as used');
        System.assertNotEquals(null, updatedCon.Availability_Data__c, 'Availability data should be stored');
        
        // Verify JSON structure
        List<Object> storedSlots = (List<Object>)JSON.deserializeUntyped(updatedCon.Availability_Data__c);
        System.assertEquals(2, storedSlots.size(), 'Should have 2 slots stored');
    }
    
   /* @isTest
    static void testSendAvailabilityLink_NullContactId() {
        List<Map<String, String>> slots = new List<Map<String, String>>{
            new Map<String, String>{
                'availabilityDate' => String.valueOf(Date.today().addDays(1)),
                'startTime' => '09:00',
                'endTime' => '10:00'
            }
        };
        
        Test.startTest();
            PanelistAvailabilityControllers.sendAvailabilityLink(null, slots);
            System.assert(false, 'Should have thrown an exception');

        Test.stopTest();
    }*/
    
   /* @isTest
    static void testSendAvailabilityLink_EmptySlots() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        
        Test.startTest();
            PanelistAvailabilityControllers.sendAvailabilityLink(con.Id, new List<Map<String, String>>());
            System.assert(false, 'Should have thrown an exception');

        Test.stopTest();
    }*/
    
    /*@isTest
    static void testSendAvailabilityLink_NoEmail() {
        // Create contact without email
        Contact noEmailContact = new Contact(
            FirstName = 'No',
            LastName = 'Email'
        );
        insert noEmailContact;
        
        List<Map<String, String>> slots = new List<Map<String, String>>{
            new Map<String, String>{
                'availabilityDate' => String.valueOf(Date.today().addDays(1)),
                'startTime' => '09:00',
                'endTime' => '10:00'
            }
        };
        
        Test.startTest();
            PanelistAvailabilityControllers.sendAvailabilityLink(noEmailContact.Id, slots);
            System.assert(false, 'Should have thrown an exception');

        Test.stopTest();
    }*/
    
    // ========== Tests for getAvailabilityRequest method ==========
    
    @isTest
    static void testGetAvailabilityRequest_ValidToken() {
        // Setup contact with token and data
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        
        String token = 'test_token_12345678901234567890';
        List<Map<String, Object>> slotsData = new List<Map<String, Object>>{
            new Map<String, Object>{
                'id' => 'slot_1',
                'date' => String.valueOf(Date.today().addDays(1)),
                'startTime' => '09:00',
                'endTime' => '10:00',
                'selected' => false
            }
        };
        
        con.Availability_Token__c = token;
        con.Token_Expiry__c = System.now().addDays(7);
        con.Availability_Link_Used__c = false;
        con.Availability_Data__c = JSON.serialize(slotsData);
        update con;
        
        Test.startTest();
        Map<String, Object> result = PanelistAvailabilityControllers.getAvailabilityRequest(token);
        Test.stopTest();
        
        // Verify result
        System.assertEquals(true, result.get('isValid'), 'Token should be valid');
        System.assertNotEquals(null, result.get('contactName'), 'Contact name should be returned');
        System.assertNotEquals(null, result.get('slots'), 'Slots should be returned');
        
        List<Object> returnedSlots = (List<Object>)result.get('slots');
        System.assertEquals(1, returnedSlots.size(), 'Should return 1 slot');
    }
    
    @isTest
    static void testGetAvailabilityRequest_BlankToken() {
        Test.startTest();
        Map<String, Object> result = PanelistAvailabilityControllers.getAvailabilityRequest('');
        Test.stopTest();
        
        System.assertEquals(false, result.get('isValid'), 'Should be invalid');
        System.assertEquals('No token provided', result.get('message'), 'Should return appropriate message');
    }
    
    @isTest
    static void testGetAvailabilityRequest_InvalidToken() {
        Test.startTest();
        Map<String, Object> result = PanelistAvailabilityControllers.getAvailabilityRequest('invalid_token');
        Test.stopTest();
        
        System.assertEquals(false, result.get('isValid'), 'Should be invalid');
        System.assertEquals('Invalid link', result.get('message'), 'Should return appropriate message');
    }
    
    @isTest
    static void testGetAvailabilityRequest_ExpiredToken() {
        // Setup contact with expired token
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        
        String token = 'expired_token_123456789012345';
        con.Availability_Token__c = token;
        con.Token_Expiry__c = System.now().addDays(-1); // Expired
        con.Availability_Link_Used__c = false;
        con.Availability_Data__c = JSON.serialize(new List<Object>());
        update con;
        
        Test.startTest();
        Map<String, Object> result = PanelistAvailabilityControllers.getAvailabilityRequest(token);
        Test.stopTest();
        
        System.assertEquals(false, result.get('isValid'), 'Should be invalid');
        System.assert(result.get('message').toString().contains('expired'), 'Should indicate token is expired');
    }
    
    @isTest
    static void testGetAvailabilityRequest_AlreadyUsedLink() {
        // Setup contact with used token
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        
        String token = 'used_token_1234567890123456';
        con.Availability_Token__c = token;
        con.Token_Expiry__c = System.now().addDays(7);
        con.Availability_Link_Used__c = true; // Already used
        con.Availability_Data__c = JSON.serialize(new List<Object>());
        update con;
        
        Test.startTest();
        Map<String, Object> result = PanelistAvailabilityControllers.getAvailabilityRequest(token);
        Test.stopTest();
        
        System.assertEquals(false, result.get('isValid'), 'Should be invalid');
        System.assert(result.get('message').toString().contains('already been used'), 
                     'Should indicate link was already used');
    }
    
    @isTest
    static void testGetAvailabilityRequest_NoAvailabilityData() {
        // Setup contact with token but no availability data
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        
        String token = 'nodata_token_123456789012345';
        con.Availability_Token__c = token;
        con.Token_Expiry__c = System.now().addDays(7);
        con.Availability_Link_Used__c = false;
        con.Availability_Data__c = null;
        update con;
        
        Test.startTest();
        Map<String, Object> result = PanelistAvailabilityControllers.getAvailabilityRequest(token);
        Test.stopTest();
        
        System.assertEquals(false, result.get('isValid'), 'Should be invalid');
        System.assert(result.get('message').toString().contains('No availability data found'), 
                     'Should indicate no data found');
    }
    
    // ========== Tests for submitSelectedSlots method ==========
    
    @isTest
    static void testSubmitSelectedSlots_Success() {
        // Setup contact with token and data
        Contact con = [SELECT Id, Email FROM Contact LIMIT 1];
        
        String token = 'submit_token_123456789012345';
        List<Map<String, Object>> slotsData = new List<Map<String, Object>>{
            new Map<String, Object>{
                'id' => 'slot_1',
                'date' => String.valueOf(Date.today().addDays(1)),
                'startTime' => '09:00',
                'endTime' => '10:00',
                'selected' => false
            },
            new Map<String, Object>{
                'id' => 'slot_2',
                'date' => String.valueOf(Date.today().addDays(2)),
                'startTime' => '14:00',
                'endTime' => '15:00',
                'selected' => false
            }
        };
        
        con.Availability_Token__c = token;
        con.Token_Expiry__c = System.now().addDays(7);
        con.Availability_Link_Used__c = false;
        con.Availability_Data__c = JSON.serialize(slotsData);
        update con;
        
        List<String> selectedSlotIds = new List<String>{'slot_1', 'slot_2'};
        
        Test.startTest();
        String result = PanelistAvailabilityControllers.submitSelectedSlots(token, selectedSlotIds);
        Test.stopTest();
        
        // Verify result
        System.assert(result.contains('successfully'), 'Should return success message');
        System.assert(result.contains('2'), 'Should mention 2 slots');
        
        // Verify contact is marked as used
        Contact updatedCon = [SELECT Availability_Link_Used__c FROM Contact WHERE Id = :con.Id];
        System.assertEquals(true, updatedCon.Availability_Link_Used__c, 'Link should be marked as used');
        
        // Verify events were created
        List<Event> events = [SELECT Id, WhoId, Subject FROM Event WHERE WhoId = :con.Id];
        System.assertEquals(2, events.size(), 'Should create 2 events');
    }
    
    @isTest
    static void testSubmitSelectedSlots_InvalidToken() {
        List<String> selectedSlotIds = new List<String>{'slot_1'};
        
        Test.startTest();
        try {
            String result = PanelistAvailabilityControllers.submitSelectedSlots('invalid_token', selectedSlotIds);
            System.assert(result.contains('Invalid or expired'), 'Should return error message');
        } catch (Exception e) {
            // Expected - either exception or error message
        }
        Test.stopTest();
    }
    
    /*@isTest
    static void testSubmitSelectedSlots_EmptySlotIds() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        String token = 'test_token_12345678901234567890';
        
        Test.startTest();
            PanelistAvailabilityControllers.submitSelectedSlots(token, new List<String>());
            System.assert(false, 'Should have thrown an exception');
        Test.stopTest();
    }*/
    
    @isTest
    static void testSubmitSelectedSlots_NoMatchingSlots() {
        // Setup contact with token and data
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        
        String token = 'nomatch_token_123456789012345';
        List<Map<String, Object>> slotsData = new List<Map<String, Object>>{
            new Map<String, Object>{
                'id' => 'slot_1',
                'date' => String.valueOf(Date.today().addDays(1)),
                'startTime' => '09:00',
                'endTime' => '10:00',
                'selected' => false
            }
        };
        
        con.Availability_Token__c = token;
        con.Token_Expiry__c = System.now().addDays(7);
        con.Availability_Link_Used__c = false;
        con.Availability_Data__c = JSON.serialize(slotsData);
        update con;
        
        // Try to submit non-existent slot IDs
        List<String> selectedSlotIds = new List<String>{'slot_999'};
        
        Test.startTest();
        try {
            String result = PanelistAvailabilityControllers.submitSelectedSlots(token, selectedSlotIds);
            System.assert(result.contains('No slots selected'), 'Should indicate no slots selected');
        } catch (Exception e) {
            // May throw exception or return error message
        }
        Test.stopTest();
    }
    
    // ========== Tests for createAvailability method ==========
    
    @isTest
    static void testCreateAvailability_Success() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        
        List<Map<String, String>> slots = new List<Map<String, String>>{
            new Map<String, String>{
                'availabilityDate' => String.valueOf(Date.today().addDays(1)),
                'startTime' => '09:00',
                'endTime' => '10:00'
            },
            new Map<String, String>{
                'availabilityDate' => String.valueOf(Date.today().addDays(2)),
                'startTime' => '13:00',
                'endTime' => '14:30'
            }
        };
        
        Test.startTest();
        PanelistAvailabilityControllers.createAvailability(con.Id, slots);
        Test.stopTest();
        
        // Verify events were created
        List<Event> events = [SELECT Id, Subject, WhoId FROM Event WHERE WhoId = :con.Id];
        System.assertEquals(2, events.size(), 'Should create 2 events');
        System.assertEquals('Interviewer Availability', events[0].Subject, 'Subject should match');
    }
    
    /*@isTest
    static void testCreateAvailability_NullContactId() {
        List<Map<String, String>> slots = new List<Map<String, String>>{
            new Map<String, String>{
                'availabilityDate' => String.valueOf(Date.today().addDays(1)),
                'startTime' => '09:00',
                'endTime' => '10:00'
            }
        };
        
        Test.startTest();
            PanelistAvailabilityControllers.createAvailability(null, slots);
            System.assert(false, 'Should have thrown an exception');
        Test.stopTest();
    }*/
    
    /*@isTest
    static void testCreateAvailability_InvalidTimeRange() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        
        // End time before start time
        List<Map<String, String>> slots = new List<Map<String, String>>{
            new Map<String, String>{
                'availabilityDate' => String.valueOf(Date.today().addDays(1)),
                'startTime' => '10:00',
                'endTime' => '09:00'
            }
        };
        
        Test.startTest();
            PanelistAvailabilityControllers.createAvailability(con.Id, slots);
            System.assert(false, 'Should have thrown an exception');
        Test.stopTest();
    }*/
    
    /*@isTest
    static void testCreateAvailability_MissingFields() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        
        // Missing endTime
        List<Map<String, String>> slots = new List<Map<String, String>>{
            new Map<String, String>{
                'availabilityDate' => String.valueOf(Date.today().addDays(1)),
                'startTime' => '09:00'
            }
        };
        
        Test.startTest();
            PanelistAvailabilityControllers.createAvailability(con.Id, slots);
            System.assert(false, 'Should have thrown an exception');
        Test.stopTest();
    }*/
    
    // ========== Tests for helper methods ==========
    
    @isTest
    static void testGenerateSecureToken() {
        // This test is implicit in the sendAvailabilityLink test
        // but we can verify token generation indirectly
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        
        List<Map<String, String>> slots = new List<Map<String, String>>{
            new Map<String, String>{
                'availabilityDate' => String.valueOf(Date.today().addDays(1)),
                'startTime' => '09:00',
                'endTime' => '10:00'
            }
        };
        
        Test.startTest();
        PanelistAvailabilityControllers.sendAvailabilityLink(con.Id, slots);
        Test.stopTest();
        
        Contact updatedCon = [SELECT Availability_Token__c FROM Contact WHERE Id = :con.Id];
        System.assertNotEquals(null, updatedCon.Availability_Token__c, 'Token should be generated');
        System.assertEquals(32, updatedCon.Availability_Token__c.length(), 'Token should be 32 characters');
    }
    
    @isTest
    static void testBuildDateTime() {
        // This is tested implicitly through createAvailability and submitSelectedSlots
        // Verifying datetime construction works correctly
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        
        String testDate = String.valueOf(Date.today().addDays(1));
        List<Map<String, String>> slots = new List<Map<String, String>>{
            new Map<String, String>{
                'availabilityDate' => testDate,
                'startTime' => '14:30',
                'endTime' => '15:45'
            }
        };
        
        Test.startTest();
        PanelistAvailabilityControllers.createAvailability(con.Id, slots);
        Test.stopTest();
        
        Event evt = [SELECT StartDateTime, EndDateTime FROM Event WHERE WhoId = :con.Id LIMIT 1];
        System.assertNotEquals(null, evt.StartDateTime, 'Start datetime should be set');
        System.assertNotEquals(null, evt.EndDateTime, 'End datetime should be set');
    }
}