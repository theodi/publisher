require 'test_helper'
require 'edition_progressor'

# The EditionProgressor expects to receive a WorkflowActor.
# In our system that's usually a User object, but it doesn't
# have to be. The DummyActor implements just enough behaviour
# to operate as a WorkflowActor without the overhead of creating
# a (database-persisted) User.
class DummyActor
  include WorkflowActor

  def initialize(permissions = [])
    @permissions = permissions
  end

  def id
    "fake-id"
  end
  
  def permissions
    @permissions
  end
  
end

class EditionProgressorTest < ActiveSupport::TestCase
  setup do
    @laura = DummyActor.new
    @publisher = DummyActor.new(['publish'])
    @statsd = stub_everything
    @guide = FactoryGirl.create(:guide_edition, panopticon_id: FactoryGirl.create(:artefact).id)
    @keyworded = FactoryGirl.create(:guide_edition, panopticon_id: FactoryGirl.create(:artefact).id)
    tag = Tag.find_or_create_by(tag_id: "test", title: "test", tag_type: "keyword")
    @artefact = @keyworded.artefact
    @artefact.tags << tag
    @artefact.save
    stub_register_published_content
  end

  test "should be able to progress an item" do
    @guide.update_attribute(:state, :ready)

    activity = {
      :request_type       => "send_fact_check",
      :comment            => "Blah",
      :email_addresses    => "user@example.com",
      :customised_message => "Hello"
    }

    command = EditionProgressor.new(@guide, @laura, @statsd)
    assert command.progress(activity)

    @guide.reload
    assert_equal 'fact_check', @guide.state
  end

  test "should not progress to fact check if the email addresses were blank" do
    @guide.update_attribute(:state, :ready)

    activity = {
      :request_type       => "send_fact_check",
      :comment            => "Blah",
      :email_addresses    => "",
      :customised_message => "Hello"
    }

    command = EditionProgressor.new(@guide, @laura, @statsd)
    refute command.progress(activity)
  end

  test "should not progress to publish if actor doesn't have publish permission" do
    @keyworded.update_attribute(:state, :ready)

    activity = {
      :request_type       => "publish",
      :comment            => "Blah",
      :email_addresses    => "",
      :customised_message => "Hello"
    }

    command = EditionProgressor.new(@keyworded, @laura, @statsd)
    refute command.progress(activity)
  end

  test "should not progress to publish if artefact has no keywords" do
    @guide.update_attribute(:state, :ready)

    activity = {
      :request_type       => "publish",
      :comment            => "Blah",
      :email_addresses    => "",
      :customised_message => "Hello"
    }

    command = EditionProgressor.new(@guide, @publisher, @statsd)
    refute command.progress(activity)
  end

  test "can progress to publish if actor has publish permission and artefact has keywords" do
    @keyworded.update_attribute(:state, :ready)
    
    activity = {
      :request_type       => "publish",
      :comment            => "Blah",
      :email_addresses    => "",
      :customised_message => "Hello"
    }

    command = EditionProgressor.new(@keyworded, @publisher, @statsd)
    assert command.progress(activity)
  end

  test "should not progress to fact check if the email addresses were invalid" do
    @guide.update_attribute(:state, :ready)

    activity = {
      :request_type       => "send_fact_check",
      :comment            => "Blah",
      :email_addresses    => "nouseratexample.com",
      :customised_message => "Hello"
    }

    command = EditionProgressor.new(@guide, @laura, @statsd)
    refute command.progress(activity)
  end
end
