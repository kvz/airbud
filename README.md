<!-- badges/ -->
[![Build Status](https://secure.travis-ci.org/kvz/airbud.png?branch=master)](http://travis-ci.org/kvz/airbud "Check this project's build status on TravisCI")
[![NPM version](http://badge.fury.io/js/airbud.png)](https://npmjs.org/package/airbud "View this project on NPM")
[![Dependency Status](https://david-dm.org/kvz/airbud.png?theme=shields.io)](https://david-dm.org/kvz/airbud)
[![Development Dependency Status](https://david-dm.org/kvz/airbud/dev-status.png?theme=shields.io)](https://david-dm.org/kvz/airbud#info=devDependencies)
<!-- /badges -->


**Consider using <https://github.com/sindresorhus/got> instead, which has a similar purpose but a much larger community to maintain it**

Retrieving stuff from the web is unreliable. Airbud adds retries for production, and fixture support for test.

![air_bud_-_golden_receiver](https://cloud.githubusercontent.com/assets/26752/3387034/c4cc56d0-fc79-11e3-8d0a-09ef9280bb0f.jpg)

Airbud is a wrapper around [request](https://www.npmjs.org/package/request) with support for for handling JSON, retries with exponential backoff &amp; injecting fixtures. This will save you some boilerplate and allow you to easier test your applications.

## Install

Inside your project, type

```bash
npm install --save airbud
```

## Use

To use Airbud, first require it

In JavaScript

```javascript
var Airbud = require('airbud');
```

Or CoffeeScript:

```coffeescript
Airbud = require "airbud"
```

Airbud doesn't care.

### Example: simple

A common usecase is getting remote JSON. By default `Airbud.json` will already:

  - Timeout each single operation in 30 seconds
  - [Retry 5 times over 10 minutes](http://www.wolframalpha.com/input/?i=Sum%5Bx%5Ek+*+5%2C+%7Bk%2C+0%2C+4%7D%5D+%3D+10+*+60+%26%26+x+%3E+0)
  - Return parsed JSON
  - Return `err` if
    - A non-2xx HTTP code is returned (3xx redirects are followed first)
    - The json could not be parsed

In CoffeeScript:

```coffeescript
Airbud.json "https://api.github.com/events", (err, events, meta) ->
  if err
    throw err
  console.log events[0].created_at
```

### Example: local JSON fixtures

Say you're writing an app that among things, retrieves public events from the GitHub API.

Using [environment variables](https://github.com/kvz/environmental), your production environment will have a `GITHUB_EVENTS_ENDPOINT` of `"https://api.github.com/events"`, but when you `source envs/test.sh`, it can be `"file://./fixtures/github-events.json"`.

Now just let `Airbud.retrieve` the `process.env.GITHUB_EVENTS_ENDPOINT`, and it will either retrieve the fixture, or the real thing, depending which environment you are in.

This makes it easy to test your app's depending functions, without having to worry about GitHub ratelimiting, downtime, or sloth when running your tests. All of this without making your app aware, or changing it's flow. In JavaScript:

```javascript
var opts   = {
  url: process.env.GITHUB_EVENTS_ENDPOINT,
};

Airbud.json(opts, function (err, events, meta) {
  if (err) {
    throw err;
  }

  console.log('Number of attempts: '+ meta.attempts);
  console.log('Time it took to complete all attempts: ' + meta.totalDuration);
  console.log('Some auto-parsed JSON: ' + events[0].created_at);
});
```

### Example: customize

You don't have to use environment vars or the local fixture feature. You can also use Airbud as a wrapper around request to profit from retries with exponential backoffs. Here's how to customize the retry flow in CoffeeScript:

```coffeescript
opts =
  retries         : 3
  randomize       : true
  factor          : 3
  minInterval     : 3  * 1000
  maxInterval     : 30 * 1000
  operationTimeout: 10 * 1000
  expectedStatus  : /^[2345]\d{2}$/
  expectedKey     : "status"
  url             : "https://api.github.com/events"

Airbud.retrieve opts, (err, events, meta) ->
  if err
    throw err

  console.log events
```


### Example: 3 retries in one minute, retry after 3s timeout for each operation

```coffeescript
opts =
  url             : "https://api2.transloadit.com/instances"
  retries         : 2
  factor          : 1.73414
  expectedKey     : "instances"
  operationTimeout: 3000
```

Some other tricks up Airbud's sleeves are `expectedKey` and `expectedStatus`, to make it error out when you get invalid data, without you writing all the extra `if` and maybes.


## Options

Here are all of Airbud's options and their default values.

```coffeescript
# Timeout of a single operation
operationTimeout: 30000

# Retry 5 times over 10 minutes
# http://www.wolframalpha.com/input/?i=Sum%5Bx%5Ek+*+5%2C+%7Bk%2C+0%2C+4%7D%5D+%3D+10+*+60+%26%26+x+%3E+0
# The maximum amount of times to retry the operation
retries: 4

# The exponential factor to use
factor: 2.99294

# The number of milliseconds before starting the first retry
minInterval: 5 * 1000

# The maximum number of milliseconds between two retries
maxInterval: Infinity

# Randomizes the intervals by multiplying with a factor between 1 to 2
randomize: true

# Automatically parse json
parseJson: null

# A key to find in the rootlevel of the parsed json.
# If not found, Airbud will error out
expectedKey: null

# An array of allowed HTTP Status codes. If specified,
# Airbud will error out if the actual status doesn't match.
# 30x redirect codes are followed automatically.
expectedStatus: "20x"

# Custom headers to submit in the request
headers: []
```

## Meta

Besides, `err`, `data`, Airbud returns a third argument `meta`. It contains some meta data about the operation(s) for your convenience.

```coffeescript
# The HTTP status code returned
statusCode
# An array of all errors that occured
errors
# Number of attempts before Airbud was able to retrieve, or gave up
attempts
# Total duration of all attempts
totalDuration
# Average duration of a single attempt
operationDuration
```

## Contribute

I'd be happy to accept pull requests. If you plan on working on something big, please first give a shout!

### Compile

This project is written in [CoffeeScript](http://coffeescript.org/), but the JavaScript it generates is commited back into the repository so people can use this module without a CoffeeScript dependency. If you want to work on the source, please do so in `./src` and type: `make build` or `make test` (also builds first). Please don't edit generated JavaScript in `./lib`!

### Test

Run tests via `make test`.

To single out a test use `make test GREP=30x`

### Release

Releasing a new version to npmjs.org can be done via `make release-major` (or minor / patch, depending on the [semantic versioning](http://semver.org/) impact of your changes). This:

 - updates the `package.json`
 - saves a release commit with the updated version in Git
 - pushes to GitHub
 - publishes to npmjs.org

## Authors

* [Kevin van Zonneveld](https://twitter.com/kvz)

## License

[MIT Licensed](LICENSE).

## Sponsor Development

Like this project? Consider a donation.
You'd be surprised how rewarding it is for me see someone spend actual money on these efforts, even if just $1.

<!-- badges/ -->
[![Gittip donate button](http://img.shields.io/gittip/kvz.png)](https://www.gittip.com/kvz/ "Sponsor the development of airbud via Gittip")
[![Flattr donate button](http://img.shields.io/flattr/donate.png?color=yellow)](https://flattr.com/submit/auto?user_id=kvz&url=https://github.com/kvz/airbud&title=airbud&language=&tags=github&category=software "Sponsor the development of airbud via Flattr")
[![PayPal donate button](http://img.shields.io/paypal/donate.png?color=yellow)](https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=kevin%40vanzonneveld%2enet&lc=NL&item_name=Open%20source%20donation%20to%20Kevin%20van%20Zonneveld&currency_code=USD&bn=PP-DonationsBF%3abtn_donate_SM%2egif%3aNonHosted "Sponsor the development of airbud via Paypal")
[![BitCoin donate button](http://img.shields.io/bitcoin/donate.png?color=yellow)](https://coinbase.com/checkouts/19BtCjLCboRgTAXiaEvnvkdoRyjd843Dg2 "Sponsor the development of airbud via BitCoin")
<!-- /badges -->
