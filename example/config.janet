# theming
(put config :border-width 2)
(put config :outer-padding 4)
(put config :inner-padding 4)
(put config :border-sticky 0x356239)
(put config :border-normal 0x444444)
(put config :border-focused 0xffffff)

# input
(put config :tap-to-click true)
(put config :natural-scroll false)
(put config :dwt true)
(put config :focus-follows-mouse true)

# layout
# 1. tile
# 2. grid
# 3. scroller
# 4. monocle
# set the default layout (fallback for all tags)
(put config :layout :tile)
(put config :main-ratio 0.60)
# per-tag layout overrides (optional)
# any tag not listed here uses the default layout above
(put config :layouts @{1 :scroller
                       2 :monocle
                       3 :grid})
 # wrap window focus with target next or previous
(put config :focus-wrap true)
(put config :float-on-top true)
# new window to be placed in start or the end of the stack
# either :start or :end
(put config :new-window-position :start) 

# rules
# match on :app-id or :title (prefix with "~" for regex)
# actions: :tag, :float, :sticky, :fullscreen
#
# examples:
# [:app-id "foot"               {:tag 3}]
# [:app-id "pavucontrol"        {:float true}]
# [:app-id "zen"                {:tag 2}]
# [:title  "Picture-in-Picture" {:float true :sticky true}]
# [:app-id "mpv"                {:float true :fullscreen true}]
# [:title  "~.*timer.*"    {:float true}]

# you can get window info from the ashrwm-msg cli tool like:
# $ ashrwm-msg windows
# $ ashrwm-msg active
(set (config :rules)
     @[[:app-id "mpv" {:float true}]
       [:title "Picture-in-Picture" {:float true :sticky true}]])


# keybinds
# mod4 = Super/Windows key
# mod1 = Alt key
(set (config :xkb-bindings)
     @[[:space {:mod4 true :mod1 true} (action/spawn ["foot"])]
       [:l {:mod4 true} (action/spawn ["fuzzel"])]
       [:u {:mod4 true :mod1 true} (action/close)]
       [:r {:mod4 true} (action/config)]
       [:e {:mod4 true} (action/focus :prev)]
       [:a {:mod4 true} (action/focus :next)]
       [:h {:mod4 true} (action/focus-output)]
       [:i {:mod4 true} (action/focus-output)]
       [:t {:mod4 true} (action/fullscreen)]
       [:k {:mod4 true} (action/zoom)]
       [:z {:mod4 true} (action/swap-main)]
       [:d {:mod4 true} (action/sticky)]
       [:t {:mod4 true :mod1 true} (action/float)]
       [:z {:mod4 true} (action/layout :tile)]
       [:x {:mod4 true} (action/layout :grid)]
       [:s {:mod4 true} (action/layout :scroller)]
       [:c {:mod4 true} (action/layout :monocle)]
       [:equal {:mod4 true} (action/main-ratio 0.05)]
       [:minus {:mod4 true} (action/main-ratio -0.05)]
       [:equal {:mod4 true :shift true} (action/window-ratio 0.05)]
       [:minus {:mod4 true :shift true} (action/window-ratio -0.05)]
       [:p {:mod4 true} (action/spawn ["sh" "-c" "grim -g \"$(slurp)\" - | wl-copy"])]
       [:Escape {:mod4 true :mod1 true :shift true :ctrl true} (action/passthrough)]
       [:BackSpace {:mod4 true :mod1 true :shift true :ctrl true} (action/exit-session)]
       [:0 {:mod4 true} (action/focus-all-tags)]])

(for i 1 10
  (let [keysym (keyword i)]
    (array/push (config :xkb-bindings) [keysym {:mod4 true} (action/focus-tag i)])
    (array/push (config :xkb-bindings) [keysym {:mod4 true :shift true} (action/set-tag i)])))

(set (config :pointer-bindings)
     @[[:left {:mod4 true} (action/pointer-move)]
       [:right {:mod4 true} (action/pointer-resize)]])
