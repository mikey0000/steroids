
allArgs = ObjC.deepUnwrap $.NSProcessInfo.processInfo.arguments
args = allArgs.splice 2

[mainCommand, firstOption, otherOptions...] = args


class Menu
  constructor: (@options = {}) ->
    throw "menu missing" unless @options.menu

    @appleMenu = @options.menu

  getMenuItems: ->
    menuItems = []

    hasMoreSubMenus = true

    # TODO: no other way to test this before BOOM?
    try
      @appleMenu.menuItems()
    catch err
      if err.message == "Invalid index."
        hasMoreSubMenus = false
      else
        throw err

    if hasMoreSubMenus
      for appleMenuItem in @appleMenu.menuItems
        menuItem = new MenuItem
          menuItem: appleMenuItem

        menuItems.push menuItem

    menuItems

  getName: ->
    @appleMenu.name()[0]

  search: (name) ->

    searchMenu = (menu, name) ->
      for menuItem in menu.getMenuItems()
        menuName = menuItem.getName()

        if menuName == name
          menuItem.click()

        if menuName == null
          console.log "------------"
        else
          console.log "#{menuName}"

        searchMenu(menuItem.menu, name)

    searchMenu(@, name)



class MenuItem
  constructor: (@options = {}) ->
    throw "menuItem missing" unless @options.menuItem

    @appleMenuItem = @options.menuItem

    @menu = new Menu
      menu: @appleMenuItem.menus[0]

  getName: ->
    @appleMenuItem.name()[0]

  click: ->
    @appleMenuItem.click()

  getMenuItems: ->
    @menu.getMenuItems()


class MenuFinder
  constructor: (@options = {}) ->
    throw "appName missing" unless @options.appName

    @SystemEvents = Application("System Events")

  get: (givenNames) ->
    names = JSON.parse(JSON.stringify(givenNames))

    findMenuOrMenuItem = (namesLeft, menus) ->
      searchFor = namesLeft.shift()

      for menu in menus
        if menu.getName() == searchFor
          if namesLeft.length == 0
            return menu
          else
            return findMenuOrMenuItem namesLeft, menu.getMenuItems()

    appProcess = @SystemEvents.processes[@options.appName]
    appleMenus = appProcess.menuBars.menus

    menus = []
    for appleMenu in appleMenus
      menu = new Menu
        menu: appleMenu
      menus.push menu if menu

    findMenuOrMenuItem(names, menus)


switch mainCommand
  when "launch"
    app = firstOption

    console.log "Launching #{firstOption}"

    app = Application(app)
    app.launch()

  when "activate"
    app = firstOption

    app = Application(app)
    app.activate()

  when "menu"
    appName = otherOptions[0]
    app = Application(appName)
    app.launch()

    switch(firstOption)
      when "print"
        menuNames = otherOptions.splice(1)

        menuFinder = new MenuFinder
          appName: appName

        menu = menuFinder.get(menuNames)

        unless menu
          console.log "Menu #{menuName} of #{appName} not found"
          process.exit(1)

        printMenuItems = (menuItems, depth="") ->
          for menuItem in menuItems
            menuName = menuItem.getName()
            if menuName == null
              console.log "#{depth}------------"
            else
              console.log "#{depth}#{menuName}"

            deeperDepth = depth + "  "
            printMenuItems(menuItem.menu.getMenuItems(), deeperDepth)

        printMenuItems(menu.getMenuItems())

      when "click"
        menuFinder = new MenuFinder
          appName: appName

        menuNames = otherOptions.splice(1)

        menu = menuFinder.get(menuNames)

        unless menu
          console.log "Menu #{menuNames.join('->')} of #{appName} not found"

        menu.click()
        app.activate()

      else
        console.log "unknown menu command"

  when "safari"
    app = Application("Safari")
    app.launch()

    switch(firstOption)
      when "listdevices"
        menuFinder = new MenuFinder
          appName: "Safari"

        menu = menuFinder.get(["Develop"])

        menuItemsThatAreDevices = []

        for menuItem in menu.getMenuItems().splice(3)
          if menuItem.getName() == null
            break

          menuItemsThatAreDevices.push menuItem

        for menuItemThatIsDevice in menuItemsThatAreDevices
          console.log menuItemThatIsDevice.getName()

      when "listviews"
        menuFinder = new MenuFinder
          appName: "Safari"

        menu = menuFinder.get(["Develop"])

        menuItemsThatAreDevices = []

        for menuItem in menu.getMenuItems().splice(3)
          if menuItem.getName() == null
            break

          menuItemsThatAreDevices.push menuItem

        for menuItemThatIsDevice in menuItemsThatAreDevices
          menuItemsThatAreViews = menuItemThatIsDevice.menu.getMenuItems()
          console.log "#{menuItemThatIsDevice.getName()}"

          for menuItemThatIsView in menuItemsThatAreViews.splice(1)
            console.log " - #{menuItemThatIsView.getName()}"


  else
    console.log "Unknown command: #{args[0]}"
