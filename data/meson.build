install_data('dev.miguel.Switchboard.desktop',
  install_dir: get_option('datadir') / 'applications',
)

install_data('dev.miguel.Switchboard.metainfo.xml',
  install_dir: get_option('datadir') / 'metainfo',
)

install_data('icons/hicolor/scalable/apps/dev.miguel.Switchboard.svg',
  install_dir: get_option('datadir') / 'icons' / 'hicolor' / 'scalable' / 'apps',
)

install_data('icons/hicolor/symbolic/apps/dev.miguel.Switchboard-symbolic.svg',
  install_dir: get_option('datadir') / 'icons' / 'hicolor' / 'symbolic' / 'apps',
)

install_data('icons/hicolor/symbolic/apps/dev.miguel.Switchboard-asleep-symbolic.svg',
  install_dir: get_option('datadir') / 'icons' / 'hicolor' / 'symbolic' / 'apps',
)

install_data('icons/hicolor/symbolic/apps/dev.miguel.Switchboard-awake-symbolic.svg',
  install_dir: get_option('datadir') / 'icons' / 'hicolor' / 'symbolic' / 'apps',
)

install_data('dev.miguel.Switchboard.gschema.xml',
  install_dir: get_option('datadir') / 'glib-2.0' / 'schemas',
)

# Also compiled into the build dir so the app can run uninstalled with
# GSETTINGS_SCHEMA_DIR pointing at it.
gnome.compile_schemas(depend_files: files('dev.miguel.Switchboard.gschema.xml'))
