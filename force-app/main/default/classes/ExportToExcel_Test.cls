@IsTest
private class ExportToExcel_Test {
    // -------------------------------------------------
    // Utility: Create Test User (for runAs)
    // -------------------------------------------------
    private static User createTestUser() {
        Profile p = [
            SELECT Id 
            FROM Profile 
            WHERE Name = 'System Administrator' 
            LIMIT 1
        ];
        User u = new User(
            Alias = 'tuser',
            Email = 'testuser@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            Username = 'testuser' + System.currentTimeMillis() + '@test.com'
        );
        insert u;
        return u;
    }

    // -------------------------------------------------
    // Utility: Create test Candidate
    // -------------------------------------------------
    private static Contact createCandidate() {
        Contact c = new Contact(
            LastName = 'Doe',
            Email = 'john.doe@test.com',
            Phone = '9999999999',
            Total_Experience__c = 5,
            Source__c = 'LinkedIn'
        );
        insert c;
        return c;
    }

    // ===========================
    // Test: Successful Export
    // ===========================
    @IsTest
    static void testExportSuccess() {
        User u = createTestUser();
        Contact cand = createCandidate();

        System.runAs(u) {
            Test.startTest();
            String result = ExportToExcel.exportCandidatesToExcel(
                new List<Id>{ cand.Id }
            );
            Test.stopTest();

            System.assertNotEquals(null, result, 'Base64 string should not be null');
            System.assert(
                result.length() > 0,
                'Export result should contain Base64 data'
            );

            // Decode to validate content
            Blob decoded = EncodingUtil.base64Decode(result);
            String csv = decoded.toString();

            System.assert(csv.contains('Candidate Name'), 'CSV header missing');
        }
    }

    // ============================================
    // Test Exception: No IDs provided
    // ============================================
    @IsTest
    static void testNoIdsException() {
        User u = createTestUser();

        System.runAs(u) {
            try {
                Test.startTest();
                ExportToExcel.exportCandidatesToExcel(new List<Id>());
                Test.stopTest();

                System.assert(false, 'Exception expected but not thrown');
            } catch (AuraHandledException e) {

            }
        }
    }

    // ============================================
    // Test Exception: No data found for IDs
    // ============================================
    @IsTest
    static void testNoDataFoundException() {
        User u = createTestUser();

        // Create & delete candidate → valid Id but no data
        Contact temp = createCandidate();
        Id deletedCandidateId = temp.Id;
        delete temp;

        System.runAs(u) {
            try {
                Test.startTest();
                ExportToExcel.exportCandidatesToExcel(
                    new List<Id>{ deletedCandidateId }
                );
                Test.stopTest();

                System.assert(false, 'Exception should have been thrown');
            } catch (AuraHandledException e) {

            }
        }
    }
}