require 'csv'
require 'redis'
require 'redis-lock'

class LocalAuthorityDataImporter

  def self.update_all
    redis.lock("publisher:#{Rails.env}:local_authority_data_importer_lock", :life => 2.hours) do
      LocalServiceImporter.update
      LocalInteractionImporter.update
      LocalContactImporter.update
    end
  rescue Redis::Lock::LockNotAcquired => e
    Rails.logger.debug("Failed to get lock for local directgov importing (#{e.message}). Another process probably got there first.")
  end

  def self.redis
    redis_config = YAML.load(ERB.new(File.read(Rails.root.join("config", "redis.yml"))).result)
    Redis.new(redis_config.symbolize_keys)
  end

  def self.update
    fh = fetch_data
    begin
      new(fh).run
    ensure
      fh.close
    end
  end

  def self.fetch_http_to_file(url)
    fh = Tempfile.new(['local_authority_data', 'csv'])
    fh.set_encoding('ascii-8bit')

    uri = URI.parse(url)
    fh.write Net::HTTP.get(uri)

    fh.rewind
    fh.set_encoding('windows-1252', 'UTF-8')
    fh
  end

  def initialize(fh)
    @filehandle = fh
  end

  def run
    CSV.new(@filehandle, headers: true).each do |row|
      begin
        process_row(row)
      rescue => e
        Rails.logger.error "Error #{e.class} processing row in #{self.class}\n#{e.backtrace.join("\n")}"
      end
    end
  end
end
