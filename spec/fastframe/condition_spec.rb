# frozen_string_literal: true

RSpec.describe Fastframe::Condition do
  def build_entity(attrs = {})
    obj = Object.new
    attrs.each do |key, value|
      obj.define_singleton_method(key) { value }
    end
    obj
  end

  describe 'Conditional Rendering' do
    context 'when condition is a Symbol (method call)' do
      let(:frame) do
        FrameStub.new do
          field :name

          condition(:admin?) do
            field :email
            field :role
          end
        end
      end

      context 'when the method returns truthy' do
        it 'merges the conditional fields into the result' do
          entity = build_entity(name: 'John', email: 'j@test.com', role: 'admin', admin?: true)
          expect(frame.render_hash(entity)).to eq({ name: 'John', email: 'j@test.com', role: 'admin' })
        end
      end

      context 'when the method returns falsy' do
        it 'excludes the conditional fields' do
          entity = build_entity(name: 'John', email: 'j@test.com', role: 'user', admin?: false)
          expect(frame.render_hash(entity)).to eq({ name: 'John' })
        end
      end
    end

    context 'when condition is a Class (type check)' do
      let(:admin_class) { Data.define(:id, :email, :full_name) }
      let(:client_class) { Data.define(:id, :full_name, :status) }

      let(:frame) do
        ac = admin_class
        cc = client_class

        FrameStub.new do
          field :id

          condition(ac) do
            field :email
            field :full_name
          end

          condition(cc) do
            field :full_name
            field :status
          end
        end
      end

      context 'when entity matches the first condition class' do
        it 'includes only fields from the matching condition' do
          entity = admin_class.new(id: 1, email: 'admin@test.com', full_name: 'Admin User')

          expect(frame.render_hash(entity)).to eq({
            id: 1,
            email: 'admin@test.com',
            full_name: 'Admin User'
          })
        end
      end

      context 'when entity matches the second condition class' do
        it 'includes only fields from the matching condition' do
          entity = client_class.new(id: 2, full_name: 'Client User', status: 'active')

          expect(frame.render_hash(entity)).to eq({
            id: 2,
            full_name: 'Client User',
            status: 'active'
          })
        end
      end

      context 'when entity matches neither condition' do
        it 'only includes base fields' do
          entity = build_entity(id: 3)
          expect(frame.render_hash(entity)).to eq({ id: 3 })
        end
      end

      context 'when entity is a subclass of a condition class' do
        it 'matches via is_a? (includes subclasses)' do
          subclass = Class.new(admin_class)
          entity = subclass.new(id: 4, email: 'sub@test.com', full_name: 'Sub Admin')

          expect(frame.render_hash(entity)).to eq({
            id: 4,
            email: 'sub@test.com',
            full_name: 'Sub Admin'
          })
        end
      end
    end

    context 'when condition is a Proc' do
      let(:frame) do
        FrameStub.new do
          field :name

          condition(->(e) { e.age >= 18 }) do
            field :email
          end
        end
      end

      it 'includes conditional fields when proc evaluates to truthy' do
        entity = build_entity(name: 'Adult', email: 'adult@test.com', age: 25)
        expect(frame.render_hash(entity)).to eq({ name: 'Adult', email: 'adult@test.com' })
      end

      it 'excludes conditional fields when proc evaluates to falsy' do
        entity = build_entity(name: 'Kid', email: 'kid@test.com', age: 10)
        expect(frame.render_hash(entity)).to eq({ name: 'Kid' })
      end
    end

    context 'when multiple conditions can match the same entity' do
      let(:frame) do
        FrameStub.new do
          field :id

          condition(:admin?) do
            field :admin_email
          end

          condition(:premium?) do
            field :plan_name
          end
        end
      end

      it 'merges fields from all matching conditions' do
        entity = build_entity(id: 1, admin?: true, premium?: true, admin_email: 'a@test.com', plan_name: 'Gold')
        expect(frame.render_hash(entity)).to eq({ id: 1, admin_email: 'a@test.com', plan_name: 'Gold' })
      end

      it 'merges only from the conditions that apply' do
        entity = build_entity(id: 2, admin?: false, premium?: true, admin_email: 'a@test.com', plan_name: 'Silver')
        expect(frame.render_hash(entity)).to eq({ id: 2, plan_name: 'Silver' })
      end
    end
  end
end
