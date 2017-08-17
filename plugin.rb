# name: discourse-sync-to-dropbox
# about: Backups discourse backups in dropbox
# version: 0.0.2
# authors: Rafael dos Santos Silva <xfalcox@gmail.com>
# url: https://github.com/xfalcox/discourse-backups-to-dropbox

gem 'public_suffix', '2.0.5', {require: false }
gem 'domain_name', '0.5.20170404', {require: false }
gem 'addressable', '2.5.1', {require: false }
gem 'http_parser.rb', '0.6.0', {require: false }
gem 'http-cookie', '1.0.3', {require: false }
gem 'http-form_data', '1.0.1', {require: false }
gem 'http', '2.0.3', {require: false }
gem 'dropbox-sdk-v2', '0.0.3', { require: false }
require 'dropbox'
require 'sidekiq'

enabled_site_setting :discourse_sync_to_dropbox_enabled

after_initialize do
  load File.expand_path("../app/jobs/regular/sync_backups_to_dropbox.rb", __FILE__)
  load File.expand_path("../lib/dropbox_synchronizer.rb", __FILE__)

  DiscourseEvent.on(:backup_created) do
    Jobs.enqueue(:sync_backups_to_dropbox)
  end
end
