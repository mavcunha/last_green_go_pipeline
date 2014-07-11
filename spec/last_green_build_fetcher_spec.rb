require_relative '../lib/go_cd/last_green_build_fetcher'
require 'ostruct'

class MockGoApiClient

  def self.reset!
    @@last_params = @@canned_return_value = nil
  end

  def self.last_params
    @@last_params
  end

  def self.canned_return_value=(value)
    @@canned_return_value = value
  end

  def self.runs(options)
    @@last_params = options
    @@canned_return_value
  end

end

describe GoCD::LastGreenBuildFetcher do

  let(:cache_file) do
    File.expand_path('./.last_green_build_fetcher_cache')
  end

  before(:each) do
    FileUtils.rm_f cache_file
  end

  describe "with mock go api" do

    before(:each) do
      GoApiClient.instance_eval do
        class << self
          alias_method :original_runs_method, :runs
          def runs(options)
            MockGoApiClient.runs(options)
          end
        end
      end
    end

    describe "with no pipeline history" do

      before(:each) do
        MockGoApiClient.canned_return_value = {
          pipelines: [],
          latest_atom_entry_id: 'ignore'
        }
      end

      it "returns nil" do
        fetcher = GoCD::LastGreenBuildFetcher.new(stage_name: 'acceptance')
        expect(fetcher.fetch).to be nil
      end

    end

    describe "with no green builds" do

      before(:each) do
        MockGoApiClient.canned_return_value = {
          pipelines: [red_pipeline],
          latest_atom_entry_id: 'ignore'
        }
      end

      it "returns nils" do
        fetcher = GoCD::LastGreenBuildFetcher.new(stage_name: 'acceptance')
        expect(fetcher.fetch).to be nil
      end

    end

    it "finds most recent passing stage" do
      MockGoApiClient.canned_return_value = {
                                          pipelines: [red_pipeline, green_pipeline].reverse,
                                          latest_atom_entry_id: 'ignore'
                                        }
      fetcher = GoCD::LastGreenBuildFetcher.new(stage_name: 'acceptance')
      expect(fetcher.fetch).to eq Time.parse('2013-02-11 14:19:00')
    end

    after(:each) do
      MockGoApiClient.reset!
      GoApiClient.instance_eval do
        class << self
          alias_method :runs, :original_runs_method
        end
      end
    end

  end

  let(:red_pipeline) do
    OpenStruct.new.tap do |pipeline|
      pipeline.stages = [OpenStruct.new(
                            name: 'unit',
                            result: 'Passed',
                            completed_at: Time.parse('2013-02-10 11:40:00')),
                         OpenStruct.new(
                            name: 'acceptance',
                            result: 'Failed',
                            completed_at: Time.parse('2013-02-10 11:45:00'))
                          ]
    end
  end

  let (:green_pipeline) do
    OpenStruct.new.tap do |pipeline|
      pipeline.stages = [OpenStruct.new(
                            name: 'unit',
                            result: 'Passed',
                            completed_at: Time.parse('2013-02-11 14:10:00')),
                         OpenStruct.new(
                             name: 'acceptance',
                             result: 'Passed',
                             completed_at: Time.parse('2013-02-11 14:19:00'))
                           ]
    end
  end


end
