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
      airbud = new Airbud
      opts   =
        url             : fakeserver.createServer(port: ++port)
      airbud.retrieve opts, (err, data, meta) ->
        expect(err).to.be.null
        data.should.equal "{ \"msg\": \"OK\" }"
        meta.should.have.property("statusCode").that.equals 202
        meta.should.have.property("attempts").that.equals 1
        done()

  describe "json", ->
    it "should be able to take a plain url as options argument", (done) ->
      airbud = new Airbud
      url    = fakeserver.createServer(port: ++port)
      airbud.json url, (err, data, meta) ->
        expect(err).to.be.null
        data.should.have.property("msg").that.equals "OK"
        meta.should.have.property("statusCode").that.equals 202
        meta.should.have.property("attempts").that.equals 1
        done()

  describe "json", ->
    it "should (re)try 500 HTTP Status 5 times by default", (done) ->
      airbud = new Airbud
      opts   =
        url             : fakeserver.createServer(port: ++port, numberOfFails: 99)
        operationTimeout: 10
        minInterval     : 1
        maxInterval     : 1
      airbud.json opts, (err, data, meta) ->
        err.should.have.property("message").that.match /500/
        meta.should.have.property("statusCode").that.equals 500
        meta.should.have.property("attempts").that.equals 5
        done()

    it "should be able to get a 500 HTTP Status without error if we're ambivalent about expectedStatus", (done) ->
      airbud = new Airbud
      opts   =
        url           : fakeserver.createServer(port: ++port, numberOfFails: 1)
        retries       : 0
        minInterval   : 1
        maxInterval   : 1
        expectedStatus: [ "xxx" ]
      airbud.json opts, (err, data, meta) ->
        expect(err).to.be.null
        meta.should.have.property("statusCode").that.equals 500
        meta.should.have.property("attempts").that.equals 1
        data.should.have.property("msg").that.equals "Internal Server Error"
        done()

    it "should retry until we receive an expected HTTP Status", (done) ->
      airbud = new Airbud
      opts   =
        url           : fakeserver.createServer(port: ++port, numberOfFails: 3)
        retries       : 4
        minInterval   : 1
        maxInterval   : 1
        expectedStatus: [ "20x", "30x" ]
      airbud.json opts, (err, data, meta) ->
        expect(err).to.be.null
        meta.should.have.property("attempts").that.equals 4
        data.should.have.property("msg").that.equals "OK"
        done()

    it "should follow 301 redirect", (done) ->
      airbud = new Airbud
      opts   =
        url             : fakeserver.createServer(port: ++port, redirect: {1: true})
        expectedStatus  : 200
      airbud.json opts, (err, data, meta) ->
        expect(err).to.be.null
        meta.should.have.property("attempts").that.equals 1
        data.should.have.property("msg").that.equals "Arrived at other location"
        done()

    it "should retry if the first operation is too slow", (done) ->
      airbud = new Airbud
      opts   =
        url             : fakeserver.createServer(port: ++port, delay: {1: 1000})
        retries         : 2
        operationTimeout: 500
        minInterval     : 1
        maxInterval     : 1
      airbud.json opts, (err, data, meta) ->
        expect(err).to.be.null
        meta.should.have.property("attempts").that.equals 2
        data.should.have.property("msg").that.equals "OK"
        # should be 500 + ~5ms. but depends on inaccurate timeout and 2nd valid request:
        meta.should.have.property("totalDuration").that.is.within 500, 600
        done()

    it "should be able to serve a local fixture", (done) ->
      airbud = new Airbud
      opts   =
        url: "file://#{fixtureDir}/root.json"
      airbud.json opts, (err, data, meta) ->
        expect(err).to.be.null
        meta.should.have.property("attempts").that.equals 1
        done()

    it "should retry and then fail on not having an expected key in root of local fixture", (done) ->
      airbud = new Airbud
      opts   =
        url        : "file://#{fixtureDir}/root.json"
        minInterval: 1
        maxInterval: 1
        retries    : 1
        expectedKey: "this-key-wont-exist"

      airbud.json opts, (err, data, meta) ->
        meta.should.have.property("attempts").that.equals 2
        expect(err).to.match /No key: this-key-wont-exist/
        done()

    it "should fail on not found, with 2 attempts on missing local fixture", (done) ->
      airbud = new Airbud
      opts   =
        url        : "file://#{fixtureDir}/non-existing.json"
        minInterval: 1
        maxInterval: 1
        retries    : 1

      airbud.json opts, (err, data, meta) ->
        meta.should.have.property("attempts").that.equals 2
        err.should.have.property("message").that.match /Error while opening/
        done()

    it "should not throw exception for unresolvable domain", (done) ->
      airbud = new Airbud
      opts   =
        minInterval: 1
        maxInterval: 1
        retries    : 1
        url        : "http://asd.asdasdasd.asdfsadf.com/non-existing.json"

      airbud.json opts, (err, data, meta) ->
        meta.should.have.property("attempts").that.equals 2
        err.should.have.property("message").that.match /getaddrinfo ENOTFOUND/
        done()

    it "should not throw exception for invalid protocol", (done) ->
      airbud = new Airbud
        minInterval: 1
        maxInterval: 1
        retries    : 1

      airbud.json "httpasd://example.com/non-existing.json", (err, data, meta) ->
        meta.should.have.property("attempts").that.equals 2
        err.should.have.property("message").that.match /Invalid protocol: httpasd:/
        done()

    it "should not throw exception for invalid json", (done) ->
      opts   =
        minInterval: 1
        maxInterval: 1
        retries    : 1
        url        : "file://#{fixtureDir}/invalid.json"

      Airbud.json opts, (err, data, meta) ->
        meta.should.have.property("attempts").that.equals 2
        err.should.have.property("message").that.match /Got an error while parsing json for file:.*\. SyntaxError: Unexpected token i/
        done()
