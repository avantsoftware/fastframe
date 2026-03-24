# frozen_string_literal: true

RSpec.describe Fastframe::Frame do
  def build_entity(attrs = {})
    obj = Object.new
    attrs.each do |key, value|
      obj.define_singleton_method(key) { value }
    end
    obj
  end

  describe 'Rendering A Single Entity' do
    let(:frame) do
      FrameStub.new do
        fields :id, :name, :email
      end
    end

    it 'returns a hash with all field values' do
      entity = build_entity(id: 1, name: 'John', email: 'john@test.com')
      expect(frame.render_hash(entity)).to eq({ id: 1, name: 'John', email: 'john@test.com' })
    end
  end

  describe 'Rendering A Collection' do
    let(:frame) do
      FrameStub.new do
        fields :id, :name
      end
    end

    it 'returns an array of hashes' do
      entities = [
        build_entity(id: 1, name: 'John'),
        build_entity(id: 2, name: 'Jane')
      ]

      expect(frame.render_hash(entities)).to eq([
        { id: 1, name: 'John' },
        { id: 2, name: 'Jane' }
      ])
    end
  end

  describe 'Rendering Nil' do
    let(:frame) do
      FrameStub.new do
        field :name
      end
    end

    it 'returns nil' do
      expect(frame.render_hash(nil)).to be_nil
    end
  end

  describe 'Full Serializer Scenario' do
    let(:admin_class) { Data.define(:id, :full_name, :email) }
    let(:client_class) { Data.define(:id, :full_name, :status) }

    let(:frame) do
      ac = admin_class
      cc = client_class

      FrameStub.new do
        field :id
        field :ip
        field :success
        field :operation_description
        field :created_at

        association(:log_changes, eager_loads: true) do
          field :id
          field :item_name
          field :created_at
        end

        association(:performed_by, eager_loads: true) do
          condition(ac) do
            field :id
            field :full_name
            field :email
          end

          condition(cc) do
            field :id
            field :full_name
            field :status
          end
        end
      end
    end

    context 'when performed_by is an admin-type entity' do
      it 'renders admin-specific fields in the association' do
        admin = admin_class.new(id: 100, full_name: 'Admin User', email: 'admin@test.com')
        changes = [build_entity(id: 1, item_name: 'Changed X', created_at: '2024-01-01')]
        entity = build_entity(
          id: 10, ip: '127.0.0.1', success: true,
          operation_description: 'Create', created_at: '2024-01-01',
          log_changes: changes, performed_by: admin
        )

        result = frame.render_hash(entity)

        expect(result[:performed_by]).to eq({
          id: 100,
          full_name: 'Admin User',
          email: 'admin@test.com'
        })
      end
    end

    context 'when performed_by is a client-type entity' do
      it 'renders client-specific fields in the association' do
        client = client_class.new(id: 200, full_name: 'Client User', status: 'active')
        entity = build_entity(
          id: 11, ip: '10.0.0.1', success: false,
          operation_description: 'Delete', created_at: '2024-02-01',
          log_changes: [], performed_by: client
        )

        result = frame.render_hash(entity)

        expect(result[:performed_by]).to eq({
          id: 200,
          full_name: 'Client User',
          status: 'active'
        })
      end
    end

    context 'when rendering a collection of entities with different performed_by types' do
      it 'correctly applies conditions per entity' do
        admin = admin_class.new(id: 100, full_name: 'Admin', email: 'a@test.com')
        client = client_class.new(id: 200, full_name: 'Client', status: 'active')

        entity1 = build_entity(
          id: 1, ip: '1.1.1.1', success: true,
          operation_description: 'Op1', created_at: '2024-01-01',
          log_changes: [], performed_by: admin
        )
        entity2 = build_entity(
          id: 2, ip: '2.2.2.2', success: false,
          operation_description: 'Op2', created_at: '2024-02-01',
          log_changes: [], performed_by: client
        )

        results = frame.render_hash([entity1, entity2])

        expect(results[0][:performed_by]).to eq({ id: 100, full_name: 'Admin', email: 'a@test.com' })
        expect(results[1][:performed_by]).to eq({ id: 200, full_name: 'Client', status: 'active' })
      end
    end
  end

  describe 'Frame Isolation' do
    it 'does not share fields between different frame subclasses' do
      frame_a = FrameStub.new { field :name }
      frame_b = FrameStub.new { field :email }

      entity = build_entity(name: 'John', email: 'john@test.com')

      expect(frame_a.render_hash(entity)).to eq({ name: 'John' })
      expect(frame_b.render_hash(entity)).to eq({ email: 'john@test.com' })
    end
  end

  describe 'Preloading' do
    context 'when a collection responds to preload' do
      let(:frame) do
        FrameStub.new do
          fields :name
        end
      end

      it 'calls preload on the collection' do
        entity = build_entity(name: 'John')
        collection = [entity]

        allow(collection).to receive(:respond_to?).and_call_original
        allow(collection).to receive(:respond_to?).with('preload').and_return(true)
        allow(collection).to receive(:preload).and_return(collection)

        frame.render_many_hash(collection)

        expect(collection).to have_received(:preload)
      end
    end

    context 'when skip_preload option is true' do
      let(:frame) do
        FrameStub.new do
          fields :name
        end
      end

      it 'does not call preload' do
        entity = build_entity(name: 'John')
        collection = [entity]

        allow(collection).to receive(:respond_to?).and_call_original
        allow(collection).to receive(:respond_to?).with('preload').and_return(true)
        allow(collection).to receive(:preload).and_return(collection)

        frame.render_many_hash(collection, skip_preload: true)

        expect(collection).not_to have_received(:preload)
      end
    end

    context 'when aggregating preloads from fields and associations' do
      let(:frame) do
        FrameStub.new do
          field :avatar_url, eager_loads: :avatar

          association(:profile, eager_loads: true) do
            field :photo_url, eager_loads: :photo
          end
        end
      end

      it 'builds a combined preload tree' do
        expect(frame.prepare_preload).to eq({ profile: { photo: {} }, avatar: {} })
      end
    end
  end
end
