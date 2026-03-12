public without sharing class LinkedInPostQueueable
    implements Queueable, Database.AllowsCallouts {

    private String content;

    public LinkedInPostQueueable(String content) {
        this.content = content;
    }

    public void execute(QueueableContext context) {

        System.debug('Queueable started for LinkedIn post');

        try {
           // LinkedInService.createPostInternal(content);
        } catch (Exception e) {
            System.debug('Queueable LinkedIn Error: ' + e.getMessage());
        }
    }
}