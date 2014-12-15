_ = require "lodash"
paths = require "../paths"
features = require '../features'

class CordovaConfig

  constructor: ->
    @editor = {}

    @statusBar =
      style: "black"
      enabled: false

    @theme = "black"

    @location = "http://localhost/index.html"

    @preloads = []
    @drawers = {}
    @initialView = null

    @navigationBar =
      portrait:
        backgroundImage:          ""
      landscape:
        backgroundImage:          ""
      tintColor:                  ""
      titleColor:                 ""
      titleShadowColor:           ""

      buttonTitleColor:           ""
      buttonShadowColor:          ""
      buttonTintColor:            ""

      borderSize:                 ""
      borderColor:                ""

    @tabBar =
      enabled:                    false
      backgroundImage:            ""
      tintColor:                  ""
      tabTitleColor:              ""
      tabTitleShadowColor:        ""
      selectedTabTintColor:       ""
      selectedTabBackgroundImage: ""
      tabs: []

    @loadingScreen =
      tintColor: ""

    @worker =  {}   # what is this?

    @hooks =
      preMake: {}
      postMake: {}

    @watch =
      exclude: []

    # Project files that will be copied to a writable UserFiles directory.
    # File is copied only if it doesn't yet exist in the UserFiles directory.
    @copyToUserFiles = []

  getCurrent: ->
    return new CordovaConfig

module.exports = CordovaConfig
