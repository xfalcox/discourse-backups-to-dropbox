module Jobs
  class SyncBackupsToDropbox < ::Jobs::Base

  	sidekiq_options queue: 'low'

    def execute(args)
      backups = Backup.all.take(SiteSetting.discourse_sync_to_dropbox_quantity)
      backups.each do |backup|
        DiscourseBackupToDropbox::DropboxSynchronizer.new(backup).sync
      end
    end
  end
end
