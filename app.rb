# frozen_string_literal: true

require 'open3'
require 'time'

require './lib/models/certificate'

class App
  ONE_MINUTE = 60

  def certbot_output()
    @certbot_output ||= begin
      stdout_str, stderr_str, status = Open3.capture3("certbot certificates")
      unless status.success?
        raise "Failed to run 'certbot certificates': #{stderr_str}"
      end
      stdout_str 
    end
  end

  def parse_certs(output)
    certs = []
    current_cert = nil

    output.split("\n").each do |raw_line|
      line = raw_line.strip
      case line
      when /Certificate Name:/
        # We've come to a new certificate.  The previous one should be added to the list.
        unless current_cert.nil?  # unless this is the very first cert (current is nil)
          certs.push(current_cert)
        end
        cert_name = line.split(":")[1].strip
        current_cert = Certificate.new cert_name
      when /Domains:/
        # Domains: alpha.ruiz.house bravo.ruiz.house charlie.ruiz.house
        domain_list = line.split(":")[1].strip
        domain_list.split.each { |domain| current_cert.domains.push(domain) }
      when /Expiry Date:/
        # Expiry Date: 2019-08-12 21:22:55+00:00 (VALID: 23 days)
        right_hand_side = line.split(":", 2)[1]
        timestamp = right_hand_side.split[0..1].join(" ")
        current_cert.expiration_date = Time.parse(timestamp)
      when /Certificate Path:/
        # Certificate Path: /etc/letsencrypt/live/alpha.ruiz.house/fullchain.pem
        path = line.split(":", 2)[1].strip
        current_cert.cert_path = path        
      when /Private Key Path:/
        # Private Key Path: /etc/letsencrypt/live/grafana.ruiz.house/privkey.pem
        path = line.split(":", 2)[1].strip
        current_cert.key_path = path
      end
    end
    # finally, add the last current_cert
    certs.push(current_cert)
  end

  def begin_manual_renewal(cert)
    mgr = RenewalManager.new(cert)
    @ongoing_renewals[cert] = mgr
    mgr.start_renewal
  end

  def create_required_record(record)
  end

  def wait(seconds)
    sleep(seconds)
  end

  def complete_manual_renewal(cert)
    mgr = @ongoing_renewals[cert]
    mgr.complete_renewal()
  end

  def run()
    begin
      config = load_config(ARGV)
      certs = parse_certs(certbot_output)
      expiring_certs = certs.select { |cert| cert.expiring? }
      expiring_certs.each do |cert|
        required_record = begin_manual_renewal(cert)
        create_required_record!(required_record)
        wait(ONE_MINUTE)
        new_cert_info = complete_manual_renewal(cert)
        handle_new_cert(new_cert_info, config)
        puts "#{cert.name} has been renewed!"
      puts "Done renewing expired certs"
    rescue RuntimeError => e
      puts e.message
    end
  end
end

app = App.new
app.run
