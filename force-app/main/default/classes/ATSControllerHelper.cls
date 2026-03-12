/**
 * @description
 * Helper class for ATS Controller class for Applicant Tracking System (ATS).
 * @author Kshitiz
 * @modifiedBy Kshitiz
 */

public with sharing class ATSControllerHelper {

/**
 * @description
 * Retrieves the Org-Wide Email Address Id that matches the
 * currently logged-in user’s email address.
 * @return Id
 *         OrgWideEmailAddress Id corresponding to the
 *         current user’s email.
 */
  public static Id getOrgWideEmailIdForCurrentUser() {

    //String userEmail = UserInfo.getUserEmail();

   // if (String.isBlank(userEmail)) {
   //     throw new AuraHandledException('Logged-in user email not found');
  //  }

    OrgWideEmailAddress owea = [
        SELECT Id
        FROM OrgWideEmailAddress
        WHERE IsAllowAllProfiles = true
         WITH SYSTEM_MODE
        ORDER BY CreatedDate ASC
        LIMIT 1
    ];

    return owea.Id;
}
}