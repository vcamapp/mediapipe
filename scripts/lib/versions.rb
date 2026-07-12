# Parses config/versions.env into a Hash. Values are returned verbatim —
# shell interpolations such as ${MEDIAPIPE_VERSION} are not expanded.
def read_versions(root)
  File.read(File.join(root, 'config/versions.env'))
      .scan(/^([A-Z_]+)="([^"]*)"/)
      .to_h
end
