# == Schema Information
#
# Table name: feed_version_infos
#
#  id                :integer          not null, primary key
#  statistics        :json
#  scheduled_service :json
#  filenames         :string           is an Array
#  feed_version_id   :integer
#  created_at        :datetime
#  updated_at        :datetime
#
# Indexes
#
#  index_feed_version_infos_on_feed_version_id  (feed_version_id)
#

FactoryGirl.define do
  factory :feed_version_info do
    feed_version
  end
end
