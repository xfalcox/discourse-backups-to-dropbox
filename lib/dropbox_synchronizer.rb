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

    def delete_old_files
      folder_name = Discourse.current_hostname
      dbx_files = dbx.list_folder("/#{folder_name}").map(&:name).reverse!
      keep = dbx_files.take(SiteSetting.discourse_sync_to_dropbox_quantity)
      trash = dbx_files - keep
      trash.each {|f| dbx.delete("/#{folder_name}/#{f}")}
    end

    protected

    def perform_sync
      folder_name = Discourse.current_hostname
      begin
        dbx.create_folder("/#{folder_name}")
      rescue
        #folder already exists
      end
      dbx_files = dbx.list_folder("/#{folder_name}")
      upload_unique_files(folder_name, dbx_files)
    end

    def upload_unique_files(folder_name, dbx_files)
      ([backup] - dbx_files).each do |f|
        if f.present?
          full_path  = f.path
          filename   = f.filename
          size       = f.size
          upload(folder_name, filename, full_path, size)
        end
      end
    end

    def upload(folder_name, file_name, full_path, size)
      if size < UPLOAD_MAX_SIZE then
        dbx.upload("/#{folder_name}/#{file_name}", "#{file_name}")
      else
        chunked_upload(folder_name, file_name, full_path)
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
