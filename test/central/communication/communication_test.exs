defmodule Central.CommunicationTest do
  use Central.DataCase

  alias Central.Communication
  alias Central.Helpers.GeneralTestLib
  alias Central.CommunicationTestLib

  describe "posts" do
    alias Central.Communication.Post

    @valid_attrs %{
      "title" => "some title",
      "content" => "some content",
      "short_content" => "some short content",
      "tags" => ["Tag 1"],
      "url_slug" => "url_slug"
    }
    @update_attrs %{
      "title" => "some updated title",
      "content" => "some updated content",
      "short_content" => "some updated short content",
      "tags" => ["Tag 2"],
      "url_slug" => "some updated url_slug"
    }
    @invalid_attrs %{"title" => nil, "content" => nil, "tags" => nil}

    test "list_posts/0 returns posts" do
      CommunicationTestLib.post_fixture()
      assert Communication.list_posts() != []
    end

    test "get_post!/1 returns the post with given id" do
      post = CommunicationTestLib.post_fixture()
      assert Communication.get_post!(post.id) == post
    end

    test "create_post/1 with valid data creates a post" do
      poster = GeneralTestLib.user_fixture()
      category = CommunicationTestLib.category_fixture()

      assert {:ok, %Post{} = post} =
               Communication.create_post(
                 Map.merge(@valid_attrs, %{"poster_id" => poster.id, "category_id" => category.id})
               )

      assert post.title == "some title"
      assert post.content == "some content"
    end

    test "create_post/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Communication.create_post(@invalid_attrs)
    end

    test "update_post/2 with valid data updates the post" do
      post = CommunicationTestLib.post_fixture()
      assert {:ok, %Post{} = post} = Communication.update_post(post, @update_attrs)
      assert post.title == "some updated title"
      assert post.content == "some updated content"
    end

    test "update_post/2 with invalid data returns error changeset" do
      post = CommunicationTestLib.post_fixture()
      assert {:error, %Ecto.Changeset{}} = Communication.update_post(post, @invalid_attrs)
      assert post == Communication.get_post!(post.id)
    end

    test "delete_post/1 deletes the post" do
      post = CommunicationTestLib.post_fixture()
      assert {:ok, %Post{}} = Communication.delete_post(post)
      assert_raise Ecto.NoResultsError, fn -> Communication.get_post!(post.id) end
    end

    test "change_post/1 returns a post changeset" do
      post = CommunicationTestLib.post_fixture()
      assert %Ecto.Changeset{} = Communication.change_post(post)
    end
  end

  describe "comments" do
    alias Central.Communication.Comment

    @valid_attrs %{"content" => "some content", "approved" => true}
    @update_attrs %{"content" => "some updated content", "approved" => true}
    @invalid_attrs %{"content" => nil, "approved" => nil}

    test "list_comments/0 returns comments" do
      CommunicationTestLib.comment_fixture()
      assert Communication.list_comments() != []
    end

    test "get_comment!/1 returns the comment with given id" do
      comment = CommunicationTestLib.comment_fixture()
      assert Communication.get_comment!(comment.id) == comment
    end

    test "create_comment/1 with valid data creates a comment" do
      post = CommunicationTestLib.post_fixture()

      assert {:ok, %Comment{} = comment} =
               Communication.create_comment(Map.merge(@valid_attrs, %{"post_id" => post.id}))

      assert comment.content == "some content"
      assert comment.approved == true
    end

    test "create_comment/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Communication.create_comment(@invalid_attrs)
    end

    test "update_comment/2 with valid data updates the comment" do
      comment = CommunicationTestLib.comment_fixture()
      assert {:ok, %Comment{} = comment} = Communication.update_comment(comment, @update_attrs)
      assert comment.content == "some updated content"
      assert comment.approved == true
    end

    test "update_comment/2 with invalid data returns error changeset" do
      comment = CommunicationTestLib.comment_fixture()
      assert {:error, %Ecto.Changeset{}} = Communication.update_comment(comment, @invalid_attrs)
      assert comment == Communication.get_comment!(comment.id)
    end

    test "delete_comment/1 deletes the comment" do
      comment = CommunicationTestLib.comment_fixture()
      assert {:ok, %Comment{}} = Communication.delete_comment(comment)
      assert_raise Ecto.NoResultsError, fn -> Communication.get_comment!(comment.id) end
    end

    test "change_comment/1 returns a comment changeset" do
      comment = CommunicationTestLib.comment_fixture()
      assert %Ecto.Changeset{} = Communication.change_comment(comment)
    end
  end

  describe "categories" do
    alias Central.Communication.Category

    @valid_attrs %{"colour" => "some colour", "icon" => "far fa-home", "name" => "some name"}
    @update_attrs %{
      "colour" => "some updated colour",
      "icon" => "fas fa-wrench",
      "name" => "some updated name"
    }
    @invalid_attrs %{"colour" => nil, "icon" => nil, "name" => nil}

    test "list_categories/0 returns categories" do
      CommunicationTestLib.category_fixture()
      assert Communication.list_categories() != []
    end

    test "get_category!/1 returns the category with given id" do
      category = CommunicationTestLib.category_fixture()
      assert Communication.get_category!(category.id) == category
    end

    test "create_category/1 with valid data creates a category" do
      assert {:ok, %Category{} = category} = Communication.create_category(@valid_attrs)
      assert category.colour == "some colour"
      assert category.icon == "far fa-home"
      assert category.name == "some name"
    end

    test "create_category/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Communication.create_category(@invalid_attrs)
    end

    test "update_category/2 with valid data updates the category" do
      category = CommunicationTestLib.category_fixture()

      assert {:ok, %Category{} = category} =
               Communication.update_category(category, @update_attrs)

      assert category.colour == "some updated colour"
      assert category.icon == "fas fa-wrench"
      assert category.name == "some updated name"
    end

    test "update_category/2 with invalid data returns error changeset" do
      category = CommunicationTestLib.category_fixture()
      assert {:error, %Ecto.Changeset{}} = Communication.update_category(category, @invalid_attrs)
      assert category == Communication.get_category!(category.id)
    end

    test "delete_category/1 deletes the category" do
      category = CommunicationTestLib.category_fixture()
      assert {:ok, %Category{}} = Communication.delete_category(category)
      assert_raise Ecto.NoResultsError, fn -> Communication.get_category!(category.id) end
    end

    test "change_category/1 returns a category changeset" do
      category = CommunicationTestLib.category_fixture()
      assert %Ecto.Changeset{} = Communication.change_category(category)
    end
  end

  describe "blog_files" do
    alias Central.Communication.BlogFile

    @valid_attrs %{"url" => "some url", "name" => "some name"}
    @update_attrs %{"url" => "some updated url", "name" => "some updated name"}
    @invalid_attrs %{"url" => nil, "name" => nil}

    test "list_blog_files/0 returns blog_files" do
      CommunicationTestLib.blog_file_fixture()
      assert Communication.list_blog_files() != []
    end

    test "get_blog_file!/1 returns the blog_file with given id" do
      blog_file = CommunicationTestLib.blog_file_fixture()
      assert Communication.get_blog_file!(blog_file.id) == blog_file
    end

    test "create_blog_file/1 with valid data creates a blog_file" do
      assert {:ok, %BlogFile{} = blog_file} = Communication.create_blog_file(@valid_attrs)
      assert blog_file.url == "some url"
      assert blog_file.name == "some name"
    end

    test "create_blog_file/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Communication.create_blog_file(@invalid_attrs)
    end

    test "update_blog_file/2 with valid data updates the blog_file" do
      blog_file = CommunicationTestLib.blog_file_fixture()

      assert {:ok, %BlogFile{} = blog_file} =
               Communication.update_blog_file(blog_file, @update_attrs)

      assert blog_file.name == "some updated name"
    end

    test "update_blog_file/2 with invalid data returns error changeset" do
      blog_file = CommunicationTestLib.blog_file_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Communication.update_blog_file(blog_file, @invalid_attrs)

      assert blog_file == Communication.get_blog_file!(blog_file.id)
    end

    test "delete_blog_file/1 deletes the blog_file" do
      blog_file = CommunicationTestLib.blog_file_fixture()
      assert {:ok, %BlogFile{}} = Communication.delete_blog_file(blog_file)
      assert_raise Ecto.NoResultsError, fn -> Communication.get_blog_file!(blog_file.id) end
    end

    test "change_blog_file/1 returns a blog_file changeset" do
      blog_file = CommunicationTestLib.blog_file_fixture()
      assert %Ecto.Changeset{} = Communication.change_blog_file(blog_file)
    end
  end
end
