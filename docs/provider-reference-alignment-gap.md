# Provider reference alignment remains unproved

CAL-PROFILE-01 is still partial. Current profiles use locally authored prompts
and largely shared tool schemas; tests prove conventions, registry behavior and
execution delegation, not reference-asset equivalence.

The source specification contains tension that must be resolved explicitly:
§3.1 asks for byte-for-byte reference bases, whereas §§3.4–3.6 describe adapted
tool names and practical affordances, and §6.2 says full prompt text is not
prescribed and specifies topics instead. No reference commit, model configuration
or extraction procedure is supplied. Do not mistake wire correctness or a
successful model run for proof of reference fidelity.

Follow-up implementation should pin authoritative reference revisions and
rendering configurations, keep source assets/provenance separate from Attractor
extensions, and record the chosen interpretation of the section-specific
adaptations. Unavailable reference assets must remain explicit gaps, not invented
copies. Implement and compare one provider at a time. Shared filesystem/process
executors may still be reused underneath genuinely provider-specific schemas.

Independent §3.3 tool behavior can progress meanwhile. Such components do not
close this profile-alignment requirement.
