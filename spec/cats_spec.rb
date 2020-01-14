require 'spec_helper'

describe "cats.png" do
  subject{ cli(sample("cats.png")) }

  it "size should be < 4k" do
    subject.size.should < 4_000
  end

  it "should get 2nd cat" do
    should include("Second cat is Marussia")
  end

  it "should get 3rd cat" do
    should include("Hello, third kitten is Bessy")
  end

  it "should get 4th cat" do
    should include("Fourth and last cat is Luke")
  end

  it "should get hint" do
    should include("Good, but look a bit deeper...")
  end
end
