request = require "request"
fs      = require "fs"
retry   = require "retry"

class Airbud
  @retrieve: (options, cb) ->
    if typeof options == "string"
      options = url: options

    airbud = new AirbudInstance options
    return airbud.retrieve cb

  @json: (options, cb) ->
    if typeof options == "string"
      options = url: options

    options.parseJson = true

    airbud = new AirbudInstance options
    return airbud.retrieve cb

class AirbudInstance
  constructor: ({
    @url,
    @operationTimeout,
    @retries,
    @factor,
    @minInterval,
    @maxInterval,
    @randomize,
    @parseJson,
    @expectedKey,
    @expectedStatus,
  } = {}) ->
    # The URL to retrieve
    @url ?= null

    # Timeout of a single operation
    @operationTimeout ?= 30000

    # Retry 5 times over 10 minutes
    # http://www.wolframalpha.com/input/?i=Sum%5Bx%5Ek+*+5%2C+%7Bk%2C+0%2C+4%7D%5D+%3D+10+*+60+%26%26+x+%3E+0
    # The maximum amount of times to retry the operation
    @retries ?= 4

    # The exponential factor to use
    @factor ?= 2.99294

    # The number of milliseconds before starting the first retry
    @minInterval ?= 5 * 1000

    # The maximum number of milliseconds between two retries
    @maxInterval ?= Infinity

    # Randomizes the intervals by multiplying with a factor between 1 to 2
    @randomize ?= true

    # Automatically parse json
    @parseJson ?= null

    # A key to find in the rootlevel of the parsed json.
    # If not found, Airbud will error out
    @expectedKey ?= null

    # An array of allowed HTTP Status codes. If specified,
    # Airbud will error out if the actual status doesn't match
    @expectedStatus ?= "20x"

    # Validate
    if !@url
      err = new Error "You did not specify a url to retrieve"
      return cb err

    # Normalize expectedStatus as we allow these input formats:
    #  - RegExp
    #  - 200
    #  - "20x"
    #  - [ "20x", "40x" ]
    #  - "xxx"
    if @expectedStatus? and @expectedStatus not instanceof RegExp
      if @expectedStatus not instanceof Array
        @expectedStatus = [ @expectedStatus ]
      @expectedStatus = @expectedStatus
        .join("|")
        .replace /x/g, "\\d"
      @expectedStatus = new RegExp "^#{@expectedStatus}$"

  retrieve: (cb) ->
    operation = retry.operation
      retries   : @retries
      factor    : @factor
      minTimeout: @minInterval
      maxTimeout: @maxInterval
      randomize : @randomize

    # Setup timeouts for single operation
    cbOperationTimeout = null
    if @operationTimeout?
      cbOperationTimeout =
        timeout: @operationTimeout
        cb: ->
          msg = "Operation timeout of #{@operationTimeout}ms reached."
          err = new Error msg
          return operation.retry err

    totalStart         = +new Date
    operationDurations = 0
    operation.attempt (currentAttempt) =>
      operationStart = +new Date
      @_execute (err, data, res) ->
        operationDurations += +new Date - operationStart
        if operation.retry(err)
          return

        totalDuration = +new Date - totalStart
        info          =
          statusCode       : res?.statusCode
          errors           : operation.errors()
          attempts         : operation.attempts()
          totalDuration    : totalDuration
          operationDuration: operationDurations / operation.attempts()
        returnErr = if err then operation.mainError() else null
        cb returnErr, data, info
    , cbOperationTimeout

  _execute: (cb) ->
    if @url.indexOf("file://") == 0
      # Url can also be local json to inject test fixtures
      path = @url.substr(7, @url.length).split("?")[0]
      fs.readFile path, "utf8", (err, buf) =>
        if err
          returnErr = new Error "Error while opening #{path}. #{err.message}"
          return cb returnErr
        return @_handleData buf, {}, cb
      return

    request.get @url, (err, res, buf) =>
      if err
        return cb err, buf, res

      if @expectedStatus?
        if not @expectedStatus.test(res.statusCode + "")
          msg  = "HTTP Status #{res.statusCode} received when fetching '#{@url}'. "
          msg += "Expected: #{@expectedStatus}. #{(buf + "").substr(0, 30)}.."
          err  = new Error msg
          return cb err, buf, res

      return @_handleData buf, res, cb

  _handleData: (buf, res, cb) ->
    data = buf

    if !@parseJson
      return cb null, data, res

    try
      data = JSON.parse data
    catch e
      e.message = "Got an error while parsing json for #{@url}. #{e}"
      return cb e, data, res

    if @expectedKey? && !data[@expectedKey]?
      msg  = "Invalid body received when fetching '#{@url}'. \n"
      msg += "No key: #{@expectedKey}. #{buf}"
      err  = new Error msg
      return cb err, data, res

    cb null, data, res

module.exports = Airbud
