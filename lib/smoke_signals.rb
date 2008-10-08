begin
  gem 'tinder'
rescue Gem::LoadError
  BAR = "=" * 80
  puts "#{BAR}\nError - smoke_signals requires the tinder gem - 'sudo gem install tinder'.  Exiting....\n#{BAR}"
  exit 1
end
require 'tinder'

class SmokeSignals
  VERSION = 1.0
  attr_accessor :room_name

  def initialize(project = nil)
    @project = project
  end

  def self.settings
    YAML.load_file(File.join(RAILS_ROOT, "config", "smoke_signals.yml")) rescue nil
  end

  def settings
    SmokeSignals.settings
  end

  def room
    self.room_name ||= settings["room"]
    return if room_name.nil?
    logger.debug("Campfire Notifier configured with #{settings.inspect}")
    campfire = Tinder::Campfire.new(settings["subdomain"], :ssl => settings["use_ssl"])
    campfire.login settings["login"], settings["password"]
    logger.debug("Logged in to campfire #{settings['subdomain']} as #{settings['login']}")
    campfire.find_room_by_name(room_name)
  rescue => e
    logger.error("Trouble initalizing campfire room #{room_name}")
    raise
  end

  def build_finished(build)
    project = build.project
    clear_flag
    if build.failed?
      build_text = "#{@project.name} build #{build.label} broken"
      build_text << ". Committed by #{project.source_control.latest_revision(project).committed_by}" unless project.nil?
      build_text << ".<br/>See #{build.url} for details."
      @failure_message = build_text
      speak(build_text)
    end
  end

  def build_fixed(build, previous_build=nil)
    clear_flag
    @failure_message = ""
    speak("#{@project.name} build fixed in #{build.label}.")
  end

  def build_loop_failed(error)
    return if flagged? && is_subversion_down?(error)
    if is_subversion_down?(error)
      speak "#{@project.name} build loop failed: Error connecting to Subversion: #{error.message}"
      set_flag
    else
      speak( "#{@project.name} build loop failed with: #{error.class}: #{error.message}")
      speak error.backtrace.join("\n")
    end
  end

  def polling_source_control
    speak(@failure_message) if @failure_message
  end

  def speak(message)
    room.speak(message) unless room_name.nil?
    rescue => e
      logger.error("Error speaking into campfire room #{room_name} for #{@project.name}")
      raise
  end

  def logger
    CruiseControl::Log
  end

  def flagged?
    File.exists?("#{@project.name}.svn_flag")
  end

  def set_flag
    File.open("#{@project.name}.svn_flag","w") do |file|
      file.puts "#{@project.name} subversion down"
    end
  end

  def clear_flag
    return unless flagged?
    File.delete("#{@project.name}.svn_flag")
    speak "Subversion is back"
  end

  def is_subversion_down?(error)
    !(/(svn: PROPFIND request failed|apr_error)/.match(error.message).nil?)
  end

end

Project.plugin :smoke_signals unless SmokeSignals.settings.nil?

