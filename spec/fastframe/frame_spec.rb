# frozen_string_literal: true

RSpec.describe Fastframe::Frame do
  def build_entity(attrs = {})
    obj = Object.new
    attrs.each do |key, value|
      obj.define_singleton_method(key) { value }
    end
    obj
  end

  describe ".fields" do
    it "renders multiple fields from an entity" do
      frame = Class.new(described_class) do
        fields :name, :email
      end

      entity = build_entity(name: "John", email: "john@example.com")
      result = frame.render_hash(entity)

      expect(result).to eq({ name: "John", email: "john@example.com" })
    end
  end

  describe ".field" do
    it "renders a single field" do
      frame = Class.new(described_class) do
        field :name
      end

      entity = build_entity(name: "John")
      result = frame.render_hash(entity)

      expect(result).to eq({ name: "John" })
    end

    it "renders a field with a custom block" do
      frame = Class.new(described_class) do
        field(:name) { |e| e.name.upcase }
      end

      entity = build_entity(name: "John")
      result = frame.render_hash(entity)

      expect(result).to eq({ name: "JOHN" })
    end

    it "renders a field with the :from option" do
      frame = Class.new(described_class) do
        field :full_name, from: :name
      end

      entity = build_entity(name: "John")
      result = frame.render_hash(entity)

      expect(result).to eq({ full_name: "John" })
    end
  end

  describe ".association" do
    it "renders a nested association" do
      frame = Class.new(described_class) do
        field :name

        association(:profile) do
          field :bio
          field :avatar_url
        end
      end

      profile = build_entity(bio: "Hello world", avatar_url: "https://example.com/avatar.png")
      entity = build_entity(name: "John", profile: profile)
      result = frame.render_hash(entity)

      expect(result).to eq({
                             name: "John",
                             profile: { bio: "Hello world", avatar_url: "https://example.com/avatar.png" }
                           })
    end

    it "renders a collection association" do
      frame = Class.new(described_class) do
        field :name

        association(:posts) do
          fields :title, :body
        end
      end

      posts = [
        build_entity(title: "First", body: "Content 1"),
        build_entity(title: "Second", body: "Content 2")
      ]
      entity = build_entity(name: "John", posts: posts)
      result = frame.render_hash(entity)

      expect(result).to eq({
                             name: "John",
                             posts: [
                               { title: "First", body: "Content 1" },
                               { title: "Second", body: "Content 2" }
                             ]
                           })
    end

    it "renders nil when association is nil" do
      frame = Class.new(described_class) do
        association(:profile) do
          field :bio
        end
      end

      entity = build_entity(profile: nil)
      result = frame.render_hash(entity)

      expect(result).to eq({ profile: nil })
    end
  end

  describe ".condition" do
    it "merges fields when condition applies" do
      frame = Class.new(described_class) do
        field :name

        condition(:admin) do
          field :email
        end
      end

      entity = build_entity(name: "John", email: "john@example.com", admin: true)
      result = frame.render_hash(entity)

      expect(result).to eq({ name: "John", email: "john@example.com" })
    end

    it "skips fields when condition does not apply" do
      frame = Class.new(described_class) do
        field :name

        condition(:admin) do
          field :email
        end
      end

      entity = build_entity(name: "John", email: "john@example.com", admin: false)
      result = frame.render_hash(entity)

      expect(result).to eq({ name: "John" })
    end

    it "supports a Proc as condition" do
      frame = Class.new(described_class) do
        field :name

        condition(->(e) { e.age >= 18 }) do
          field :email
        end
      end

      minor = build_entity(name: "Kid", email: "kid@example.com", age: 10)
      adult = build_entity(name: "Adult", email: "adult@example.com", age: 25)

      expect(frame.render_hash(minor)).to eq({ name: "Kid" })
      expect(frame.render_hash(adult)).to eq({ name: "Adult", email: "adult@example.com" })
    end
  end

  describe ".render_hash" do
    it "returns nil for a nil entity" do
      frame = Class.new(described_class) do
        field :name
      end

      expect(frame.render_hash(nil)).to be_nil
    end

    it "renders an array of entities" do
      frame = Class.new(described_class) do
        fields :name, :email
      end

      entities = [
        build_entity(name: "John", email: "john@example.com"),
        build_entity(name: "Jane", email: "jane@example.com")
      ]
      result = frame.render_hash(entities)

      expect(result).to eq(
        [
          { name: "John", email: "john@example.com" },
          { name: "Jane", email: "jane@example.com" }
        ]
      )
    end
  end
end
