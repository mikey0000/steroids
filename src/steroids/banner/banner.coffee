class Banner

  @print: (message, speed) ->
    new Promise (resolve, reject) ->

      printter = (chars, speed) ->
        if chars.length == 0
          console.log ""
          resolve()
          return

        char = chars.shift()
        process.stdout.write char

        setTimeout ->
          printter(chars, speed)
        , speed

      printter message.split(""), speed


  @dolan: ->
    Help = require "../help"
    Help.logo()

    afterInitialDelay = =>
      @print("Made with love in Helsinki and San Francisco by", 100).then =>
        @print("\n\n\n\n         (in random order)\n\n\n\n", 50).then =>
          banner = new @
          names = ["matti", "harsa", "satu", "ezku", "sampax", "tomi", "mevi", "varya", "mluukkai", "PG", "yoka", "xstoffer", "juhazi", "juhq", "youngkasi", "nate", "Genetic", "pentateu"]
          suffled = names.sort -> 0.5 - Math.random()
          format = suffled.join "\n"

          output = banner.makeSync format

          @print(output, 2).then =>
            @print("\n\n\n\n\n\n\n\nthank you!\n\n", 100).then =>
              setTimeout =>
                fs = require "fs"
                dolanPath = path.join __dirname, "..", "..", "..", "support", "dolan"
                dolan = fs.readFileSync(dolanPath).toString()

                console.log dolan
              , 1000

    setTimeout afterInitialDelay, 800

  constructor: (@options = {}) ->
    @figlet = require "figlet"

    @font = @options.font || 'Graffiti'
    @horizontalLayout = @options.horizontalLayout || 'default'
    @verticalLayout = @options.verticalLayout || 'default'

  makeSync: (opts={}) ->
    text = if opts.constructor.name == "String"
      opts
    else
      opts.text

    output = @figlet.textSync text,
      font: @font
      horizontalLayout: @horizontalLayout
      verticalLayout: @verticalLayout

    output

  availableFonts: =>
    new Promise (resolve, reject) =>
      @figlet.fonts (err, fonts) =>
        if err
          reject err
        else
          resolve fonts

module.exports = Banner
