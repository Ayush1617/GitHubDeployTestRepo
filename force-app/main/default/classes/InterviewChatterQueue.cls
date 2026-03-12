/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : InterviewChatterQueue
 * Author          : <YourName>
 * Created Date    : Feb 26, 2026
 * Last Modified By: <YourName>
 * Last Modified On: Feb 26, 2026
 * Description     : This class implements for......
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Feb 26, 2026  │ <YourName>   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */

public class InterviewChatterQueue implements Queueable {

    private List<FeedItem> posts;

    public InterviewChatterQueue(List<FeedItem> chatterPosts){
        this.posts = chatterPosts;
    }

    public void execute(QueueableContext context){
        insert posts;
    }
}