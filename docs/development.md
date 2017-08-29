# Development

## Install Ruby
Install the latest Ruby. It is recommended to to use RVM for installing the latest Ruby version ([rvm.io](http://rvm.io/))

## Install required OS packages
#### CentOS/RHEL
```bash
$ sudo yum install gcc gcc-c++ ruby-devel mysql-devel postgresql-devel postgresql-libs sqlite-devel libxslt-devel libxml2-devel yajl-ruby patch openssl genisoimage
```

#### Ubuntu
```bash
$ sudo apt-get install -y build-essential zlibc zlib1g-dev ruby-dev openssl libxslt-dev libxml2-dev libssl-dev libreadline6 libreadline6-dev libyaml-dev libsqlite3-dev libxslt1-dev libpq-dev libmysqlclient-dev zlib1g-dev genisoimage
```

## Install the bosh cli
```bash
$ gem install bosh_cli --no-ri --no-rdoc
```

## Upload blobs
```bash
$ bosh add blob ../blobs/acropolis_cpi_mkisofs/patch-include_schily_sha2.h acropolis_cpi_mkisofs
$ bosh add blob ../blobs/acropolis_cpi_mkisofs/smake-1.2.4.tar.bz2 acropolis_cpi_mkisofs
$ bosh add blob ../blobs/acropolis_cpi_mkisofs/cdrtools-3.00.tar.bz2 acropolis_cpi_mkisofs
$ bosh add blob ../blobs/acropolis_ruby/bundler-1.11.2.gem acropolis_cpi_ruby
$ bosh add blob ../blobs/acropolis_ruby/bundler-1.12.4.gem acropolis_cpi_ruby
$ bosh add blob ../blobs/acropolis_ruby/ruby-2.2.4.tar.gz acropolis_cpi_ruby
$ bosh add blob ../blobs/acropolis_ruby/ruby-2.3.1.tar.gz acropolis_cpi_ruby
$ bosh add blob ../blobs/acropolis_ruby/rubygems-2.6.2.tgz acropolis_cpi_ruby
$ bosh add blob ../blobs/acropolis_ruby/rubygems-2.6.7.tgz acropolis_cpi_ruby
$ bosh add blob ../blobs/acropolis_ruby/yaml-0.1.5.tar.gz acropolis_cpi_ruby

$ bosh upload blobs
```
Ensure that blobs match with those in ```config\blobs.yml``` by running the following command:
```
bosh blobs
```
## Install bundler
The release requires the Ruby gem Bundler (used by the vendoring script):
```
gem install bundler
```
Navigate to ```CPI_DIR/src/acropolis_cpi/```

With bundler installed, run the vendoring script:
```bash
$ chmod +x vendor_gems
$ ./vendor_gems
```
## Creating a dev release
Run the following command to create a dev release
```bash
$ bosh create release --force --with-tarball --name bosh-acropolis-cpi
```

## Running tests
### Unit tests:
```bash
bundle exec rspec spec/unit
```

### Integration tests:

Edit ```config.yml``` present in ```spec/assets``` before executing the integration test suite
```bash
bundle exec rspec spec/integration
```
