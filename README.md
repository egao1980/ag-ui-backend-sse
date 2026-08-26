# ag-ui-backend-sse

Default AG-UI transport: `POST RunAgentInput` → `text/event-stream` of typed events.

Uses [`sse-protocol`](https://github.com/egao1980/sse-protocol) +
[`http-server-protocol`](https://github.com/egao1980/http-server-protocol). **Not JSON-RPC.**

```lisp
(asdf:load-system "ag-ui-backend-sse")
(asdf:load-system "http-server-backend-hunchentoot")

(let ((backend (ag-ui-backend-sse:make-sse-ag-ui-backend
                :agent (ag-ui-protocol:make-ag-ui-agent))))
  (ag-ui-protocol:serve-ag-ui backend :host "127.0.0.1" :port 8080 :path "/"))
```

Client (same process, no URL) runs the local echo agent. With `:url`, POSTs via `http-protocol`.

Tracks [cl-stack#187](https://github.com/egao1980/cl-stack/issues/187).

## License

MIT
