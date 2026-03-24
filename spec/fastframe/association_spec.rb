# frozen_string_literal: true

RSpec.describe Fastframe::Association do
  def build_entity(attrs = {})
    obj = Object.new
    attrs.each do |key, value|
      obj.define_singleton_method(key) { value }
    end
    obj
  end

  describe 'Rendering' do
    context 'when association points to a single entity' do
      let(:frame) do
        FrameStub.new do
          field :id
          association(:profile) do
            field :bio
            field :avatar_url
          end
        end
      end

      it 'renders the nested entity as a hash' do
        profile = build_entity(bio: 'Hello', avatar_url: 'https://example.com/avatar.png')
        entity = build_entity(id: 1, profile: profile)

        expect(frame.render_hash(entity)).to eq({
          id: 1,
          profile: { bio: 'Hello', avatar_url: 'https://example.com/avatar.png' }
        })
      end
    end

    context 'when association points to a collection' do
      let(:frame) do
        FrameStub.new do
          field :id
          association(:log_changes) do
            field :id
            field :item_name
          end
        end
      end

      it 'renders each element in the collection' do
        changes = [
          build_entity(id: 1, item_name: 'First'),
          build_entity(id: 2, item_name: 'Second')
        ]
        entity = build_entity(id: 10, log_changes: changes)

        expect(frame.render_hash(entity)[:log_changes]).to eq([
          { id: 1, item_name: 'First' },
          { id: 2, item_name: 'Second' }
        ])
      end
    end

    context 'when association is nil' do
      let(:frame) do
        FrameStub.new do
          association(:profile) do
            field :bio
          end
        end
      end

      it 'returns nil for the association key' do
        entity = build_entity(profile: nil)
        expect(frame.render_hash(entity)).to eq({ profile: nil })
      end
    end

    context 'when :from option remaps to a different method' do
      let(:frame) do
        FrameStub.new do
          association :file, from: :file_attachment do
            field :id
            field :content_type
          end
        end
      end

      it 'reads from the specified source method' do
        attachment = build_entity(id: 5, content_type: 'image/png')
        entity = build_entity(file_attachment: attachment)

        expect(frame.render_hash(entity)).to eq({
          file: { id: 5, content_type: 'image/png' }
        })
      end
    end

    context 'when :from option is a callable' do
      let(:frame) do
        FrameStub.new do
          association :file, from: ->(e) { e.attachments.first } do
            field :id
          end
        end
      end

      it 'calls the lambda to resolve the associated entity' do
        attachment = build_entity(id: 7)
        entity = build_entity(attachments: [attachment])

        expect(frame.render_hash(entity)).to eq({ file: { id: 7 } })
      end
    end

    context 'when :from callable returns a collection' do
      let(:frame) do
        FrameStub.new do
          association :recent_posts, from: ->(e) { e.posts.select { |p| p.published } } do
            field :title
          end
        end
      end

      it 'renders each element from the lambda result' do
        posts = [
          build_entity(title: 'Published', published: true),
          build_entity(title: 'Draft', published: false)
        ]
        entity = build_entity(posts: posts)

        expect(frame.render_hash(entity)).to eq({
          recent_posts: [{ title: 'Published' }]
        })
      end
    end

    context 'when associations are deeply nested' do
      let(:frame) do
        FrameStub.new do
          field :id
          association(:log_reason) do
            field :value
            association(:file, from: :file_attachment) do
              field :id
              field(:content_type) { |obj| obj.blob&.content_type }
            end
          end
        end
      end

      it 'renders all nesting levels' do
        blob = build_entity(content_type: 'application/pdf')
        file = build_entity(id: 3, blob: blob)
        reason = build_entity(value: 'Reason text', file_attachment: file)
        entity = build_entity(id: 1, log_reason: reason)

        expect(frame.render_hash(entity)).to eq({
          id: 1,
          log_reason: {
            value: 'Reason text',
            file: {
              id: 3,
              content_type: 'application/pdf'
            }
          }
        })
      end
    end
  end

  describe 'Preloading' do
    context 'when eager_loads is true' do
      let(:frame) do
        FrameStub.new do
          association(:log_changes, eager_loads: true) do
            field :id
          end
        end
      end

      it 'includes the association in the preload tree' do
        expect(frame.prepare_preload).to eq({ log_changes: {} })
      end
    end

    context 'when eager_loads is a symbol remapping the preload key' do
      let(:frame) do
        FrameStub.new do
          association :file, from: :file_attachment, eager_loads: :file_attachment do
            field :id
          end
        end
      end

      it 'uses :from as the preload key' do
        expect(frame.prepare_preload).to eq({ file_attachment: {} })
      end
    end

    context 'when nested associations also have eager_loads' do
      let(:frame) do
        FrameStub.new do
          association(:log_reason, eager_loads: true) do
            field :value
            association(:file, from: :file_attachment, eager_loads: :file_attachment) do
              field :id
            end
          end
        end
      end

      it 'builds a nested preload tree' do
        expect(frame.prepare_preload).to eq({
          log_reason: { file_attachment: {} }
        })
      end
    end

    context 'when no eager_loads and no nested preloads' do
      let(:frame) do
        FrameStub.new do
          association(:profile) do
            field :bio
          end
        end
      end

      it 'returns an empty hash' do
        expect(frame.prepare_preload).to eq({})
      end
    end
  end
end
