http = require "http"

class Fakeserver
  requestCnt  : 0
  createServer: (params = {}) ->
    params.numberOfFails ?= 0
    params.delay         ?= {}
    params.redirect      ?= {}
    params.port          ?= 7000
    @requestCnt =  0

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
        res.end '{ "msg": "OK" }'
        try
          # Might have been closed by Airbud already due to delay param
          server.close()
        catch e
          console.log e
      , delay
    server.listen params.port
    return "http://localhost:#{params.port}"

module.exports = Fakeserver
