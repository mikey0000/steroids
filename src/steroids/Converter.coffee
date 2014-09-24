fs = require "fs"

Paths = require "./paths"
Config = require "./Config"
CloudConfig = require "./CloudConfig"
routingHelpers = require "./routingHelpers"

class Converter
  constructor: (@configPath)->

  configToAnkaFormat: ->

    @config = new Config()
    configObject = @config.getCurrent()

    cloudConfig = new CloudConfig().getCurrentSync()
    cloudId = if cloudConfig
      cloudConfig.id
    else
      1

    ankaLikeJSON =
      id: cloudId
      name: configObject.name||"Default name"

    if fs.existsSync Paths.temporaryZip
      ankaLikeJSON.build_timestamp = fs.lstatSync(Paths.temporaryZip).mtime.getTime()

    ankaLikeJSON.configuration = @configurationObject(configObject)
    ankaLikeJSON.appearance = @appearanceObject(configObject)
    ankaLikeJSON.preloads = @preloadsObject(configObject)
    ankaLikeJSON.drawers = @drawersObject(configObject)

    # runtime crashes with empty initialView object
    initialViewObject = @initialViewObject(configObject)
    if initialViewObject?
      ankaLikeJSON.initialView = initialViewObject

    # supersonic stuff
    ankaLikeJSON.rootView = @rootViewObject(configObject)

    ankaLikeJSON.files = []
    ankaLikeJSON.archives = []

    ankaLikeJSON.bottom_bars = ankaLikeJSON.tabs = @tabsObject(configObject)

    return ankaLikeJSON

  tabsObject: (config) =>
    @config.eitherSupersonicOrLegacy().fold(
      ->
        if config.structure.tabs?
          tabs = []
          for configTab, i in config.structure.tabs
            tab =
              position: i
              title: configTab.title
              image_path: configTab.icon
              target_url: routingHelpers.getLocationFromRouteOrUrl(configTab)

            tabs.push tab

          tabs
      ->
        unless config.tabBar.tabs.length or config.tabBar.enabled == false
          return []

        tabs = []
        for configTab, i in config.tabBar.tabs
          tab =
            position: i,
            title: configTab.title
            image_path: configTab.icon
            target_url: configTab.location

          tabs.push tab

        return tabs
    )

  configurationObject: (config) =>
    {statusBar, fullscreen, location} =
      @config.eitherSupersonicOrLegacy().fold(
        ->
          statusBar: "default" # will be overridden by native CSS
          fullscreen: !(config.structure.tabs?)
          location: if config.structure.rootView?
            routingHelpers.getLocationFromRouteOrUrl(config.structure.rootView)
          else
            ""
        ->
          statusBar:
            if config.statusBar?.enabled == false or config.statusBar?.enabled == undefined
              "hidden"
            else
              config.statusBar.style
          fullscreen: config.tabBar.enabled == false
          location: config.location
      )

    return {
      fullscreen: fullscreen
      fullscreen_start_url: location
      status_bar_style: statusBar
      request_user_location: "false"
      splashscreen_duration_in_seconds: 0
      client_version: "edge"
      navigation_bar_style: "black"
      initial_eval_js_string: ""
      background_eval_js_string: ""
      wait_for_document_ready_before_open: "true"
      open_clicked_links_in_new_layer: "false"
      shake_gesture_enabled_during_development: "false"
      copy_to_user_files: @userFilesObject(config)
    }

  appearanceObject: (config)->
    @config.eitherSupersonicOrLegacy().fold(
      ->
        null
      ->
        appearanceObject =
          nav_bar_portrait_background_image: "#{config.navigationBar.portrait.backgroundImage}"
          nav_bar_landscape_background_image: "#{config.navigationBar.landscape.backgroundImage}"
          nav_bar_tint_color: "#{config.navigationBar.tintColor}"
          nav_bar_title_text_color: "#{config.navigationBar.titleColor}"
          nav_bar_title_shadow_color: "#{config.navigationBar.titleShadowColor}"
          nav_bar_button_tint_color: "#{config.navigationBar.buttonTintColor}"
          nav_bar_button_title_text_color: "#{config.navigationBar.buttonTitleColor}"
          nav_bar_button_title_shadow_color: "#{config.navigationBar.buttonShadowColor}"
          tab_bar_background_image: "#{config.tabBar.backgroundImage}"
          tab_bar_tint_color: "#{config.tabBar.tintColor}"
          tab_bar_button_title_text_color: "#{config.tabBar.tabTitleColor}"
          tab_bar_button_title_shadow_color: "#{config.tabBar.tabTitleShadowColor}"
          tab_bar_selected_icon_tint_color: "#{config.tabBar.selectedTabTintColor}"
          tab_bar_selected_indicator_background_image: "#{config.tabBar.selectedTabBackgroundImage}"
          loading_screen_color: "#{config.loadingScreen.tintColor}"

        # legacy support: bug in 3.1.5 client causes empty strings for these values to crash
        unless config.navigationBar.borderSize is null or config.navigationBar.borderSize is ""
          appearanceObject.nav_bar_border_size = "#{config.navigationBar.borderSize}"

        unless config.navigationBar.borderColor is null or config.navigationBar.borderColor is ""
          appearanceObject.nav_bar_border_color = "#{config.navigationBar.borderColor}"

        appearanceObject
    )

  preloadsObject: (config)->
    @config.eitherSupersonicOrLegacy().fold(
      ->
        if config.structure.preloads?
          preloads = []

          for view in config.structure.preloads
            view.location = routingHelpers.getLocationFromRouteOrUrl(view)
            preloads.push view

          preloads
      ->
        config.preloads
    )

  drawersObject: (config)->
    @config.eitherSupersonicOrLegacy().fold(
      ->
        if config.structure.drawers?
          leftDrawer = config.structure.drawers.left
          rightDrawer = config.structure.drawers.right

          for drawer in [leftDrawer, rightDrawer]
            drawer?.location =
              routingHelpers.getLocationFromRouteOrUrl(drawer)

          config.structure.drawers
      ->
        config.drawers
    )

  initialViewObject: (config)->
    @config.eitherSupersonicOrLegacy().fold(
      ->
        initView = config.structure.initialView
        initView?.location =
          routingHelpers.getLocationFromRouteOrUrl(initView)
        initView
      ->
        config.initialView
    )

  userFilesObject: (config)->
    userFilesObject = []

    if config.copyToUserFiles?
      for file in config.copyToUserFiles
        userFilesObject.push file

    return userFilesObject

  rootViewObject: (config)->
    @config.eitherSupersonicOrLegacy().fold ->
      config.structure.rootView

module.exports = Converter
