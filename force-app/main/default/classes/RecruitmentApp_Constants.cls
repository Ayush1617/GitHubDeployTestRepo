/*
 ##################################################### 
 # Created By (Date)   : Admin (08 Aug, 2025)
 # Description         : Class to store application-wide constant values.
 #                       - Prevents hardcoding strings in multiple places.
 #                       - Makes updates easier and less error-prone.
 # Modifications Log   : 
 * Ver    Date              Author         Modification
 * 1.0    08 Aug, 2025      Admin          Initial Version
 #####################################################
*/

public with sharing class RecruitmentApp_Constants {
   public static String STATUS_EXTENDED = 'Extended';
   public static String INTERVIEW_STATUS_HIRED = 'Hired';
   public static String INTERVIEW_STATUS_OFFERED = 'Offered';
   public static String INTERVIEW_STATUS_INTERVIEWING = 'Interviewing';
   public static String WORKORDER_STATUS_NEW = 'New';
   public static String ROUND_HR = 'HR';
}