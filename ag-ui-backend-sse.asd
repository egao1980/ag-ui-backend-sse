(defsystem "ag-ui-backend-sse"
  :version "0.2.1"
  :description "SSE transport backend for ag-ui-protocol (POST RunAgentInput → events)"
  :author "egao1980"
  :license "MIT"
  :depends-on ("ag-ui-protocol"
               "sse-protocol"
               "sse-backend-clack"
               "http-protocol"
               "http-server-protocol"
               "babel")
  :properties (:cl-repo (:ci (:with ("dissect"))))
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
