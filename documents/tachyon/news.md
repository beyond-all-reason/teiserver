## Blog
### `c.news.get_latest_game_news`
Requires a category name and will return the latest
TODO: Add cache invalidation without refresh-on-touch
TODO: Identify if using a cache for categories and a cache for posts is better than a combined one using the :category_name filter in post_lib.ex

#### Successful response
* blog_post :: BlogPost

If the blog post does not exist or the category does not exist then you will receive a null response for the `blog_post` key.

```
{
  "cmd": "c.news.get_latest_game_news",
  "category": "Game updates"
}

{
  "cmd": "s.news.get_latest_game_news",
  "blog_post": BlogPost
}

{
  "cmd": "s.news.get_latest_game_news",
  "blog_post": null
}
```