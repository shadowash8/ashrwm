(import wayland :as wl)

(use ./registry)

(import ./window)

(defn- update-windowing []
  (:update-windowing-finish (registry :wm)))

(defn- update-rendering []
  (:update-rendering-finish (registry :wm)))

(defn- handle-event [obj event wm]
  (match event
    [:unavailable] (do
                     (print "another window manager is already running")
                     (os/exit 1))
    [:finished] (error "unreachable")
    [:update-windowing-start] (update-windowing)
    [:update-rendering-start] (update-rendering)
    [:window obj] (array/push (wm :windows) (window/create obj))
    [:output]
    [:seat]))

(defn- init [wm]
  (:set-listener (registry :wm) handle-event wm))

(def wm @{:windows @[]
          :outputs @[]
          :seats @[]
          :init init})
