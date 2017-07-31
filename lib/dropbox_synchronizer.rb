module DiscourseBackupToDropbox
  class DropboxSynchronizer < Synchronizer
    CHUNK_SIZE = 25600000
    UPLOAD_MAX_SIZE = CHUNK_SIZE * 4

    def initialize(backup)
      super(backup)
      @api_key   = SiteSetting.discourse_sync_to_dropbox_api_key
      @turned_on = SiteSetting.discourse_sync_to_dropbox_enabled
    end

    def dbx
      @dbx ||= Dropbox::Client.new(@api_key)
    end

    def can_sync?
      @turned_on && @api_key.present? && backup.present?
    end

    protected
    def perform_sync
      full_path  = backup.path
      filename   = backup.filename
      size       = backup.size
      file       = upload(filename, full_path, size)
      add_to_folder(file)
      dropbox_backup_files   = dbx.list_folder("/#{folder_name}").map(&:name)
      file_difference_remote = dropbox_backup_files - local_backup_files
      file_difference_remote.dbx.delete("/#{folder_name}/#{filename}") # used dbx, as a method here
    end

    def add_to_folder(file)
      folder_name = Discourse.current_hostname
      begin
        folder = dbx.create_folder("/#{folder_name}")
      rescue
        #folder already exists
      end
      folder.add(file)
    end                                                                  # and took out the loop

    def upload(folder_name, file_name, full_path, size)
      if size < UPLOAD_MAX_SIZE then
        dbx.upload("/#{folder_name}/#{file_name}", File.open(full_path, "r"))
      else
        backup.chunked_upload(folder_name, file_name, full_path)
      end
    end

    def chunked_upload(folder_name, file_name, full_path)
      File.open(full_path) do |f|
        loops = f.size / CHUNK_SIZE
        cursor = dbx.start_upload_session(f.read(CHUNK_SIZE))
        (loops-1).times do |i|
          dbx.append_upload_session( cursor, f.read(CHUNK_SIZE) )
        end

        dbx.finish_upload_session(cursor, "/#{folder_name}/#{file_name}", f.read(CHUNK_SIZE))
      end
    end

  end
end
