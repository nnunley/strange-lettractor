# Gemini provider aliases

Provider registry IDs are application names; the configured protocol determines
adapter behavior. A Gemini endpoint registered under a custom ID must preserve
tool-call state just as the built-in `gemini` provider does.

The 2026-09-12 audit found `make-provider-adapter` creating its call-ID/name
lookup only when the ID was literally `gemini`. Responses were otherwise
decoded correctly through the configured native protocol, but a subsequent
tool result carrying only `tool_call_id` serialized as a Gemini
`functionResponse` with an empty name.

The lookup is now allocated per adapter whenever its protocol is
`:gemini-generate-content`. The regression drives a custom provider through
the real complete and streaming decoders, then sends the resulting call ID back
without repeating the tool name. It inspects the serialized native continuation
and checks the recovered name, result content and final reply. Both paths failed
the name assertion before the fix and now pass.

Verification: alias contract 1 test/8 assertions; LLM 83/495; providers 12/107;
all passing, with a successful CLI build. The test supplies an in-memory
transport and protocol lookup to isolate this adapter behavior. It does not
establish a credentialed Gemini server run; that live matrix remains pending.
