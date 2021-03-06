require 'thread'
module Intrigue
module Task
class TcpBindAndCollect < BaseTask

  include  Intrigue::Task::Server::Listeners

  def self.metadata
    {
      :name => "tcp_bind_and_collect",
      :pretty_name => "TCP Bind And Collect",
      :authors => ["jcran"],
      :description => "Given a set of ports (or all), bind and collect all connections",
      :references => [],
      :type => "discovery",
      :passive => false,
      :allowed_types => ["String"],
      :example_entities =>  [{"type" => "String", "details" => {"name" => "default"}}],
      :allowed_options => [
        {:name => "ports", :regex=> "alpha_numeric", :default => "23,25,53,80,81,110,111,443,5000,7001,8000,8001,8008,8081,8080,8443,10000,10001"},
        {:name => "notify", :regex=> "boolean", :default => true },
        {:name => "create_entity", :regex=> "boolean", :default => true }
      ],
      :created_types => ["String"]
    }
  end

  def run
    super
    bind_and_listen _get_option("ports").split(",")
  end

  def track_connection(c)
    _log "#{c}"
    e = _create_entity("IpAddress",{"name" => c["source_address"], "certificate" => "#{c["source_certificate"]}"}) if _get_option "create_entity"
    _notify "#{c["source_address"]}:#{c["source_port"]} -> #{c["listening_port"]} ```#{c["message"]}```" if _get_option "notify"
  end

  def bind_and_listen(ports=[])

    if ports.empty?
      ports = [23,25,53,80,81,110,111,443,5000,7001,8000,8001,8008,8081,8080,8443,10000,10001]
    end

    # Create threads to listen to each port
    threads = ports.map do |port|
      Thread.new do

        # if ssl server
        if port =~ /443$/ || port == "22"
          _log_good "Creating SSL Listener for port #{port}"
          start_ssl_listener(port) do |c|
            connection_details = {}
            connection_details["timestamp"] = DateTime.now
            connection_details["listening_address"] = "#{c.addr.last}"
            connection_details["listening_port"] = "#{c.addr[1]}"
            connection_details["source_certificate"] = OpenSSL::X509::Certificate.new(c.peer_cert) if c.peer_cert
            connection_details["source_address"] = "#{c.peeraddr.last}"
            connection_details["source_port"] = "#{c.peeraddr[1]}"
            connection_details["message"] = ""
            while (lineIn = c.gets)
              connection_details["message"] << "#{lineIn.chomp}\n"
            end
            c.each_line do |line|

            end
            track_connection connection_details
            c.close
          end
        else
          # if normal
          _log_good "Creating TCP Listener for port #{port}"
          start_tcp_listener(port) do |c|
            connection_details = {}
            connection_details["timestamp"] = DateTime.now
            connection_details["listening_address"] = "#{c.addr.last}"
            connection_details["listening_port"] = "#{c.addr[1]}"
            connection_details["source_address"] = "#{c.peeraddr.last}"
            connection_details["source_port"] = "#{c.peeraddr[1]}"
            connection_details["message"] = ""
            while (lineIn = c.gets)
              connection_details["message"] << "#{lineIn.chomp}\n"
            end
            track_connection connection_details
            c.close
          end
        end
      end
    end

    # Wait for all threads to complete
    threads.map &:join
  end


end
end
end
