(defsystem "ag-ui-backend-sse"
  :version "0.1.0"
  :description "SSE transport backend for ag-ui-protocol"
  :author "egao1980"
  :license "MIT"
  :depends-on ("ag-ui-protocol" "rpc-protocol" "rpc-backend-sse" "sse-protocol")
  :serial t
  :pathname "src"
  :components ((:file "package")
               (:file "backend"))
  :in-order-to ((test-op (test-op "ag-ui-backend-sse/tests"))))

(defsystem "ag-ui-backend-sse/tests"
  :depends-on ("ag-ui-backend-sse" "rove")
  :pathname "tests"
  :serial t
  :components ((:file "package")
               (:file "backend-test"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "tests failed for ~A" (component-name c)))))
