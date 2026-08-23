(in-package #:ag-ui-backend-sse)

(defclass sse-ag-ui-backend (ag-ui-protocol:ag-ui-backend) ())

(defun make-sse-ag-ui-backend ()
  (make-instance 'sse-ag-ui-backend))

(defun use-sse-ag-ui-backend ()
  (setf ag-ui-protocol:*ag-ui-backend* (make-sse-ag-ui-backend)))
