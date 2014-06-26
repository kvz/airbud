request = require "request"
fs      = require "fs"
retry   = require "retry"

class Airbud
  @_defaults:
    # The URL to fetch
    url: null

    # How many times to try
    retries: 0

    # Timeout in milliseconds per try
    timeout: null

    # Automatically parse json
    parseJson: true

    # A key to find in the rootlevel of the parsed json.
    # If not found, Airbud will error out
    expectedKey: null

    # Only used by Airbud's own testsuite to test the timeout mechanism
    testDelay: 0

  @fetch: (options, cb) ->
    if !options.url
      err = new Error "You did not specify a url to fetch"
      return cb err

    for key, val of @_defaults
      if !options[key]?
        options[key] = val

    operation = retry.operation options

    # Setup timeouts for single operation
    timeoutForOperation = null
    if options.timeout?
      timeoutForOperation =
        timeout: options.timeout
        cb: ->
          msg = "Operation timeout of #{options.timeout}ms reached."
          err = new Error msg
          return operation.retry err

    totalStart         = +new Date
    operationDurations = 0
    operation.attempt (currentAttempt) =>
      operationStart = +new Date
      @_fetch options, (err, data) ->
        operationDurations += +new Date - operationStart
        if operation.retry(err)
          return

        totalDuration = +new Date - totalStart
        info          =
          errors           : operation.errors()
          attempts         : operation.attempts()
          totalDuration    : totalDuration
          operationDuration: operationDurations / operation.attempts()
        cb operation.mainError(), data, info
    , timeoutForOperation

  @_fetch: (options, cb) ->
    if options.url.indexOf("file://") == 0
      # Url can also be local json to inject test fixtures
      path = options.url.substr(7, options.url.length).split("?")[0]
      setTimeout =>
        fs.readFile path, "utf8", (err, buf) =>
          if err
            returnErr = new Error "Error while opening #{path}. #{err.message}"
            return cb returnErr
          return @_handleData options, buf, cb
      , options.testDelay
      return

    request.get options.url, (err, res, buf) =>
      if err
        return cb err, buf

      if options.expectedStatus?
        if options.expectedStatus.indexOf(parseInt(res.statusCode, 10)) == -1
          msg = "#{res.statusCode} received when fetching '#{url}'. \n expected"
          msg += " one status of: #{options.expectedStatus.join(', ')}. #{buf}"
          err = new Error msg
          return cb err

      return @_handleData options, buf, cb

  @_handleData: (options, buf, cb) ->
    data = buf

    if !options.parseJson
      return cb null, data

    try
      data = JSON.parse data
    catch e
      return cb e, data

    if options.expectedKey? && !data[options.expectedKey]?
      msg = "Invalid body received when fetching '#{options.url}'. \n"
      msg += "No key: #{options.expectedKey}. #{buf}"
      err = new Error msg
      return cb err

    cb null, data

module.exports = Airbud
