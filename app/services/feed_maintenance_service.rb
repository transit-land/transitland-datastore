class FeedMaintenanceService
  include Singleton

  DEFAULT_EXTEND_FROM_DATE = 1.month
  DEFAULT_EXTEND_TO_DATE = 1.year
  DEFAULT_EXPIRED_ON_DATE = 1.week

  def self.enqueue_next_feed_versions(date, import_level: nil, max_imports: nil)
    # Find feed versions that can be updated
    queue = []
    Feed.find_each do |feed|
      # Enqueue FeedEater job for feed.find_next_feed_version
      # Skip this feed is tag 'manual_import' is 'true'
      next if feed.tags['manual_import'] == 'true'
      # Use the previous import_level, or default to 2
      import_level ||= feed.active_feed_version.try(:import_level) || 2
      # Find the next feed_version
      next_feed_version = feed.find_next_feed_version(date)
      next unless next_feed_version
      # Return if it's been imported before
      next if next_feed_version.feed_version_imports.last
      # Enqueue
      queue << [feed, next_feed_version, import_level]
    end
    # The maximum number of feeds to enqueue
    max_imports ||= queue.size
    log "enqueue_next_feed_versions: found #{queue.size} feeds to update; max_imports = #{max_imports}"
    # Sort by last_imported_at, asc.
    queue = queue.sort_by { |feed, _, _| feed.last_imported_at }.first(max_imports)
    # Enqueue
    queue.each do |feed, next_feed_version, import_level|
      log "enqueue_next_feed_versions: adding #{feed.onestop_id} #{next_feed_version.sha1} #{import_level}"
      FeedEaterWorker.perform_async(
        feed.onestop_id,
        next_feed_version.sha1,
        import_level
      )
    end
  end

  def self.extend_expired_feed_versions(expired_on_date: nil)
    expired_on_date ||= (DateTime.now + DEFAULT_EXPIRED_ON_DATE)
    feed_versions = FeedVersion.where_active.where('latest_calendar_date <= ?', expired_on_date)
    feed_versions.each do |feed_version|
      self.extend_feed_version(feed_version)
    end
  end

  def self.extend_feed_version(feed_version, extend_from_date: nil, extend_to_date: nil)
    feed = feed_version.feed
    previously_extended = (feed_version.tags || {})["extend_from_date"]
    extend_from_date ||= (feed_version.latest_calendar_date - DEFAULT_EXTEND_FROM_DATE)
    extend_to_date ||= (feed_version.latest_calendar_date + DEFAULT_EXTEND_TO_DATE)
    ssp_total = feed_version.imported_schedule_stop_pairs.count
    ssp_updated = feed_version.imported_schedule_stop_pairs.where('service_end_date >= ?', extend_from_date).count
    log "Feed: #{feed.onestop_id}"
    log "  active_feed_version: #{feed_version.sha1}"
    log "    latest_calendar_date: #{feed_version.latest_calendar_date}"
    log "    ssp total: #{ssp_total}"
    if previously_extended
      log "  already extended, skipping:"
      log "    extend_from_date: #{feed_version.tags['extend_from_date']}"
      log "    extend_to_date: #{feed_version.tags['extend_to_date']}"
    else
      log "  extending:"
      log "    extend_from_date: #{extend_from_date}"
      log "    extend_to_date: #{extend_to_date}"
      log "    ssp to update: #{ssp_updated}"
      feed_version.extend_schedule_stop_pairs_service_end_date(extend_from_date, extend_to_date)
    end
  end

  private

end
