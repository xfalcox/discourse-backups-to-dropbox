module Jobs
  class SyncBackupsToDropbox < ::Jobs::Base

  	sidekiq_options queue: 'low'

    def execute(args)
      Backup.all.take(SiteSetting.discourse_sync_to_dropbox_quantity).each do |backup|
        DiscourseBackupToDropbox::DropboxSynchronizer.new(backup).sync # sync inherited from base class, which results in perform_sync
      end
    end
  end
end