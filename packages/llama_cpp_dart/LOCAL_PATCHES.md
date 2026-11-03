# Vendored llama_cpp_dart 0.9.0-dev.12

Source: pub.dev release 0.9.0-dev.12, original LICENSE preserved.
Runtime library, native asset hook, release CPU AAR and package metadata are
vendored. The upstream AAR SHA-256 sidecar is preserved.

Local fix: `MultimodalContext.evalChunks` must initialize `mtmd_input_text.text_len`
to the prompt's UTF-8 byte length. The generated binding includes this required
field but the upstream wrapper leaves it zero, causing native mtmd to report zero
media markers for a nonempty image prompt. This is not a model/backend workaround.
Also adds a missing `const` to a BatchEmbedder exception for the app's lint rules.
