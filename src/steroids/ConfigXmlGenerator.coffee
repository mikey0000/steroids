fs = require "fs"
xmlbuilder = require "xmlbuilder"
_ = require "lodash"

paths = require "./paths"
Config = require "./Config"

module.exports = class ConfigXmlGenerator

  constructor: ->

  writeConfigAndroidXml: ->
    config = new Config()
    currentConfig = config.getCurrent()

    unless fs.existsSync paths.application.configs.configAndroidXml
      xml = @constructAndroidXmlFromConfig(currentConfig)

      fs.writeFileSync paths.application.dist.configAndroidXml, xml


  writeConfigIosXml: ->
    config = new Config()
    currentConfig = config.getCurrent()

    unless fs.existsSync paths.application.configs.configIosXml
      xml = @constructIosXmlFromConfig(currentConfig)

      fs.writeFileSync paths.application.dist.configIosXml, xml

  constructIosXmlFromConfig: (config)->
    root = xmlbuilder.create("widget")
    root.ele "access", origin: "*"

    _.forIn config, (value, key)=>
      switch key
        when "webView"
          namespace = "webView"
        when "splashscreen"
          namespace = "splashscreen"
        else
          namespace = null

      if namespace?
        _.forIn config[namespace], (value, key)=>
          {key, value} = @getLegacyProperty(namespace, key, value)
          root.ele "preference",
            name: key
            value: value

    root.end
      pretty: true

  constructAndroidXmlFromConfig: (config)->
    root = xmlbuilder.create("widget")
    root.ele "access", origin: "*"

    namespace = "splashscreen"
    key = "autohide"
    value = config[namespace][key]
    {key, value} = @getLegacyProperty(namespace, key, value)
    root.ele "preference",
      name: key
      value: value

    root.ele "preference",
      name: "fullscreen"
      value: "false"

    root.end
      pretty: true

  getLegacyProperty: (namespace, key, value)->
    switch namespace
      when "webView"
        switch key
          when "viewsIgnoreStatusBar"
            key: "ViewIgnoresStatusBar"
            value: value
          when "enableDoubleTapToFocus"
            key: "DisableDoubleTapToFocus"
            value: !value
          when "disableOverscroll"
            key: "DisallowOverscroll"
            value: value
          when "enableViewportScale"
            key: "EnableViewportScale"
            value: value
          when "enablePopGestureRecognition"
            key: "EnablePopGestureRecognition"
            value: value
          when "allowInlineMediaPlayback"
            key: "AllowInlineMediaPlayback"
            value: value
          else
            key: key
            value: value

      when "splashscreen"
        switch key
          when "autohide"
            key: "AutoHideSplashScreen"
            value: value
