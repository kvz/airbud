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
    for key, val of @_defaults
      if !options[key]?
        options[key] = val

    if !options.url
      return cb new Error "You did not specify a url to fetch"

    operation = retry.operation options

    # Setup timeouts for single operation
    timeoutForOperation = null
    if options.timeout?
      timeoutForOperation =
        timeout: options.timeout
        cb: ->
          return operation.retry(new Error "Operation timeout of #{options.timeout}ms reached. ")

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
            return cb new Error "Error while opening #{path}. #{err.message}"
          return @handleData options, buf, cb
      , options.testDelay
      return

    request.get options.url, (err, res, buf) =>
      if err
        return cb err, buf

      if options.expectedStatus?
        if options.expectedStatus.indexOf(parseInt(res.statusCode, 10)) == -1
          return cb new Error(
            "#{res.statusCode} received when fetching '#{url}'. \n" +
            "expected one status of: #{options.expectedStatus.join(', ')}. #{buf} "
          )

      return @handleData options, buf, cb

  @handleData: (options, buf, cb) ->
    data = buf

    if options.parseJson
      try
        data = JSON.parse data
      catch e
        return cb e, data

      if options.expectedKey?
        if !data[options.expectedKey]?
          return cb new Error(
            "Invalid body received when fetching '#{options.url}'. \n" +
            "No key: #{options.expectedKey}. #{buf}"
          )

    cb null, data

module.exports = Airbud
