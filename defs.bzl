"""Actions that create CAS disk load in the actiond guest with bash builtins only."""

def _write_impl(ctx):
    out = ctx.actions.declare_file(ctx.label.name + ".dat")

    # A 64 KiB chunk that is unique per target, so the CAS cannot deduplicate the outputs.
    ctx.actions.run_shell(
        outputs = [out],
        command = """
set -eu
line='{name} 0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
chunk=""
while (( ${{#chunk}} < 65536 )); do chunk+="$line"$'\\n'; done
for (( i = 0; i < {mib} * 16; i++ )); do printf '%s' "$chunk"; done > {out}
""".format(name = ctx.label.name, mib = ctx.attr.mib, out = out.path),
        mnemonic = "ReproWrite",
    )
    return [DefaultInfo(files = depset([out]))]

repro_write = rule(
    implementation = _write_impl,
    attrs = {"mib": attr.int(default = 64)},
)

def _read_impl(ctx):
    out = ctx.actions.declare_file(ctx.label.name + ".count")
    ctx.actions.run_shell(
        inputs = ctx.files.srcs,
        outputs = [out],
        command = """
set -eu
total=0
for f in "$@"; do
  while IFS= read -r -N 65536 chunk || [[ -n "$chunk" ]]; do total=$(( total + ${{#chunk}} )); done < "$f"
done
echo "{name} $total" > {out}
""".format(name = ctx.label.name, out = out.path),
        arguments = [f.path for f in ctx.files.srcs],
        mnemonic = "ReproRead",
    )
    return [DefaultInfo(files = depset([out]))]

repro_read = rule(
    implementation = _read_impl,
    attrs = {"srcs": attr.label_list(allow_files = True)},
)
