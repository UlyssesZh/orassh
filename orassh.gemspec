# frozen_string_literal: true

require_relative "lib/orassh/version"

Gem::Specification.new do |spec|
	spec.name = "orassh"
	spec.version = Orassh::VERSION
	spec.authors = ["Ulysses Zhan"]
	spec.email = ["UlyssesZhan@gmail.com"]
	
	spec.summary = "Uses GitHub Gist and ngrok to help you connect to your remote computer with SSH."
	spec.description = "A free ngrok account can help you connect to your remote computer over the internet, " +
		"but the URL and port differ each time. " +
		"This tool helps you to automate the task:\n" +
		"- On server: run ngrok, and upload the URL and port to a GitHub Gist file;\n" +
		"- On client: read the URL and port from the GitHub Gist file, and do the previously configured task."
	spec.homepage = "https://github.com/UlyssesZh/orassh"
	spec.license = "MIT"
	spec.required_ruby_version = ">= 3.0.0"
	
	spec.metadata["homepage_uri"] = spec.homepage
	spec.metadata["source_code_uri"] = "https://github.com/UlyssesZh/orassh"
	
	# Specify which files should be added to the gem when it is released.
	# The `git ls-files -z` loads the files in the RubyGem that have been added into git.
	spec.files = Dir.chdir(File.expand_path(__dir__)) do
		`git ls-files -z`.split("\x0").reject do |f|
			(f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
		end
	end
	spec.bindir = "exe"
	spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
	spec.require_paths = ["lib"]
	
	spec.add_dependency "gist", ">= 6.0.0"
	spec.add_dependency "highline", ">= 2.0.0"
	
	# For more information and examples about making a new gem, check out our
	# guide at: https://bundler.io/guides/creating_gem.html
end
