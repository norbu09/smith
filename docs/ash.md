# Onboarding to Ash Framework: Building Declarative Elixir Applications

Welcome to the team, Junior Developer! I'm thrilled to have you here. You're stepping into an exciting world with Ash Framework, a tool that has fundamentally reshaped how we approach software development. Forget everything you thought you knew about traditional web frameworks; Ash is something different, and it's incredibly powerful.

My goal with this document is to give you a deep, practical understanding of Ash Framework's core concepts, how it integrates with the broader Elixir ecosystem, and how we leverage it, even for cutting-edge areas like AI. I'll pass on my insights on declarative coding, showing you *why* Ash is so effective, not just *what* it does. Let's dive in!

---

## 1. The Ash Philosophy: Model Your Domain, Derive the Rest

At its heart, Ash is an **application framework**, not just a web framework. Its tagline, "Model your domain, derive the rest," succinctly captures its essence. This means we focus on defining the "what" of our application's business logic and data, and Ash handles the "how".

Think of it like this: in traditional development, you might describe your data, then manually write code for interacting with databases, creating API endpoints, building UI forms, handling authentication, and more. With Ash, you describe your core domain model once, and Ash can automatically generate many of these components for you.

This approach is rooted in three fundamental principles of declarative design:

*   **Data > Code:** We model our application components using Ash's Domain Specific Language (DSL), which compiles into introspectible data structures. This "application-as-data" approach allows Ash to understand your domain deeply and generate wildly useful things with little effort. It helps reduce "sprawl and spaghetti" code.
*   **Derive > Hand-write:** Instead of manually writing multiple layers (e.g., controllers, serializers, OpenAPI schemas for a JSON API, then repeating for GraphQL), Ash derives these directly from your single source of truth: your resource definitions. This drastically cuts down on boilerplate, prevents functionality drift between layers, and reduces conceptual overhead.
*   **What > How:** Like HTML or SQL, you tell Ash *what* you want to achieve, not *how* to achieve it. Ash interprets your declarative descriptions and makes it happen. This might feel like magic at first, but it's simply declarative design taken to its logical conclusion.

By embracing this philosophy, we achieve cleaner, more maintainable, and scalable software. It means we spend more time on unique business logic and less on repetitive plumbing.

---

## 2. Core Building Blocks: Resources, Domains, and Data

The "Tunez" application we'll be building (a music database similar to Spotify) is a great way to understand these concepts hands-on.

### 2.1. Resources: The Nouns of Your Application

**Resources** are the central concept in Ash. They represent your domain model objects—the "nouns" your application revolves around, like `Artist`, `Album`, or `Track`. A resource typically contains some kind of data and defines the actions that can be taken on that data.

Here's how we'd generate an `Artist` resource:

```elixir
# In your terminal
mix ash.gen.resource Tunez.Music.Artist --extend postgres
```

This command automatically generates the resource module and includes it in its domain. A basic generated resource might look like this:

```elixir
# lib/tunez/music/artist.ex
defmodule Tunez.Music.Artist do
  use Ash.Resource, otp_app: :tunez, domain: Tunez.Music, data_layer: AshPostgres.DataLayer

  postgres do
    table "artists"
    repo Tunez.Repo
  end
end
```

### 2.2. Domains: Context Boundaries

**Domains** serve as "context boundaries" that group related resources. For example, `Tunez.Music` groups music-related resources like `Artist`, `Album`, and `Track`, while `Tunez.Accounts` handles `User` and `Notification`. Domains also define shared configuration and functionality, and are where we expose interfaces for the rest of the application to interact with the domain model, much like Phoenix contexts.

When you generate a resource, Ash automatically includes it in a new or existing domain module. The domain module looks something like this:

```elixir
# lib/tunez/music.ex
defmodule Tunez.Music do
  use Ash.Domain, otp_app: :tunez, extensions: [AshPhoenix]

  resources do
    resource Tunez.Music.Artist do
      # ... resource specific definitions here ...
    end

    resource Tunez.Music.Album do
      # ...
    end
  end
end
```

While technically possible to put all resources in a single domain, we generally recommend using multiple domains to clearly separate closely-related resources and manage complexity.

### 2.3. Attributes: Defining Your Data

**Attributes** define the fields (or columns, when using a database) for your resource. Ash provides macros for common attribute types (`:string`, `:integer`, `:uuid`, etc.), and you can configure options like `allow_nil?`.

Here's how you'd add attributes to the `Artist` resource:

```elixir
# lib/tunez/music/artist.ex
defmodule Tunez.Music.Artist do
  use Ash.Resource, otp_app: :tunez, domain: Tunez.Music, data_layer: AshPostgres.DataLayer

  postgres do
    table "artists"
    repo Tunez.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string do
      allow_nil? false
    end
    attribute :biography, :string
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
```

### 2.4. Data Layers & Migrations

Ash supports various **data layers** for persistence, with `AshPostgres.DataLayer` being our primary choice for PostgreSQL.

Once you define your resources and their attributes, you need to generate database migrations to bring your schema to life. Ash provides `mix ash.codegen` for this, embodying the "model your domain, derive the rest" philosophy:

```elixir
# In your terminal, after defining the Artist resource with attributes
mix ash.codegen create_artists
```

This task:
*   Creates **snapshots** of your current resource definitions (JSON files in `priv/resource_snapshots/`).
*   Compares them to previous snapshots.
*   Generates **deltas** as new Ecto migrations (e.g., `priv/repo/migrations/[timestamp]_create_artists.ex`).

This process ensures your database schema stays in sync with your resource definitions without manual boilerplate. After generating, you run the migration:

```elixir
# In your terminal
mix ash.migrate
```

This command runs all pending Ash-generated migrations, setting up your database tables.

---

## 3. Actions: The Verbs of Your Application

**Actions** define "what can be done with a resource and its data". They are the "verbs" to a resource's "nouns".

### 3.1. Basic Action Types (CRUD)

The four basic types of actions are `create`, `read`, `update`, and `destroy` (CRUD). Ash also supports **generic actions** for operations that don't fit these categories.

Here's how to define basic actions for `Artist`:

```elixir
# lib/tunez/music/artist.ex (inside the resource module)
actions do
  # Create action
  create :create do
    accept [:name, :biography] # Specify which attributes this action accepts
  end

  # Read action (marked as primary, for default usage)
  read :read do
    primary? true
  end

  # Update action
  update :update do
    accept [:name, :biography]
  end

  # Destroy action
  destroy :destroy do
    # No attributes to accept, just identifies the record to delete
  end
end
```

For common CRUD actions that don't require custom logic, you can use the `defaults` macro to avoid boilerplate:

```elixir
# lib/tunez/music/artist.ex (simplified actions block)
actions do
  defaults [:create, :read, :update, :destroy] # Generates all four default CRUD actions
  default_accept [:name, :biography] # Sets default accepted attributes for create/update
end
```

### 3.2. Running Actions: Changesets vs. Code Interfaces

You interact with Ash actions in two primary ways:

#### 3.2.1. Changesets (the "lower-level" way)

Similar to Ecto changesets, you create a changeset for a specific action and then `Ash.create()`, `Ash.read()`, `Ash.update()`, or `Ash.destroy()` it.

```elixir
iex> Ash.Changeset.for_create(Tunez.Music.Artist, :create, %{
...>   name: "Valkyrie's Fury",
...>   biography: "A power metal band hailing from Tallinn, Estonia"
...> })
...> |> Ash.create!() # Use ! version for immediate error raising

{:ok, #Tunez.Music.Artist<...>}

iex> Tunez.Music.Artist
...> |> Ash.Query.for_read(:read) # Build a read query
...> |> Ash.Query.sort(name: :asc) # Add sorting
...> |> Ash.Query.limit(1) # Add limiting
...> |> Ash.read!() # Execute the query
{:ok, [#Tunez.Music.Artist<...>]}
```

If you provide invalid data, Ash will return an error.

#### 3.2.2. Code Interfaces (the "idiomatic" way)

Code interfaces expose your Ash actions as regular Elixir functions on your domain module, making them much easier and more readable to call.

To define them, use the `define` macro in your domain:

```elixir
# lib/tunez/music.ex (inside the resource block for Tunez.Music.Artist)
resources do
  resource Tunez.Music.Artist do
    define :create_artist, action: :create
    define :read_artists, action: :read
    define :get_artist_by_id, action: :read, get_by: :id # To read a single record by primary key
    define :update_artist, action: :update
    define :destroy_artist, action: :destroy
  end
end
```

Now you can call these functions directly:

```elixir
iex> Tunez.Music.create_artist!(%{
...>   name: "Valkyrie's Fury",
...>   biography: "A power metal band hailing from Tallinn, Estonia"
...> })
{:ok, #Tunez.Music.Artist<...>}

iex> Tunez.Music.read_artists!()
{:ok, [#Tunez.Music.Artist<...>, ...]}

iex> artist = Tunez.Music.get_artist_by_id!("your-artist-uuid")
#Tunez.Music.Artist<...>
```

While code interfaces abstract away the changeset, they still use them internally. Code interfaces are generally preferred for their readability and ease of use in application code.

---

## 4. Relationships: Connecting Your Nouns

Applications rarely deal with isolated pieces of data. **Relationships** (or associations) describe connections between resources.

Ash supports several types of relationships:

*   **`has_many`**: One resource relates to many others (e.g., an `Artist` `has_many` `Albums`).
*   **`belongs_to`**: One resource belongs to a single parent (e.g., an `Album` `belongs_to` an `Artist`).
*   **`has_one`**: One resource relates to one other, with the related resource holding the reference.
*   **`many_to_many`**: Many resources relate to many others, typically via a **join resource** (e.g., a `User` can `follow` many `Artists`, and an `Artist` can have many `Followers`, linked by an `ArtistFollower` join resource).

Here's how we define a `belongs_to` relationship on `Album` and a `has_many` on `Artist`:

```elixir
# lib/tunez/music/artist.ex
defmodule Tunez.Music.Artist do
  # ...
  relationships do
    has_many :albums, Tunez.Music.Album # An Artist has many Albums
  end
end

# lib/tunez/music/album.ex
defmodule Tunez.Music.Album do
  # ...
  relationships do
    belongs_to :artist, Tunez.Music.Artist do # An Album belongs to an Artist
      allow_nil? false
    end
  end

  # ... also, specify the foreign key index for Postgres for efficiency
  postgres do
    # ...
    references do
      reference :artist, index?: true
    end
  end
end
```

Remember to `mix ash.codegen` and `mix ash.migrate` after defining new relationships to update your database schema.

### 4.1. Loading Related Data (`load` option)

When reading a resource, you can efficiently load its related data using the `load` option, similar to Ecto's `preload`.

```elixir
iex> Tunez.Music.get_artist_by_id!("your-artist-uuid", load: [:albums])
#Tunez.Music.Artist<
  albums: [#Tunez.Music.Album<...>, ...],
  ...
>

# You can even nest loads
iex> Tunez.Music.get_artist_by_id!("your-artist-uuid", load: [albums: [:tracks]])
#Tunez.Music.Artist<
  albums: [#Tunez.Music.Album<tracks: [...], ...>, ...],
  ...
>
```

### 4.2. Managing Relationships (`manage_relationship` change)

When working with forms that update related data (like tracks within an album), Ash provides the powerful `manage_relationship` change. It handles the creation, updating, and deletion of related records based on the data provided in the parent resource's action.

```elixir
# lib/tunez/music/album.ex (within update action)
update :update do
  accept [:name, :year_released, :cover_image_url] # Album attributes
  argument :tracks, {:array, :map} # Argument for nested track data
  # This change processes the `tracks` argument and manages the relationship
  change manage_relationship(:tracks, type: :direct_control, bypass_manual_accept?: true)
  # When managing relationships with updates, it often requires disabling atomic updates for now
  require_atomic? false
end
```

### 4.3. Cascading Deletes

You need to decide what happens to related records when a parent record is deleted. Ash offers two main approaches:

*   **Database-level `ON DELETE`**: Configured in the `postgres` block, this is the most efficient way as the database handles the deletion (`on_delete: :delete`). Use this when no application-level business logic is needed during deletion.

    ```elixir
    # lib/tunez/accounts/notification.ex (for example)
    postgres do
      # ...
      references do
        reference :user, index?: true, on_delete: :delete
        reference :album, on_delete: :delete
      end
    end
    ```

*   **Ash's `cascade_destroy` change**: This is an Ash change that calls a bulk destroy action on related resources. Use this when you *need* to run application-level business logic (e.g., sending PubSub messages) during the deletion of related records.

    ```elixir
    # lib/tunez/music/album.ex (within destroy action)
    destroy :destroy do
      primary? true
      # This will destroy related notifications, and we request notifications back for PubSub
      change cascade_destroy(:notifications, return_notifications?: true, after_action?: false)
    end
    ```
    Note `after_action?: false` means it runs before the album itself is deleted.

---

## 5. Enhancing Your Domain: Validations, Identities, Calculations, and Changes

These features allow you to embed complex business logic and derived data directly into your domain model.

### 5.1. Validations: Ensuring Data Integrity

**Validations** define rules for data integrity and are checked before an action is run. Ash provides many built-in validations (`numericality`, `match`, etc.). They can be applied globally to a resource or to individual actions.

```elixir
# lib/tunez/music/album.ex
defmodule Tunez.Music.Album do
  # ...
  attributes do
    # ...
    attribute :name, :string do
      allow_nil? false # Implicit validation: name must be present
    end
    attribute :year_released, :integer do
      allow_nil? false
    end
  end

  validations do
    validate numericality(:year_released,
               greater_than: 1950,
               less_than_or_equal_to: &__MODULE__.next_year/0
             ),
             where: [present(:year_released)],
             message: "must be between 1950 and next year"
  end

  def next_year, do: Date.utc_today().year + 1
end
```

### 5.2. Identities: Unique Record Identification

An **identity** is an attribute or combination of attributes that can uniquely identify a record. While a primary key is an automatic identity, you can define custom identities for business-level uniqueness. AshPostgres implements these as unique indexes at the database level.

```elixir
# lib/tunez/music/album.ex
defmodule Tunez.Music.Album do
  # ...
  identities do
    # Ensure album name is unique per artist
    identity :unique_album_names_per_artist, [:name, :artist_id],
      message: "already exists for this artist"
  end
end
```

### 5.3. Calculations & Aggregates: Derived Data

**Calculations** are "virtual fields" that are computed on-demand from other information, not stored directly in your database. They can use data from related resources, external sources, or existing attributes. Ash allows calculations to have both an Elixir (code) and a database (expression) implementation, optimizing for efficiency.

**Aggregates** are a special type of calculation specifically for deriving values from *related* records (e.g., `count`, `sum`, `first`). They often result in efficient single SQL queries, avoiding N+1 issues.

Examples:

```elixir
# lib/tunez/music/artist.ex
defmodule Tunez.Music.Artist do
  # ...
  calculations do
    calculate :followed_by_me, :boolean, expr(exists(follower_relationships, follower_id == ^actor(:id)))
    # You can also define code interfaces for calculations
    # define_calculation :artist_name_length, calculation: :name_length, args: [{:ref, :name}]
  end

  aggregates do
    # Count of albums for an artist
    count :album_count, :albums do
      public? true # Make it visible in APIs/sorting
    end
    # Latest album release year
    first :latest_album_year_released, :albums, :year_released do
      public? true
    end
  end
end

# lib/tunez/music/track.ex
defmodule Tunez.Music.Track do
  # ...
  calculations do
    calculate :number, :integer, expr(order + 1) # A 1-indexed track number
    # Complex calculation using a separate module for Elixir logic or database fragment
    calculate :duration, :string, Tunez.Music.Calculations.SecondsToMinutes do
      public? true
    end
  end
end

# lib/tunez/music/calculations/seconds_to_minutes.ex
defmodule Tunez.Music.Calculations.SecondsToMinutes do
  use Ash.Resource.Calculation
  @impl true
  def calculate(tracks, _opts, _context) do
    Enum.map(tracks, fn %{duration_seconds: duration} ->
      seconds = rem(duration, 60) |> Integer.to_string() |> String.pad_leading(2, "0")
      "#{div(duration, 60)}:#{seconds}"
    end)
  end
  # Example of a database-optimized expression for this calculation (uses PostgreSQL specific functions)
  # @impl true
  # def expression(_opts) do
  #   expr(fragment("(?:bigint / 60 || to_char(?:bigint * interval '1s', ':SS'))", duration_seconds, duration_seconds))
  # end
end
```

When retrieving data, you explicitly request calculations and aggregates using the `load` option:

```elixir
iex> Tunez.Music.search_artists!("some query", load: [:album_count, :latest_album_year_released])
# Returns artists with these derived fields
```

### 5.4. Preparations & Changes: Modifying Data

**Preparations** define logic that runs *before* a read action, typically to load related data or calculations by default.

**Changes** define logic to apply to a changeset *before* an action is executed. They are used for data transformations, custom validations, or side effects. Changes can be inline anonymous functions or extracted into dedicated change modules.

Ash provides built-in changes (e.g., `set_attribute`, `relate_actor`). You can also implement `after_action` or `before_action` hooks within changes for logic that should run only once per action, particularly useful for side effects like sending notifications.

```elixir
# lib/tunez/music/artist.ex (example of an inline change in an update action)
update :update do
  accept [:name, :biography]
  change fn changeset, _context ->
    if Ash.Changeset.changing_attribute?(changeset, :name) do
      new_name = Ash.Changeset.get_attribute(changeset, :name)
      # Append new name to previous_names list
      Ash.Changeset.change_attribute(changeset, :previous_names, [new_name] ++ Ash.Changeset.get_attribute(changeset, :previous_names))
    else
      changeset
    end
  end
  require_atomic? false # Required if Ash can't push changes to DB atomically
end

# lib/tunez/music/album.ex (resource-level change for created_by/updated_by)
changes do
  # Automatically sets 'created_by' to the actor on create actions
  change relate_actor(:created_by, allow_nil?: true), on: [:create]
  # Automatically sets 'updated_by' to the actor on all create/update actions (default)
  change relate_actor(:updated_by, allow_nil?: true)
end
```

### 5.5. Atomic Updates

**Atomic updates** ensure that changes to resource attributes are applied directly and safely at the data layer (database) level, preventing race conditions in concurrent operations. Ash tries to be atomic by default.

If a change's logic cannot be translated into an atomic database operation (e.g., complex Elixir logic, `manage_relationship`), you must explicitly set `require_atomic? false` on the action. For changes that *can* be atomic but aren't by default (like incrementing a counter), Ash provides `atomic_update`.

```elixir
# Example of an atomic update
update :follow do
  change atomic_update(:follower_count, expr(follower_count + 1))
end
```

---

## 6. Building Interfaces with Ash Extensions

Ash's "derive the rest" philosophy truly shines when building interfaces.

### 6.1. AshPhoenix: Web UI Integration

`AshPhoenix` is a core library that complements Phoenix (especially LiveView) to make working with Ash in web applications seamless.

Key features:

*   **`AshPhoenix.Form`**: This wraps an `Ash.Changeset` and acts as a drop-in replacement for Ecto.Changesets, allowing Phoenix's existing form helpers to work perfectly with Ash.
*   **Domain Extensions**: `AshPhoenix` adds functions to your domain (e.g., `Tunez.Music.form_to_create_album`) for consistent form generation.
*   **Nested Forms**: `AshPhoenix` simplifies handling complex nested forms, like tracks within an album, by integrating with Phoenix's `inputs_for` component and `manage_relationship`.

```elixir
# lib/tunez_web/live/albums/form_live.ex (example of form handling)
def mount(params, _session, socket) do
  # ... determine if creating new or editing existing album ...
  form =
    if album_id do
      # For updating an existing album
      album = Tunez.Music.get_album_by_id!(album_id, load: [:artist, :tracks])
      Tunez.Music.form_to_update_album(album, actor: socket.assigns.current_user)
    else
      # For creating a new album
      artist_id = Map.fetch!(params, "artist_id")
      Tunez.Music.form_to_create_album(artist_id, actor: socket.assigns.current_user)
    end
    |> AshPhoenix.Form.ensure_can_submit!() # Ensures the form can be submitted based on policies

  {:ok, assign(socket, form: to_form(form), ...)}
end

def handle_event("validate", %{"form" => form_data}, socket) do
  socket = update(socket, :form, fn form ->
    AshPhoenix.Form.validate(form, form_data)
  end)
  {:noreply, socket}
end

def handle_event("save", %{"form" => form_data}, socket) do
  case AshPhoenix.Form.submit(socket.assigns.form, params: form_data) do
    {:ok, album} ->
      # Handle success, e.g., redirect
      {:noreply, push_navigate(socket, to: ~p"/artists/#{album.artist_id}")}
    {:error, form} ->
      # Handle errors, re-assign form with errors
      {:noreply, assign(socket, form: form)}
  end
end
```

### 6.2. API Generation: AshJsonApi & AshGraphql

Ash can automatically generate full REST JSON:API and GraphQL APIs from your existing resource and action definitions.

#### 6.2.1. AshJsonApi (REST JSON:API)

Provides full JSON:API compliant endpoints and can generate OpenAPI schemas for documentation.

```elixir
# Install:
mix igniter.install ash_json_api

# Expose a resource to the API:
mix ash.extend Tunez.Music.Artist json_api

# Define routes in your domain (lib/tunez/music.ex):
json_api do
  routes do
    base_route "/artists", Tunez.Music.Artist do
      get :read # /api/json/artists/:id
      index :search # /api/json/artists (list/search)
      post :create # /api/json/artists
      patch :update # /api/json/artists/:id
      delete :destroy # /api/json/artists/:id
    end
  end
end
```

**Key Points:**
*   Only attributes explicitly marked `public? true` are returned by default for security.
*   Aggregates/calculations and relationships also need `public? true` and/or explicit `includes` for API exposure.
*   OpenAPI documentation is automatically generated and can be viewed via Swagger UI (`/api/json/swaggerui`).
*   You can customize API titles, versions, and descriptions.

#### 6.2.2. AshGraphql (GraphQL)

Built on Absinthe, this provides a powerful GraphQL endpoint with auto-generated types and fields.

```elixir
# Install:
mix igniter.install ash_graphql

# Expose a resource to GraphQL:
mix ash.extend Tunez.Music.Artist graphql

# Define queries and mutations in your domain (lib/tunez/music.ex):
graphql do
  queries do
    get Tunez.Music.Artist, :get_artist_by_id, :read # Maps to getArtistById query
    list Tunez.Music.Artist, :search_artists, :search # Maps to searchArtists query
  end

  mutations do
    create Tunez.Music.Artist, :create_artist, :create
    update Tunez.Music.Artist, :update_artist, :update
    destroy Tunez.Music.Artist, :destroy_artist, :destroy
  end
end
```

**Key Points:**
*   Similar to JSON:API, attributes, calculations, and relationships need `public? true` to be exposed in the GraphQL schema.
*   GraphQL Mutations naturally return data wrapped in `result` and `metadata` fields.
*   Queries that return metadata (like auth tokens) might require a `type_name` to define a new GraphQL type that includes the metadata.
*   `identity false` can be used on `get` queries if you don't want to query by primary key.
*   GraphQL also offers powerful filtering and sorting directly via the API, which you can disable if you prefer custom logic (`derive_filter? false`, `derive_sort? false`).

---

## 7. Security: Authentication & Authorization

Security is paramount. Ash provides robust extensions for this.

### 7.1. AshAuthentication: Knowing Who Your Users Are

`AshAuthentication` is a pre-built extension for handling user authentication. It generates user and token resources within a dedicated domain (e.g., `Tunez.Accounts`).

```elixir
# Install:
mix igniter.install ash_authentication

# Add a password strategy (generates user attributes like email, hashed_password):
mix ash_authentication.add_strategy password

# You can also add other strategies like magic_link:
mix ash_authentication.add_strategy magic_link
```

`AshAuthentication` uses JSON Web Tokens (JWTs) for session management, which are cryptographically signed to prevent tampering. You can inspect and verify these tokens.

For debugging authentication failures during development, you can enable verbose logging:

```elixir
# config/dev.exs
config :ash_authentication, debug_authentication_failures?: true
```

### 7.2. AshAuthenticationPhoenix: Web UI for Authentication

This library integrates `AshAuthentication` with Phoenix LiveView, providing automatic UI components for registration, sign-in, and password resets.

```elixir
# Install:
mix igniter.install ash_authentication_phoenix
```

**Key Points:**
*   You'll need to update your Tailwind CSS configuration to include `AshAuthenticationPhoenix` paths.
*   LiveView routes that need access to the current user must be wrapped in `ash_authentication_live_session` in your router. This ensures the LiveView process has access to session data.
*   You can customize the look and feel of the generated LiveViews using UI overrides in `TunezWeb.AuthOverrides`.

### 7.3. Policies: What Can Users Do?

**Policies** define "who has access to resources within our app, and what actions they can run". They are checked internally by Ash *before* any action is run. If policies fail, the action is not executed, and an error is returned.

Policies are defined within a resource's `policies` block, requiring the `Ash.Policy.Authorizer` extension. They consist of `policy` or `bypass` blocks, with conditions like `action`, `action_type`, `authorize_if`, and `forbid_if`.

```elixir
# lib/tunez/music/artist.ex
defmodule Tunez.Music.Artist do
  use Ash.Resource, otp_app: :tunez, domain: Tunez.Music,
    data_layer: AshPostgres.DataLayer, extensions: [AshGraphql.Resource, AshJsonApi.Resource],
    authorizers: [Ash.Policy.Authorizer] # Enable policy authorizer

  policies do
    # This policy applies to calls from AshAuthenticationPhoenix's LiveViews and always authorizes
    # This allows auth forms to work out-of-the-box
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    # Policy for create action: only admins can create artists
    policy action(:create) do
      authorize_if actor_attribute_equals(:role, :admin)
    end

    # Policy for read/search actions: all users (even unauthenticated) can read artists
    policy action_type(:read) do
      authorize_if always()
    end

    # Policy for update/destroy actions:
    # Admins can do anything, Editors can only update/destroy albums they created
    policy action_type([:update, :destroy]) do
      authorize_if expr(^actor(:role) == :admin) # Admin can update/destroy anything
      authorize_if expr(^actor(:role) == :editor and created_by_id == ^actor(:id)) # Editor can update/destroy their own records
    end
  end
end
```

**Key Points:**
*   Policies are checked automatically on *all* action calls (web UI, APIs, IEx).
*   The `actor` (the entity performing the action, usually a user) is central to policy checks.
*   `Ash.Policy.Authorizer` defaults to forbidding access if no policies apply or pass, providing secure-by-default behavior.
*   **Debugging Policies**: Enable `show_policy_breakdowns?: true` in `config/dev.exs` to see detailed explanations of why policies pass or fail.
*   **Filtering Read Actions**: Policies for read actions act as filters, determining which records an actor is allowed to see.

#### 7.3.1. UI Integration with Policies

*   **Passing the `actor`**: Always pass `socket.assigns.current_user` (or `nil` if unauthenticated) as the `actor` option to your Ash action calls in LiveViews.
*   **`AshPhoenix.Form.ensure_can_submit!`**: For forms, this helper raises an exception if the current `actor` isn't authorized to submit the form's underlying action.
*   **Page-level Authorization (`on_mount`)**: Use `TunezWeb.LiveUserAuth`'s `on_mount` callbacks to prevent unauthorized users from even accessing certain LiveView pages.
*   **Hiding UI Elements (`Ash.can?` / `can_*?`)**: Use `Ash.can?` (low-level check) or the more convenient `can_*?` functions (dynamically generated per code interface) to conditionally render buttons or links based on the `actor`'s permissions.

    ```elixir
    # In a LiveView template
    <.button_link navigate={~p"/artists/new"} kind="primary"
      :if={Tunez.Music.can_create_artist?(@current_user)}>
      New Artist
    </.button_link>
    ```

---

## 8. Advanced Features & Integrations

### 8.1. Testing Ash Applications

Automated testing is crucial for maintaining code quality and preventing regressions. While Ash provides many features, it's still essential to test your application's unique logic thoroughly.

**Key Principle**: The majority of your testing should focus on calling your **resource actions**, as all interfaces (web UI, APIs) ultimately rely on them.

#### 8.1.1. Test Data Setup

*   **Using Actions**: Call Ash actions directly to set up test data. This tests the "real sequences of events" your application would undergo.
    *   **Pro**: Tests real application behavior, catches issues like validations or side effects.
    *   **Con**: Can be slower, and tests might fail if the action's creation logic itself breaks.
*   **Seeding Data**: Use `Ash.Seed.seed!` to directly insert data into the data layer, bypassing action logic. Useful for setting up "bad data" or specific database states for validation tests.
    *   **Pro**: Faster, simpler test setup for specific data conditions.
    *   **Con**: Bypasses action logic, so might miss issues related to changes or policies during creation.
*   **`Ash.Generator`**: A powerful tool for dynamically generating test data (records, action inputs, changesets) using `StreamData`. This consolidates test setup logic and provides explicit, succinct data generation.

    ```elixir
    # lib/tunez/generator.ex
    defmodule Tunez.Generator do
      use Ash.Generator

      def user(opts \\ []) do
        changeset_generator(
          Tunez.Accounts.User, :register_with_password,
          defaults: [
            email: sequence(:user_email, &"user#{&1}@example.com"),
            password: "password", password_confirmation: "password"
          ],
          overrides: opts,
          after_action: fn user ->
            role = opts[:role] || :user
            Tunez.Accounts.set_user_role!(user, role, authorize?: false)
          end
        )
      end

      # Use 'once' to generate a shared actor for many artists
      def artist(opts \\ []) do
        actor = opts[:actor] || once(:default_actor, fn ->
          generate(user(role: :admin))
        end)
        changeset_generator(Tunez.Music.Artist, :create,
          defaults: [name: sequence(:artist_name, &"Artist #{&1}")],
          actor: actor, overrides: opts
        )
      end
    end
    ```

#### 8.1.2. Testing Resources (Actions, Policies, Calculations)

*   **Actions**: Prefer code interfaces (bang versions) to test actions.
    ```elixir
    # test/tunez/music/artist_test.exs
    test "can filter by partial name matches" do
      ["hello", "goodbye", "what?"] |> Enum.each(&generate(artist(name: &1)))
      assert Enum.sort(Music.read_artists!(query: [filter: expr(contains(name, "o"))]).results) == ["goodbye", "hello"]
    end
    ```
*   **Errors**: Use `assert_raise` (for exceptions) or `Ash.Test.assert_has_error` (for `{:error, %Ash.Error}` tuples).
*   **Policies**: Crucial to test rigorously. Use `Ash.can?` or `can_*?` helper functions for create/update/destroy policies. For read policies (which act as filters), use the `data` option to check if specific records are returned.
*   **Calculations**: Test in isolation using `Ash.calculate/3`, passing a map of `refs` (dependencies). You can also define code interfaces for calculations with `define_calculation`.

#### 8.1.3. Testing Interfaces (UI/API)

Once your resource layer is thoroughly tested, UI and API tests can be less rigorous, focusing on sanity checks and basic interactions.
*   **GraphQL**: Use `absinthe`'s testing utilities. Consider generating and comparing schema SDL to guard against breaking changes.
*   **JSON:API**: Use Phoenix controller helpers and `AshJsonApi.Test` utilities. Similar schema comparison can be done with OpenAPI specs.
*   **Phoenix LiveView**: Use `PhoenixTest` and `Phoenix.LiveViewTest` for UI interaction tests.

### 8.2. PubSub and Real-Time Notifications

Ash integrates seamlessly with Phoenix's PubSub for real-time features. `Ash.Notifier.PubSub` allows resources to broadcast messages when actions occur.

```elixir
# lib/tunez/accounts/notification.ex
defmodule Tunez.Accounts.Notification do
  use Ash.Resource, otp_app: :tunez, domain: Tunez.Accounts,
    data_layer: AshPostgres.DataLayer, authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub] # Enable PubSub notifier

  # ... actions and attributes ...

  pub_sub do
    prefix "notifications" # Topic prefix
    module TunezWeb.Endpoint # Phoenix PubSub module
    # Publish on create actions, using the user_id as part of the topic
    publish :create, [:user_id]
    # Publish on destroy actions, useful for real-time removal from UI
    publish :destroy, [:user_id]
    # Transform the broadcast payload to send only necessary data
    transform fn notification -> Map.take(notification.data, [:id, :user_id, :album_id]) end
  end
end
```

**Key Points:**
*   For bulk actions, ensure `notify?: true` is set to trigger notifications.
*   Enable `config :ash, :pub_sub, debug?: true` in `config/dev.exs` for debugging broadcasts.
*   LiveViews subscribe to these topics in `mount` and handle messages in `handle_info` to update the UI in real-time.
*   When deleting related records with business logic (like sending notifications), you might need to use `cascade_destroy` in code rather than database `ON DELETE`.

### 8.3. Ash AI: The LLM Toolbox

`Ash AI` is a comprehensive toolbox that builds directly on Ash Framework's core strengths to help developers rapidly and safely implement Large Language Model (LLM) features. It emphasizes routing AI agent choices through a "well formed and secure application layer" rather than direct database access.

```elixir
# Install:
mix igniter.install ash_ai
```

**Key Features:**

*   **Prompt-backed Actions with Structured Outputs**: Leverage Ash's generic actions to delegate work to LLM agents. Prompts are automatically derived from action descriptions, inputs, and types, ensuring structured and predictable LLM outputs.

    ```elixir
    # In a resource module, e.g., MyApp.Shopping.Product
    action :scan_for_products, {:array, MyApp.Types.ProductInfo} do
      description """ Scans a given html page for product information, extracting their name and price. """
      argument :page_contents, :string do
        allow_nil? false
        description "The raw contents of the HTML page"
      end
      run prompt(LangChain.ChatModels.ChatOpenAI.new!(%{model: "gpt-4o"}))
    end
    ```

*   **Tool Definition**: Any existing Ash application action can be declared as a "tool call" for AI agents. These tool calls are secure and respect existing Ash authorization policies.

    ```elixir
    # In your domain module, e.g., MyApp.Shopping
    tools do
      tool :convert_to_usd, MyApp.Money.Currencies, :convert_to_usd
      tool :create_product, MyApp.Shopping.Product, :create_product
    end

    # Then use tools in a prompt-backed action
    action :scan_for_products, {:array, MyApp.Types.ProductInfo} do
      # ...
      run prompt(
        LangChain.ChatModels.ChatOpenAI.new!(%{model: "gpt-4o"}),
        tools: [:convert_to_usd, :create_product]
      )
    end
    ```

*   **Vectorization**: Tools to automatically translate Ash data models into vector embeddings, stored alongside data using `pgvector`, enabling Retrieval Augmented Generation (RAG) capabilities. Policies can be configured to bypass for embedding updates.

    ```elixir
    # In a resource, e.g., MyApp.Shopping.Product
    vectorize do
      full_text do
        text fn product -> """ Name: #{product.name} Description: #{product.description} """ end
      end
      attributes(description: :vectorized_description)
      embedding_model MyApp.OpenAiEmbeddingModel # You bring your own embedding model
      strategy :ash_oban # Asynchronously update embeddings via Oban
    end
    ```

*   **`mix ash_ai.gen.chat`**: A quickstart tool that generates Ash resources and Phoenix LiveViews for a fully functional chat feature, including conversations, persistence, streaming responses, and tool calls.

    ```bash
    # Example for a fresh Ash project with AI chat
    mix igniter.new my_app --with phx.new \
      --install ash,ash_postgres,ash_authentication \
      --install ash_authentication_phoenix \
      --install ash_ai@github:ash-project/ash_ai \
      --auth-strategy password

    cd my_app
    mix ash_ai.gen.chat --live
    mix ash.setup
    iex -S mix phx.server # Visit http://localhost:4000/chat
    ```

*   **MCP Server**: An MCP (Model Context Protocol) server allows external AI agents (like IDEs or Claude) to discover and interact with your application's defined tools.

    ```elixir
    # In your router (lib/tunez_web/router.ex) for a production MCP server
    scope "/mcp" do
      pipe_through :mcp
      forward "/", AshAi.Mcp.Router, tools: [:get_weather], otp_app: :my_app
    end
    ```

Ash AI truly exemplifies the power of building on a strong declarative foundation. The same tools and skills you learn for "regular" Ash actions are directly leveraged to build "first-class AI products," providing "guardrails for agents" and fostering collaboration between developers and LLM tools.

---

## 9. Conclusion

You've just completed a whirlwind tour through the foundational concepts and powerful extensions of Ash Framework. We've covered everything from its core philosophy of declarative design to practical implementation details of resources, actions, relationships, and essential features like authentication, authorization, and API generation. We even touched upon how Ash extends into the exciting realm of AI.

The core takeaway is this: Ash is more than just a library; it's a paradigm shift. By modeling your domain explicitly as data and embracing the "derive the rest" principle, you'll dramatically reduce boilerplate, ensure consistency, and build applications that are more maintainable, scalable, and a joy to work with.

This document is your starting point. As you work with Ash, you'll find that its compile-time verifications and explanatory errors make development a much smoother experience. Don't hesitate to revisit these concepts, experiment in `iex`, and explore the documentation for deeper dives.

Welcome to the declarative world of Ash! Now, let's build something amazing together!
