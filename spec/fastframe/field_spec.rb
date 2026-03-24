# frozen_string_literal: true

RSpec.describe Fastframe::Field do
  def build_entity(attrs = {})
    obj = Object.new
    attrs.each do |key, value|
      obj.define_singleton_method(key) { value }
    end
    obj
  end

  describe 'Extraction' do
    context 'when using a simple field' do
      let(:frame) do
        FrameStub.new do
          field :name
        end
      end

      it 'extracts the value by calling the method matching the field name' do
        entity = build_entity(name: 'John')
        expect(frame.render_hash(entity)).to eq({ name: 'John' })
      end
    end

    context 'when using a block to compute the value' do
      let(:frame) do
        FrameStub.new do
          field(:full_name) { |e| "#{e.first_name} #{e.last_name}" }
        end
      end

      it 'uses the block result as the field value' do
        entity = build_entity(first_name: 'John', last_name: 'Doe')
        expect(frame.render_hash(entity)).to eq({ full_name: 'John Doe' })
      end
    end

    context 'when using the :from option to remap the source' do
      let(:frame) do
        FrameStub.new do
          field :display_name, from: :name
        end
      end

      it 'reads from the specified source method' do
        entity = build_entity(name: 'John')
        expect(frame.render_hash(entity)).to eq({ display_name: 'John' })
      end
    end

    context 'when using a block shorthand (&:method)' do
      let(:frame) do
        FrameStub.new do
          field :attachment_id, &:id
        end
      end

      it 'calls the referenced method via the block' do
        entity = build_entity(id: 42)
        expect(frame.render_hash(entity)).to eq({ attachment_id: 42 })
      end
    end

    context 'when a block accesses nested data with safe navigation' do
      let(:frame) do
        FrameStub.new do
          field(:content_type) { |obj| obj.blob&.content_type }
        end
      end

      it 'returns nil when the chain is broken' do
        entity = build_entity(blob: nil)
        expect(frame.render_hash(entity)).to eq({ content_type: nil })
      end

      it 'traverses nested objects when present' do
        blob = build_entity(content_type: 'image/png')
        entity = build_entity(blob: blob)
        expect(frame.render_hash(entity)).to eq({ content_type: 'image/png' })
      end
    end

    context 'when both block and :from are provided' do
      let(:frame) do
        FrameStub.new do
          field(:display_name, from: :name) { |e| e.name.reverse }
        end
      end

      it 'prioritizes the block over :from' do
        entity = build_entity(name: 'John')
        expect(frame.render_hash(entity)).to eq({ display_name: 'nhoJ' })
      end
    end
  end

  describe 'Bulk Declaration With Fields' do
    context 'when listing multiple symbols' do
      let(:frame) do
        FrameStub.new do
          fields :id, :name, :email, :status
        end
      end

      it 'extracts all listed fields' do
        entity = build_entity(id: 1, name: 'John', email: 'j@test.com', status: 'active')
        expect(frame.render_hash(entity)).to eq({ id: 1, name: 'John', email: 'j@test.com', status: 'active' })
      end
    end

    context 'when non-Symbol/String values are mixed in' do
      let(:frame) do
        FrameStub.new do
          fields :name, 123, :email, nil
        end
      end

      it 'silently ignores non-Symbol/String arguments' do
        entity = build_entity(name: 'John', email: 'j@test.com')
        expect(frame.render_hash(entity)).to eq({ name: 'John', email: 'j@test.com' })
      end
    end
  end

  describe 'Preloading' do
    context 'when field has no eager_loads' do
      let(:frame) do
        FrameStub.new do
          field :name
        end
      end

      it 'contributes nothing to the preload tree' do
        expect(frame.prepare_preload).to eq({})
      end
    end

    context 'when eager_loads is a Symbol' do
      let(:frame) do
        FrameStub.new do
          field :avatar_url, eager_loads: :avatar
        end
      end

      it 'adds the eager_loads key to the preload tree' do
        expect(frame.prepare_preload).to eq({ avatar: {} })
      end
    end

    context 'when eager_loads is a Hash' do
      let(:frame) do
        FrameStub.new do
          field :avatar_url, eager_loads: { avatar: { file: {} } }
        end
      end

      it 'passes the hash through as-is' do
        expect(frame.prepare_preload).to eq({ avatar: { file: {} } })
      end
    end

    context 'when eager_loads is true' do
      let(:frame) do
        FrameStub.new do
          field :avatar_url, eager_loads: true
        end
      end

      it 'uses the field name as the preload key' do
        expect(frame.prepare_preload).to eq({ avatar_url: {} })
      end
    end
  end
end
