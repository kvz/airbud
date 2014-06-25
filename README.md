<!-- badges/ -->
[![Build Status](https://secure.travis-ci.org/kvz/airbud.png?branch=master)](http://travis-ci.org/kvz/airbud "Check this project's build status on TravisCI")
[![NPM version](http://badge.fury.io/js/airbud.png)](https://npmjs.org/package/airbud "View this project on NPM")
[![Dependency Status](https://david-dm.org/kvz/airbud.png?theme=shields.io)](https://david-dm.org/kvz/airbud)
[![Development Dependency Status](https://david-dm.org/kvz/airbud/dev-status.png?theme=shields.io)](https://david-dm.org/kvz/airbud#info=devDependencies)
<!-- /badges -->

# airbud

![air_bud_-_golden_receiver](https://cloud.githubusercontent.com/assets/26752/3387034/c4cc56d0-fc79-11e3-8d0a-09ef9280bb0f.jpg)

Airbud is a wrapper around [request](https://www.npmjs.org/package/request) with support for for handling JSON, retries with exponential backoff &amp; injecting fixtures. This will save you some boilerplate and allow you to easier test your applications, as they don't have to rely on external HTTP calls.

## Example

Using [environment variables](https://npmjs.org/package/environmental), your test environment can have `GITHUB_ENDPOINT` of `"./fixtures/github-events.json"`, while in production, it's `"https://api.github.com/events"`.

Now just let `Airbud.fetch` the `options.url`: `process.env.GITHUB_ENDPOINT`, and it will either serve the fixture, or the real thing, depending which environment you are in. This makes it easy to test your app's event parsing capabilities, without having to worry about Github ratelimiting, downtime, or sloth when running your tests:

```javascript
Airbud = require("airbud");
opts   = {
  url    : process.env.GITHUB_ENDPOINT,
  retries: 3
};

Airbud.fetch (opts, function (err, events, info) {
  if (err) {
    throw err;
  }

  // Number of attempts
  console.log(info.attempts);
  // Time it took to complete all attempts
  console.log(info.totalDuration);
  // events json is parsed by default
  console.log(events[0].created_at);
});
```

## Install

Inside your project, type

```bash
npm install --save airbud
```

## Options

Here are all of Airbud's options and their default values

```coffeescript
# Automatically parse json
parseJson: true
# How many times to try
retries: 0
# Timeout in milliseconds per try
timeout: null
# Only used to test the timeout mechanism
testDelay: 0
# A key to find in the rootlevel of the parsed json.
# If not found, Airbud will error out
expectedKey: null
```

## Contributing

I'd be happy to accept pull requests. If you plan on working on something big, please first give a shout!

### Building

This project is written in [CoffeeScript](http://coffeescript.org/), but the JavaScript it generates is commited back into the repository so people can use this module without a CoffeeScript dependency. If you want to work on the source, please do so in `./src` and type: `make build` or `make test` (also builds first). Please don't edit generated JavaScript in `./lib`!

### Testing

Check your sources for linting errors via `make lint`, and unit tests via `make test`.

### Releasing

Releasing a new version to npmjs.org can be done via `make release-major` (or minor / patch, depending on the [semantic versioning](http://semver.org/) impact of your changes). This will

 - update the `package.json`
 - save a release commit with the updated version in Git
 - push to Github
 - publish to npmjs.org

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
