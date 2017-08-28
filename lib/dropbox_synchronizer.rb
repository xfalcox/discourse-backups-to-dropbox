module DiscourseBackupToDropbox
  class DropboxSynchronizer
    CHUNK_SIZE = 25600000
    UPLOAD_MAX_SIZE = CHUNK_SIZE * 4

    def self.sync
      dbx = Dropbox::Client.new(SiteSetting.discourse_backups_to_dropbox_api_key)

      folder_name = Discourse.current_hostname

      begin
        dbx.create_folder("/#{folder_name}")
      rescue
        #folder already exists
      end

      dropbox_backup_files = dbx.list_folder("/#{folder_name}").map(&:name)

      local_backup_files = Backup.all.map(&:filename).take(SiteSetting.discourse_backups_to_dropbox_quantity)

      (local_backup_files - dropbox_backup_files).each do |filename|
        full_path = Backup[filename].path
        size = Backup[filename].size
        upload(dbx, folder_name, filename, full_path, size)
      end

      (dropbox_backup_files - local_backup_files).each do |filename|
        dbx.delete("/#{folder_name}/#{filename}")
      end
    end

    def self.upload(dbx, folder_name, file_name, full_path, size)
      if size < UPLOAD_MAX_SIZE then
        dbx.upload("/#{folder_name}/#{file_name}", File.open(full_path, "r"))
      else
        chunked_upload(dbx, folder_name, file_name, full_path)
      end
    end

    def self.chunked_upload(dbx, folder_name, file_name, full_path)
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