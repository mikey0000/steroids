open = require "open"
qrcode = require "qrcode-terminal"

class QRCode
  constructor: (@options = {}) ->

  show: (options={})=>
    return if process.env.STEROIDS_TEST_RUN

    if steroidsCli.options.argv["terminal-qrcode"]
      qrcode.generate @options.data, (terminalQRCode) ->
        console.log terminalQRCode
    else
      urlToOpen = "http://localhost:#{@options.port}/test/testbench.html?qrcode=#{encodeURIComponent(@options.data)}"

      steroidsCli.debug "Opening URL #{urlToOpen} in default web browser..."
      open urlToOpen

  @showLocal: (options={}) =>
    interfaces = steroidsCli.server.interfaces()
    ips = steroidsCli.server.ipAddresses()

    encodedJSONIPs = encodeURIComponent(JSON.stringify(ips))
    encodedPort = encodeURIComponent(options.port)

    qrCodeData = "appgyver://?ips=#{encodedJSONIPs}&port=#{encodedPort}"
    code = new QRCode
      data: qrCodeData
      port: options.port

    code.show(options)





module.exports = QRCode
