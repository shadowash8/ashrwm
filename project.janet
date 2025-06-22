(declare-project
  :name "rijan"
  :description "Window manager for the river Wayland compositor"
  :author "Isaac Freund"
  :dependencies [{:url "https://github.com/janet-lang/spork"}
                 {:url "https://codeberg.org/ifreund/janet-wayland"}]
  :version "0.0.0")

(declare-executable
  :name "rijan"
  :entry "src/main.janet"
  :install true
  :pkg-config-libs ["wayland-client"])
