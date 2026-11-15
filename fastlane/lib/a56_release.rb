require "fileutils"
require "cgi"

module A56Release
  ROOT = File.expand_path("../..", __dir__)
  APP_IDENTIFIER = "com.giovannimonaco.TangenzialeNapoli".freeze
  VERSION = "1.0".freeze
  METADATA = File.join(ROOT, "docs/app-store/metadata").freeze
  NOTES = File.join(ROOT, "docs/app-store/review-notes.txt").freeze
  OUTPUT = File.join(ROOT, "build/fastlane").freeze
  FIELD_LIMITS = {
    "name" => 30, "subtitle" => 30, "promotional_text" => 170,
    "description" => 4000, "keywords" => 100
  }.freeze

  def self.validate_metadata!
    fields = FIELD_LIMITS.to_h do |field, limit|
      path = File.join(METADATA, "it", "#{field}.txt")
      raise "Missing Italian metadata field: #{field}" unless File.file?(path)
      value = File.read(path, encoding: "UTF-8").strip
      raise "Empty or invalid Italian metadata field: #{field}" if value.empty? || !value.valid_encoding?
      count = field == "keywords" ? value.bytesize : value.length
      raise "Italian #{field} exceeds #{limit}" if count > limit
      [field, { count: count, limit: limit, value: value }]
    end
    keywords = fields.fetch("keywords").fetch(:value).split(",", -1)
    raise "Empty keyword or surrounding whitespace" unless keywords.all? { |word| !word.empty? && word == word.strip }
    raise "Duplicate keywords" unless keywords.map(&:downcase).uniq.length == keywords.length
    raise "Missing review notes" unless File.file?(NOTES) && !File.read(NOTES, encoding: "UTF-8").strip.empty?
    fields
  end

  def self.archive_path(value = nil)
    File.expand_path(value || ENV["A56_ARCHIVE_PATH"] || File.join(OUTPUT, "A56Napoli.xcarchive"), ROOT)
  end

  def self.export_directory(value = nil)
    File.expand_path(value || ENV["A56_EXPORT_PATH"] || File.join(OUTPUT, "AppStore"), ROOT)
  end

  def self.write_export_options!(directory)
    # Current Xcode export method; destination=export never uploads the product.
    team = ENV["A56_TEAM_ID"].to_s
    raise "A56_TEAM_ID contains invalid characters" unless team.empty? || team.match?(/\A[A-Z0-9]+\z/)
    team_xml = team.empty? ? "" : "<key>teamID</key><string>#{CGI.escapeHTML(team)}</string>"
    FileUtils.mkdir_p(directory)
    path = File.join(directory, "ExportOptions.plist")
    File.write(path, <<~XML)
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0"><dict>
      <key>method</key><string>app-store-connect</string>
      <key>destination</key><string>export</string>
      <key>signingStyle</key><string>automatic</string>
      #{team_xml}
      <key>manageAppVersionAndBuildNumber</key><false/>
      <key>stripSwiftSymbols</key><true/>
      <key>uploadSymbols</key><false/>
      </dict></plist>
    XML
    path
  end
end
