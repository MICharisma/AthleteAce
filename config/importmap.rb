# Pin npm packages by running ./bin/importmap

pin "application"
pin "ahoy", to: "ahoy.js"
pin "analytics", to: "analytics.js"
pin "shared-ratings/dimension", to: "shared_ratings/dimension.js"
pin "shared-ratings/horizontal-drag", to: "shared_ratings/horizontal_drag.js"
pin "shared-ratings/suggestions-controller", to: "shared_ratings/suggestions_controller.js"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
