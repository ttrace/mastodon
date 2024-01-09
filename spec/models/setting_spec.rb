# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Setting do
  describe '#to_param' do
    let(:setting) { Fabricate(:setting, var: var) }
    let(:var)     { 'var' }

    it 'returns setting.var' do
      expect(setting.to_param).to eq var
    end
  end

  describe '.[]' do
    let(:key)         { 'key' }
    let(:cache_key)   { 'cache-key' }
    let(:cache_value) { 'cache-value' }

    before do
      allow(described_class).to receive(:cache_key).with(key).and_return(cache_key)
    end

    context 'when Rails.cache does not exists' do
      before do
        allow(described_class).to receive(:default_settings).and_return(default_settings)

        Fabricate(:setting, var: key, value: 42) if save_setting

        Rails.cache.delete(cache_key)
      end

      let(:default_value)    { 'default_value' }
      let(:default_settings) { { key => default_value } }
      let(:save_setting)     { true }

      context 'when the setting has been saved to database' do
        it 'returns the value from database' do
          callback = double
          allow(callback).to receive(:call)

          ActiveSupport::Notifications.subscribed callback, 'sql.active_record' do
            expect(described_class[key]).to eq 42
          end

          expect(callback).to have_received(:call)
        end
      end

      context 'when the setting has not been saved to database' do
        let(:save_setting) { false }

        it 'returns default_settings[key]' do
          expect(described_class[key]).to be default_settings[key]
        end
      end
    end

    context 'when Rails.cache exists' do
      before do
        Rails.cache.write(cache_key, cache_value)
      end

      it 'does not query the database' do
        callback = double
        allow(callback).to receive(:call)
        ActiveSupport::Notifications.subscribed callback, 'sql.active_record' do
          described_class[key]
        end
        expect(callback).to_not have_received(:call)
      end

      context 'when Rails.cache exists' do
        before do
          Rails.cache.write(cache_key, cache_value)
        end

        it 'does not query the database' do
          callback = double
          allow(callback).to receive(:call)
          ActiveSupport::Notifications.subscribed callback, 'sql.active_record' do
            described_class[key]
          end
          expect(callback).to_not have_received(:call)
        end

        it 'returns the cached value' do
          expect(described_class[key]).to eq cache_value
        end
      end
    end
  end

  describe '.all_as_records' do
    before do
      settings_double = instance_double(Settings::ScopedSettings, thing_scoped: records)
      allow(Settings::ScopedSettings).to receive(:new).and_return(settings_double)
      allow(described_class).to receive(:default_settings).and_return(default_settings)
    end

    let(:key)              { 'key' }
    let(:default_value)    { 'default_value' }
    let(:default_settings) { { key => default_value } }
    let(:original_setting) { Fabricate(:setting, var: key, value: nil) }
    let(:records)          { [original_setting] }

    it 'returns a Hash' do
      expect(described_class.all_as_records).to be_a Hash
    end

    context 'when records includes Setting with var as the key' do
      let(:records) { [original_setting] }

      it 'includes the original Setting' do
        setting = described_class.all_as_records[key]
        expect(setting).to eq original_setting
      end
    end

    context 'when records includes nothing' do
      let(:records) { [] }

      it 'includes Setting with value of default_value' do
        setting = described_class.all_as_records[key]

        expect(setting).to be_a described_class
        expect(setting).to have_attributes(var: key)
        expect(setting).to have_attributes(value: default_value)
      end
    end
  end

  describe '.default_settings' do
    subject { described_class.default_settings }

    before do
      allow(RailsSettings::Default).to receive(:enabled?).and_return(enabled)
    end

    context 'when RailsSettings::Default.enabled? is false' do
      let(:enabled) { false }

      it 'returns {}' do
        expect(subject).to eq({})
      end
    end

    context 'when RailsSettings::Settings.enabled? is true' do
      let(:enabled) { true }

      it 'returns instance of RailsSettings::Default' do
        expect(subject).to be_a RailsSettings::Default
      end
    end
  end
end
