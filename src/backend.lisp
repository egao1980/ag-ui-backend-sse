(in-package #:ag-ui-backend-sse)

;;; SSE wire via sse-protocol. AG-UI codec is not JSON-RPC.
;;; Remote I/O = http-protocol:send-async on the bound event-protocol loop.
;;; Do not spawn worker threads — blocking stream reads deadlock the loop
;;; (async-body-input-stream). Decode in the send-async callback.

(defclass sse-ag-ui-backend (ag-ui-protocol:ag-ui-backend)
  ((url :initarg :url :accessor backend-url :initform nil)
   (agent :initarg :agent :accessor backend-agent :initform nil)
   (path :initarg :path :accessor backend-path :initform "/")))

(defun make-sse-ag-ui-backend (&key url agent (path "/"))
  (make-instance 'sse-ag-ui-backend :url url :agent agent :path path))

(defun use-sse-ag-ui-backend (&rest args &key &allow-other-keys)
  (setf ag-ui-protocol:*ag-ui-backend* (apply #'make-sse-ag-ui-backend args)))

(defun %ensure-http ()
  (unless http-protocol:*http-backend*
    (error 'ag-ui-protocol:ag-ui-error
           :message "*http-backend* is nil — bind an http-protocol backend")))

(defun %ensure-url (backend)
  (or (backend-url backend)
      (error 'ag-ui-protocol:ag-ui-run-error
             :message "sse AG-UI backend has no :url")))

(defun %ensure-loop ()
  (unless (and event:*event-backend* event:*event-loop*)
    (error 'ag-ui-protocol:ag-ui-error
           :message "bind event-protocol:*event-backend* and *event-loop*"))
  (values event:*event-backend* event:*event-loop*))

(defun %ensure-http-server ()
  (or http-server-protocol:*http-server-backend*
      (progn
        (asdf:load-system "http-server-backend-hunchentoot")
        (funcall (find-symbol "USE-HUNCHENTOOT-BACKEND"
                              :http-server-backend-hunchentoot)))))

(defun decode-sse-body (body &key on-event)
  "Decode AG-UI events from a stream, string, or octets. ON-EVENT fires per event."
  (let ((src (cond
               ((streamp body)
                (sse-protocol:make-sse-input-stream body))
               ((stringp body) (make-string-input-stream body))
               ((and (vectorp body) (not (stringp body)))
                (make-string-input-stream
                 (babel:octets-to-string body :encoding :utf-8)))
               (t (make-string-input-stream "")))))
    (if (typep src 'sse-protocol:sse-object-input-stream)
        (let ((out '()))
          (loop for ev = (io-protocol:read-object src)
                until (eq ev :eof)
                do (let ((decoded (ag-ui-protocol:decode-ag-ui-event
                                   (sse-protocol:sse-event-data ev))))
                     (when on-event (funcall on-event decoded))
                     (push decoded out)))
          (nreverse out))
        (ag-ui-protocol:decode-ag-ui-sse-stream src :on-event on-event))))

(defun %run-remote (backend input on-event)
  "POST RunAgentInput via SEND-ASYNC; decode SSE on the event loop."
  (%ensure-http)
  (multiple-value-bind (eb el) (%ensure-loop)
    (let* ((payload (ag-ui-protocol:encode-json
                     (ag-ui-protocol:encode-run-agent-input
                      (if (typep input 'ag-ui-protocol:run-agent-input)
                          input
                          (ag-ui-protocol:decode-run-agent-input input)))))
           (client (or http-protocol:*http-client*
                       (http-protocol:make-http-client http-protocol:*http-backend*)))
           (req (http-protocol:make-http-request
                 :method :post
                 :url (%ensure-url backend)
                 :content payload
                 :headers '(("content-type" . "application/json")
                            ("accept" . "text/event-stream"))))
           (events nil)
           (err nil))
      (http-protocol:send-async
       http-protocol:*http-backend* client req
       :callback
       (lambda (res)
         (handler-case
             (let ((status (http-protocol:response-status res)))
               (unless (<= 200 status 299)
                 (error 'ag-ui-protocol:ag-ui-run-error
                        :code status
                        :message (format nil "HTTP ~a" status)))
               (setf events (decode-sse-body (http-protocol:response-body res)
                                             :on-event on-event)))
           (error (e) (setf err e)))
         (event:stop eb el))
       :error-callback
       (lambda (c)
         (setf err c)
         (event:stop eb el)))
      (event:run eb el :stop-when-idle nil)
      (when err (error err))
      events)))

(defmethod ag-ui-protocol:run-agent ((backend sse-ag-ui-backend) input
                                     &key on-event)
  (if (backend-url backend)
      (%run-remote backend input on-event)
      (let ((agent (or (backend-agent backend)
                       (ag-ui-protocol:make-ag-ui-agent))))
        (ag-ui-protocol:run-agent agent input :on-event on-event))))

(defmethod ag-ui-protocol:serve-ag-ui ((backend sse-ag-ui-backend)
                                       &key (path nil)
                                         (host "127.0.0.1")
                                         (port 8080))
  (%ensure-http-server)
  (let* ((agent (or (backend-agent backend)
                    (ag-ui-protocol:make-ag-ui-agent)))
         (app-path (or path (backend-path backend) "/"))
         (app (ag-ui-protocol:make-ag-ui-app agent :path app-path)))
    (http-server-protocol:serve app :host host :port port)))

(use-sse-ag-ui-backend)
