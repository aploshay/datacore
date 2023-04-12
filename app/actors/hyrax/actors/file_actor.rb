# frozen_string_literal: true

module Hyrax

  module Actors

    # Actions for a file identified by file_set and relation (maps to use predicate)
    # @note Spawns asynchronous jobs
    class FileActor
      attr_reader :file_set, :relation, :user

      # @param [FileSet] file_set the parent FileSet
      # @param [Symbol, #to_sym] relation the type/use for the file
      # @param [User] user the user to record as the Agent acting upon the file
      def initialize(file_set, relation, user)
        @file_set = file_set
        @relation = relation.to_sym
        @user = user
      end

      # Persists file as part of file_set and spawns async job to characterize and create derivatives.
      # @param [JobIoWrapper] io the file to save in the repository, with mime_type and original_name
      # @return [CharacterizeJob, FalseClass] spawned job on success, false on failure
      # @note Instead of calling this method, use IngestJob to avoid synchronous execution cost
      # @see IngestJob
      # @todo create a job to monitor the temp directory (or in a multi-worker system, directories!) to prune old files that have made it into the repo
      def ingest_file( io,
                       continue_job_chain: true,
                       continue_job_chain_later: true,
                       current_user: nil,
                       delete_input_file: true,
                       uploaded_file_ids: [],
                       bypass_fedora: false )

        Deepblue::LoggingHelper.bold_debug [ Deepblue::LoggingHelper.here,
                                             Deepblue::LoggingHelper.called_from,
                                             "io=#{io})",
                                             "user=#{user}",
                                             "continue_job_chain=#{continue_job_chain}",
                                             "continue_job_chain_later=#{continue_job_chain_later}",
                                             "delete_input_file=#{delete_input_file}",
                                             "uploaded_file_ids=#{uploaded_file_ids}" ]
        if bypass_fedora
          Hydra::Works::AddExternalFileToFileSet.call( file_set,
                                               bypass_fedora,
                                               relation,
                                               versioning: false )
        else
          # Skip versioning because versions will be minted by VersionCommitter as necessary during save_characterize_and_record_committer.
          Hydra::Works::AddFileToFileSet.call( file_set,
                                               io,
                                               relation,
                                               versioning: false )
        end
        return false unless file_set.save
        repository_file = related_file
        Hyrax::VersioningService.create( repository_file, current_user )
        pathhint = io.uploaded_file.uploader.path if io.uploaded_file # in case next worker is on same filesystem
        # FIXME: skip characterization for external file?
        if continue_job_chain_later
          CharacterizeJob.perform_later( file_set,
                                         repository_file.id,
                                         pathhint || io.path,
                                         current_user: current_user,
                                         uploaded_file_ids: uploaded_file_ids )
        else
          CharacterizeJob.perform_now( file_set,
                                       repository_file.id,
                                       pathhint || io.path,
                                       continue_job_chain: continue_job_chain,
                                       continue_job_chain_later: continue_job_chain_later,
                                       current_user: current_user,
                                       delete_input_file: delete_input_file,
                                       uploaded_file_ids: uploaded_file_ids )
        end
      end

      # Reverts file and spawns async job to characterize and create derivatives.
      # @param [String] revision_id
      # @return [CharacterizeJob, FalseClass] spawned job on success, false on failure
      def revert_to( revision_id )
        Deepblue::LoggingHelper.bold_debug [ Deepblue::LoggingHelper.here,
                                             Deepblue::LoggingHelper.called_from,
                                             "user=#{user}",
                                             "file_set.id=#{file_set.id}",
                                             "relation=#{relation}",
                                             "revision_id=#{revision_id}" ]
        repository_file = related_file
        current_version = file_set.latest_version
        prior_revision_id = current_version.label
        prior_create_date = current_version.created
        # Deepblue::LoggingHelper.bold_debug [ Deepblue::LoggingHelper.here,
        #                                      Deepblue::LoggingHelper.called_from,
        #                                      "repository_file=#{repository_file}",
        #                                      "file_set.latest_version_create_datetime=#{prior_create_date}" ]
        repository_file.restore_version(revision_id)
        return false unless file_set.save
        current_version = file_set.latest_version
        new_revision_id = current_version.label
        new_create_date = current_version.created
        file_set.provenance_update_version( current_user: user,
                                            event_note: "revert_to",
                                            new_create_date: new_create_date,
                                            new_revision_id: new_revision_id,
                                            prior_create_date: prior_create_date,
                                            prior_revision_id: prior_revision_id,
                                            revision_id: revision_id )
        Hyrax::VersioningService.create( repository_file, user )
        CharacterizeJob.perform_later( file_set, repository_file.id, current_user: user )
      end

      # @note FileSet comparison is limited to IDs, but this should be sufficient, given that
      #   most operations here are on the other side of async retrieval in Jobs (based solely on ID).
      def ==(other)
        return false unless other.is_a?(self.class)
        file_set.id == other.file_set.id && relation == other.relation && user == other.user
      end

      private

        # @return [Hydra::PCDM::File] the file referenced by relation
        def related_file
          file_set.public_send(relation) || raise("No #{relation} returned for FileSet #{file_set.id}")
        end

    end

  end

end
