# frozen_string_literal: true

require 'json'

class Certificate
  attr_accessor :name, :domains, :expiration_date, :cert_path, :key_path
  ALLOWED_REMAINING_DAYS = 11

  def initialize(cert_name)
    self.name = cert_name
    self.domains = []
  end

  def expiring?()
    now = Time.new
    days_remaining = (self.expiration_date.to_date - now.to_date).floor
    puts "days_remaining: #{days_remaining}, ALLOWED: #{ALLOWED_REMAINING_DAYS}"
    days_remaining < ALLOWED_REMAINING_DAYS
  end

  def to_json()
    hash = {}
    self.instance_variables.each do |var|
      hash[var] = self.instance_variable_get var
    end
    hash.to_json
  end
end

