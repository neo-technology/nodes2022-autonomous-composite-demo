package sharding;

import org.neo4j.procedure.Description;
import org.neo4j.procedure.Name;
import org.neo4j.procedure.UserFunction;

public class Sharding
{
    private static final long NUM_POSTS_SHARDS = 10;

    @UserFunction
    @Description("Returns the name of the posts shard for the given person id")
    public String postsByPersonId(@Name("personId") Long personId) {
        return "social.posts" + postsNumByPersonId(personId);
    }

    @UserFunction
    @Description("Returns the number of the posts shard for the given person id")
    public long postsNumByPersonId(@Name("personId") Long personId) {
        return (personId % NUM_POSTS_SHARDS) + 1;
    }
}