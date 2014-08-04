should     = require("chai").should()
Fakeserver = require "./fakeserver"
debug      = require("debug")("Airbud:test-airbud")
util       = require "util"
expect     = require("chai").expect
Airbud     = require "../src/Airbud"
fixtureDir = "#{__dirname}/fixtures"
fakeserver = new Fakeserver()
port       = 7000


Airbud.setDefaults
  minInterval: 1
  maxInterval: 1
  retries    : 1

describe "airbud", ->
  @timeout 10000 # <-- This is the Mocha timeout, allowing tests to run longer
  describe "retrieve", ->
    it "should not try to parse JSON by default", (done) ->
      opts =
        url: fakeserver.createServer(port: ++port)
      Airbud.retrieve opts, (err, data, meta) ->
        expect(err).to.be.null
        data.should.equal "{ \"msg\": \"OK\" }"
        meta.should.have.property("statusCode").that.equals 202
        meta.should.have.property("attempts").that.equals 1
        done()

  describe "json", ->
    it "should be able to take a plain url as options argument", (done) ->
      url = fakeserver.createServer(port: ++port)
      Airbud.json url, (err, data, meta) ->
        expect(err).to.be.null
        data.should.have.property("msg").that.equals "OK"
        meta.should.have.property("statusCode").that.equals 202
        meta.should.have.property("attempts").that.equals 1
        done()

    it "should (re)try 500 HTTP Status 5 times", (done) ->
      opts =
        url             : fakeserver.createServer(port: ++port, numberOfFails: 99)
        retries         : 4
        operationTimeout: 10
      Airbud.json opts, (err, data, meta) ->
        err.should.have.property("message").that.match /500/
        meta.should.have.property("statusCode").that.equals 500
        meta.should.have.property("attempts").that.equals 5
        done()

    it "should be able to get a 500 HTTP Status without error if we're ambivalent about expectedStatus", (done) ->
      opts =
        url           : fakeserver.createServer(port: ++port, numberOfFails: 1)
        retries       : 0
        expectedStatus: [ "xxx" ]
      Airbud.json opts, (err, data, meta) ->
        expect(err).to.be.null
        meta.should.have.property("statusCode").that.equals 500
        meta.should.have.property("attempts").that.equals 1
        data.should.have.property("msg").that.equals "Internal Server Error"
        done()

    it "should retry until we receive an expected HTTP Status", (done) ->
      opts =
        url           : fakeserver.createServer(port: ++port, numberOfFails: 3)
        retries       : 4
        expectedStatus: [ "20x", "30x" ]
      Airbud.json opts, (err, data, meta) ->
        expect(err).to.be.null
        meta.should.have.property("attempts").that.equals 4
        data.should.have.property("msg").that.equals "OK"
        done()

    it "should follow 301 redirect", (done) ->
      opts =
        url             : fakeserver.createServer(port: ++port, redirect: {1: true})
        expectedStatus  : 200
      Airbud.json opts, (err, data, meta) ->
        expect(err).to.be.null
        meta.should.have.property("attempts").that.equals 1
        data.should.have.property("msg").that.equals "Arrived at other location"
        done()

    it "should retry if the first operation is too slow", (done) ->
      opts =
        url             : fakeserver.createServer(port: ++port, delay: {1: 400, 2: 400, 3: 1})
        retries         : 2
        operationTimeout: 100
        minInterval     : 1
        maxInterval     : 1
        randomize       : false
      Airbud.json opts, (err, data, meta) ->
        expect(err).to.be.null
        data.should.have.property("msg").that.equals "OK"
        meta.should.have.property("attempts").that.equals 3
        # should be 2x operationTimeout, then the 3rd try is quick. So 101ms, but throwing in some inaccuracy:
        meta.should.have.property("totalDuration").that.is.within 100, 200
        done()

    it "should be able to serve a local fixture", (done) ->
      opts =
        url: "file://#{fixtureDir}/root.json"
      Airbud.json opts, (err, data, meta) ->
        expect(err).to.be.null
        meta.should.have.property("attempts").that.equals 1
        done()

    it "should retry and then fail on not having an expected key in root of local fixture", (done) ->
      opts =
        url        : "file://#{fixtureDir}/root.json"
        expectedKey: "this-key-wont-exist"

      Airbud.json opts, (err, data, meta) ->
        meta.should.have.property("attempts").that.equals 2
        expect(err).to.match /No key: this-key-wont-exist/
        done()

    it "should fail on not found, with 2 attempts on missing local fixture", (done) ->
      opts =
        url: "file://#{fixtureDir}/non-existing.json"

      Airbud.json opts, (err, data, meta) ->
        meta.should.have.property("attempts").that.equals 2
        err.should.have.property("message").that.match /Cannot open/
        done()

    it "should only fire the callback once, no matter how many attempts", (done) ->
      opts =
        retries: 5
        url    : "file://#{fixtureDir}/non-existing.json"

      cnt = 0
      Airbud.json opts, (err, data, meta) ->
        meta.should.have.property("attempts").that.equals 6
        err.should.have.property("message").that.match /Cannot open/
        expect(++cnt).to.equal 1
        done()

    it "should only fire the callback once, even for retries after timeouts", (done) ->
      opts =
        url             : fakeserver.createServer(port: ++port, delay: {1: 1000, 2: 1000})
        retries         : 1
        minInterval     : 1
        maxInterval     : 1
        operationTimeout: 1
        factor          : 1.3524 # 3x in 30 seconds
        expectedStatus: [ 200 ]

      cnt = 0
      Airbud.json opts, (err, data, meta) ->
        err.should.have.property("message").that.match /Operation timeout of 1ms reached/
        meta.should.have.property("attempts").that.equals 2
        expect(++cnt).to.equal 1
        done()

    it "should not throw exception for unresolvable domain", (done) ->
      opts =
        url: "http://asd.asdasdasd.asdfsadf.com/non-existing.json"

      Airbud.json opts, (err, data, meta) ->
        meta.should.have.property("attempts").that.equals 2
        err.should.have.property("message").that.match /getaddrinfo ENOTFOUND/
        done()

    it "should not throw exception for invalid protocol", (done) ->
      opts =
        url: "httpasd://example.com/non-existing.json"

      Airbud.json opts, (err, data, meta) ->
        meta.should.have.property("attempts").that.equals 2
        err.should.have.property("message").that.match /Invalid protocol: httpasd:/
        done()

    it "should not throw exception for invalid json", (done) ->
      opts =
        url: "file://#{fixtureDir}/invalid.json"

      Airbud.json opts, (err, data, meta) ->
        meta.should.have.property("attempts").that.equals 2
        err.should.have.property("message").that.match /Got an error while parsing json for file:.*\. SyntaxError: Unexpected token i/
        done()


    it "should be possible to set global defaults", (done) ->
      Airbud.setDefaults
        retries: 9

      Airbud.json "httpasd://example.com/non-existing.json", (err, data, meta) ->
        meta.should.have.property("attempts").that.equals 10
        err.should.have.property("message").that.match /Invalid protocol: httpasd:/
        done()
