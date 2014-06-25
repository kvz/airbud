should = require("chai").should()
expect = require("chai").expect
Airbud = require "../src/airbud"

fixtureDir = "#{__dirname}/fixtures"

describe "endpoint", ->
  @timeout 10000

  describe "fetch", ->
    it "should not return an error for an existing endpoint", (done) ->
      opts =
        url: "file://#{fixtureDir}/root.json"
      Airbud.fetch opts, (err, data, info) ->
        expect(err).to.be.null
        info.should.have.property("attempts").that.equals 1
        done()

    it "should fail on not having a desired key in body", (done) ->
      opts =
        url        : "file://#{fixtureDir}/root.json"
        expectedKey: "this-key-wont-exist"

      Airbud.fetch opts, (err, data, info) ->
        expect(err).to.match /No key: this-key-wont-exist/
        done()

    it "should fail on not found, with 2 attempts", (done) ->
      opts =
        url       : "file://#{fixtureDir}/non-existing.json"
        minTimeout: 1 * 1000
        maxTimeout: 2 * 1000
        retries   : 1

      Airbud.fetch opts, (err, data, info) ->
        info.should.have.property("attempts").that.equals 2
        info.should.have.property("totalDuration").that.is.within opts.minTimeout, opts.maxTimeout
        err.should.have.property("message").that.match /Error while opening/
        done()

    it "should retry and fail on long execution", (done) ->
      opts =
        url      : "file://#{fixtureDir}/root.json"
        testDelay: 100
        timeout  : 50
        retries  : 1

      Airbud.fetch opts, (err, data, info) ->
        err.should.have.property("message").that.match /Operation timeout of \d+ms reached/
        info.should.have.property("attempts").that.equals 2
        info.should.have.property("totalDuration").that.is.within 97, 103
        #         should be 100. but allow for timer inaccuracy --^
        done()
