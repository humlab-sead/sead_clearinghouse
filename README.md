# VISEAD ClearingHouse

A clearinghouse system for the SEAD database including script for reporting and data imports.

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes. See deployment for notes on how to deploy the project on a live system.

### Prerequisites

Just make sure you have `docker` installed.

#### Setup development environment

##### Build and run development PHP-server (Docker image)


Clone the project from source.
```bash
git clone https://github.com/humlab/sead_clearinghouse.git
```
Run webpack in development and watch mode (bundles source files to ./public)
```bash
npm run dev
```
- Download php_xdebug.dll from https://xdebug.org/download.php and copy to PHP extension folder.
- Add to `php.ini`
```
[XDebug]
zend_extension = "path-to-php\ext\php_xdebug.dll"
xdebug.remote_enable = 1
xdebug.remote_autostart = 1
xdebug.remote_port = 9000
xdebug.profiler_output_dir="path-to-temp"
```
- Add file `.clearinghouse.env` with DB credentials (or set environment variables)
```
CH_HOST=database-server
CH_PORT=port
CH_DATABASE=database
CH_USER=username
CH_PASSWORD=password
```
```
% docker build --file dev.Dockerfile -t ch/dev:latest .
% docker run --rm --env-file .docker.env -p 88:88 -p 9000:9000 -v "path-to-local-project"/sead_clearing_house:/home ch/dev:latest
```

#### Setup the clearinghouse database
Follow instructions in `sql/README`. `npm run build:clean-db` does a clean indtall.

## Build application
### Docker image (prefered)
Download latest [Dockerfile](https://github.com/humlab-sead/sead_clearinghouse/raw/master/Dockerfile) (into an empty folder) and build the image from the same folder.
```
wget https://github.com/humlab-sead/sead_clearinghouse/raw/master/Dockerfile
```
Build from scratch using master branch:
```
docker build --no-cache -t clearinghouse/app:latest .
```
Build from specific branch:
```
docker build --build-arg source_branch=branch-name -t clearinghouse/app:latest .
```
Docker will also build from source in current diectory if folder `./src`is present::
```
git clone --branch branch-name --single-branch https://github.com/humlab/sead_clearinghouse.git
docker build -t clearinghouse/app:latest .
```

### Bundled web from source
Compile and bundle the entire web application using `npm`:
```
npm install .
npm run build:release
```
Bundled files are stored in `./public` and is a ready to be deployed web (`./dist` is a compressed version).

## Deployment

### Docker image (preferred)
```bash
sudo docker run --rm --env-file ~/vault/.clearinghouse.env --detach --publish 8060:8060 clearinghouse/app:latest
```
### Bundled source files (deprecated)
1. Copy `./public` folder to target server.
2. Run `start_clearinghouse.bash --build`

## Test

Install [PHPUnit](https://phpunit.de) as described in `https://phpunit.de`.

```bash
$ wget https://phar.phpunit.de/phpunit-x.y.phar
$ chmod +x phpunit-x.y.phar
$ sudo mv phpunit-x.y.phar /usr/local/bin/phpunit
$ phpunit --version
```
For windows
1. Download https://phar.phpunit.de/phpunit-x.y.phar and save the file as phpunit.phar in a folder that exists in PATH.
2. Create `phpunit.cmd` as `echo @php "%~dp0phpunit.phar" %* > phpunit.cmd` (absolute path to php if php not in PATH)
$ phpunit --version
```

## Built With

## Authors

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details

## Acknowledgments

* Hat tip to anyone whose code was used
* Inspiration
* etc
