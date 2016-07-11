---
title: "Concurrent Feature Tests with Phoenix and Hound"
date: 2016-07-11 09:00:00
categories: [Elixir, Phoenix, Testing]
---

With the release of Phoenix 1.2 and Ecto 2.0, we now have the ability run automated browser tests
concurrently, even ones that that hit the database!

We'll be using [Hound](https://github.com/HashNuke/hound) for this example, but the setup should be
similar for any automated browser tool.

## Step 1: Install Hound

Follow the [Hound setup instructions](https://hexdocs.pm/hound/readme.html#Setup)

## Step 2: Install a driver

The driver determines what browser Hound will interact with during tests.

Here, we'll be using [Selenium](http://www.seleniumhq.org/) to drive Firefox. Other drivers are also
available such including [chromedriver](https://sites.google.com/a/chromium.org/chromedriver/) and
[phantomjs](http://phantomjs.org/). See the [Hound readme](https://hexdocs.pm/hound/readme.html)
for details.

First, install the driver. Here, I'm using homebrew

```sh
> brew install selenium-server-standalone
```

Then, start the selenium-server daemon. Hound doesn't start webdriver servers itself, so you'll need
to manage that. Selenium installed via homebrew registers itself as a service.

```sh
> brew services start selenium-server-standalone
```

Configure Hound to use your driver.

```elixir
# config/test.exs

config :hound, driver: "selenium", browser: "firefox"
```

## Step 3: Turn On the Test Server

This starts up our phoenix endpoint during test runs.

```elixir
# config/test.exs

config :your_app, YourApp.Endpoint,
  server: true
```

## Step 4: Add the Ecto Sandbox Plug

[phoenix_ecto](https://github.com/phoenixframework/phoenix_ecto)) ships with a plug to dynamically
switch database transactions for each request, allowing multiple browsers to talk to the same
database concurrently.

First, set a flag to enable the sandbox plug in your test config:

```elixir
# config/test.exs

config :your_app, sql_sandbox: true
```

Then use the flag to conditionally add add it your endpoint during acceptance tests.

**IMPORTANT:** The order of plugs matters, and this one must be listed before any others.

```elixir
# lib/your_app/endpoint.ex

defmodule YourApp.Endpoint do
  use Phoenix.Endpoint, otp_app: :your_app

  if Application.get_env(:your_app, :sql_sandbox) do
    plug Phoenix.Ecto.SQL.Sandbox
  end

  # ...more plugs
end
```

## Step 4: Define a FeatureCase

We need to define an ExUnit case file to be used by each feature test.

For concurrent tests, ones with `async: true`, we need to checkout a
sandboxed database connection and pass it to Hound.

```elixir
# test/support/feature_case.ex

defmodule YourApp.FeatureCase do
  use ExUnit.CaseTemplate

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(YourApp.Repo)

    if tags[:async] do
      metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(YourApp.Repo, self())
      Hound.start_session(metadata: metadata)
    else
      Hound.start_session
      Ecto.Adapters.SQL.Sandbox.mode(YourApp.Repo, {:shared, self()})
    end

    :ok
  end
end
```

## Step 5: Try It

Create some async feature tests modules (I put them in `test/features`) with
`use YourApp.FeatureCase, async: true`. Each test module will run in a separate browser instance.
That's pretty cool!

By default, hound sets the number of concurrently running browsers to the number of schedulers
initialized by the Erlang VM (usually one per core).

## Further Reading

There's a lot going on under the covers here. If you're interested in learning more, I recommend
checking out the following:

  * Ecto 2.0 [Beta](http://blog.plataformatec.com.br/2016/02/ecto-2-0-0-beta-0-is-out/)
  and [RC](http://blog.plataformatec.com.br/2016/04/ecto-2-0-0-rc-is-out/) Posts
  * [Phoenix Ecto](https://github.com/phoenixframework/phoenix_ecto)
  * [Ecto Sandbox Adapter](https://hexdocs.pm/ecto/Ecto.Adapters.SQL.Sandbox.html)
  * [DB Connection](https://hexdocs.pm/db_connection/DBConnection.html)

**A note on terminology:** I use the term _feature tests_ to mean an automated test that drives a
browser through the application. Some prefer the term _end-to-end tests_, _acceptance tests_ or
_integration tests_. For most people, these terms are used interchanably.
