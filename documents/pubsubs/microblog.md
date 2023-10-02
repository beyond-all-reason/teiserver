#### microblog_posts
Used to communicate regarding new posts and updates to existing posts.
```elixir
%{
  event: :post_created
  post: Post object
}

%{
  event: :post_updated
  post: Post object
}

%{
  event: :post_deleted
  post: Post object
}
```
