# Seed pilot fixture

The original fourteen top-level manifests of the seed library (plus its
sequence registry), frozen from the data repository before the library moved
to the catalog/batch layout. `spec/services/seeds/library_importer_spec.rb`
uses them as a small, realistic library for importer behavior: replay,
reordering, renamed files, wipes, and aliases. They are test input, not the
maintained catalog, and are not imported by `db:seed`.
