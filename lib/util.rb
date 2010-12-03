module Oboe
  def self.passthrough?
    ["always", "through"].include?(Oboe::Config[:tracing_mode])
  end

  def self.always?
      Oboe::Config[:tracing_mode] == "always"
  end

  def self.through?
      Oboe::Config[:tracing_mode] == "through"
  end

  def self.never?
      Oboe::Config[:tracing_mode] == "never"
  end
end
