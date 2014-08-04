request = require "request"
fs      = require "fs"
retry   = require "retry"

class Airbud
  @_defaults:
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

  @getDefaults: ->
    return Airbud._defaults

  @setDefaults: (options) ->
    for key, val of options
      Airbud._defaults[key] = val

  @json: (options, cb) ->
    airbud = new Airbud options, parseJson: true

    Airbud.retrieve airbud, cb

  @retrieve: (options, cb) ->
    if options instanceof Airbud
      airbud = options
    else
      airbud = new Airbud options

    try
      airbud.fetch cb
    catch err
      err.message = "Got an error while retrieving #{airbud.url}. #{err}"
      cb err

  constructor: (optionSets...) ->
    optionSets.unshift Airbud.getDefaults()

    for options in optionSets
      if typeof options == "string"
        options = url: options

      for key, val of options
        this[key] = val

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
        .join "|"
        .replace /x/g, "\\d"
      @expectedStatus = new RegExp "^#{@expectedStatus}$"

  fetch: (mainCb) ->
    operation = retry.operation
      retries   : @retries
      factor    : @factor
      minTimeout: @minInterval
      maxTimeout: @maxInterval
      randomize : @randomize

    # Setup timeouts for single operation
    cbOperationTimeout = null
    timeoutErr         = null

    if @operationTimeout?
      cbOperationTimeout =
        timeout: @operationTimeout
        cb     : =>
          msg        = "Operation timeout of #{@operationTimeout}ms reached."
          timeoutErr = new Error msg

    totalStart         = +new Date
    operationDurations = 0
    operation.attempt (currentAttempt) =>
      operationStart = +new Date
      @_execute (err, data, res) ->
        operationDurations += +new Date - operationStart

        if timeoutErr
          err = timeoutErr

        timeoutErr = null

        if operation.retry(err)
          return

        totalDuration = +new Date - totalStart
        meta          =
          statusCode       : res?.statusCode
          errors           : operation.errors()
          attempts         : operation.attempts()
          totalDuration    : totalDuration
          operationDuration: operationDurations / operation.attempts()
        returnErr = if err then operation.mainError() else null
        mainCb returnErr, data, meta
    , cbOperationTimeout

  _execute: (cb) ->
    # Validate
    if !@url
      err = new Error "You did not specify a url to fetch"
      return cb err

    if @url.indexOf("file://") == 0
      # Url can also be local json to inject test fixtures
      path = @url.substr(7, @url.length).split("?")[0]
      fs.readFile path, "utf8", (err, buf) =>
        if err
          returnErr = new Error "Cannot open '#{path}'. #{err.message}"
          return cb returnErr

        @_handleData buf, {}, cb

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

      @_handleData buf, res, cb

  _handleData: (buf, res, cb) ->
    data = buf

    if !@parseJson
      return cb null, data, res

    try
      data = JSON.parse data
    catch err
      err.message = "Got an error while parsing json for #{@url}. #{err}"
      return cb err, data, res

    if @expectedKey? && !data[@expectedKey]?
      msg  = "Invalid body received when fetching '#{@url}'. \n"
      msg += "No key: #{@expectedKey}. #{buf}"
      err  = new Error msg
      return cb err, data, res

    cb null, data, res

module.exports = Airbud
