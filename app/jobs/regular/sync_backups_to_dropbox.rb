module Jobs  
  class SyncBackupsToDropbox < ::Jobs::Base

  	sidekiq_options queue: 'low'

    def execute(args)
      ::DiscourseBackupToDropbox::DropboxSynchronizer.sync if SiteSetting.discourse_backups_to_dropbox_enabled
    end
  end
end