(in-package #:ag-ui-backend-sse/tests)

(deftest backend-class
  (ok (typep (ag-ui-backend-sse:make-sse-ag-ui-backend)
             'ag-ui-backend-sse:sse-ag-ui-backend))
  (ok (typep ag-ui-protocol:*ag-ui-backend* 'ag-ui-backend-sse:sse-ag-ui-backend)))

(deftest claims-streaming
  (let ((caps (ag-ui-protocol:get-capabilities
               (ag-ui-backend-sse:make-sse-ag-ui-backend
                :agent (ag-ui-protocol:make-ag-ui-agent :name "sse")))))
    (ok (equal "sse" (ag-ui-protocol:identity-name
                      (ag-ui-protocol:capabilities-identity caps))))
    (ok (ag-ui-protocol:transport-streaming-p
         (ag-ui-protocol:capabilities-transport caps)))
    (ng (ag-ui-protocol:transport-http-binary-p
         (ag-ui-protocol:capabilities-transport caps)))))

(deftest local-run-without-url
  (let* ((backend (ag-ui-backend-sse:make-sse-ag-ui-backend
                   :agent (ag-ui-protocol:make-ag-ui-agent)))
         (events (ag-ui-protocol:run-agent
                  backend
                  (ag-ui-protocol:make-run-agent-input
                   :thread-id "t" :run-id "r"
                   :messages (list (ag-ui-protocol:make-ag-ui-message
                                    :role "user" :content "hi"))))))
    (ok (= 5 (length events)))
    (ok (equal "RUN_STARTED"
               (ag-ui-protocol:ag-ui-event-type (first events))))
    (ok (equal "hi" (ag-ui-protocol:text-message-delta (third events))))))

(deftest missing-url-errors-on-http-path
  ;; url bound but no http backend → transport error, not echo
  (let ((backend (ag-ui-backend-sse:make-sse-ag-ui-backend
                  :url "http://127.0.0.1:9/"))
        (http-protocol:*http-backend* nil))
    (ok (signals (ag-ui-protocol:run-agent
                  backend
                  (ag-ui-protocol:make-run-agent-input :thread-id "t" :run-id "r"))
                 'ag-ui-protocol:ag-ui-error))))

(deftest run-agent-use-value
  (let ((backend (ag-ui-backend-sse:make-sse-ag-ui-backend
                  :url "http://127.0.0.1:9/"))
        (http-protocol:*http-backend* nil)
        (events (list (ag-ui-protocol:make-run-started-event
                       :thread-id "t" :run-id "r"))))
    (let ((got (handler-bind ((ag-ui-protocol:ag-ui-error
                               (lambda (c)
                                 (use-value events c))))
                 (ag-ui-protocol:run-agent
                  backend
                  (ag-ui-protocol:make-run-agent-input
                   :thread-id "t" :run-id "r")))))
      (ok (equal events got)))))
