---
title: "Soft-Delete Pattern In Postgres"
date: 2018-07-08 09:00:00
categories: Postgresql
tags: [SQL]
---

You're building a application on a Postgres database. At some point, you'll be faced with the
question:

> How do I allow my users to delete records while maintaining historical data?

The most widely recommended solutions to this problem often involve adding some form of an
`is_deleted` column, and each query filters out rows where `is_deleted = true`. There are a number
of reasons why I don't prefer this method, most of which are detailed in the excellent post:
[Soft-deletes are bad, m'kay?](https://weblogs.asp.net/fbouma/soft-deletes-are-bad-m-kay). So, if
not an `is_deleted` column, then what?

After trying a number of alternatives, I finally settled on a solution that I think provides the
most clarity and flexibility.

### Setup

Let's start with a simple example: a `posts` table:

```sql
CREATE TABLE posts(
   id SERIAL PRIMARY KEY NOT NULL,
   title VARCHAR(256) NOT NULL,
   body TEXT NOT NULL
);
```

Then, we'll create an additional `posts` table under a new `deleted` schema:

```sql
CREATE SCHEMA deleted;
CREATE TABLE deleted.posts (
  deleted_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW(),
  LIKE posts INCLUDING ALL
);
```

The `LIKE` clause copies all column definitions of the original table to the newly created
table. We've also added a `deleted_at` column to track when posts are deleted. Keep in mind that the
`LIKE` clause will not copy any foreign key constraints or triggers.

Finally, we'll create a view to query records from both `posts` and `deleted.posts` tables. We'll
also keep this under a separate schema called `combined`.

```sql
CREATE SCHEMA combined;
CREATE VIEW combined.posts AS
  SELECT null AS deleted_at, * FROM posts
  UNION ALL
  SELECT * FROM deleted.posts;
```

### Usage

Let's add two rows to our `posts` table. 

```
SELECT * FROM posts;

 id |     title      |        body
----+----------------+---------------------
  1 | My First Post  | Yay, my first post!
  2 | My Second Post | Woot, on a roll!
```

Deleting a post is as simple as copying the row from the `posts` table to the `deleted_posts` table
and then deleting the original:

```sql
INSERT INTO deleted.posts 
  SELECT NOW() AS deleted_at, * FROM posts
  WHERE posts.id = 2;
  
DELETE FROM posts
  WHERE posts.id = 2;
```

The `posts` table now contains only the single active post:

```
SELECT * FROM posts;

 id |     title      |        body
----+----------------+---------------------
  1 | My First Post  | Yay, my first post!
```

And the `deleted_posts` table now contains the deleted post:

```
SELECT * FROM deleted.posts;

     deleted_at      | id |     title       |        body
---------------------+----+-----------------+---------------------
 2018-01-01 00:00:00 |  2 | My Second Post  | Woot, on a roll!
```
 
Queries that require both active and deleted posts simply select from the `combined_posts` view.

```
 SELECT * FROM combined.posts

     deleted_at      | id |     title      |        body
---------------------+----+----------------+---------------------
                     |  1 | My First Post  | Yay, my first post!
 2018-01-01 00:00:00 |  2 | My Second Post | Woot, on a roll!
```

The main benefit of using separate schemas comes when you want to reuse your existing join queries
across both active and deleted records. Since the table names are all identical, you just need to
switch name of the schema your operating on.

For [Ecto](https://github.com/elixir-ecto/ecto) users, it's as simple as adding the `prefix` option:

```elixir
Repo.all(some_complex_join_query, prefix: "combined")
```

### Caveats

The main thing to keep in mind is that changes to columns on the `posts` table need to also be made
to the `deleted.posts` table. And in most cases, it will also require dropping and re-created the
`combined.posts` view. This can be a bit of a pain.

When creating your `deleted` tables, make sure to list the `deleted_at` column first. Otherwise,
the column names wont align when you decide to add new columns in the future.

Any sufficiently complex application will likely involve deleting multiple related records
simultaneously (ie: deleting a post will also need to delete comments, categories, ect.), so it's
important to keep all that logic well encapsulated.

### Conclusion

There are many ways to solve the soft-delete problem. While the solution outlined here certainly
involves more setup time, I think it's ultimatly the most maintainable one I've seen. Please let me
know in the comments if you've had better luck with other options.
