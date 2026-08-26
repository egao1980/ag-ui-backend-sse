(in-package #:ag-ui-backend-sse)

;;; SSE wire via sse-protocol. AG-UI codec is not JSON-RPC.

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
      (error 'ag-ui-protocol:ag-ui-error
             :message "sse AG-UI backend has no :url")))

(defun %body-string (response)
  (let ((b (http-protocol:response-body response)))
    (cond
      ((stringp b) b)
      ((and (vectorp b) (not (stringp b)))
       (babel:octets-to-string b :encoding :utf-8))
      (t ""))))

(defun %ensure-http-server ()
  (or http-server-protocol:*http-server-backend*
      (progn
        (asdf:load-system "http-server-backend-hunchentoot")
        (funcall (find-symbol "USE-HUNCHENTOOT-BACKEND"
                              :http-server-backend-hunchentoot)))))

(defmethod ag-ui-protocol:run-agent ((backend sse-ag-ui-backend) input
                                     &key on-event)
  (if (backend-url backend)
      (progn
        (%ensure-http)
        (let* ((payload (ag-ui-protocol:encode-json
                         (ag-ui-protocol:encode-run-agent-input
                          (if (typep input 'ag-ui-protocol:run-agent-input)
                              input
                              (ag-ui-protocol:decode-run-agent-input input)))))
               (res (http:post (%ensure-url backend)
                               :content payload
                               :headers '(("content-type" . "application/json")
                                          ("accept" . "text/event-stream"))))
               (status (http-protocol:response-status res)))
          (unless (<= 200 status 299)
            (error 'ag-ui-protocol:ag-ui-error
                   :message (format nil "HTTP ~a" status)))
          (ag-ui-protocol:decode-ag-ui-sse-stream (%body-string res)
                                                  :on-event on-event)))
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
