---
title: "Painless Phoenix Feature Tests"
date: 2016-08-13 09:00:00
categories: Elixir
tags: [Elixir, Phoenix, Testing]
---

Writing and maintaining feature tests can be very difficult, but they also provide an invaluable
measure of confidence that your application works as expected. By following a few best practices,
you can keep your feature test suite under control.

The following examples are all contained in this
[example phoenix application](github.com/rockwood/phoenix_feature_test_example). Checkout
[Concurrent Feature Tests with Phoenix and Hound](/2016/concurrent-feature-tests-with-phoenix/) for
instructions on setting up Hound in a Phoenix application.

**A note on terminology:** I use the term _feature test_ to mean an automated test that drives a
browser through the application. Some prefer the terms _end-to-end test_, _acceptance test_ or
_integration test_. For most purposes, these terms are used interchanably.

## Use Page Modules

Page modules offer the perfect abstraction between your test cases and your application's behavior.
They allow your tests to be clear an concise. To illustrate, let's take a simple test case for
creating a blog post. This is what our test might look like:

```elixir
describe "creating a new post" do
  test "succeeds with valid attributes" do
    post_attrs = %{title: "Test Title", body: "Test Body"}
    navigate_to "/posts/new"
    fill_field({:id, "title-field"}, post_attrs.title)
    fill_field({:id, "body-field"}, post_attrs.body)
    click({:class, "submit-button"})
    accept_dialog()
    assert Repo.one(Post)
  end
end
```

You'll notice that the test above has more to do with interacting with the DOM than with testing the
functionality we care about. If we think about what we're specifically trying to test, then there are
only three steps of importance here:

  1. Build a set of post attributes
  2. Submit the post attributes
  3. Assert that the post was saved

By introducing the concept of Page Modules, We can hide the DOM code and provide a clear API that
describes the functionality we need. Let's rewrite the above example with page modules:

```elixir
describe "creating a new post" do
  test "succeeds with valid attributes" do
    post_attrs = %{title: "Test Title", body: "Test Body"} # 1. Build a set of post attributes
    PostNewPage.submit(post_attrs)                         # 2. Submit the post attributes
    assert Repo.one(Post)                                  # 3. Assert that the post was saved
  end
end
```

The test that utilizes a page module is much easier to reason about because it hides most of the
details behind an explicit API.

In the above example, we introduced the page module `PostNewPage`. It looks like this:

```elixir
# test/support/pages/post_new_page.ex

defmodule Blog.PostNewPage do
  use Blog.Browser

  def submit(post_attrs) do
    visit
    Enum.each(post_attrs, &fill_form_field/1)
    submit_form
  end

  def visit do
    navigate_to("/posts/new")
  end

  def submit_form do
    click({:class, "qa-submit"})
    accept_dialog()
  end

  defp fill_form_field({:title, value}) do
    fill_field({:class, "qa-title-field"}, value)
  end
  defp fill_form_field({:body, value}) do
    fill_field({:class, "qa-body-field"}, value)
  end
end
```

Each page module uses `Blog.Browser` to include the hound API. This is also a great place to add
additional functions to simplify DOM interaction. It looks like this:

```elixir
# test/support/browser.ex

defmodule Blog.Browser do
  defmacro __using__(_) do
    quote do
      use Hound.Helpers
    end
  end
end
```

## Embrace Asynchronous Assertions

Sometimes the thing you're trying to assert on doesn't happen right away, especially if there's
Javascript involved. In the test above, the assertion `assert Repo.one(Post)` might fail because
the submission hasn't yet reached the database.

To make assertions more robust, we can make use of an `eventually` helper function. It takes a
function and simply calls it repeatedly until the assertions pass. If the assertions don't pass in
the allotted time, the test fails.

```elixir

defmodule AsyncHelpers do
  @default_timeout 2_000
  @interval 50

  def eventually(func), do: eventually(func, @default_timeout)
  def eventually(func, 0), do: func.()
  def eventually(func, timeout) do
    try do
      func.()
    rescue
      _ ->
        Process.sleep(@interval)
        eventually(func, max(0, timeout - @interval))
    end
  end
end
```

Import `AsyncHelpers` into your case file and use it like this:

```elixir
eventually fn ->
  assert Repo.one(Post)
end
```

## Prefer More Focused Tests

The key to keeping your feature tests under control is to keep them focused. It can be tempting to
want your tests to drive through large parts of your application at once. It's much easier to
maintain your feature tests over time if they're small and only test one piece of functionality. Use
setup blocks to perform any complex setup, and only test one action at a time.

## Stick With It

Imagine having the confidence to make major changes to your application and never feel the need to
click though and make sure you didn't break anything. That's the confidence that a well-built
feature test suite can provide. Feature testing can often be a frustrating process, and yes, it will
slow down your development speed at first. However, spending the time up front will pay dividends in
the long run.
