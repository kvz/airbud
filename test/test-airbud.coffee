should     = require("chai").should()
Fakeserver = require "./fakeserver"
expect     = require("chai").expect
Airbud     = require "../src/airbud"
fixtureDir = "#{__dirname}/fixtures"
fakeserver = new Fakeserver()
port       = 7000

describe "airbud", ->
  @timeout 10000 # <-- This is the Mocha timeout, allowing tests to run longer
  describe "retrieve", ->
    it "should not try to parse JSON by default", (done) ->
      opts =
        url             : fakeserver.createServer(port: ++port)
      Airbud.retrieve opts, (err, data, info) ->
        expect(err).to.be.null
        data.should.equal "{ \"msg\": \"OK\" }"
        info.should.have.property("statusCode").that.equals 202
        info.should.have.property("attempts").that.equals 1
        done()

  describe "json", ->
    it "should be able to take a plain url as options argument", (done) ->
      url = fakeserver.createServer(port: ++port)
      Airbud.json url, (err, data, info) ->
        expect(err).to.be.null
        data.should.have.property("msg").that.equals "OK"
        info.should.have.property("statusCode").that.equals 202
        info.should.have.property("attempts").that.equals 1
        done()

  describe "json", ->
    it "should (re)try 500 HTTP Status 5 times by default", (done) ->
      opts =
        url             : fakeserver.createServer(port: ++port, numberOfFails: 99)
        operationTimeout: 10
        minInterval     : 1
        maxInterval     : 1
      Airbud.json opts, (err, data, info) ->
        err.should.have.property("message").that.match /500/
        info.should.have.property("statusCode").that.equals 500
        info.should.have.property("attempts").that.equals 5
        done()

    it "should be able to get a 500 HTTP Status without error if we're ambivalent about expectedStatus", (done) ->
      opts =
        url           : fakeserver.createServer(port: ++port, numberOfFails: 1)
        retries       : 0
        minInterval   : 1
        maxInterval   : 1
        expectedStatus: [ "xxx" ]
      Airbud.json opts, (err, data, info) ->
        expect(err).to.be.null
        info.should.have.property("statusCode").that.equals 500
        info.should.have.property("attempts").that.equals 1
        data.should.have.property("msg").that.equals "Internal Server Error"
        done()

    it "should retry until we receive an expected HTTP Status", (done) ->
      opts =
        url           : fakeserver.createServer(port: ++port, numberOfFails: 3)
        retries       : 4
        minInterval   : 1
        maxInterval   : 1
        expectedStatus: [ "20x", "30x" ]
      Airbud.json opts, (err, data, info) ->
        expect(err).to.be.null
        info.should.have.property("attempts").that.equals 4
        data.should.have.property("msg").that.equals "OK"
        done()

    it "should follow 301 redirect", (done) ->
      opts =
        url             : fakeserver.createServer(port: ++port, redirect: {1: true})
        expectedStatus  : 200
      Airbud.json opts, (err, data, info) ->
        expect(err).to.be.null
        info.should.have.property("attempts").that.equals 1
        data.should.have.property("msg").that.equals "Arrived at other location"
        done()

    it "should retry if the first operation is too slow", (done) ->
      opts =
        url             : fakeserver.createServer(port: ++port, delay: {1: 1000})
        retries         : 2
        operationTimeout: 500
        minInterval     : 1
        maxInterval     : 1
      Airbud.json opts, (err, data, info) ->
        expect(err).to.be.null
        info.should.have.property("attempts").that.equals 2
        data.should.have.property("msg").that.equals "OK"
        # should be 500 + ~5ms. but depends on inaccurate timeout and 2nd valid request:
        info.should.have.property("totalDuration").that.is.within 500, 600
        done()

    it "should be able to serve a local fixture", (done) ->
      opts =
        url: "file://#{fixtureDir}/root.json"
      Airbud.json opts, (err, data, info) ->
        expect(err).to.be.null
        info.should.have.property("attempts").that.equals 1
        done()

    it "should retry and then fail on not having an expected key in root of local fixture", (done) ->
      opts =
        url        : "file://#{fixtureDir}/root.json"
        minInterval: 1
        maxInterval: 1
        retries    : 1
        expectedKey: "this-key-wont-exist"

      Airbud.json opts, (err, data, info) ->
        info.should.have.property("attempts").that.equals 2
        expect(err).to.match /No key: this-key-wont-exist/
        done()

    it "should fail on not found, with 2 attempts on missing local fixture", (done) ->
      opts =
        url        : "file://#{fixtureDir}/non-existing.json"
        minInterval: 1
        maxInterval: 1
        retries    : 1

      Airbud.json opts, (err, data, info) ->
        info.should.have.property("attempts").that.equals 2
        err.should.have.property("message").that.match /Error while opening/
        done()

    it "should not throw exception for unresolvable domain", (done) ->
      opts =
        minInterval: 1
        maxInterval: 1
        retries    : 1
        url        : "http://asd.asdasdasd.asdfsadf.com/non-existing.json"

      Airbud.json opts, (err, data, info) ->
        info.should.have.property("attempts").that.equals 2
        err.should.have.property("message").that.match /getaddrinfo ENOTFOUND/
        done()

    it "should not throw exception for invalid protocol", (done) ->
      opts =
        minInterval: 1
        maxInterval: 1
        retries    : 1
        url        : "httpasd://example.com/non-existing.json"

      Airbud.json opts, (err, data, info) ->
        info.should.have.property("attempts").that.equals 2
        err.should.have.property("message").that.match /Invalid protocol: httpasd:/
        done()

    it "should not throw exception for invalid json", (done) ->
      opts =
        minInterval: 1
        maxInterval: 1
        retries    : 1
        url        : "file://#{fixtureDir}/invalid.json"

      Airbud.json opts, (err, data, info) ->
        info.should.have.property("attempts").that.equals 2
        err.should.have.property("message").that.match /Got an error while parsing json for file:.*\. SyntaxError: Unexpected token i/
        done()
