# frozen_string_literal: true

require 'yaml'
require 'json'
require 'open3'
require 'net/http'
require 'gist'
require_relative "orassh/version"

def Gist.get_gist_content id, file_name = nil
	url = "#{base_path}/gists/#{id}"
	
	access_token = auth_token()
	
	request = Net::HTTP::Get.new(url)
	request['Authorization'] = "token #{access_token}" if access_token.to_s != ''
	response = http(api_url, request)
	
	if response.code == '200'
		body = JSON.parse(response.body)
		files = body["files"]
		
		if file_name
			file = files[file_name]
			raise Gist::Error, "Gist with id of #{id} and file #{file_name} does not exist." unless file
		else
			file = files.values.first
		end
		
		file["content"]
	else
		raise Gist::Error, "Gist with id of #{id} does not exist."
	end
end

class Orassh::NgrokNotFoundError < StandardError
end

class Orassh::NgrokBadConfigError < StandardError
end

class Orassh::ConfigNotFoundError < StandardError
end

class Orassh::MissingConfigItemError < StandardError
end

class Orassh::ConfigSyntaxError < StandardError
end

class Orassh::UnknownTunnelError < StandardError
end

class Orassh::GitHubTokenNotFoundError < Orassh::MissingConfigItemError
end

class Orassh::TunnelsNotSpecifiedError < Orassh::MissingConfigItemError
end

class Orassh::MissingGistIdError < Orassh::MissingConfigItemError
end

class Orassh::TunnelNotAvailable < StandardError
end

class Orassh::CommandNotSpecified < Orassh::MissingConfigItemError
end

Orassh::DEFAULT_NGROK_CONFIG = case
                               when /cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM
	                               File.expand_path '~/AppData/Local/ngrok/ngrok.yml'
                               when /darwin/ =~ RUBY_PLATFORM
	                               File.expand_path '~/Library/Application Support/ngrok/ngrok.yml'
                               else
	                               File.expand_path '~/.config/ngrok/ngrok.yml'
                               end

Orassh::DEFAULT_CONFIG = <<YAML
gist_id: YOUR_GIST_ID
gist_filename: YOUR_FILENAME.json
server:
  github_token: YOUR_GITHUB_TOKEN
  ngrok_command: ngrok
  ngrok_webhook_url: http://localhost:4040
  ngrok_config:
  - "#{Orassh::DEFAULT_NGROK_CONFIG}"
client:
  tunnels:
    ssh:
      command: ssh -p {PORT} {DOMAIN}
    jupyter-notebook:
      command: xdg-open {URL}
YAML

class << Orassh
	
	attr_reader :config, :gist_id, :gist_filename
	
	def load_config path
		begin
			@config = YAML.load_file path
		rescue Errno::ENOENT
			raise Orassh::ConfigNotFoundError, "Config file is not found at #{path}"
		rescue JSON::ParserError => e
			raise Orassh::ConfigSyntaxError, e.message
		end
		unless @gist_id = @config['gist_id']
			raise Orassh::MissingGistIdError, '`gist_id` is not specified in config'
		end
		@gist_filename = @config['gist_filename'] || 'orassh.json'
	end
end

class << Orassh::Server = Module.new
	
	attr_accessor :ngrok_command, :ngrok_config, :github_token, :ngrok_tunnels, :tunnels
	attr_reader :ngrok_pid, :ngrok_webhook_url, :api_tunnels_list, :processed_tunnels
	
	def load_config path
		Orassh.load_config path
		@ngrok_command = Orassh.config['server']['ngrok_command'] || 'ngrok'
		@ngrok_config = Orassh.config['server']['ngrok_config'] || [Orassh::DEFAULT_NGROK_CONFIG]
		unless @github_token = Orassh.config['server']['github_token']
			raise Orassh::GitHubTokenNotFoundError, 'GitHub token is not specified'
		end
		@ngrok_webhook_url = Orassh.config['server']['ngrok_webhook_url'] || 'http://localhost:4040'
		check_ngrok
		load_ngrok_config
		check_tunnels
	end
	
	def check_ngrok
		case system @ngrok_command, 'config', 'check', '--config', *@ngrok_config
		when nil
			raise Orassh::NgrokNotFoundError, 'Failed to execute `ngrok` command'
		when false
			raise Orassh::NgrokBadConfigError, 'Bad ngrok config file; run `ngrok config check` to see details'
		end
	end
	
	def load_ngrok_config
		@ngrok_tunnels = {}
		@ngrok_config.each do |path|
			tunnels = YAML.load_file(path)['tunnels']
			@ngrok_tunnels.merge! tunnels if tunnels
		end
	end
	
	def check_tunnels
		if !@tunnels || @tunnels.empty?
			raise Orassh::TunnelsNotSpecifiedError, 'Tunnels are not specified'
		end
		@tunnels.each do |name|
			unless @ngrok_tunnels.has_key? name
				raise Orassh::UnknownTunnelError,  "Unknown tunnel #{name}"
			end
		end
	end
	
	def start_tunnels
		@ngrok_pid = spawn @ngrok_command, 'start', *@tunnels, '--config', *@ngrok_config, out: File::NULL
		begin
			@api_tunnels_list = JSON.parse(Net::HTTP.get URI "#@ngrok_webhook_url/api/tunnels")['tunnels']
		rescue Errno::ECONNREFUSED
			next
		end until @api_tunnels_list&.size == @tunnels.size
		@processed_tunnels = @api_tunnels_list.each_with_object({}) do |tunnel_data, hash|
			match_data = /(?<proto>[a-z]+):\/\/(?<domain>(\w+[\-.])+\w+)(:(?<port>\d+))?/.match tunnel_data['public_url']
			hash[tunnel_data['name']] = {
				'id' => tunnel_data['ID'],
				'proto' => match_data[:proto],
				'domain' => match_data[:domain],
				'port' => match_data[:port],
				'addr' => tunnel_data['config']['addr'],
				'url' => tunnel_data['public_url']
			}
		end
	end
	
	def send_tunnel_data
		Gist.gist JSON.generate(@processed_tunnels),
		          access_token: @github_token, update: Orassh.gist_id, filename: Orassh.gist_filename
	end
	
	def run config_path, tunnels
		@tunnels = tunnels
		load_config config_path
		start_tunnels
		begin
			send_tunnel_data
		rescue Gist::Error => e
			Process.kill 'INT', @ngrok_pid
			raise e
		end
		puts @processed_tunnels.to_yaml
		begin
			Process.wait @ngrok_pid
		rescue Interrupt
			Process.kill 'INT', @ngrok_pid
		end
	end
end

class << Orassh::Client = Module.new
	attr_accessor :configured_tunnels, :processed_tunnels
	
	def load_config config_path
		Orassh.load_config config_path
		@configured_tunnels = Orassh.config['client']['tunnels'] || {}
	end
	
	def receive_tunnel_data
		@processed_tunnels = JSON.parse Gist.get_gist_content Orassh.gist_id, Orassh.gist_filename
	end
	
	def run_task tunnel
		unless configured_tunnel = @configured_tunnels[tunnel]
			raise Orassh::UnknownTunnelError, "Unknown tunnel '#{tunnel}'"
		end
		unless processed_tunnel = @processed_tunnels[tunnel]
			raise Orassh::TunnelNotAvailable, "Information about tunnel '#{tunnel}' cannot be found on Gist"
		end
		unless command = configured_tunnel['command']
			raise Orassh::CommandNotSpecified, "Command is not specified for tunnel '#{tunnel}'"
		end
		command.gsub! '{NAME}', tunnel
		command.gsub! '{ID}', processed_tunnel['id'].to_s
		command.gsub! '{PROTO}', processed_tunnel['proto'].to_s
		command.gsub! '{DOMAIN}', processed_tunnel['domain'].to_s
		command.gsub! '{PORT}', processed_tunnel['port'].to_s
		command.gsub! '{ADDR}', processed_tunnel['addr'].to_s
		command.gsub! '{URL}', processed_tunnel['url'].to_s
		command.gsub! '\}', '}'
		system command
	end
	
	def run config_path, tunnels
		load_config config_path
		begin
			receive_tunnel_data
		rescue JSON::ParserError, Gist::Error => e
			raise e
		end
		tunnels.each { run_task _1 }
	end
end
