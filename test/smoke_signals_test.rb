require 'rubygems'
require File.dirname(__FILE__) + '/../lib/smoke_signals'
require 'mocha'
require 'test/spec'

describe "SmokeSignals" do
  it "speaks when the build is fixed" do
    notifier = SmokeSignals.new(stub(:name => "project_name"))
    build = stub(:label => "label", :url => "url")
    notifier.expects(:speak).with("project_name build fixed in label.")
    notifier.expects(:clear_flag)
    notifier.build_fixed(build)
  end

  it "speaks when the build fails" do
    notifier = SmokeSignals.new(stub(:name => "project_name"))
    project = stub(:source_control => stub(:latest_revision => stub(:committed_by => "Careless Carl")))
    build = stub(:label => "label", :failed? => true, :url => "http://cc.project.com/builds/Project/label", :project => project)
    notifier.expects(:speak).with("project_name build label broken. Committed by Careless Carl.<br/>See http://cc.project.com/builds/Project/label for details.")
    notifier.expects(:clear_flag)
    notifier.build_finished(build)
  end

  it "recognize apr_error as svn failures" do
    notifier = SmokeSignals.new
    notifier.is_subversion_down?(stub(:message => "apr_error=something")).should == true
  end

  it "recognize PROPFIND request failure as svn failures" do
    notifier = SmokeSignals.new
    notifier.is_subversion_down?(stub(:message => "svn: PROPFIND request failed|apr_error")).should == true
  end

  it "speaks when the build loop fails because of a subversion error" do
    notifier = SmokeSignals.new(stub(:name => "project_name"))
    notifier.stubs(:flagged?).returns(false)
    notifier.expects(:speak).with("project_name build loop failed: Error connecting to Subversion: svn: PROPFIND request failed")
    notifier.expects(:is_subversion_down?).returns(true)
    notifier.expects(:set_flag)
    notifier.build_loop_failed(stub(:message => "svn: PROPFIND request failed"))
  end

  describe 'polling source control event' do
    it 'speaks if there is a failure message' do
      notifier = SmokeSignals.new(stub(:name => "project_name"))
      notifier.instance_variable_set(:@failure_message, "Careless Carl broke the build etc.")
      notifier.expects(:speak)
      notifier.polling_source_control
    end

    it 'is silent without a failure message' do
      notifier = SmokeSignals.new(stub(:name => "project_name"))
      notifier.expects(:speak).never
    end
  end

  it "doesn't spam campfire when failing because it's not an svn error" do
    notifier = SmokeSignals.new(stub_everything)
    notifier.stubs(:flagged?).returns(false)
    notifier.expects(:speak).times(2)
    notifier.expects(:is_subversion_down?).returns(false)
    notifier.build_loop_failed(stub_everything(:backtrace => [:x, :y, :z, :a, :b]))
  end

  it "room is nil if room_name is nil" do
    notifer = SmokeSignals.new
    notifer.stubs(:settings).returns(stub_everything)
    notifer.room_name = nil
    notifer.room.should == nil
  end

  it "delegates settings to the class variable settings" do
    SmokeSignals.stubs(:settings).returns(settings = stub)
    SmokeSignals.new(stub(:name => "project_name")).settings.should == settings
  end
end
