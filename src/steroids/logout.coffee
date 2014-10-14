class Logout

    run: =>
      Help = require "./Help"
      Login = require "./Login"

      Login.removeAuthToken()
      Help.logo()
      Help.loggedOut()

module.exports = Logout
