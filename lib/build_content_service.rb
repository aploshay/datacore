# frozen_string_literal: true

require 'tasks/new_content_service'

# Given a configuration hash read from a yaml file,
# build the contents in the repository.
class BuildContentService < Deepblue::NewContentService

  def self.call( path_to_yaml_file:, mode: nil, ingester: nil, args: )
    cfg_hash = YAML.load_file( path_to_yaml_file )
    base_path = File.dirname( path_to_yaml_file )
    bcs = BuildContentService.new( path_to_yaml_file: path_to_yaml_file,
                                   cfg_hash: cfg_hash,
                                   base_path: base_path,
                                   mode: mode,
                                   ingester: ingester,
                                   args: args )
    bcs.run
  rescue Exception => e # rubocop:disable Lint/RescueException
    Rails.logger.error "BuildContentService.call(#{path_to_yaml_file}) #{e.class}: #{e.message} at\n#{e.backtrace.join("\n")}"
  end

  def initialize( path_to_yaml_file:, cfg_hash:, base_path:, mode:, ingester:, args: )
    initialize_with_msg( args: args,
                         path_to_yaml_file: path_to_yaml_file,
                         cfg_hash: cfg_hash,
                         base_path: base_path,
                         mode: mode,
                         ingester: ingester,
                         msg: "NEW CONTENT SERVICE AT YOUR ... SERVICE" )
  end

  protected

    def build_repo_contents
      build_works
      build_collections
      report_measurements( first_label: 'id' )
    rescue Exception => e # rubocop:disable Lint/RescueException
      Rails.logger.error "BuildContentService.build_repo_contents #{e.class}: #{e.message} at\n#{e.backtrace.join("\n")}"
    end

end
