module DiscourseBackupToDropbox
  class DropboxSynchronizer < Synchronizer #inherit from the base class
    CHUNK_SIZE = 25600000
    UPLOAD_MAX_SIZE = CHUNK_SIZE * 4

    def initialize(backup)
      super(backup) #need to initialize neccessary params for the can_sync?
      @api_key = SiteSetting.discourse_backups_to_dropbox_api_key
      @turned_on = SiteSetting.discourse_backups_to_dropbox_enabled
      @dbx = Dropbox::Client.new(@api_key)
    end

    protected

    def can_sync? #needs to be true in order to perform sync
      @turned_on && @api_key.present? && backup.present?
    end

    def perform_sync
      folder_name = Discourse.current_hostname
      begin
        @dbx.create_folder("/#{folder_name}")
      rescue
        #folder already exists
      end

      dropbox_backup_files = @dbx.list_folder("/#{folder_name}").map(&:name)

      local_backup_files = Backup.all.map(&:filename).take(SiteSetting.discourse_backups_to_dropbox_quantity)

      (local_backup_files - dropbox_backup_files).each do |filename|
        full_path = Backup[filename].path
        size = Backup[filename].size
        upload(@dbx, folder_name, filename, full_path, size)
      end

      (dropbox_backup_files - local_backup_files).each do |filename|
        @dbx.delete("/#{folder_name}/#{filename}")
      end
    end
##################################################################################
    # renamed @dbx for dbx as we must memoize the call
    # deleted dbx argument in both uploads because of memoization
    def self.upload(folder_name, file_name, full_path, size)
      if size < UPLOAD_MAX_SIZE then
        dbx.upload("/#{folder_name}/#{file_name}", File.open(full_path, "r"))
      else
        chunked_upload(dbx, folder_name, file_name, full_path)
      end
    end

    def self.chunked_upload(folder_name, file_name, full_path)
      File.open(full_path) do |f|
        loops = f.size / CHUNK_SIZE

        cursor = dbx.start_upload_session(f.read(CHUNK_SIZE))

        (loops-1).times do |i|
          dbx.append_upload_session( cursor, f.read(CHUNK_SIZE) )
        end

        dbx.finish_upload_session(cursor, "/#{folder_name}/#{file_name}", f.read(CHUNK_SIZE))
      end
    end
##################################################################################
  end
end
