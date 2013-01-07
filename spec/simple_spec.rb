require 'spec_helper'

describe "samples/Code.png" do
  subject{ cli(sample("Code.png")) }
  it { should include("QkJCQjIAAACR2PFtcCA6q2eaC8SR+8dmD/zNzLQC+td3tFQ4qx8O447TDeuZw5P+0SsbEcYR\n78jKLw==".inspect) }
end

describe "samples/stg300.png" do
  subject{ cli(sample("stg300.png")) }
  it { should include("Congrats") }
  it { should include("4E34B38257200616FB75CD869B8C3CF0") }
end

describe "samples/06_enc.png" do
  subject{ cli(sample("06_enc.png")) }
  it { should include("Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod") }
end

describe "samples/montenach-enc.png" do
  subject{ cli(sample("montenach-enc.png")) }
  it { should include("48300:TG9yZW0gaXBzdW0gZG9sb3Igc2l0IGFtZXQsIGNvbnNlY3RldHVyIGFkaXBp") }
end
