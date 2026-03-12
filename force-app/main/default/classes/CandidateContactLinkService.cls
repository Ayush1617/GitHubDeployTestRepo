/**
 * @description
 * Service class responsible for updating Candidate Contacts
 * when portal (Experience Cloud) Users are created.
 *
 * Matching is performed using email address.
 *
 * @author Ajay
 * @createdDate 15-Dec-2025
 * @lastModifiedDate 15-Dec-2025
 */
public without sharing class CandidateContactLinkService {

    /**
     * Entry-point method invoked from User AFTER INSERT trigger.
     */
    public static void linkCandidatesFromUsers(List<User> insertedUsers) {

        if (insertedUsers == null || insertedUsers.isEmpty()) {
            return;
        }

        Set<Id> contactIds = new Set<Id>();
        for (User usr : insertedUsers) {
            if (usr.ContactId != null) {
                contactIds.add(usr.ContactId);
            }
        }

        if (contactIds.isEmpty()) {
            return;
        }

        Map<Id, Contact> contactMap = fetchEligibleContacts(contactIds);
        if (contactMap.isEmpty()) {
            return;
        }

        Set<Id> accountIds = new Set<Id>();
        for (Contact con : contactMap.values()) {
            accountIds.add(con.AccountId);
        }

        Set<Id> customerAccountIds = getCustomerAccountIds(accountIds);
        if (customerAccountIds.isEmpty()) {
            return;
        }

        Map<String, Id> emailToAccountIdMap = new Map<String, Id>();
        for (Contact con : contactMap.values()) {
            if (customerAccountIds.contains(con.AccountId)) {
                emailToAccountIdMap.put(con.Email.toLowerCase(), con.AccountId);
            }
        }

        if (emailToAccountIdMap.isEmpty()) {
            return;
        }

        List<Contact> candidateContactsToUpdate =
            fetchCandidatesForUpdate(emailToAccountIdMap);

        if (!candidateContactsToUpdate.isEmpty()) {
            update candidateContactsToUpdate;
        }
    }

    // ------------------------------------------------------------------
    // Helper Methods (ALL 4 METHODS PRESERVED)
    // ------------------------------------------------------------------

    /**
     * Fetches Contacts that have Email and Account populated.
     */
    private static Map<Id, Contact> fetchEligibleContacts(Set<Id> contactIds) {

        Map<Id, Contact> contactMap = new Map<Id, Contact>();

        for (Contact con : [
            SELECT Id, Email, AccountId
            FROM Contact
            WHERE Id IN :contactIds
            AND Email != null
            AND AccountId != null
        ]) {
            contactMap.put(con.Id, con);
        }

        return contactMap;
    }

    /**
     * Retrieves Account Ids whose RecordType is Customer Community Account.
     */
    private static Set<Id> getCustomerAccountIds(Set<Id> accountIds) {

        Set<Id> customerAccountIds = new Set<Id>();

        if (accountIds.isEmpty()) {
            return customerAccountIds;
        }

        for (Account acc : [
            SELECT Id
            FROM Account
            WHERE Id IN :accountIds
            AND RecordType.DeveloperName = 'Customer_Community_Account'
        ]) {
            customerAccountIds.add(acc.Id);
        }

        return customerAccountIds;
    }

    /**
     * Fetches Candidate Contacts (RecordType = Candidate)
     * and updates them based on email match.
     */
    private static List<Contact> fetchCandidatesForUpdate(
        Map<String, Id> emailToAccountIdMap
    ) {

        List<Contact> contactsToUpdate = new List<Contact>();

        for (Contact cand : [
            SELECT Id, Email, AccountId
            FROM Contact
            WHERE RecordType.DeveloperName = 'Candidate'
            AND Email IN :emailToAccountIdMap.keySet()
        ]) {

            if (cand.AccountId == null) {
                cand.AccountId =
                    emailToAccountIdMap.get(cand.Email.toLowerCase());

                contactsToUpdate.add(cand);
            }
        }

        return contactsToUpdate;
    }
}