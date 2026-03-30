# autostart
(defn autostart [cmd]
  (ev/spawn (os/proc-wait (os/spawn cmd :p))))

(autostart ["sh" "-c" "swaybg -i $(cat ~/.cache/ashwal/ashwal)"])

# theming
(put config :border-width 2)
(put config :border-focused 0xffffff)
(put config :border-normal 0x444444)
(put config :background nil)

# input
(put config :tap-to-click true)
(put config :natural-scroll false)
(put config :dwt true)
(put config :focus-follow-mouse true)

# keybinds
# mod4 = Super/Windows key
# mod1 = Alt key
(array/push
  (config :xkb-bindings)
  [:space {:mod4 true :mod1 true} (action/spawn ["foot"])]
  [:l {:mod4 true} (action/spawn ["fuzzel"])]
  [:u {:mod4 true :mod1 true} (action/close)]
  [:space {:mod4 true} (action/zoom)]
  [:e {:mod4 true} (action/focus :prev)]
  [:a {:mod4 true} (action/focus :next)]
  [:h {:mod4 true} (action/focus-output)]
  [:i {:mod4 true} (action/focus-output)]
  [:t {:mod4 true} (action/fullscreen)]
  [:z {:mod4 true} (action/swap-main)]
  [:s {:mod4 true} (action/sticky)]
  [:t {:mod4 true :mod1 true} (action/float)]
  [:p {:mod4 true} (action/spawn ["sh" "-c" "grim -g \"$(slurp)\" - | wl-copy"])]
  [:Escape {:mod4 true :mod1 true :shift true :ctrl true} (action/passthrough)]
  [:BackSpace {:mod4 true :mod1 true :shift true :ctrl true} (action/exit-session)]
  [:0 {:mod4 true} (action/focus-all-tags)])

(for i 1 10
  (def keysym (keyword i))
  (array/push
    (config :xkb-bindings)
    [keysym {:mod4 true} (action/focus-tag i)]
    [keysym {:mod4 true :mod1 true} (action/set-tag i)]
    [keysym {:mod4 true :mod1 true :shift true} (action/toggle-tag i)]))

(array/push
  (config :pointer-bindings)
  [:left {:mod4 true} (action/pointer-move)]
  [:right {:mod4 true} (action/pointer-resize)])
