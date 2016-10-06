module DiscourseBackupToDropbox
  class DropboxSynchronizer

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
        dbx.upload("/#{folder_name}/#{filename}", File.open(full_path, "r"))
      end

      (dropbox_backup_files - local_backup_files).each do |filename|
        dbx.delete("/#{folder_name}/#{filename}")
      end
    end
  end
end