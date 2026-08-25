(in-package #:ag-ui-backend-sse)

;;; SSE wire is rpc-backend-sse. AG-UI codec is not JSON-RPC — do not
;;; wrap events in a JSON-RPC envelope.

(defclass sse-ag-ui-backend (ag-ui-protocol:ag-ui-backend)
  ((transport :initarg :transport :accessor backend-transport :initform nil)))

(defun make-sse-ag-ui-backend (&key transport)
  (make-instance 'sse-ag-ui-backend
                 :transport (or transport rpc-protocol:*rpc-transport*)))

(defun use-sse-ag-ui-backend (&rest args &key &allow-other-keys)
  (setf ag-ui-protocol:*ag-ui-backend* (apply #'make-sse-ag-ui-backend args)))

(defmethod ag-ui-protocol:run-agent ((backend sse-ag-ui-backend) input
                                     &key on-event
                                       (transport (or (backend-transport backend)
                                                      rpc-protocol:*rpc-transport*)))
  (call-next-method backend input :on-event on-event :transport transport))

(use-sse-ag-ui-backend)
