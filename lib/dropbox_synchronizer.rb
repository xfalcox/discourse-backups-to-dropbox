module DiscourseBackupToDropbox
  class DropboxSynchronizer < Synchronizer
    CHUNK_SIZE ||= 25600000
    UPLOAD_MAX_SIZE ||= CHUNK_SIZE * 4

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
    # def perform_sync
    #   folder_name = "one"
    #   dbx.create_folder("/#{folder_name}")
    #   full_path = backup.path
    #   filename = backup.filename
    #   size = backup.size
    #   upload(folder_name, filename, full_path, size)
    # end

    def perform_sync
      folder_name = Discourse.current_hostname
      begin
        dbx.create_folder("/#{folder_name}")
      rescue
        #folder already exists
      end
      dbx_files = dbx.list_folder("/#{folder_name}").map(&:name)
      (backup.filename - dbx_files).each do |f|
        if f.present?
          full_path  = f.path
          filename   = f.filename
          size       = f.size
          upload(folder_name, filename, full_path, size)
        end
      end
    end
    # def add_to_folder(file)
    #   folder_name = Discourse.current_hostname
    #   begin
    #     folder = dbx.create_folder("/#{folder_name}")
    #   rescue
    #     #folder already exists
    #   end
    #   folder.add(file)
    # end
    #
    # dropbox_backup_files   = dbx.list_folder("/#{folder_name}").map(&:name)
    # file_difference_remote = dropbox_backup_files - local_backup_files
    # file_difference_remote.dbx.delete("/#{folder_name}/#{filename}") # used dbx, as a method here

#
    def upload(folder_name, file_name, full_path, size)
      if size < UPLOAD_MAX_SIZE then
        dbx.upload("/#{folder_name}/#{file_name}", "#{file_name}")
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
#
  end
end
