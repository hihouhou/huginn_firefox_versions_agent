require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::FirefoxVersionsAgent do
  before(:each) do
    @valid_options = Agents::FirefoxVersionsAgent.new.default_options
    @checker = Agents::FirefoxVersionsAgent.new(:name => "FirefoxVersionsAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
