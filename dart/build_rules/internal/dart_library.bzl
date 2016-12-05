load(
    ":common.bzl",
    "assert_third_party_licenses",
    "has_dart_sources",
    "make_dart_context",
    "api_summary_extension",
)
# TODO: Migrate both of these to an aspect? This would eliminate the
# ddc/analyzer dependency for targets which don't actually need them.
load(":analyze.bzl", "summary_action")
load(":ddc.bzl", "ddc_action")

def dart_library_impl(ctx):
  """Implements the dart_library() rule."""
  assert_third_party_licenses(ctx)

  ddc_output = ctx.outputs.ddc_output if ctx.attr.enable_ddc else None
  source_map_output = ctx.outputs.ddc_sourcemap if ctx.attr.enable_ddc else None
  strong_summary = ctx.outputs.strong_summary
  _has_dart_sources = has_dart_sources(ctx.files.srcs)

  dart_ctx = make_dart_context(ctx.label,
                               srcs=ctx.files.srcs,
                               data=ctx.files.data,
                               deps=ctx.attr.deps,
                               pub_pkg_name=ctx.attr.pub_pkg_name,
                               strong_summary=strong_summary,)

  if not _has_dart_sources:
    ctx.file_action(
        output=strong_summary,
        content=("// empty summary, package %s has no dart sources" %
                 ctx.label.name))
  else:
    summary_action(ctx, dart_ctx)

  if ctx.attr.enable_ddc:
    if not _has_dart_sources:
      ctx.file_action(
          output=ddc_output,
          content=("// intentionally empty: package %s has no dart sources" %
                   ctx.label.name))
      ctx.file_action(
          output=source_map_output,
          content=("// intentionally empty: package %s has no dart sources" %
                   ctx.label.name))
    else:
      ddc_action(ctx, dart_ctx, ddc_output, source_map_output)

  return struct(
      dart=dart_ctx,
      ddc=struct(
        enabled=ctx.attr.enable_ddc,
        output=ddc_output,
        sourcemap=source_map_output,
      ),
  )

def dart_library_outputs(enable_ddc):
  """Returns the outputs of a Dart library rule.

  Dart library targets emit the following outputs:

  * name.api.ds: the strong-mode summary from dart analyzer (API only), if specified.
  * name.js:     the js generated by DDC if enabled
  * name.js.map: the source map generated by DDC if enabled

  Returns:
    a dict of types of outputs to their respective file suffixes
  """
  outs = {
    "strong_summary": "%{name}." + api_summary_extension,
  }

  if enable_ddc:
    outs += {
      "ddc_output": "%{name}.js",
      "ddc_sourcemap": "%{name}.js.map",
    }

  return outs
