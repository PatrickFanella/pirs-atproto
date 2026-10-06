# PDS transport adapters

`PdsHooks.xrpcMiddleware` accepts trusted transport adapters only. Plugin code
must remain in a separate process and must not receive the PDS context or keys.
Keep adapters after basic/well-known routes and CORS, before XRPC and its error
handler. An omitted or empty adapter list must preserve upstream behavior.
Run the hook integration tests and the full PDS suite when changing this seam.
