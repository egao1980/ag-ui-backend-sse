(in-package #:ag-ui-backend-sse/tests)

(deftest backend-class
  (ok (typep (ag-ui-backend-sse:make-sse-ag-ui-backend) 'ag-ui-backend-sse:sse-ag-ui-backend)))
