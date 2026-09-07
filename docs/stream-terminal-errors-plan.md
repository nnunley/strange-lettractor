# Terminal streaming failures

Pinned unified LLM §§3.13, 6.1–6.6 require SDK errors and prohibit retry after
partial data delivery. Current Anthropic error+message_stop emits error+finish;
native Gemini error frames are ignored and OpenAI failure details may be nested
under response.error. The compatible path suppresses later normalized events
but can keep consuming the wire tail.

1. Add test/attractor/stream_terminal_error_test.lg with public native low-level,
   configured-client and high-level streams for all four adapters. Show RED:
   partial text then error then late text/tool/finish must end at one error;
   preserve partial response/text, raw provider event and SDK error fields.
   No retries, tool execution, or second provider call after partial failure.
   Include first-event errors and a lazy tail that throws/blocks if consumed.
   After terminal failure, high-level :response must raise the retained SDK
   error; :partial_response and :text_stream preserve delivered partial output.
   Exercise this distinction for native and custom-adapter first/partial errors.
2. Modify src/attractor/llm.lg: normalize native error payloads to SDK-compatible
   exceptions while retaining event.raw. Cover OpenAI response.failed nested
   response.error and error events, Anthropic error, Gemini error, compatible
   error. A terminal sequence boundary must emit the error once, close its owned
   body, and not realize later native/normalized events. Apply the same stop
   rule to custom client-adapter error events at the high-level boundary.
   Preserve existing already-typed errors and successful stream semantics.
   Update old tests that expected raw maps under :error to check typed fields
   and the retained raw event instead. Do not fabricate a success FINISH.
3. Parent extends loopback HTTP fixture and adds a checker: send partial data,
   an error, then hold the connection; assert one request, partial output,
   typed error, no retry/late frames, and server-observed close before release.
4. Independent spec/quality review, focused regression suites, final full suite,
   bundled tests and build. Commit and push scoped changes after verification.

Do not rewrite generic transport cancellation or promise native default timeouts.
Before-headers cancellation (#816), monitor/worker join-before-return, provider
release parity and other stream lifecycle requirements remain separate. Use
native Go-based let-go APIs; no runtime checkout changes or live model requests.
