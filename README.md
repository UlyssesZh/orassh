# Orassh

A free ngrok account can help you connect to your remote computer over the internet,
but the URL and port differ each time.
This tool helps you to automate the task:

- On server: run ngrok, and upload the URL and port to a GitHub Gist file;
- On client: read the URL and port from the GitHub Gist file, and do the previously configured task.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'orassh'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install orassh

## Usage

Default configuration file is at `~/.config/orassh.yml`.
On the server, make sure to get tunnels set up in the ngrok config file
(default at `~/.config/ngrok/ngrok.yml`).

Use command `orassh -h` to see help for the `orassh` command.

Typical use: configure the tunnel with TCP protocol named as `ssh` in both
Orassh config file and ngrok config file,
and then run
```shell
orassh --server ssh
```
to start the ngrok tunnel.
Then, in other computers, you can SSH to the server using
```shell
orassh ssh
```
as long as the server and the client have the same Gist ID
configured in their Orassh config files. 

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/UlyssesZh/orassh. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/orassh/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Orassh project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/orassh/blob/master/CODE_OF_CONDUCT.md).
