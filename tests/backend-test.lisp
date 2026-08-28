(in-package #:ag-ui-backend-sse/tests)

(deftest backend-class
  (ok (typep (ag-ui-backend-sse:make-sse-ag-ui-backend)
             'ag-ui-backend-sse:sse-ag-ui-backend))
  (ok (typep ag-ui-protocol:*ag-ui-backend* 'ag-ui-backend-sse:sse-ag-ui-backend)))

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

(deftest remote-requires-event-loop
  (let ((backend (ag-ui-backend-sse:make-sse-ag-ui-backend
                  :url "http://127.0.0.1:9/"))
        (http-protocol:*http-backend* (make-instance 'http-protocol:http-backend))
        (event-protocol:*event-backend* nil)
        (event-protocol:*event-loop* nil))
    (ok (signals (ag-ui-protocol:run-agent
                  backend
                  (ag-ui-protocol:make-run-agent-input :thread-id "t" :run-id "r"))
                 'ag-ui-protocol:ag-ui-error))))

(deftest decode-sse-body-incremental
  (let* ((order '())
         (wire (concatenate
                'string
                (ag-ui-protocol:encode-ag-ui-sse
                 (ag-ui-protocol:make-run-started-event :thread-id "t" :run-id "r"))
                (ag-ui-protocol:encode-ag-ui-sse
                 (ag-ui-protocol:make-run-finished-event :thread-id "t" :run-id "r"))))
         (events (ag-ui-backend-sse:decode-sse-body
                  wire
                  :on-event (lambda (ev)
                              (push (ag-ui-protocol:ag-ui-event-type ev) order)))))
    (ok (= 2 (length events)))
    (ok (equal '("RUN_FINISHED" "RUN_STARTED") order))))

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
