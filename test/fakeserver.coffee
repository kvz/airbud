http  = require "http"
debug = require("depurar")("Airbud")
util  = require "util"

class Fakeserver
  requestCnt  : 0
  createServer: (params = {}) ->
    params.numberOfFails ?= 0
    params.delay         ?= {}
    params.redirect      ?= {}
    params.port          ?= 7000
    @requestCnt           = 0
    expectedRequests      = 1

    if (maybe = Object.keys(params.delay).length) >= expectedRequests
      expectedRequests = maybe
    if (maybe = Object.keys(params.redirect).length) >= expectedRequests
      expectedRequests = maybe

    server = http.createServer (req, res) =>
      cnt      = ++@requestCnt
      delay    = params.delay[cnt]
      redirect = params.redirect[cnt]

      setTimeout ->
        if req.url == "/other-location"
          res.writeHead 200,
            "content-type": "application/json"
          res.end '{ "msg": "Arrived at other location" }'
          return

        if redirect == true
          res.writeHead 301,
            "location": "/other-location"
          res.end()
          return

        if cnt <= params.numberOfFails
          res.writeHead 500,
            "content-type": "application/json"
          res.end '{ "msg": "Internal Server Error" }'
          return

        res.writeHead 202,
          "content-type": "application/json"

        payload =
          msg: "OK"

        if req.headers?
          payload.received_headers = req.headers

        res.end JSON.stringify payload


        # debug "#{cnt} of #{expectedRequests}"
        if cnt >= expectedRequests
          # debug "Closing server"
          try
            # Might have been closed by Airbud already due to delay param
            server.close()
          catch e
            console.log e

      , delay
    server.listen params.port
    return "http://localhost:#{params.port}"

module.exports = Fakeserver
