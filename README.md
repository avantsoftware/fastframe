<p align="center">
  <h1 align="center">Fastframe</h1>
  <p align="center">
    The serializer Ruby deserves. Beautiful DSL. Zero boilerplate. Blazing fast.
  </p>
</p>

<p align="center">
  <a href="https://rubygems.org/gems/fastframe"><img src="https://img.shields.io/gem/v/fastframe.svg" alt="Gem Version"></a>
  <a href="https://github.com/avantsoftware/fastframe/actions"><img src="https://github.com/avantsoftware/fastframe/actions/workflows/main.yml/badge.svg" alt="CI"></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License"></a>
</p>

---

Stop writing serializer classes that are longer than your models. Fastframe lets you define exactly what your API returns in a clean, declarative DSL -- with **inline associations**, **polymorphic conditions**, and **automatic eager loading** built in.

```ruby
class UserSerializer < Fastframe::Frame
  field :id
  field :name
  field :email
  field(:member_since) { |user| user.created_at.year }

  association :posts do
    field :id
    field :title
    field :published_at
  end
end

UserSerializer.render_hash(user)
# => {
#      id: 1,
#      name: "Jane",
#      email: "jane@example.com",
#      member_since: 2023,
#      posts: [
#        {
#          id: 1,
#          title: "Hello World",
#          published_at: "2024-01-15"
#        }
#      ]
#    }
```

## Why Fastframe?

| | Fastframe | AMS | Blueprinter | Alba |
|---|---|---|---|---|
| **Inline associations** | `association(:posts) { field :title }` | Separate class + `has_many :posts` | Separate class + `association :posts, blueprint: PostBlueprint` | Separate class + `many :posts, resource: PostResource` |
| **Polymorphic conditions** | Built-in `condition` DSL | Manual `if/case` in methods | Not built-in | Not built-in |
| **Auto eager loading** | `eager_loads: true` | Manual | Manual | Manual |
| **Boilerplate** | Minimal | Heavy | Moderate | Moderate |
| **No instance needed** | Class methods only | Instantiates per object | Class methods | Instantiates per object |

## Installation

Add to your Gemfile:

```ruby
gem "fastframe"
```

Then run:

```bash
bundle install
```

## Guide

### Fields

The building block. Declare what gets serialized.

```ruby
class ProductSerializer < Fastframe::Frame
  # Multiple fields at once
  fields :id, :name, :sku, :price

  # Single field with options
  field :category_name, from: :category_display_name

  # Computed fields with blocks
  field(:price_formatted) { |product| "$#{'%.2f' % product.price}" }

  # Method reference shorthand
  field :slug, &:parameterize
end
```

The `:from` option lets you decouple the JSON key from the source method -- rename fields without touching your models.

### Associations

Define nested serializers **inline**. No separate classes. No wiring. Just nest the block.

```ruby
class OrderSerializer < Fastframe::Frame
  field :id
  field :status
  field :total

  association :customer do
    field :id
    field :name
    field :email
  end

  association :line_items do
    field :id
    field :quantity
    field :unit_price

    association :product do
      field :id
      field :name
      field :sku
    end
  end
end
```

Single entity? Collection? `nil`? Fastframe handles it automatically:

```ruby
OrderSerializer.render_hash(order)
# customer renders as a hash, line_items as an array of hashes

OrderSerializer.render_hash(order_with_nil_customer)
# => { ..., customer: nil, ... }
```

#### Remapping associations

Use `:from` to read from a different method, or pass a **lambda** for full control:

```ruby
class PostSerializer < Fastframe::Frame
  field :id
  field :title

  # Read from a different method
  association :image, from: :featured_image do
    field :id
    field :url
    field :alt_text
  end

  # Lambda for custom resolution
  association :recent_comments, from: ->(post) { post.comments.order(created_at: :desc).limit(5) } do
    field :id
    field :body
    field :author_name
  end
end
```

### Conditions -- Polymorphic Serialization

This is where Fastframe shines. Conditionally include fields based on the entity's **type**, a **method**, or a **lambda**.

#### By class (polymorphic associations)

```ruby
class ActivitySerializer < Fastframe::Frame
  field :id
  field :action
  field :created_at

  association :actor do
    # Each type gets its own fields -- no case statements, no type checking
    condition Admin::User do
      field :id
      field :full_name
      field :email
      field :role
    end

    condition Client::User do
      field :id
      field :full_name
      field :company_name
    end

    condition Pos::Machine do
      field :id
      field :reference_number
      field :location
    end
  end
end
```

Fastframe checks `entity.is_a?(Class)` and merges only the matching fields. Subclasses match too.

#### By method

```ruby
class UserSerializer < Fastframe::Frame
  field :id
  field :name

  condition :admin? do
    field :email
    field :permissions
    field :last_sign_in_at
  end

  condition :premium? do
    field :plan_name
    field :plan_expires_at
  end
end

# Admin + premium user gets all fields merged
# Regular user gets only :id and :name
```

#### By lambda

```ruby
class UserSerializer < Fastframe::Frame
  field :id
  field :name

  condition ->(user) { user.age >= 18 } do
    field :email
  end
end
```

### Automatic Eager Loading

N+1 queries killed your last deploy? Fastframe builds the preload tree for you.

```ruby
class InvoiceSerializer < Fastframe::Frame
  field :id
  field :number
  field :total

  association :customer, eager_loads: true do
    field :id
    field :name
  end

  association :line_items, eager_loads: true do
    field :id
    field :description
    field :amount

    association :product, eager_loads: true do
      field :id
      field :name
      field :thumbnail_url, eager_loads: :thumbnail  # eager load a specific relation
    end
  end
end
```

When you pass an ActiveRecord relation, Fastframe automatically calls `.preload` with the full nested tree:

```ruby
InvoiceSerializer.render_hash(Invoice.all)
# Automatically preloads: { customer: {}, line_items: { product: { thumbnail: {} } } }
# One query per table. Zero N+1s.
```

You can also use `:from` with `:eager_loads` when the preload key differs from the association name:

```ruby
association :image, from: :file_attachment, eager_loads: :file_attachment do
  field :id
  field :content_type
end
```

### Rendering

```ruby
# Hash (single entity)
UserSerializer.render_hash(user)
# => { id: 1, name: "Jane", ... }

# Hash (collection)
UserSerializer.render_hash(users)
# => [{ id: 1, ... }, { id: 2, ... }]

# JSON string with root key (requires Oj)
UserSerializer.render_json(user)
# => '{"data":{"id":1,"name":"Jane",...}}'

# Custom root key
UserSerializer.render_json(user, root: :user)
# => '{"user":{"id":1,"name":"Jane",...}}'

# Alias
UserSerializer.render(user)  # same as render_json
```

## Real-World Example

A complete serializer from a production API:

```ruby
class Admin::Log::RequestSerializer < Fastframe::Frame
  field :id
  field :ip
  field :user_agent
  field :domain
  field :success
  field :operation_description
  field :error_string
  field :created_at

  association :log_changes, eager_loads: true do
    field :id
    field :item_name
    field :item_id
    field :object_changes_translated
    field :created_at
  end

  association :log_reason, eager_loads: true do
    field :id
    field :value

    association :file, from: :file_attachment, eager_loads: :file_attachment do
      field :id
      field(:content_type) { |obj| obj.blob&.content_type }
      field :attachment_id, &:id
      field(:url) { |obj| obj.blob&.url }
    end
  end

  association :performed_by, eager_loads: true do
    condition Admin::User do
      field :id
      field :full_name
      field :email
      field :status
    end

    condition Client::User do
      field :id
      field :full_name
      field :status
    end

    condition Establishment::User do
      field :id
      field :full_name
      field :status
    end

    condition Pos::Machine do
      field :id
      field :reference_number
      field :status
    end
  end
end
```

Fields, associations, eager loading, polymorphic conditions -- all in one readable file. No inheritance chains. No configuration objects. No surprises.

## Development

```bash
bin/setup          # Install dependencies
bundle exec rspec  # Run tests
bin/console        # Interactive console
```

## Contributing

Bug reports and pull requests are welcome on [GitHub](https://github.com/avantsoftware/fastframe). This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/avantsoftware/fastframe/blob/main/CODE_OF_CONDUCT.md).

## License

Available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
