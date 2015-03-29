# WinRM::Transport

[![Gem Version](https://badge.fury.io/rb/winrm-transport.svg)](http://badge.fury.io/rb/winrm-transport)
[![Build Status](https://secure.travis-ci.org/test-kitchen/winrm-transport.svg?branch=master)](https://travis-ci.org/test-kitchen/winrm-transport)
[![Code Climate](https://codeclimate.com/github/test-kitchen/winrm-transport.svg)](https://codeclimate.com/github/test-kitchen/winrm-transport)
[![Dependency Status](https://gemnasium.com/test-kitchen/winrm-transport.svg)](https://gemnasium.com/test-kitchen/winrm-transport)
[![Inline docs](http://inch-ci.org/github/test-kitchen/winrm-transport.svg?branch=master)](http://inch-ci.org/github/test-kitchen/winrm-transport)

WinRM transport logic for re-using remote shells and uploading files. The original code was extracted from the [Test Kitchen][test_kitchen] project and remains the primary reference use case.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'winrm-transport'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install winrm-transport

## Usage

This a library gem and doesn't have any CLI commands. There are 2 primary object classes:

* [WinRM::Transport::CommandExecutor][command_executor]: an object which can
  execute multiple commands and PowerShell script in one shared remote shell
  session.
* [WinRM::Transport::FileTransporter][file_transporter]: an object which can
  upload one or more files or directories to a remote host over WinRM only
  using PowerShell scripts and CMD commands.

## Versioning

WinRM::Transport aims to adhere to [Semantic Versioning 2.0.0][semver].

## Development

* Source hosted at [GitHub][repo]
* Report issues/questions/feature requests on [GitHub Issues][issues]

After checking out the repo, run `bin/setup` to install dependencies. Then, run
`bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Pull requests are very welcome! Make sure your patches are well tested.
Ideally create a topic branch for every separate change you make. For
example:

1. Fork it ( https://github.com/test-kitchen/winrm-transport/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Authors

Created and maintained by [Fletcher Nichol][fnichol] (<fnichol@nichol.ca>) and
a growing community of [contributors][contributors].

## License

Apache License, Version 2.0 (see [LICENSE.txt][license])

[command_executor]: https://github.com/test-kitchen/winrm-transport/blob/master/lib/winrm/transport/command_executor.rb
[contributors]: https://github.com/test-kitchen/winrm-transport/graphs/contributors
[file_transporter]: https://github.com/test-kitchen/winrm-transport/blob/master/lib/winrm/transport/file_transporter.rb
[fnichol]: https://github.com/fnichol
[issues]: https://github.com/test-kitchen/winrm-transpor/issues
[license]: https://github.com/test-kitchen/winrm-transport/blob/master/LICENSE.txt
[repo]: https://github.com/test-kitchen/winrm-transport
[semver]: http://semver.org/
[test_kitchen]: http://kitchen.ci
