require 'redis'
require 'redis-lock'

class CsvReportGenerator
  def self.csv_path
    "#{ENV['GOVUK_APP_ROOT'] || Rails.root}/reports"
  end

  def run!
    redis.lock("publisher:#{Rails.env}:report_generation_lock", :life => 15.minutes) do
      reports.each do |report|
        puts "Generating #{path}/#{report.report_name}.csv"
        report.write_csv(path)
      end

      move_temporary_reports_into_place
    end
  rescue Redis::Lock::LockNotAcquired => e
    Rails.logger.debug("Failed to get lock for report generation (#{e.message}). Another process probably got there first.")
  end

  def reports
    @reports ||= [
      EditorialProgressPresenter.new(
        Edition.not_in(state: ["archived"])),

      BusinessSupportExportPresenter.new(
        BusinessSupportEdition.published.asc("title")),

      OrganisationContentPresenter.new(
        Artefact.where(owning_app: "publisher").not_in(state: ["archived"])),

      EditionChurnPresenter.new(
        Edition.not_in(state: ["archived"]).order(created_at: 1)),

      ContentWorkflowPresenter.new(Edition.published.order(created_at: :desc)),
    ]
  end

  def path
    return @path if @path
    @path = File.join(Dir.tmpdir,
      "publisher_reports-#{Time.zone.now.strftime("%Y%m%d%H%M%S")}-#{Process.pid}")
    FileUtils.mkdir_p(@path)
    return @path
  end

  def move_temporary_reports_into_place
    Dir[File.join(path, "*.csv")].each do |file|
      FileUtils.mv(file, self.class.csv_path, force: true)
    end
  end

  def redis
    redis_config = YAML.load_file(Rails.root.join("config", "redis.yml"))
    Redis.new(redis_config.symbolize_keys)
  end
end